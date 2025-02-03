module.exports = ({ github, context, core }) => {
  const fs = require("fs");
  const path = require("path");

  try {
    const logsDir = path.join("~/Library/Logs/scan");
    if (!fs.existsSync(logsDir)) {
      throw new Error("No logs directory found");
    }
    const logs = fs.readdirSync(logsDir);
    const lastLog = logs[logs.length - 1];
    if (!lastLog) {
      throw new Error("No logs found");
    }
    const lastLogPath = path.join(logsDir, lastLog);
    const lastLogContent = fs.readFileSync(lastLogPath, "utf8");
    const retryReasonRegexs = [
      /Test\srunner\snever\sbegan\sexecuting\stests\safter\slaunching/,
    ];
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
