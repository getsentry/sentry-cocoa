#!/usr/bin/env node

/**
 * SauceLabs Helpers
 *
 * This script provides utility functions for managing SauceLabs tests and jobs,
 * extracted from the benchmarking GitHub Actions workflow.
 *
 * See each function for more details.
 *
 * USAGE:
 *
 * 1. Set environment variables:
 *    export SAUCE_USERNAME="your-username"
 *    export SAUCE_ACCESS_KEY="your-access-key"
 *
 * 2. Run specific functions:
 *    node saucelabs-helpers.js check-test-recovery output.log
 *    node saucelabs-helpers.js cancel-jobs output.log retry-output.log
 *
 * FUNCTIONS:
 * - shouldRetryTest(logFile): Checks if a failed test should be retried (async)
 * - cancelJobs(logFiles): Cancels SauceLabs jobs found in log files (async)
 */

const fs = require("fs");

// SauceLabs API configuration

/**
 * Check if SauceLabs credentials are available
 * @returns {{username: string, accessKey: string}|undefined} Credentials if set in environment variables, undefined otherwise
 */
function getCredentialsFromEnv() {
  if (!process.env.SAUCE_USERNAME || !process.env.SAUCE_ACCESS_KEY) {
    console.error(
      `ERROR: SauceLabs credentials not found. Please set SAUCE_USERNAME and SAUCE_ACCESS_KEY environment variables.`
    );
    return undefined;
  }
  return {
    username: process.env.SAUCE_USERNAME,
    accessKey: process.env.SAUCE_ACCESS_KEY,
  };
}

/**
 * Extract unique SauceLabs job IDs from multiple log files
 *
 * @param {string[]} logFiles - Paths to log files to search for job IDs
 * @returns {Set<string>} Set of unique job IDs found across all log files, empty if none found
 */
function extractJobIdsFromLogs(logFiles) {
  const uniqueJobIds = new Set();

  // Extract SauceLabs test URLs and get job IDs
  // Note: The CLI output might change over time, so this regex might need to be updated.
  const urlRegex = /https:\/\/app\.saucelabs\.com\/tests\/([^\s]+)/g;

  for (const logFile of logFiles) {
    try {
      if (!fs.existsSync(logFile)) {
        console.log(`Log file ${logFile} not found, skipping...`);
        return;
      }

      console.log(`Checking ${logFile} for SauceLabs test IDs...`);
      const logContent = fs.readFileSync(logFile, "utf8");

      let match;
      while ((match = urlRegex.exec(logContent)) !== null) {
        const jobId = match[1];
        if (jobId) {
          uniqueJobIds.add(jobId);
          console.log(`Found SauceLabs job ID: ${jobId}`);
        }
      }
    } catch (error) {
      console.error(`Error reading log file ${logFile}: ${error.message}`);
    }
  }

  console.log(`Total unique job IDs found: ${uniqueJobIds.size}`);
  for (const jobId of uniqueJobIds) {
    console.log(` - ${jobId}`);
  }
  return uniqueJobIds;
}

/**
 * Sends an authenticated API request
 *
 * @param {string} apiPath - The API path (e.g., "/jobs/123/stop") relative to the base URL, must start with a slash
 * @param {RequestInit} options - The options to pass to the fetch function
 * @returns {Promise<Response>} The response from the API
 */
async function sendAuthenticatedAPIRequest(apiPath, options) {
  const credentials = getCredentialsFromEnv();
  if (!credentials) {
    throw new Error("SauceLabs credentials not available");
  }

  const auth = Buffer.from(
    `${credentials.username}:${credentials.accessKey}`
  ).toString("base64");

  // Construct URL properly (don't use path.join for URLs)
  const url = `https://api.us-west-1.saucelabs.com/rest/v1/${credentials.username}${apiPath}`;

  return await fetch(url, {
    ...options,
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/json",
      ...options.headers,
    },
  });
}

/**
 * Cancel a SauceLabs job via REST API
 * Reference: https://docs.saucelabs.com/dev/api/jobs/#stop-a-job
 * @param {string} jobId - The job ID to cancel
 * @returns {Promise<boolean>} True if successful, false otherwise
 */
