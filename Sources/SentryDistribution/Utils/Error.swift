enum Error: Swift.Error {
  case invalidUrl
  case noBundleId
  case invalidData
  case requestError(Swift.Error)
  case decodeError(Swift.Error)
  case unknownError
}
