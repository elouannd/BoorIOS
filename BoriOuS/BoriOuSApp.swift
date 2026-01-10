//
//  BoriOuSApp.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import SwiftUI
import SwiftData

@main
struct BoriOuSApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            BooruSource.self,
            UserPreferences.self,
            FavoritePost.self,
            Collection.self,
            FavoriteTag.self,
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
            MainTabView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