async function cancelJob(jobId) {
  console.log(`Attempting to cancel SauceLabs job: ${jobId}`);

  try {
    const credentials = getCredentialsFromEnv();
    const auth = Buffer.from(
      `${credentials.username}:${credentials.accessKey}`
    ).toString("base64");

    // Real Device Cloud (RDC) jobs use the /rest/v1/rdc/jobs API and do not include the username in the path
    const response = await fetch(
      `https://api.us-west-1.saucelabs.com/rest/v1/rdc/jobs/${jobId}/stop`,
      {
        method: "PUT",
        headers: {
          Authorization: `Basic ${auth}`,
          "Content-Type": "application/json",
        },
      }
    );

    if (response.ok) {
      console.log(`Successfully cancelled SauceLabs job: ${jobId}`);
      return true;
    }
    if (response.status === 404) {
      console.log(`Job ${jobId} not found (may already be finished)`);
      return false;
    }
    const errorText = await response.text();
    console.log(
      `Failed to cancel job ${jobId}: HTTP ${response.status} - ${errorText}`
    );
    return false;
  } catch (error) {
    console.log(`Error cancelling job ${jobId}: ${error.message}`);
    return false;
  }
}

/**
 * Cancel SauceLabs jobs found in the provided log files
 * This function mimics the cancellation logic from the GitHub Actions workflow
 *
 * @param {string[]} logFiles - Paths to log files to search for job IDs
 * @returns {Promise<{success: boolean, totalJobs?: number, cancelledJobs?: number, reason: string}>} Result object with cancelled job count and details
 */
async function cancelJobs(logFiles) {
  console.log("Attempting to cancel SauceLabs jobs from log files");

  if (!getCredentialsFromEnv()) {
    console.error("Missing SauceLabs credentials");
    return { success: false, reason: "Missing SauceLabs credentials" };
  }

  const jobIds = extractJobIdsFromLogs(logFiles);

  if (jobIds.size === 0) {
    console.log("No SauceLabs job IDs found in log files");
    return {
      success: true,
      cancelledJobs: 0,
      reason: "No jobs found to cancel",
    };
  }

  console.log(`Found ${jobIds.size} unique job(s) to cancel`);

  let cancelledCount = 0;
  for (const jobId of jobIds) {
    const cancelled = await cancelJob(jobId);
    if (cancelled) {
      cancelledCount++;
    }
  }

  return {
    success: true,
    totalJobs: jobIds.size,
    cancelledJobs: cancelledCount,
    reason: `Cancelled ${cancelledCount} out of ${jobIds.size} jobs`,
  };
}

/**
 * Helper function to check job status via SauceLabs API
 * @param {string} testId - The test ID to check
 * @returns {Promise<boolean>} True if should retry, false if completed successfully
 */
async function checkJobStatus(testId) {
  const response = await sendAuthenticatedAPIRequest(`/jobs/${testId}`, {
    method: "GET",
  });

  // TODO: The fetching of the job status is not working as expected, because job is never found, even when it exists.
  if (response.status === 404) {
    console.log(
      `Test ${testId} not found in SauceLabs --> should retry (job never existed)`
    );
    return true;
  }

  if (!response.ok) {
    const errorText = await response.text();
    console.log(
      `Failed to check test ${testId}: HTTP ${response.status} - ${errorText} --> should retry`
    );
    return true;
  }

  const jobData = await response.json();
  console.log(
    `Test ${testId} found. Status: "${jobData.status}", Error: ${jobData.error}, Passed: ${jobData.passed}`
  );

  if (jobData.status === "complete" && jobData.error === null) {
    console.log(
      `Test ${testId} completed successfully by SauceLabs --> should not retry`
    );
    return false;
  }

  const reason = jobData.error || `incomplete status: ${jobData.status}`;
  console.log(
    `Test ${testId} had infrastructure issues: ${reason} --> should retry`
  );
  return true;
}

/**
 * Check if a failed SauceLabs test should be retried
 *
 * IMPORTANT: This method assumes it's only called when the workflow has already
 * reported a failure status. It determines whether that failure was due to SauceLabs
 * infrastructure issues (should retry) or legitimate test failures (should not retry).
 *
 * RETRY DECISION LOGIC:
 * This function implements the core retry logic for SauceLabs benchmarking tests.
 * It addresses the problem where SauceLabs internal errors cause CI failures that
 * can be resolved by simply re-running the test.
 *
 * Decision Tree:
 * 1. Extract test ID from log file
 *    - If no test ID found → RETRY (SauceLabs failed to start the test)
 * 2. Query SauceLabs API for detailed job information
 *    - If 404 (not found) → RETRY (job never existed, infrastructure issue)
 *    - If 200 (exists) → analyze job details:
 *      - status="complete" AND error=null → DON'T RETRY (legitimate test result)
 *      - status="error" OR error field present → RETRY (infrastructure error)
 *      - status incomplete (running/queued) → RETRY (job never finished)
 *    - If other HTTP error → RETRY (SauceLabs API problems)
 * 3. Network/credential errors → RETRY (temporary issues)
 *
 * Key Fields from SauceLabs API Response:
 * - status: "complete", "error", "running", "queued", etc.
 * - error: null if no infrastructure errors, string if SauceLabs had issues
 * - passed: true/false (only meaningful if status is "complete" and error is null)
 * - consolidated_status: "passed", "failed", "error", etc.
 *
 * The key principle: Only retry when we can't confirm that SauceLabs successfully
 * completed the test execution (status="complete" AND error=null). If SauceLabs
 * completed the test run, the actual test result (pass/fail) doesn't matter for
 * retry decisions - retrying won't fix legitimate test failures.
 *
 * Background: SauceLabs infrastructure issues were causing frequent CI failures
 * where re-triggering the workflow would make tests pass. This retry mechanism
 * automates that re-triggering but only when appropriate.
 *
 * Reference: https://docs.saucelabs.com/dev/api/jobs/#get-a-job
 * @param {string} logFile - Path to the output log file from saucectl
 * @returns {Promise<{shouldRetry: boolean, reason: string}>} Result object with shouldRetry boolean and reason string
 */
