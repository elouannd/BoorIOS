//
//  FavoritesView.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import SwiftUI
import SwiftData

/// View for managing saved favorites and collections
struct FavoritesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoritePost.addedAt, order: .reverse) private var favorites: [FavoritePost]
    @Query(sort: \Collection.order) private var collections: [Collection]
    
    @State private var selectedPost: Post?
    @State private var showCreateCollection = false
    @State private var selectedCollection: Collection?
    @State private var columnCount = 3
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: columnCount)
    }
    
    private var filteredFavorites: [FavoritePost] {
        if let collection = selectedCollection {
            return favorites.filter { $0.collectionIds.contains(collection.id.uuidString) }
        }
        return favorites
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Collection filter bar
                if !collections.isEmpty {
                    collectionBar
                }
                
                // Favorites grid
                if filteredFavorites.isEmpty {
                    emptyView
                } else {
                    favoritesGrid
                }
            }
            .navigationTitle("Favorites")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showCreateCollection = true
                        } label: {
                            Label("New Collection", systemImage: "folder.badge.plus")
                        }
                        
                        Divider()
                        
                        Picker("Columns", selection: $columnCount) {
                            Text("2 Columns").tag(2)
                            Text("3 Columns").tag(3)
                            Text("4 Columns").tag(4)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showCreateCollection) {
                CreateCollectionSheet { name, icon in
                    createCollection(name: name, icon: icon)
                }
            }
            .fullScreenCover(item: $selectedPost) { post in
                ImageViewerView(
                    post: post,
                    posts: filteredFavorites.map { $0.asPost },
                    sourceId: filteredFavorites.first { $0.postId == post.id }?.sourceId ?? "",
                    onDismiss: { selectedPost = nil }
                )
            }
        }
    }
    
    // MARK: - Subviews
    
    private var collectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All favorites
                collectionChip(name: "All", icon: "heart.fill", isSelected: selectedCollection == nil) {
                    selectedCollection = nil
                }
                
                // User collections
                ForEach(collections) { collection in
                    collectionChip(
                        name: collection.name,
                        icon: collection.iconName,
                        isSelected: selectedCollection?.id == collection.id
                    ) {
                        selectedCollection = collection
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    private func collectionChip(name: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(name)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Theme.primary : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
    
    private var favoritesGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 2) {
                ForEach(filteredFavorites) { favorite in
                    GalleryGridItem(post: favorite.asPost)
                        .onTapGesture {
                            selectedPost = favorite.asPost
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteFavorite(favorite)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            
                            if !collections.isEmpty {
                                Menu {
                                    ForEach(collections) { collection in
                                        Button {
                                            toggleCollection(favorite, collection: collection)
                                        } label: {
                                            if favorite.collectionIds.contains(collection.id.uuidString) {
                                                Label(collection.name, systemImage: "checkmark")
                                            } else {
                                                Text(collection.name)
                                            }
                                        }
                                    }
                                } label: {
                                    Label("Add to Collection", systemImage: "folder.badge.plus")
                                }
                            }
                        }
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No favorites yet")
                .font(.headline)
            
            Text("Tap the heart icon on any image to save it here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func deleteFavorite(_ favorite: FavoritePost) {
        withAnimation {
            modelContext.delete(favorite)
        }
    }
    
    private func toggleCollection(_ favorite: FavoritePost, collection: Collection) {
        if let index = favorite.collectionIds.firstIndex(of: collection.id.uuidString) {
            favorite.collectionIds.remove(at: index)
        } else {
            favorite.collectionIds.append(collection.id.uuidString)
        }
    }
    
    private func createCollection(name: String, icon: String) {
        let collection = Collection(
            name: name,
            iconName: icon,
            order: collections.count
        )
        modelContext.insert(collection)
    }
}

// MARK: - Create Collection Sheet

struct CreateCollectionSheet: View {
    let onCreate: (String, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedIcon = "folder"
    
    private let iconOptions = [
        "folder", "folder.fill", "star", "star.fill",
        "heart", "heart.fill", "bookmark", "bookmark.fill",
        "tag", "tag.fill", "paintpalette", "photo.artframe"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Collection name", text: $name)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Theme.primary : Color(.systemGray5))
                                    .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name, selectedIcon)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    FavoritesView()
        .modelContainer(for: [FavoritePost.self, Collection.self], inMemory: true)
}
