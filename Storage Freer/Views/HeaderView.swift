import SwiftUI

/// A header view displaying total size and status information.
public struct HeaderView: View {
    let totalSize: Int64
    let isCalculating: Bool
    let hasPermissionIssues: Bool
    let currentDirectoryName: String

    public init(totalSize: Int64, isCalculating: Bool, hasPermissionIssues: Bool, currentDirectoryName: String) {
        self.totalSize = totalSize
        self.isCalculating = isCalculating
        self.hasPermissionIssues = hasPermissionIssues
        self.currentDirectoryName = currentDirectoryName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(currentDirectoryName)
                    .font(.headline)
                Spacer()
                if isCalculating {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 20, height: 20)
                }
            }

            HStack {
                Text("Total Size:")
                    .fontWeight(.bold)
                Text(FileSystemManager.formatBytes(totalSize))
            }
            .font(.subheadline)
            
            if hasPermissionIssues {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Some items could not be accessed. Grant Full Disk Access for accurate results.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}
