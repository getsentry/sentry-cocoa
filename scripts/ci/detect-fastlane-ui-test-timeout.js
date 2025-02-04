module.exports = ({ github, context, core }) => {
  const fs = require("fs");
  const path = require("path");

  try {
    const logsDir = path.join(process.env.HOME, "Library", "Logs", "scan");
    console.log("Checking logs directory:", logsDir);
    if (!fs.existsSync(logsDir)) {
      throw new Error("No logs directory found");
    }
    console.log("Logs directory exists, looking for logs...");
    const logs = fs.readdirSync(logsDir);
    console.log(`Found ${logs.length} logs`);
    const lastLog = logs[logs.length - 1];
    if (!lastLog) {
      throw new Error("No logs found");
    }
    const lastLogPath = path.join(logsDir, lastLog);
    console.log("Last log path:", lastLogPath);

    const lastLogContent = fs.readFileSync(lastLogPath, "utf8");
    const retryReasonRegexs = [
      /Test\srunner\snever\sbegan\sexecuting\stests\safter\slaunching/,
    ];
    console.log("Checking for retry reason...");
    const retryReason = retryReasonRegexs.find((regex) =>
      lastLogContent.match(regex)
    );
    if (retryReason) {
      core.warning("Retry condition found, retrying...");
      core.setOutput("RETRY_TEST", "true");

      return;
    }

    throw new Error("Retry condition not found!");
  } catch (error) {
    core.setFailed(error.message);
  }
};
