import Foundation
import AppKit

/// Manages file system operations such as scanning directories and calculating sizes.
public class FileSystemManager: ObservableObject {
    @Published public var items: [FileSystemItem] = []
    @Published public var totalSize: Int64 = 0
    @Published public var isCalculating = false
    @Published public var hasPermissionIssues = false

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
        }

        directoryQueue.async {
            do {
                let contents = try self.fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: .skipsHiddenFiles)
                
                var initialItems: [FileSystemItem] = []
                for itemURL in contents {
                    var isDirectory = false
                    do {
                        let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
                        isDirectory = resourceValues.isDirectory ?? false
                    } catch {
                        // Could be a permission error, mark it as such
                        // This will be properly flagged in the final update
                    }
                    
                    var newItem = FileSystemItem(path: itemURL, isDirectory: isDirectory)
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
                    // Handle error, e.g., show an alert to the user
                    print("Error scanning directory: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Calculates the sizes of the items in the `items` array.
    private func calculateSizes(for itemsToProcess: [FileSystemItem]) {
        let group = DispatchGroup()
        let resultsQueue = DispatchQueue(label: "com.soance.storagefreer.results")
        var results: [UUID: Int64] = [:]

        for item in itemsToProcess {
            group.enter()
            
            directoryQueue.async {
                let size = self.calculateSize(at: item.path)
                resultsQueue.sync {
                    results[item.id] = size
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            var finalTotalSize: Int64 = 0
            var finalHasPermissionIssues = false

            // Apply all results in one go
            for i in 0..<self.items.count {
                let id = self.items[i].id
                if let size = results[id] {
                    self.items[i].size = size
                    self.items[i].isCalculating = false // Mark as done
                    
                    if size >= 0 {
                        finalTotalSize += size
                    } else {
                        self.items[i].error = "Permission Denied"
                        finalHasPermissionIssues = true
                    }
                }
            }
            
            // Update final properties
            self.totalSize = finalTotalSize
            self.hasPermissionIssues = finalHasPermissionIssues
            
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
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles, errorHandler: { (url, error) -> Bool in
            // Error handler for enumerator
            return true // Continue enumerating
        }) else {
            cacheQueue.sync { self.sizeCache[url] = -1 }
            return -1 // Permission error
        }

        for case let fileURL as URL in enumerator {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                totalSize += attributes[.size] as? Int64 ?? 0
            } catch {
                // Could not access a file, likely a permission issue
            }
        }
        
        cacheQueue.sync { self.sizeCache[url] = totalSize }
        return totalSize
    }
    
    /// Opens the given URL in Finder.
    public func openInFinder(at url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    /// Formats bytes into a human-readable string (e.g., "1.23 GB").
    public static func formatBytes(_ bytes: Int64) -> String {
        guard bytes >= 0 else { return "Access Denied" }
        guard bytes > 0 else { return "0 B" }
        
        let units = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"]
        let digitGroups = Int(log2(Double(bytes)) / 10)
        
        return String(format: "%.2f %@", Double(bytes) / pow(1024, Double(digitGroups)), units[digitGroups])
    }
}
