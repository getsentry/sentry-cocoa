import Vapor

func routes(_ app: Application) throws {
    app.get { _ in
        return "It works!"
    }

    app.get("hello") { _ -> String in
        return "Hello, world!"
    }
}
