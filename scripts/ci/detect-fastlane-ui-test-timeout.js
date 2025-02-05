module.exports = ({ github, context, core }, pathToLogFile) => {
  const fs = require("fs");
  const path = require("path");

  try {
    core.info("Checking if log file exists:", pathToLogFile);
    if (!fs.existsSync(pathToLogFile)) {
      throw new Error("Log file does not exist");
    }

    core.info("Reading log file:", pathToLogFile);
    const lastLogContent = fs.readFileSync(pathToLogFile, "utf8");

    if (core.isDebug()) {
      core.debug("Log file content:");
      core.debug(lastLogContent);
    }

    const retryReasonRegexs = [
      /Test\srunner\snever\sbegan\sexecuting\stests\safter\slaunching/,
    ];

    core.info("Checking log content for retry reason...");
    const retryReason = retryReasonRegexs.find((regex) =>
      lastLogContent.match(regex)
    );
    if (!retryReason) {
      throw new Error("Retry condition not found!");
    }

    core.warning("Retry condition found, retrying...");
    core.setOutput("RETRY_TEST", "true");
  } catch (error) {
    core.setFailed(error.message);
  }
};
