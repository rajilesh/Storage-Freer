import SwiftUI

struct FinderSidebar: View {
    @ObservedObject var fileSystemManager: FileSystemManager
    @Binding var selection: FileSystemItem?
    
    var body: some View {
        List(selection: $selection) {
            ForEach(fileSystemManager.items) { item in
                SidebarRow(item: item, selection: $selection, fileSystemManager: fileSystemManager)
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 220)
    }
}

struct SidebarRow: View {
    @ObservedObject var item: FileSystemItem
    @Binding var selection: FileSystemItem?
    var fileSystemManager: FileSystemManager
    
    var body: some View {
        DisclosureGroup(isExpanded: $item.isExpanded) {
            if let children = item.children {
                ForEach(children) { child in
                    SidebarRow(item: child, selection: $selection, fileSystemManager: fileSystemManager)
                }
            } else if item.isExpanded {
                ProgressView().onAppear {
                    fileSystemManager.loadChildren(for: item)
                }
            }
        } label: {
            HStack {
                Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                Text(item.name)
                Spacer()
                if let size = item.size {
                    Text(FileSystemManager.formatBytes(size))
                        .font(.subheadline)
                        .foregroundColor(item.error != nil ? .orange : .secondary)
                } else {
                    Text("-")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selection = item
            }
            .contextMenu {
                Button("Open in Finder") {
                    fileSystemManager.openInFinder(at: item.path)
                }
            }
        }
    }
}

public struct FileExplorerView: View {
    @EnvironmentObject private var fileSystemManager: FileSystemManager
    @State private var selection: FileSystemItem? = nil
    
    public var body: some View {
        NavigationSplitView {
            FinderSidebar(fileSystemManager: fileSystemManager, selection: $selection)
        } detail: {
            if let selected = selection {
                FolderColumnView(folder: selected, fileSystemManager: fileSystemManager, selection: $selection)
            } else {
                Text("Select a folder")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            if fileSystemManager.items.isEmpty {
                fileSystemManager.scanDirectory(at: nil)
            }
        }
    }
}

struct FolderColumnView: View {
    @ObservedObject var folder: FileSystemItem
    var fileSystemManager: FileSystemManager
    @Binding var selection: FileSystemItem?
    
    var body: some View {
        VStack(alignment: .leading) {
            HeaderView(
                totalSize: folder.size ?? 0,
                isCalculating: folder.isCalculating,
                hasPermissionIssues: folder.error != nil,
                currentDirectoryName: folder.name
            )
            List {
                if let children = folder.children {
                    ForEach(children) { item in
                        HStack {
                            Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                            Text(item.name)
                                .onTapGesture {
                                    fileSystemManager.openInFinder(at: item.path)
                                }
                            Spacer()
                            if let size = item.size {
                                Text(FileSystemManager.formatBytes(size))
                                    .font(.subheadline)
                                    .foregroundColor(item.error != nil ? .orange : .secondary)
                            } else {
                                Text("-")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if item.isDirectory {
                                selection = item
                                if item.children == nil {
                                    fileSystemManager.loadChildren(for: item)
                                }
                            }
                        }
                    }
                } else {
                    ProgressView().onAppear {
                        fileSystemManager.loadChildren(for: folder)
                    }
                }
            }
        }
        .frame(minWidth: 300)
    }
}

struct FileExplorerView_Previews: PreviewProvider {
    static var previews: some View {
        FileExplorerView().environmentObject(FileSystemManager())
    }
}
