import Vapor

public func routes(_ app: Application) {
    app.get { _ in
        "It works!"
    }

    app.get("health") { _ in
        "OK"
    }

    app.get("echo-baggage-header") { request in
        echoedHeader(named: "baggage", from: request)
    }

    app.get("echo-sentry-trace") { request in
        echoedHeader(named: "sentry-trace", from: request)
    }

    app.get("http-client-error") { _ -> String in
        throw Abort(.badRequest)
    }
}

private func echoedHeader(named name: HTTPHeaders.Name, from request: Request) -> String {
    request.headers[name].first ?? "(NO-HEADER)"
}
