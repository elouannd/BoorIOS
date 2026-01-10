//
//  SearchView.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import SwiftUI
import SwiftData

/// Search view with tag autocomplete
struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sources: [BooruSource]
    @Query private var preferences: [UserPreferences]
    @Query(sort: \FavoriteTag.order) private var favoriteTags: [FavoriteTag]
    
    @State private var searchText = ""
    @State private var suggestions: [Tag] = []
    @State private var selectedTags: [String] = []
    @State private var isSearching = false
    @State private var showResults = false
    @State private var resultsViewModel = GalleryViewModel()
    
    private let booruService = BooruService()
    
    private var userPrefs: UserPreferences? {
        preferences.first
    }
    
    private var activeSource: BooruSource? {
        if let prefSourceId = userPrefs?.activeSourceId {
            return sources.first { $0.id.uuidString == prefSourceId }
        }
        return sources.first { $0.isEnabled && $0.isSFW } ?? sources.first
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selected tags
                if !selectedTags.isEmpty {
                    selectedTagsBar
                }
                
                // Search results or suggestions
                if showResults {
                    searchResultsGrid
                } else if !suggestions.isEmpty {
                    suggestionsList
                } else if !searchText.isEmpty {
                    loadingOrEmptyView
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            favoriteTagsSection
                            searchHistoryContent
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search tags...")
            .onChange(of: searchText) { _, newValue in
                Task {
                    await fetchSuggestions(for: newValue)
                }
            }
            .onSubmit(of: .search) {
                performSearch()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var selectedTagsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedTags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag.replacingOccurrences(of: "_", with: " "))
                        Button {
                            withAnimation {
                                selectedTags.removeAll { $0 == tag }
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.primary.opacity(0.15))
                    .foregroundStyle(Theme.primary)
                    .clipShape(Capsule())
                }
                
                // Search button
                Button {
                    performSearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .padding(8)
                        .background(Theme.primary)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    private var suggestionsList: some View {
        List(suggestions) { tag in
            Button {
                addTag(tag.name)
            } label: {
                HStack {
                    Text(tag.displayName)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(tag.formattedCount)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contextMenu {
                Button {
                    addTag(tag.name)
                } label: {
                    Label("Add to Search", systemImage: "plus.circle")
                }
                
                Button {
                    addTagToFavorites(tag)
                } label: {
                    Label("Add to Favorites", systemImage: "star")
                }
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }
    
    private func addTagToFavorites(_ tag: Tag) {
        // Check if already exists
        if !favoriteTags.contains(where: { $0.name == tag.name }) {
            let favorite = FavoriteTag.from(tag: tag)
            favorite.order = favoriteTags.count
            modelContext.insert(favorite)
        }
    }
    
    private var loadingOrEmptyView: some View {
        VStack {
            if isSearching {
                ProgressView()
            } else {
                Text("No suggestions found")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var searchHistoryContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let history = userPrefs?.searchHistory, !history.isEmpty {
                Text("Recent Searches")
                    .font(.headline)
                
                ForEach(history.prefix(10), id: \.self) { term in
                    Button {
                        selectedTags = term.split(separator: " ").map(String.init)
                        performSearch()
                    } label: {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(.secondary)
                            Text(term.replacingOccurrences(of: "_", with: " "))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var favoriteTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Favorite Tags")
                    .font(.headline)
                Spacer()
            }
            
            if favoriteTags.isEmpty {
                Text("Long-press a tag to add to favorites")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(favoriteTags) { tag in
                        Button {
                            addTag(tag.name)
                        } label: {
                            Text(tag.displayName)
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(colorForCategory(tag.category).opacity(0.15))
                                .foregroundStyle(colorForCategory(tag.category))
                                .clipShape(Capsule())
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                modelContext.delete(tag)
                            } label: {
                                Label("Remove from Favorites", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func colorForCategory(_ category: Int) -> Color {
        switch category {
        case 1: return .red      // Artist
        case 3: return .purple   // Copyright
        case 4: return .green    // Character
        case 5: return .orange   // Meta
        default: return Theme.primary
        }
    }
    
    private var searchResultsGrid: some View {
        GalleryView()
    }
    
    // MARK: - Actions
    
    private func fetchSuggestions(for query: String) async {
        guard !query.isEmpty, let source = activeSource else {
            suggestions = []
            return
        }
        
        isSearching = true
        
        do {
            suggestions = try await booruService.autocomplete(query: query, from: source)
        } catch {
            suggestions = []
        }
        
        isSearching = false
    }
    
    private func addTag(_ tag: String) {
        if !selectedTags.contains(tag) {
            withAnimation {
                selectedTags.append(tag)
            }
        }
        searchText = ""
        suggestions = []
    }
    
    private func performSearch() {
        let searchQuery = selectedTags.joined(separator: " ")
        
        // Save to history
        if var prefs = userPrefs {
            prefs.addToSearchHistory(searchQuery)
        }
        
        showResults = true
        
        Task {
            if let source = activeSource {
                await resultsViewModel.loadPosts(from: source, tags: searchQuery)
            }
        }
    }
}

#Preview {
    SearchView()
        .modelContainer(for: [BooruSource.self, UserPreferences.self], inMemory: true)
}
