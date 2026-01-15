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
    @Query private var favorites: [FavoritePost]
    @Query(sort: \FavoriteTag.order) private var favoriteTags: [FavoriteTag]
    
    @State private var searchText = ""
    @State private var suggestions: [Tag] = []
    @State private var selectedTags: [String] = []
    @State private var isSearching = false
    @State private var showResults = false
    @State private var resultsViewModel = GalleryViewModel()
    
    // View mode state for results
    @State private var isFeedMode = false
    @State private var columnCount = 3
    @State private var scrollToPostId: Int?
    
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
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: columnCount)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selected tags bar (always visible when tags selected)
                if !selectedTags.isEmpty {
                    selectedTagsBar
                }
                
                // Results control bar (shown when viewing results)
                if showResults {
                    resultsControlBar
                }
                
                // Main content
                if showResults {
                    searchResultsContent
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
            .navigationTitle(showResults ? "Results" : "Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search tags...")
            .onChange(of: searchText) { _, newValue in
                if showResults && !newValue.isEmpty {
                    // User is typing new search - go back to suggestions
                    showResults = false
                }
                Task {
                    await fetchSuggestions(for: newValue)
                }
            }
            .onSubmit(of: .search) {
                performSearch()
            }
            .toolbar {
                if showResults {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation {
                                showResults = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Search")
                            }
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 12) {
                            // View mode toggle
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isFeedMode.toggle()
                                }
                            } label: {
                                Image(systemName: isFeedMode ? "rectangle.grid.1x2" : "square.grid.3x3")
                            }
                            
                            // Column picker (only in grid mode)
                            if !isFeedMode {
                                Menu {
                                    Picker("Columns", selection: $columnCount) {
                                        Text("2 Columns").tag(2)
                                        Text("3 Columns").tag(3)
                                        Text("4 Columns").tag(4)
                                        Text("5 Columns").tag(5)
                                    }
                                } label: {
                                    Image(systemName: "slider.horizontal.3")
                                }
                            }
                            
                            // Sort order picker
                            Menu {
                                Picker("Sort", selection: $resultsViewModel.sortOrder) {
                                    ForEach(SortOrder.allCases, id: \.self) { order in
                                        Label(order.rawValue, systemImage: order.icon).tag(order)
                                    }
                                }
                            } label: {
                                Image(systemName: resultsViewModel.sortOrder.icon)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Results Control Bar
    
    private var resultsControlBar: some View {
        HStack(spacing: 16) {
            // Back button
            Button {
                withAnimation {
                    showResults = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.subheadline)
            }
            
            Spacer()
            
            // View mode toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFeedMode.toggle()
                }
            } label: {
                Image(systemName: isFeedMode ? "rectangle.grid.1x2" : "square.grid.3x3")
                    .font(.body)
            }
            
            // Column picker (only in grid mode)
            if !isFeedMode {
                Menu {
                    Picker("Columns", selection: $columnCount) {
                        Text("2 Columns").tag(2)
                        Text("3 Columns").tag(3)
                        Text("4 Columns").tag(4)
                        Text("5 Columns").tag(5)
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body)
                }
            }
            
            // Sort order picker
            Menu {
                Picker("Sort", selection: $resultsViewModel.sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Label(order.rawValue, systemImage: order.icon).tag(order)
                    }
                }
            } label: {
                Image(systemName: resultsViewModel.sortOrder.icon)
                    .font(.body)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .overlay(
            Divider(), alignment: .bottom
        )
    }
    
    // MARK: - Search Results Content
    
    @ViewBuilder
    private var searchResultsContent: some View {
        if resultsViewModel.isLoading && resultsViewModel.posts.isEmpty {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Searching...")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = resultsViewModel.error, resultsViewModel.posts.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Error")
                    .font(.headline)
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Retry") {
                    Task {
                        await resultsViewModel.refresh()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        } else if resultsViewModel.posts.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("No results found")
                    .font(.headline)
                Text("Try different tags")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if isFeedMode {
            searchResultsFeed
        } else {
            searchResultsGrid
        }
    }
    
    private var searchResultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 2) {
                ForEach(resultsViewModel.posts) { post in
                    GalleryGridItem(
                        post: post,
                        useHighQuality: userPrefs?.preferHighQualityThumbnails ?? false
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollToPostId = post.id
                            isFeedMode = true
                        }
                    }
                    .onAppear {
                        if resultsViewModel.shouldLoadMore(currentPost: post) {
                            Task {
                                await resultsViewModel.loadMorePosts()
                            }
                        }
                    }
                }
                
                if resultsViewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                    .gridCellColumns(columnCount)
                }
            }
            .padding(.horizontal, 2)
        }
        .refreshable {
            await resultsViewModel.refresh()
        }
    }
    
    private var searchResultsFeed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(resultsViewModel.posts) { post in
                        FeedCardView(
                            post: post,
                            sourceName: post.sourceId ?? (activeSource?.name ?? "Unknown"),
                            onTap: { },
                            onFavorite: {
                                toggleFavorite(post)
                            },
                            onTagSearch: { tag in
                                // Trigger new search with this tag
                                selectedTags = [tag]
                                performSearch()
                            }
                        )
                        .id(post.id)
                        .onAppear {
                            if resultsViewModel.shouldLoadMore(currentPost: post) {
                                Task {
                                    await resultsViewModel.loadMorePosts()
                                }
                            }
                        }
                    }
                    
                    if resultsViewModel.isLoadingMore {
                        ProgressView()
                            .padding()
                    }
                }
                .padding()
            }
            .refreshable {
                await resultsViewModel.refresh()
            }
            .onChange(of: scrollToPostId) { _, newId in
                if let id = newId {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .top)
                    }
                    scrollToPostId = nil
                }
            }
            .onAppear {
                if let id = scrollToPostId {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(id, anchor: .top)
                        }
                        scrollToPostId = nil
                    }
                }
            }
        }
    }
    
    private func toggleFavorite(_ post: Post) {
        let sourceId = activeSource?.id.uuidString ?? ""
        
        if let existing = favorites.first(where: { $0.postId == post.id && $0.sourceId == sourceId }) {
            modelContext.delete(existing)
        } else {
            let favorite = FavoritePost.from(post: post, sourceId: sourceId)
            modelContext.insert(favorite)
        }
    }
    
    // MARK: - Original Subviews
    
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
        if let prefs = userPrefs {
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

