import SwiftUI

/// A view for a single row in the file explorer list.
public struct FileRowView: View {
    let item: FileSystemItem

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
            
            Spacer()

            // Size or status
            if item.isCalculating {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(FileSystemManager.formatBytes(item.size ?? 0))
                    .font(.subheadline)
                    .foregroundColor(item.error != nil ? .orange : .secondary)
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
