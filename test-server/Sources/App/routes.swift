import Vapor

func routes(_ app: Application) throws {
    app.get { _ in
        return "It works!"
    }

    app.get("hello") { request -> String in
        let tracestate = request.headers["tracestate"]
        if let sentryTraceHeader = tracestate.first {
            // We just validate if the trace header is there.
            // The proper format of the trace header is covered
            // with unit tests.
            if sentryTraceHeader.starts(with: "sentry=") {
                return "Hello, world! Trace header added."
            }
        }
        
        return "Hello, world!"
    }
}
