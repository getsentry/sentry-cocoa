class URLSessionTaskMock: URLSessionTask {
    private var _state: URLSessionTask.State = .suspended
    private var _request: URLRequest
    
    override var state: URLSessionTask.State {
        get {
            return _state
        }
        set {
            _state = newValue
        }
    }
    override var currentRequest: URLRequest? {
        get { return _request }
    }
    
    init(request: URLRequest) {
        _request = request
    }
}
