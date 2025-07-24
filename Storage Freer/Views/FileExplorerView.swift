import SwiftUI

/// The main view of the application, displaying the file explorer.
public struct FileExplorerView: View {
    @StateObject private var fileSystemManager = FileSystemManager()
    let url: URL?

    public init(url: URL?) {
        self.url = url
    }

    public var body: some View {
        VStack {
            // Header with total size and status
            HeaderView(
                totalSize: fileSystemManager.totalSize,
                isCalculating: fileSystemManager.isCalculating,
                hasPermissionIssues: fileSystemManager.hasPermissionIssues,
                currentDirectoryName: currentDirectoryName
            )

            // List of files and directories
            List(fileSystemManager.items) { item in
                NavigationLink(destination: FileExplorerView(url: item.path)) {
                    FileRowView(item: item)
                }
                .disabled(!item.isDirectory)
            }
            .listStyle(PlainListStyle())
        }
        .navigationTitle(currentDirectoryName)
        .toolbar {
            // Refresh button
            ToolbarItem {
                Button(action: {
                    fileSystemManager.scanDirectory(at: url)
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            // Initial scan of the directory
            fileSystemManager.scanDirectory(at: url)
        }
    }
    
    private var currentDirectoryName: String {
        guard let url = url, url.path != "/" else {
            return "Macintosh HD"
        }
        return url.lastPathComponent
    }
}

struct FileExplorerView_Previews: PreviewProvider {
    static var previews: some View {
        FileExplorerView(url: nil)
    }
}
