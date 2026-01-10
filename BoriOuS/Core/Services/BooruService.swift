//
//  BooruService.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import Foundation

/// Service for fetching data from booru APIs
actor BooruService {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }
    
    // MARK: - Posts
    
    /// Fetch posts from a booru source
    func fetchPosts(
        from source: BooruSource,
        tags: String? = nil,
        page: Int = 1,
        limit: Int = 40
    ) async throws -> [Post] {
        switch source.apiType {
        case .danbooru:
            return try await fetchDanbooruPosts(baseURL: source.baseURL, tags: tags, page: page, limit: limit)
        case .gelbooru:
            return try await fetchGelbooruPosts(
                baseURL: source.baseURL,
                tags: tags,
                page: page,
                limit: limit,
                apiKey: source.apiKey,
                userId: source.userId
            )
        case .moebooru:
            return try await fetchMoebooruPosts(baseURL: source.baseURL, tags: tags, page: page, limit: limit)
        case .e621:
            return try await fetchE621Posts(baseURL: source.baseURL, tags: tags, page: page, limit: limit)
        }
    }
    
    /// Fetch a single post by ID
    func fetchPost(id: Int, from source: BooruSource) async throws -> Post? {
        switch source.apiType {
        case .danbooru:
            let endpoint = BooruEndpoint.danbooruPost(id: id)
            return try await apiClient.fetch(endpoint)
        default:
            // For other sources, fetch with ID filter
            let posts = try await fetchPosts(from: source, tags: "id:\(id)", limit: 1)
            return posts.first
        }
    }
    
    // MARK: - Tags
    
    /// Search for tags
    func searchTags(
        query: String,
        from source: BooruSource,
        limit: Int = 20
    ) async throws -> [Tag] {
        guard !query.isEmpty else { return [] }
        
        switch source.apiType {
        case .danbooru:
            let endpoint = BooruEndpoint.danbooruTags(query: query, limit: limit)
            return try await apiClient.fetch(endpoint)
        case .gelbooru:
            let endpoint = BooruEndpoint.gelbooruTags(query: query, limit: limit)
            let response: [Tag] = try await apiClient.fetch(endpoint)
            return response
        case .moebooru:
            // Moebooru uses similar endpoint to Danbooru
            return try await fetchMoebooruTags(baseURL: source.baseURL, query: query, limit: limit)
        case .e621:
            // e621 has different autocomplete format, return empty for now
            return []
        }
    }
    
    /// Get autocomplete suggestions
    func autocomplete(
        query: String,
        from source: BooruSource
    ) async throws -> [Tag] {
        guard !query.isEmpty else { return [] }
        
        switch source.apiType {
        case .danbooru:
            let endpoint = BooruEndpoint.danbooruAutocomplete(query: query)
            let results: [AutocompleteTag] = try await apiClient.fetch(endpoint)
            return results.map { $0.asTag }
        default:
            // Fall back to tag search
            return try await searchTags(query: query, from: source, limit: 10)
        }
    }
    
    // MARK: - Private Helpers
    
    private func fetchDanbooruPosts(
        baseURL: String,
        tags: String?,
        page: Int,
        limit: Int
    ) async throws -> [Post] {
        let endpoint = BooruEndpoint.danbooruPosts(tags: tags, page: page, limit: limit)
        let posts: [Post] = try await apiClient.fetch(endpoint)
        return posts
    }
    
    private func fetchGelbooruPosts(
        baseURL: String,
        tags: String?,
        page: Int,
        limit: Int,
        apiKey: String?,
        userId: String?
    ) async throws -> [Post] {
        var components = URLComponents(string: baseURL)!
        components.path = "/index.php"
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "dapi"),
            URLQueryItem(name: "s", value: "post"),
            URLQueryItem(name: "q", value: "index"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "pid", value: "\(page - 1)"), // Gelbooru uses 0-indexed page
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let tags = tags, !tags.isEmpty {
            queryItems.append(URLQueryItem(name: "tags", value: tags))
        }
        
        if let apiKey = apiKey {
            queryItems.append(URLQueryItem(name: "api_key", value: apiKey))
        }
        
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: userId))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        // Fetch raw data to handle different response formats
        let data = try await apiClient.fetchData(from: url)
        let decoder = JSONDecoder()
        // NOT using convertFromSnakeCase - GelbooruPost has explicit CodingKeys
        
        // Safebooru returns array directly: [...]
        // Gelbooru returns wrapped: {"post": [...]} or {"@attributes": {...}, "post": [...]}
        
        // First try direct array (Safebooru format)
        if let posts = try? decoder.decode([GelbooruPost].self, from: data) {
            return posts.map { $0.asPost }
        }
        
        // Then try wrapped format (Gelbooru format)
        if let response = try? decoder.decode(GelbooruResponse.self, from: data) {
            return response.posts
        }
        
        // If both fail, throw error
        throw NetworkError.decodingError(NSError(domain: "BooruService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown response format"]))
    }
    
    private func fetchMoebooruPosts(
        baseURL: String,
        tags: String?,
        page: Int,
        limit: Int
    ) async throws -> [Post] {
        // Moebooru uses similar format to Danbooru
        var components = URLComponents(string: baseURL)!
        components.path = "/post.json"
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let tags = tags, !tags.isEmpty {
            queryItems.append(URLQueryItem(name: "tags", value: tags))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        // Moebooru returns array directly
        let data = try await apiClient.fetchData(from: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        // Moebooru has slightly different field names
        struct MoebooruPost: Codable {
            let id: Int
            let score: Int?
            let rating: String?
            let width: Int?
            let height: Int?
            let tags: String?
            let fileUrl: String?
            let previewUrl: String?
            let sampleUrl: String?
            let source: String?
        }
        
        let moePosts = try decoder.decode([MoebooruPost].self, from: data)
        
        return moePosts.map { moe in
            Post(
                id: moe.id,
                score: moe.score ?? 0,
                source: moe.source,
                rating: ContentRating.from(moe.rating),
                imageWidth: moe.width ?? 0,
                imageHeight: moe.height ?? 0,
                tagString: moe.tags ?? "",
                fileUrl: moe.fileUrl,
                previewUrl: moe.previewUrl,
                sampleUrl: moe.sampleUrl
            )
        }
    }
    
    private func fetchMoebooruTags(
        baseURL: String,
        query: String,
        limit: Int
    ) async throws -> [Tag] {
        var components = URLComponents(string: baseURL)!
        components.path = "/tag.json"
        components.queryItems = [
            URLQueryItem(name: "name", value: "\(query)*"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "order", value: "count")
        ]
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        let data = try await apiClient.fetchData(from: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode([Tag].self, from: data)
    }
    
    private func fetchE621Posts(
        baseURL: String,
        tags: String?,
        page: Int,
        limit: Int
    ) async throws -> [Post] {
        var components = URLComponents(string: baseURL)!
        components.path = "/posts.json"
        
        var queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        
        if let tags = tags, !tags.isEmpty {
            queryItems.append(URLQueryItem(name: "tags", value: tags))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        // e621 requires User-Agent header
        let data = try await apiClient.fetchData(from: url)
        let decoder = JSONDecoder()
        
        let response = try decoder.decode(E621Response.self, from: data)
        return response.posts.map { $0.asPost }
    }
}
