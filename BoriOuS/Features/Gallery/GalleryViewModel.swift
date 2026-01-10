//
//  GalleryViewModel.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import Foundation
import SwiftUI

/// Sort order options for gallery
enum SortOrder: String, CaseIterable {
    case newest = "Newest"
    case score = "Top Rated"
    case random = "Random"
    
    var icon: String {
        switch self {
        case .newest: return "clock"
        case .score: return "arrow.up.circle"
        case .random: return "shuffle"
        }
    }
}

/// View model for the gallery view
@MainActor
@Observable
final class GalleryViewModel {
    // MARK: - State
    
    private(set) var posts: [Post] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var error: Error?
    private(set) var hasMorePages = true
    
    var currentTags: String = ""
    var currentSource: BooruSource?
    var sortOrder: SortOrder = .newest {
        didSet {
            if sortOrder != oldValue {
                applySorting()
            }
        }
    }
    
    // MARK: - Private
    
    private let booruService = BooruService()
    private var currentPage = 1
    private let postsPerPage = 40
    private var unsortedPosts: [Post] = []  // Keep original order for re-sorting
    
    // MARK: - Public Methods
    
    /// Load initial posts
    func loadPosts(from source: BooruSource, tags: String? = nil) async {
        guard !isLoading else { return }
        
        currentSource = source
        currentTags = tags ?? ""
        currentPage = 1
        hasMorePages = true
        isLoading = true
        error = nil
        
        do {
            let newPosts = try await booruService.fetchPosts(
                from: source,
                tags: tags,
                page: currentPage,
                limit: postsPerPage
            )
            
            storePosts(newPosts)
            hasMorePages = newPosts.count >= postsPerPage
        } catch {
            self.error = error
            storePosts([])
        }
        
        isLoading = false
    }
    
    /// Load more posts (pagination)
    func loadMorePosts() async {
        guard !isLoadingMore,
              !isLoading,
              hasMorePages,
              let source = currentSource else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        do {
            let newPosts = try await booruService.fetchPosts(
                from: source,
                tags: currentTags.isEmpty ? nil : currentTags,
                page: currentPage,
                limit: postsPerPage
            )
            
            // Filter out duplicates
            let existingIds = Set(posts.map { $0.id })
            let uniqueNewPosts = newPosts.filter { !existingIds.contains($0.id) }
            
            storePosts(uniqueNewPosts, append: true)
            hasMorePages = newPosts.count >= postsPerPage
        } catch {
            // Don't clear existing posts on pagination error
            currentPage -= 1
            self.error = error
        }
        
        isLoadingMore = false
    }
    
    /// Refresh posts
    func refresh() async {
        guard let source = currentSource else { return }
        await loadPosts(from: source, tags: currentTags.isEmpty ? nil : currentTags)
    }
    
    /// Check if should load more (for infinite scroll)
    func shouldLoadMore(currentPost: Post) -> Bool {
        guard let lastPost = posts.last else { return false }
        return currentPost.id == lastPost.id && hasMorePages && !isLoadingMore
    }
    
    // MARK: - Sorting
    
    private func applySorting() {
        switch sortOrder {
        case .newest:
            // Restore original order (newest first from API)
            posts = unsortedPosts
        case .score:
            posts = unsortedPosts.sorted { $0.score > $1.score }
        case .random:
            posts = unsortedPosts.shuffled()
        }
    }
    
    /// Store posts for later sorting
    private func storePosts(_ newPosts: [Post], append: Bool = false) {
        if append {
            unsortedPosts.append(contentsOf: newPosts)
            posts.append(contentsOf: newPosts)
        } else {
            unsortedPosts = newPosts
            posts = newPosts
        }
        
        // Apply current sort order if not newest
        if sortOrder != .newest {
            applySorting()
        }
    }
}
