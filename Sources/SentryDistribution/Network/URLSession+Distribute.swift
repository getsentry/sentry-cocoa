import Foundation

enum RequestError: Error {
  case invalidData
  case unknownError
}

extension URLSession {
  func checkForUpdate(_ request: URLRequest, completion: @escaping @MainActor (Result<UpdateCheckResponse, Error>) -> Void) {
    self.perform(request, decode: UpdateCheckResponse.self, completion: completion)
  }
  
  private func perform<T: Sendable & Decodable>(
    _ request: URLRequest,
    decode decodable: T.Type,
    completion: @escaping @MainActor (Result<T, Error>) -> Void) {
    URLSession.shared.dataTask(with: request) { (data, response, error) in
      var result: Result<T, Error> = .failure(RequestError.unknownError)
      defer {
        DispatchQueue.main.async { [result] in
          completion(result)
        }
      }
      if let error = error {
        result = .failure(error)
        return
      }
      guard let httpResponse = response as? HTTPURLResponse,
            let data = data else {
        result = .failure(RequestError.invalidData)
        return
      }
      guard (200...299).contains(httpResponse.statusCode) else {
        result = .failure(RequestError.unknownError)
        return
      }
      
      do {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        result = .success(try jsonDecoder.decode(decodable, from: data))
      } catch {
        result = .failure(error)
      }
    }.resume()
  }

}
