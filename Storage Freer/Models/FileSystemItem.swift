import Foundation

/// Represents an item in the file system, such as a file or a directory.
public struct FileSystemItem: Identifiable, Hashable {
    /// A unique identifier for the item.
    public let id = UUID()
    
    /// The URL path to the file system item.
    public let path: URL
    
    /// The name of the item.
    public var name: String { path.lastPathComponent }
    
    /// A Boolean value indicating whether the item is a directory.
    public var isDirectory: Bool
    
    /// The size of the item in bytes. `nil` if not yet calculated. A negative value indicates an error.
    public var size: Int64?
    
    /// A Boolean value indicating whether the size calculation is in progress.
    public var isCalculating: Bool = false
    
    /// An error message if accessing the item failed.
    public var error: String?

    // Conformance to Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Conformance to Equatable
    public static func == (lhs: FileSystemItem, rhs: FileSystemItem) -> Bool {
        lhs.id == rhs.id
    }
}
