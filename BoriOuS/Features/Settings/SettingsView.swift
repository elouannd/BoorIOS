//
//  SettingsView.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import SwiftUI
import SwiftData

/// Settings view for app configuration
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]
    @Query private var sources: [BooruSource]
    
    @State private var showSourceSettings = false
    @State private var showBlacklistEditor = false
    @State private var newBlacklistTag = ""
    
    private var userPrefs: UserPreferences {
        if let existing = preferences.first {
            return existing
        }
        let newPrefs = UserPreferences()
        modelContext.insert(newPrefs)
        return newPrefs
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Sources Section
                Section {
                    NavigationLink {
                        SourcesSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "photo.stack")
                                .foregroundStyle(Theme.primary)
                                .frame(width: 30)
                            Text("Booru Sources")
                        }
                    }
                } header: {
                    Text("Sources")
                }
                
                // Content Filtering Section
                Section {
                    Toggle(isOn: Bindable(userPrefs).showSafeContent) {
                        HStack {
                            Image(systemName: "checkmark.shield")
                                .foregroundStyle(.green)
                                .frame(width: 30)
                            Text("Safe Content")
                        }
                    }
                    
                    Toggle(isOn: Bindable(userPrefs).showQuestionableContent) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.yellow)
                                .frame(width: 30)
                            Text("Questionable Content")
                        }
                    }
                    
                    Toggle(isOn: Bindable(userPrefs).showExplicitContent) {
                        HStack {
                            Image(systemName: "exclamationmark.octagon")
                                .foregroundStyle(.red)
                                .frame(width: 30)
                            Text("Explicit Content")
                        }
                    }
                    
                    Toggle(isOn: Bindable(userPrefs).blurNSFWThumbnails) {
                        HStack {
                            Image(systemName: "eye.slash")
                                .foregroundStyle(.secondary)
                                .frame(width: 30)
                            Text("Blur NSFW Thumbnails")
                        }
                    }
                } header: {
                    Text("Content Filtering")
                } footer: {
                    Text("Control which content ratings are visible in the gallery.")
                }
                
                // Blacklist Section
                Section {
                    NavigationLink {
                        BlacklistEditorView(preferences: userPrefs)
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundStyle(.orange)
                                .frame(width: 30)
                            Text("Tag Blacklist")
                            Spacer()
                            Text("\(userPrefs.blacklistedTags.count) tags")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Blacklist")
                } footer: {
                    Text("Posts containing blacklisted tags will be hidden.")
                }
                
                // Display Section
                Section {
                    Picker(selection: Bindable(userPrefs).gridColumnCount) {
                        Text("2 Columns").tag(2)
                        Text("3 Columns").tag(3)
                        Text("4 Columns").tag(4)
                        Text("5 Columns").tag(5)
                    } label: {
                        HStack {
                            Image(systemName: "square.grid.3x3")
                                .foregroundStyle(Theme.primary)
                                .frame(width: 30)
                            Text("Grid Columns")
                        }
                    }
                    
                    // Default Source Picker
                    Picker(selection: Bindable(userPrefs).activeSourceId) {
                        Text("None").tag(String?.none)
                        ForEach(sources.filter { $0.isEnabled }) { source in
                            Text(source.name).tag(String?.some(source.id.uuidString))
                        }
                    } label: {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundStyle(.blue)
                                .frame(width: 30)
                            Text("Default Source")
                        }
                    }
                    
                    Toggle(isOn: Bindable(userPrefs).preferHighQualityThumbnails) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.purple)
                                .frame(width: 30)
                            Text("High Quality Thumbnails")
                        }
                    }
                    
                    Toggle(isOn: Bindable(userPrefs).autoPlayAnimations) {
                        HStack {
                            Image(systemName: "play.circle")
                                .foregroundStyle(.blue)
                                .frame(width: 30)
                            Text("Auto-play Animations")
                        }
                    }
                } header: {
                    Text("Display")
                }
                
                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/elouannd/BoorIOS")!) {
                        HStack {
                            Text("Source Code")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("BoorIOS")
                }
                
                // Data Section
                Section {
                    Button(role: .destructive) {
                        clearSearchHistory()
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .frame(width: 30)
                            Text("Clear Search History")
                        }
                    }
                } header: {
                    Text("Data")
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private func clearSearchHistory() {
        userPrefs.searchHistory = []
    }
}

// MARK: - Sources Settings View

struct SourcesSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BooruSource.order) private var sources: [BooruSource]
    
    var body: some View {
        List {
            ForEach(sources) { source in
                NavigationLink {
                    SourceDetailView(source: source)
                } label: {
                    HStack {
                        Image(systemName: source.iconName)
                            .foregroundStyle(source.isSFW ? .green : .orange)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text(source.name)
                            Text(source.baseURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if !source.isEnabled {
                            Text("Disabled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onMove { from, to in
                // Reorder sources
                var orderedSources = sources.sorted(by: { $0.order < $1.order })
                orderedSources.move(fromOffsets: from, toOffset: to)
                for (index, source) in orderedSources.enumerated() {
                    source.order = index
                }
            }
        }
        .navigationTitle("Sources")
        .toolbar {
            EditButton()
        }
    }
}

// MARK: - Source Detail View

struct SourceDetailView: View {
    @Bindable var source: BooruSource
    
    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $source.isEnabled)
            }
            
            Section("Information") {
                LabeledContent("Name", value: source.name)
                LabeledContent("URL", value: source.baseURL)
                LabeledContent("API Type", value: source.apiType.displayName)
                LabeledContent("Content", value: source.isSFW ? "SFW" : "NSFW")
            }
            
            if !source.isSFW {
                Section("Authentication") {
                    TextField("API Key", text: Binding(
                        get: { source.apiKey ?? "" },
                        set: { source.apiKey = $0.isEmpty ? nil : $0 }
                    ))
                    
                    TextField("User ID", text: Binding(
                        get: { source.userId ?? "" },
                        set: { source.userId = $0.isEmpty ? nil : $0 }
                    ))
                }
            }
        }
        .navigationTitle(source.name)
    }
}

// MARK: - Blacklist Editor View

struct BlacklistEditorView: View {
    @Bindable var preferences: UserPreferences
    @State private var newTag = ""
    
    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Add tag to blacklist", text: $newTag)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    Button {
                        addTag()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Theme.primary)
                    }
                    .disabled(newTag.isEmpty)
                }
            }
            
            Section {
                if preferences.blacklistedTags.isEmpty {
                    Text("No blacklisted tags")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(preferences.blacklistedTags, id: \.self) { tag in
                        Text(tag.replacingOccurrences(of: "_", with: " "))
                    }
                    .onDelete { indexSet in
                        preferences.blacklistedTags.remove(atOffsets: indexSet)
                    }
                }
            } header: {
                Text("Blacklisted Tags")
            } footer: {
                Text("Posts containing any of these tags will be hidden from results.")
            }
        }
        .navigationTitle("Tag Blacklist")
        .toolbar {
            EditButton()
        }
    }
    
    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
        
        guard !tag.isEmpty, !preferences.blacklistedTags.contains(tag) else { return }
        
        preferences.blacklistedTags.append(tag)
        newTag = ""
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserPreferences.self, BooruSource.self], inMemory: true)
}
