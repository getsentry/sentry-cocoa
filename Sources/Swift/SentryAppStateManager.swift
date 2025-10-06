@_spi(Private) @objc public protocol SentryAppStateManager {
    var startCount: Int { get }
    
    func start()
    func stop()
    func stop(withForce force: Bool)
    
    /**
     * Builds the current app state.
     * @discussion The systemBootTimestamp is calculated by taking the current time and subtracting
     * @c NSProcesInfo.systemUptime . @c NSProcesInfo.systemUptime returns the amount of time the system
     * has been awake since the last time it was restarted. This means This is a good enough
     * approximation about the timestamp the system booted.
     */
    func buildCurrentAppState() -> SentryAppState
    
    func loadPreviousAppState() -> SentryAppState?
    
    func storeCurrentAppState()
    
    func updateAppState(_ block: @escaping (SentryAppState) -> Void)
}
