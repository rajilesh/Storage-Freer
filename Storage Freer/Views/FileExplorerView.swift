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
    @StateObject private var fileSystemManager = FileSystemManager()
    @State private var selection: FileSystemItem? = nil
    
    public var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading) {
                HeaderView(
                    totalSize: fileSystemManager.rootTotalSize,
                    isCalculating: fileSystemManager.isCalculating,
                    hasPermissionIssues: fileSystemManager.hasPermissionIssues,
                    currentDirectoryName: "Macintosh HD"
                )
                FinderSidebar(fileSystemManager: fileSystemManager, selection: $selection)
            }
        } detail: {
            if let selected = selection {
                FolderColumnView(folder: selected, fileSystemManager: fileSystemManager, selection: $selection)
            } else {
                VStack {
                    if fileSystemManager.isCalculating {
                        ProgressView("Scanning...")
                    } else {
                        Text("Select a folder to view its contents")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            if fileSystemManager.items.isEmpty {
                fileSystemManager.scanDirectory(at: nil)
            }
        }
        .alert(isPresented: $fileSystemManager.showPermissionAlert) {
            Alert(
                title: Text("Permission Required"),
                message: Text("To access all files and folders, please grant Full Disk Access in System Settings."),
                primaryButton: .default(Text("Open Settings"), action: {
                    fileSystemManager.openPrivacySettings()
                }),
                secondaryButton: .cancel()
            )
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

struct PermissionRequestView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
            Text("Full Disk Access Needed")
                .font(.title2)
                .fontWeight(.bold)
            Text("To scan folders like 'Users' and 'Desktop', please grant Full Disk Access in System Settings.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FullDiskAccess") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .frame(maxWidth: 400)
    }
}

struct FileExplorerView_Previews: PreviewProvider {
    static var previews: some View {
        FileExplorerView().environmentObject(FileSystemManager())
    }
}
