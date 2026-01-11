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
    var isMultiSourceSearch = false
    var sourcesForMultiSearch: [BooruSource] = []
    
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
    
    /// Load initial posts from a single source
    func loadPosts(from source: BooruSource, tags: String? = nil) async {
        guard !isLoading else { return }
        
        isMultiSourceSearch = false
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
    
    /// Load posts from all enabled sources
    func loadPostsFromAllSources(sources: [BooruSource], tags: String? = nil) async {
        guard !isLoading else { return }
        
        let enabledSources = sources.filter { $0.isEnabled }
        guard !enabledSources.isEmpty else { return }
        
        isMultiSourceSearch = true
        sourcesForMultiSearch = enabledSources
        currentSource = nil
        currentTags = tags ?? ""
        currentPage = 1
        hasMorePages = false  // Multi-source doesn't support pagination
        isLoading = true
        error = nil
        
        var allPosts: [Post] = []
        var fetchErrors: [Error] = []
        
        // Fetch from all sources concurrently
        await withTaskGroup(of: (BooruSource, Result<[Post], Error>).self) { group in
            for source in enabledSources {
                group.addTask {
                    do {
                        let posts = try await self.booruService.fetchPosts(
                            from: source,
                            tags: tags,
                            page: 1,
                            limit: 20  // Limit per source to avoid overwhelming
                        )
                        return (source, .success(posts))
                    } catch {
                        return (source, .failure(error))
                    }
                }
            }
            
            for await (source, result) in group {
                switch result {
                case .success(let posts):
                    // Tag each post with its source info
                    let taggedPosts = posts.map { post -> Post in
                        var mutablePost = post
                        mutablePost.sourceId = source.name
                        mutablePost.sourceBaseUrl = source.baseURL
                        return mutablePost
                    }
                    allPosts.append(contentsOf: taggedPosts)
                case .failure(let error):
                    fetchErrors.append(error)
                }
            }
        }
        
        // Remove duplicates based on post ID and file URL
        var seenIds = Set<String>()
        let uniquePosts = allPosts.filter { post in
            let key = "\(post.id)-\(post.fileUrl ?? "")"
            if seenIds.contains(key) {
                return false
            }
            seenIds.insert(key)
            return true
        }
        
        // Sort by score by default for multi-source
        let sortedPosts = uniquePosts.sorted { $0.score > $1.score }
        
        storePosts(sortedPosts)
        
        // Only set error if ALL sources failed
        if allPosts.isEmpty && !fetchErrors.isEmpty {
            self.error = fetchErrors.first
        }
        
        isLoading = false
    }
    
    /// Load more posts (pagination) - only for single source
    func loadMorePosts() async {
        guard !isLoadingMore,
              !isLoading,
              hasMorePages,
              !isMultiSourceSearch,
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
        if isMultiSourceSearch {
            await loadPostsFromAllSources(sources: sourcesForMultiSearch, tags: currentTags.isEmpty ? nil : currentTags)
        } else if let source = currentSource {
            await loadPosts(from: source, tags: currentTags.isEmpty ? nil : currentTags)
        }
    }
    
    /// Check if should load more (for infinite scroll)
    func shouldLoadMore(currentPost: Post) -> Bool {
        guard !isMultiSourceSearch else { return false }
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