async function shouldRetryTest(logFile) {
  console.log(`Checking if the test should be retried: ${logFile}`);
  if (!getCredentialsFromEnv()) {
    return { shouldRetry: false, reason: "Missing SauceLabs credentials" };
  }

  console.log(`Extracting test ID from output log: ${logFile}`);
  const jobIds = extractJobIdsFromLogs([logFile]);
  const jobId = jobIds.size > 0 ? Array.from(jobIds)[0] : null;

  if (!jobId) {
    console.warn(
      "No SauceLabs test ID found in output log, it might have changed --> should retry test"
    );
    return { shouldRetry: true, reason: "No test ID found in log" };
  }

  console.log(`Found test ID: ${jobId}, checking status in SauceLabs...`);

  try {
    const shouldRetry = await checkJobStatus(jobId);

    if (shouldRetry) {
      console.log("Test should be retried");
      return {
        shouldRetry: true,
        reason: "Test failed or not found in SauceLabs",
      };
    }

    console.log(
      "Test did not have infrastructure issues in SauceLabs --> should not retry"
    );
    return {
      shouldRetry: false,
      reason: "Test exists and did not have infrastructure issues in SauceLabs",
    };
  } catch (error) {
    console.log(
      `Error checking test ${jobId}: ${error.message} --> should retry`
    );
    return {
      shouldRetry: true,
      reason: "Network error checking SauceLabs status",
    };
  }
}

/**
 * Main function to run the script
 * @returns {Promise<void>}
 */
async function main() {
  /**
   * Print usage information
   */
  function printUsage() {
    console.log("Usage:");
    console.log("  node saucelabs-helpers.js check-test-recovery <logFile>");
    console.log(
      "  node saucelabs-helpers.js cancel-jobs <logFile1> [<logFile2> ...]"
    );
  }

  /**
   * Parses the arguments and runs the cancelJobs command
   * @param {string[]} args - The arguments to parse
   * @returns {Promise<void>}
   */
  async function runCancelJobs(args) {
    if (args.length < 2) {
      console.error("Missing log file argument(s) for cancelJobs");
      printUsage();
      process.exit(1);
    }

    const logFiles = args.slice(1);
    try {
      const result = await cancelJobs(logFiles);
      console.log("Cancel jobs result:", result);
      process.exit(result.success ? 0 : 2);
    } catch (err) {
      console.error("Error running command:", err);
      process.exit(2);
    }
  }

  /**
   * Parses the arguments and runs the checkTestRecovery command
   * @param {string[]} args - The arguments to parse
   * @returns {Promise<void>}
   */
  async function runCheckTestRecovery(args) {
    if (args.length < 2) {
      console.error("Missing log file argument for checkTestRecovery");
      printUsage();
      process.exit(1);
    }

    try {
      const shouldRetry = await shouldRetryTest(args[1]);
      process.exit(shouldRetry ? 0 : 2);
    } catch (err) {
      console.error("Error running command:", err);
      process.exit(2);
    }
  }

  // Remove the node command and the script name from the arguments
  const args = process.argv.slice(2);
  if (args.length === 0) {
    printUsage();
    process.exit(0);
  }

  // Parse the command and run the appropriate function
  const command = args[0];
  switch (command) {
    case "check-test-recovery":
      await runCheckTestRecovery(args);
      break;
    case "cancel-jobs":
      await runCancelJobs(args);
      break;
    default:
      console.error(`Unknown command: ${command}`);
      printUsage();
      process.exit(3);
  }
}

if (require.main === module) {
  // Only run the main function if the script is run directly
  main().catch((err) => {
    console.error("Error running main:", err);
    process.exit(1);
  });
}

// Export functions for use as a module in the GitHub Actions workflow
module.exports = {
  shouldRetryTest,
  cancelJobs,
};
