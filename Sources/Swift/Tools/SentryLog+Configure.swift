@_implementationOnly import _SentryPrivate

extension SentryLog {

  @objc
  public static func configure(_ isDebug: Bool, diagnosticLevel: SentryLevel) {
      _configure(isDebug, diagnosticLevel: diagnosticLevel)
    SentryAsyncLogWrapper.initializeAsyncLogFile()
  }
}
