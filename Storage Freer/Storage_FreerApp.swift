//
//  Storage_FreerApp.swift
//  Storage Freer
//
//  Created by Rajilesh Panoli on 24/07/25.
//

import SwiftUI
import SwiftData

@main
struct Storage_FreerApp: App {
    @StateObject private var fileSystemManager = FileSystemManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            NavigationView {
                FileExplorerView()
            }
            .environmentObject(fileSystemManager)
            .modelContainer(sharedModelContainer)
        }
    }
}
