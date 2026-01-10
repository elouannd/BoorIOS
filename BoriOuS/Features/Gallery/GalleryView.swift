//
//  GalleryView.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import SwiftUI
import SwiftData

/// Main gallery view displaying posts in a grid
struct GalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sources: [BooruSource]
    @Query private var favorites: [FavoritePost]
    @Query private var userPreferences: [UserPreferences]
    @State private var viewModel = GalleryViewModel()
    
    private var preferences: UserPreferences? {
        userPreferences.first
    }
    @State private var selectedPost: Post?
    @State private var searchText = ""
    @State private var showSourcePicker = false
    @State private var columnCount = 3
    @State private var isFeedMode = false
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: columnCount)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                // Content
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    loadingView
                } else if let error = viewModel.error, viewModel.posts.isEmpty {
                    errorView(error)
                } else if viewModel.posts.isEmpty {
                    emptyView
                } else if isFeedMode {
                    feedView
                } else {
                    galleryGrid
                }
            }
            .navigationTitle(viewModel.currentSource?.name ?? "Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search tags...")
            .onSubmit(of: .search) {
                Task {
                    if let source = viewModel.currentSource {
                        await viewModel.loadPosts(from: source, tags: searchText)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    sourceButton
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
                            Picker("Sort", selection: $viewModel.sortOrder) {
                                ForEach(SortOrder.allCases, id: \.self) { order in
                                    Label(order.rawValue, systemImage: order.icon).tag(order)
                                }
                            }
                        } label: {
                            Image(systemName: viewModel.sortOrder.icon)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSourcePicker) {
                SourcePickerSheet(
                    sources: sources,
                    selectedSource: viewModel.currentSource
                ) { source in
                    // Update preferences
                    preferences?.activeSourceId = source.id.uuidString
                    Task {
                        await viewModel.loadPosts(from: source)
                    }
                }
            }
            .fullScreenCover(item: $selectedPost) { post in
                ImageViewerView(
                    post: post,
                    posts: viewModel.posts,
                    sourceId: viewModel.currentSource?.id.uuidString ?? "",
                    onDismiss: { selectedPost = nil },
                    onSelectTag: { tag in
                        selectedPost = nil
                        searchText = tag
                        if let source = viewModel.currentSource {
                            Task {
                                await viewModel.loadPosts(from: source, tags: tag)
                            }
                        }
                    }
                )
            }
        }
        .task {
            // Initialize with first available source or create defaults
            await initializeSources()
        }
    }
    
    // MARK: - Subviews
    
    private var galleryGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 2) {
                ForEach(viewModel.posts) { post in
                    GalleryGridItem(
                        post: post,
                        useHighQuality: preferences?.preferHighQualityThumbnails ?? false
                    )
                        .onTapGesture {
                            selectedPost = post
                        }
                        .onAppear {
                            if viewModel.shouldLoadMore(currentPost: post) {
                                Task {
                                    await viewModel.loadMorePosts()
                                }
                            }
                        }
                }
                
                // Loading more indicator
                if viewModel.isLoadingMore {
                    loadingMoreIndicator
                }
            }
            .padding(.horizontal, 2)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    private var feedView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.posts) { post in
                    FeedCardView(
                        post: post,
                        sourceName: viewModel.currentSource?.name ?? "Unknown",
                        onTap: {
                            selectedPost = post
                        },
                        onFavorite: {
                            toggleFavorite(post)
                        }
                    )
                    .onAppear {
                        if viewModel.shouldLoadMore(currentPost: post) {
                            Task {
                                await viewModel.loadMorePosts()
                            }
                        }
                    }
                }
                
                // Loading more indicator
                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding()
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    private func toggleFavorite(_ post: Post) {
        let sourceId = viewModel.currentSource?.id.uuidString ?? ""
        
        // Check if already favorited
        if let existing = favorites.first(where: { $0.postId == post.id && $0.sourceId == sourceId }) {
            modelContext.delete(existing)
        } else {
            let favorite = FavoritePost.from(post: post, sourceId: sourceId)
            modelContext.insert(favorite)
        }
    }
    
    private func isFavorited(_ post: Post) -> Bool {
        let sourceId = viewModel.currentSource?.id.uuidString ?? ""
        return favorites.contains { $0.postId == post.id && $0.sourceId == sourceId }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .foregroundStyle(.secondary)
        }
    }
    
    private var loadingMoreIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding()
            Spacer()
        }
        .gridCellColumns(columnCount)
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            
            Text("Oops!")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No posts found")
                .font(.headline)
            
            Text("Try a different search or source")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var sourceButton: some View {
        Button {
            showSourcePicker = true
        } label: {
            HStack(spacing: 4) {
                if let source = viewModel.currentSource {
                    Image(systemName: source.iconName)
                    Text(source.name)
                        .font(.subheadline)
                } else {
                    Image(systemName: "photo.stack")
                    Text("Sources")
                        .font(.subheadline)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func initializeSources() async {
        // If no sources exist, create defaults
        if sources.isEmpty {
            for defaultSource in BooruSource.defaultSources {
                modelContext.insert(defaultSource)
            }
            try? modelContext.save()
        }
        
        // Try to load last active source
        if let activeId = preferences?.activeSourceId,
           let lastSource = sources.first(where: { $0.id.uuidString == activeId && $0.isEnabled }) {
            await viewModel.loadPosts(from: lastSource)
        } else if let firstSource = sources.first(where: { $0.isSFW && $0.isEnabled }) ?? sources.first {
            // Fallback to first SFW source
            await viewModel.loadPosts(from: firstSource)
        }
    }
}

// MARK: - Source Picker Sheet

struct SourcePickerSheet: View {
    let sources: [BooruSource]
    let selectedSource: BooruSource?
    let onSelect: (BooruSource) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(sources.filter { $0.isEnabled }.sorted(by: { $0.order < $1.order })) { source in
                Button {
                    onSelect(source)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: source.iconName)
                            .foregroundStyle(source.isSFW ? .green : .orange)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text(source.name)
                                .foregroundStyle(.primary)
                            Text(source.baseURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if source.id == selectedSource?.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .disabled(!source.isEnabled)
                .opacity(source.isEnabled ? 1 : 0.5)
            }
            .navigationTitle("Select Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    GalleryView()
        .modelContainer(for: [BooruSource.self, UserPreferences.self], inMemory: true)
}
