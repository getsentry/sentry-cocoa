import Foundation

extension URLSession {
  
  func perform<T: Sendable & Decodable>(
    _ request: URLRequest,
    decode decodable: T.Type,
    completion: @escaping @Sendable (Result<T, Error>) -> Void) {
    dataTask(with: request) { (data, response, error) in
      var result: Result<T, Error> = .failure(.unknownError)
      defer {
        completion(result)
      }
      if let error = error {
        result = .failure(.requestError(error))
        return
      }
      guard let httpResponse = response as? HTTPURLResponse,
            let data = data else {
        result = .failure(.invalidData)
        return
      }
      guard (200...299).contains(httpResponse.statusCode) else {
        result = .failure(.unknownError)
        return
      }
      
      do {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        result = .success(try jsonDecoder.decode(decodable, from: data))
      } catch {
        result = .failure(.decodeError(error))
      }
    }.resume()
  }

}
