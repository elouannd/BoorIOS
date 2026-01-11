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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

/// Root content view that applies dynamic appearance
struct ContentView: View {
    @Query private var preferences: [UserPreferences]
    
    private var colorScheme: ColorScheme? {
        guard let prefs = preferences.first else { return .dark }
        switch prefs.appearanceMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    var body: some View {
        MainTabView()
            .preferredColorScheme(colorScheme)
    }
}
