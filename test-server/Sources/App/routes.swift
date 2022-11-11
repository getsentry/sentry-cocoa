import Vapor

func routes(_ app: Application) throws {
    app.get { _ in
        return "It works!"
    }

    app.get("echo-baggage-header") { request -> String in
        let baggage = request.headers["baggage"]
        if let sentryTraceHeader = baggage.first {
          return sentryTraceHeader
        }

        return "(NO-HEADER)"
    }

    app.get("echo-sentry-trace") { request -> String in
        let trace_id = request.headers["sentry-trace"]
        if let sentryTraceHeader = trace_id.first {
            return sentryTraceHeader
        }
        
        return "(NO-HEADER)"
    }

    app.get("http-client-error") { _ -> String in
        throw Abort(.badRequest)
    }
}
