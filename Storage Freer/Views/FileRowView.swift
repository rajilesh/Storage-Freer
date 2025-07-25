import SwiftUI

/// A view for a single row in the file explorer list.
public struct FileRowView: View {
    let item: FileSystemItem
    @EnvironmentObject private var fileSystemManager: FileSystemManager

    public init(item: FileSystemItem) {
        self.item = item
    }

    public var body: some View {
        HStack {
            // Icon
            Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                .foregroundColor(item.error != nil ? .orange : .primary)

            // Name
            Text(item.name)
                .lineLimit(1)
                .onTapGesture {
                    fileSystemManager.openInFinder(at: item.path)
                }
            
            Spacer()

            // Size or status
            if let size = item.size {
                Text(FileSystemManager.formatBytes(size))
                    .font(.subheadline)
                    .foregroundColor(item.error != nil ? .orange : .secondary)
            } else if item.isCalculating {
                Text("Calculating...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text(FileSystemManager.formatBytes(item.size ?? 0))
                    .font(.subheadline)
                    .foregroundColor(item.error != nil ? .orange : .secondary)
            } else {
                Text("-")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Disclosure indicator for directories
            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
