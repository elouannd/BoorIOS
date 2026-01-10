//
//  MainTabView.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import SwiftUI

/// Main navigation for the app - uses sidebar on iPad, tabs on iPhone
struct MainTabView: View {
    @State private var selectedTab = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad: Sidebar navigation
            iPadSplitView
        } else {
            // iPhone: Tab navigation
            iPhoneTabView
        }
    }
    
    // MARK: - iPhone Tab View
    
    private var iPhoneTabView: some View {
        TabView(selection: $selectedTab) {
            GalleryView()
                .tabItem {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                }
                .tag(0)
            
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)
            
            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(Theme.primary)
        // Keyboard shortcuts for tabs
        .keyboardShortcut("1", modifiers: .command) { selectedTab = 0 }
        .keyboardShortcut("2", modifiers: .command) { selectedTab = 1 }
        .keyboardShortcut("3", modifiers: .command) { selectedTab = 2 }
        .keyboardShortcut("4", modifiers: .command) { selectedTab = 3 }
    }
    
    // MARK: - iPad Split View
    
    private var iPadSplitView: some View {
        NavigationSplitView {
            // Sidebar with button-based navigation
            List {
                Section("Browse") {
                    sidebarButton("Gallery", icon: "photo.on.rectangle", tag: 0)
                    sidebarButton("Search", icon: "magnifyingglass", tag: 1)
                }
                
                Section("Library") {
                    sidebarButton("Favorites", icon: "heart.fill", tag: 2)
                }
                
                Section("App") {
                    sidebarButton("Settings", icon: "gearshape.fill", tag: 3)
                }
            }
            .navigationTitle("BoriOuS")
            .listStyle(.sidebar)
        } detail: {
            // Detail view
            switch selectedTab {
            case 0:
                GalleryView()
            case 1:
                SearchView()
            case 2:
                FavoritesView()
            case 3:
                SettingsView()
            default:
                GalleryView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(Theme.primary)
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func sidebarButton(_ title: String, icon: String, tag: Int) -> some View {
        Button {
            selectedTab = tag
        } label: {
            Label(title, systemImage: icon)
        }
        .listRowBackground(selectedTab == tag ? Theme.primary.opacity(0.15) : Color.clear)
        .foregroundStyle(selectedTab == tag ? Theme.primary : .primary)
    }
}

// MARK: - Keyboard Shortcut Extension

extension View {
    @ViewBuilder
    func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers, action: @escaping () -> Void) -> some View {
        self.background {
            Button("") { action() }
                .keyboardShortcut(key, modifiers: modifiers)
                .opacity(0)
        }
    }
}

#Preview {
    MainTabView()
}

