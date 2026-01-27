#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

@_spi(Private) import Sentry

/**
 * Function to call through to save a view hierarchy, which can be passed around
 * as a function pointer in the C crash reporting code or called directly from tests.
 * @param reportDirectoryPath The path to the directory containing crash reporting files, in which a
 * new file will be created to store the view hierarchy description.
 */
@_cdecl("saveViewHierarchy")
public func saveViewHierarchy(_ reportDirectoryPath: UnsafePointer<CChar>?) {
    guard let reportDirectoryPath = reportDirectoryPath else { return }
    let reportPath = String(cString: reportDirectoryPath)
    let filePath = (reportPath as NSString).appendingPathComponent("view-hierarchy.json")
    SentryDependencyContainer.sharedInstance().viewHierarchyProvider?.saveViewHierarchy(filePath)
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
