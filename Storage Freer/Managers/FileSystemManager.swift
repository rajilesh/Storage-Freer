import Foundation
import AppKit
import UniformTypeIdentifiers

/// Manages file system operations such as scanning directories and calculating sizes.
public class FileSystemManager: ObservableObject {
    @Published public var items: [FileSystemItem] = []
    @Published public var totalSize: Int64 = 0
    @Published public var rootTotalSize: Int64 = 0
    @Published public var isCalculating = false
    @Published public var hasPermissionIssues = false
    @Published public var showPermissionAlert = false

    private var sizeCache: [URL: Int64] = [:]
    private let fileManager = FileManager.default
    private let directoryQueue = DispatchQueue(label: "com.soance.storagefreer.directoryscanner", qos: .userInitiated, attributes: .concurrent)
    private let cacheQueue = DispatchQueue(label: "com.soance.storagefreer.cachequeue")

    public init() {}

    /// Scans the contents of a given directory URL.
    /// - Parameter url: The URL of the directory to scan. If `nil`, the root directory "/" is used.
    public func scanDirectory(at url: URL?) {
        let directoryURL = url ?? URL(fileURLWithPath: "/")

        // Update UI immediately to show we are starting
        DispatchQueue.main.async {
            self.isCalculating = true
            self.hasPermissionIssues = false
            self.items = []
            self.totalSize = 0
            self.rootTotalSize = 0
        }

        directoryQueue.async {
            do {
                let contents = try self.fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [])

                var initialItems: [FileSystemItem] = []
                for itemURL in contents {
                    var isDirectory = false
                    do {
                        let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
                        isDirectory = resourceValues.isDirectory ?? false
                    } catch {
                        print("Error accessing resource values for \(itemURL.path): \(error.localizedDescription)")
                    }

                    let newItem = FileSystemItem(path: itemURL, isDirectory: isDirectory)
                    newItem.isCalculating = true // Mark for spinner UI
                    initialItems.append(newItem)
                }

                DispatchQueue.main.async {
                    self.items = initialItems
                    self.calculateSizes(for: initialItems)
                }
            } catch {
                DispatchQueue.main.async {
                    self.hasPermissionIssues = true
                    self.isCalculating = false
                    print("Error scanning directory: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Scans the entire file system starting from the root directory.
    public func scanEntireFileSystem() {
        let rootURL = URL(fileURLWithPath: "/")
        directoryQueue.async {
            do {
                let contents = try self.fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [])
                var initialItems: [FileSystemItem] = []
                for itemURL in contents {
                    var isDirectory = false
                    do {
                        let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
                        isDirectory = resourceValues.isDirectory ?? false
                    } catch {
                        print("Error accessing resource values for \(itemURL.path): \(error.localizedDescription)")
                    }

                    let newItem = FileSystemItem(path: itemURL, isDirectory: isDirectory)
                    newItem.isCalculating = true // Mark for spinner UI
                    initialItems.append(newItem)
                }

                DispatchQueue.main.async {
                    self.items = initialItems
                    self.calculateSizes(for: initialItems)
                }
            } catch {
                DispatchQueue.main.async {
                    self.hasPermissionIssues = true
                    self.isCalculating = false
                    print("Error scanning root directory: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Calculates the sizes of the items in the `items` array.
    private func calculateSizes(for itemsToProcess: [FileSystemItem]) {
        let group = DispatchGroup()
        let totalSizeQueue = DispatchQueue(label: "com.soance.storagefreer.totalsize")
        var runningTotalSize: Int64 = 0
        var runningPermissionIssues = false

        for item in itemsToProcess {
            group.enter()

            directoryQueue.async {
                let size = self.calculateSize(at: item.path)

                totalSizeQueue.sync {
                    if size >= 0 {
                        runningTotalSize += size
                    } else {
                        runningPermissionIssues = true
                    }
                }

                DispatchQueue.main.async {
                    if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                        let fileItem = self.items[index]
                        fileItem.size = size
                        fileItem.isCalculating = false
                        if size < 0 {
                            fileItem.error = "Permission Denied"
                        }
                        // Incrementally update totalSize as each item is calculated
                        if size >= 0 {
                            self.totalSize += size
                        }
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            // self.totalSize is updated incrementally now.
            self.rootTotalSize = runningTotalSize
            self.hasPermissionIssues = self.hasPermissionIssues || runningPermissionIssues

            // Sort once at the very end
            self.items.sort { (item1, item2) -> Bool in
                (item1.size ?? -1) > (item2.size ?? -1)
            }

            self.isCalculating = false
        }
    }

    /// Recursively calculates the size of a directory or file.
    /// - Parameter url: The URL of the item.
    /// - Returns: The size in bytes, or -1 if there was a permission error.
    private func calculateSize(at url: URL) -> Int64 {
        var cachedResult: Int64?
        cacheQueue.sync {
            cachedResult = self.sizeCache[url]
        }
        if let cachedSize = cachedResult {
            return cachedSize
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return 0
        }

        if !isDirectory.boolValue {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                let size = attributes[.size] as? Int64 ?? 0
                cacheQueue.sync { self.sizeCache[url] = size }
                return size
            } catch {
                cacheQueue.sync { self.sizeCache[url] = -1 }
                return -1 // Permission error
            }
        }

        var totalSize: Int64 = 0
        var permissionErrorOccurred = false
        let errorHandler = { (url: URL, error: Error) -> Bool in
            permissionErrorOccurred = true
            return true // Continue enumerating
        }

        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .totalFileSizeKey, .totalFileAllocatedSizeKey], options: [.skipsHiddenFiles], errorHandler: errorHandler) else {
            cacheQueue.sync { self.sizeCache[url] = -1 }
            return -1 // Permission error
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            } catch {
                permissionErrorOccurred = true
            }
        }

        if permissionErrorOccurred && !self.hasPermissionIssues {
            DispatchQueue.main.async {
                self.hasPermissionIssues = true
                if !self.checkFullDiskAccess() {
                    self.showPermissionAlert = true
                }
            }
        }

        cacheQueue.sync { self.sizeCache[url] = totalSize }
        return totalSize
    }

    private func checkFullDiskAccess() -> Bool {
        let testURL = URL(fileURLWithPath: "/Library/Application Support")
        do {
            _ = try fileManager.contentsOfDirectory(atPath: testURL.path)
            return true
        } catch {
            return false
        }
    }

    /// Opens the given URL in Finder.
    public func openInFinder(at url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Opens the Privacy & Security settings for Full Disk Access.
    public func openPrivacySettings() {
        if let url = URL(string: "x-apple-systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Loads children (subfolders) for a given FileSystemItem. Only loads folders.
    public func loadChildren(for item: FileSystemItem, completion: (() -> Void)? = nil) {
        guard item.isDirectory else { completion?(); return }
        directoryQueue.async {
            do {
                let contents = try self.fileManager.contentsOfDirectory(at: item.path, includingPropertiesForKeys: [.isDirectoryKey], options: [])
                var children: [FileSystemItem] = []
                for url in contents {
                    let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if isDirectory {
                        let child = FileSystemItem(path: url, isDirectory: isDirectory)
                        children.append(child)
                    }
                }
                DispatchQueue.main.async {
                    item.children = children
                    self.calculateSizes(for: children)
                    completion?()
                }
            } catch {
                DispatchQueue.main.async {
                    item.children = []
                    item.error = "Permission Denied"
                    completion?()
                }
            }
        }
    }

    /// Formats bytes into a human-readable string (e.g., "1.23 GB").
    public static func formatBytes(_ bytes: Int64) -> String {
        guard bytes >= 0 else { return "Access Denied" }
        guard bytes > 0 else { return "0 B" }

        let units = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"]
        let digitGroups = Int(log2(Double(bytes)) / 10)

        return String(format: "%.2f %@", Double(bytes) / pow(1024, Double(digitGroups)), units[digitGroups])
    }

    /// Requests access to a directory if permission issues are encountered.
    /// - Parameter url: The URL of the directory to request access for.
    private func requestAccess(to url: URL) {
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.message = "Permission required to access this directory."
            openPanel.directoryURL = url
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.allowsMultipleSelection = false

            if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
                self.storeBookmark(for: selectedURL)
                do {
                    let bookmarkData = try selectedURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    UserDefaults.standard.set(bookmarkData, forKey: "Bookmark_\(selectedURL.path)")
                    print("Access granted for: \(selectedURL.path)")
                } catch {
                    print("Failed to create bookmark for \(selectedURL.path): \(error.localizedDescription)")
                }
            }
        }
    }

    /// Stores a security-scoped bookmark for a given URL.
    /// - Parameter url: The URL to store the bookmark for.
    private func storeBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "Bookmark_\(url.path)")
            print("Bookmark stored for: \(url.path)")
        } catch {
            print("Failed to store bookmark for \(url.path): \(error.localizedDescription)")
        }
    }

    /// Resolves a security-scoped bookmark for a given path.
    /// - Parameter path: The path to resolve the bookmark for.
    /// - Returns: The resolved URL if successful, or nil.
    private func resolveBookmark(for path: String) -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "Bookmark_\(path)") else {
            return nil
        }

        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                print("Bookmark is stale for: \(path)")
            }
            return url
        } catch {
            print("Failed to resolve bookmark for \(path): \(error.localizedDescription)")
            return nil
        }
    }
}

