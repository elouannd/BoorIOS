//
//  Post.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import Foundation
import SwiftData

/// Represents a post/image from a booru
struct Post: Identifiable, Decodable, Hashable {
    let id: Int
    let createdAt: Date?
    let score: Int
    let source: String?
    let rating: ContentRating
    let imageWidth: Int
    let imageHeight: Int
    let tagString: String
    let fileUrl: String?
    let previewUrl: String?
    let sampleUrl: String?
    let fileExt: String?
    let fileSize: Int?
    let uploaderName: String?
    
    // Source identifier (which booru this came from)
    var sourceId: String?
    var sourceBaseUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case score
        case source
        case rating
        case imageWidth = "image_width"
        case imageHeight = "image_height"
        case tagString = "tag_string"
        case fileUrl = "file_url"
        case previewUrl = "preview_url"
        case sampleUrl = "sample_url"
        case fileExt = "file_ext"
        case fileSize = "file_size"
        case uploaderName = "uploader_name"
        // Danbooru-specific keys
        case previewFileUrl = "preview_file_url"
        case largeFileUrl = "large_file_url"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        score = (try? container.decode(Int.self, forKey: .score)) ?? 0
        source = try? container.decode(String.self, forKey: .source)
        imageWidth = (try? container.decode(Int.self, forKey: .imageWidth)) ?? 0
        imageHeight = (try? container.decode(Int.self, forKey: .imageHeight)) ?? 0
        tagString = (try? container.decode(String.self, forKey: .tagString)) ?? ""
        fileUrl = try? container.decode(String.self, forKey: .fileUrl)
        fileExt = try? container.decode(String.self, forKey: .fileExt)
        fileSize = try? container.decode(Int.self, forKey: .fileSize)
        uploaderName = try? container.decode(String.self, forKey: .uploaderName)
        
        // Handle preview URL - try Danbooru's field first, then standard
        if let danbooruPreview = try? container.decode(String.self, forKey: .previewFileUrl) {
            previewUrl = danbooruPreview
        } else {
            previewUrl = try? container.decode(String.self, forKey: .previewUrl)
        }
        
        // Handle sample URL - try Danbooru's field first, then standard
        if let danbooruSample = try? container.decode(String.self, forKey: .largeFileUrl) {
            sampleUrl = danbooruSample
        } else {
            sampleUrl = try? container.decode(String.self, forKey: .sampleUrl)
        }
        
        // Parse rating - use ContentRating.from() to handle all formats
        if let ratingString = try? container.decode(String.self, forKey: .rating) {
            rating = ContentRating.from(ratingString)
        } else {
            rating = .safe
        }
        
        // Parse date - handle both ISO8601 and other formats
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdAt = formatter.date(from: dateString)
        } else {
            createdAt = nil
        }
    }
    
    init(
        id: Int,
        createdAt: Date? = nil,
        score: Int = 0,
        source: String? = nil,
        rating: ContentRating = .safe,
        imageWidth: Int = 0,
        imageHeight: Int = 0,
        tagString: String = "",
        fileUrl: String? = nil,
        previewUrl: String? = nil,
        sampleUrl: String? = nil,
        fileExt: String? = nil,
        fileSize: Int? = nil,
        uploaderName: String? = nil,
        sourceId: String? = nil,
        sourceBaseUrl: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.score = score
        self.source = source
        self.rating = rating
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.tagString = tagString
        self.fileUrl = fileUrl
        self.previewUrl = previewUrl
        self.sampleUrl = sampleUrl
        self.fileExt = fileExt
        self.fileSize = fileSize
        self.uploaderName = uploaderName
        self.sourceId = sourceId
        self.sourceBaseUrl = sourceBaseUrl
    }
    
    // MARK: - Computed Properties
    
    /// Tags as an array
    var tags: [String] {
        tagString.split(separator: " ").map(String.init)
    }
    
    /// Best URL for viewing (sample if available, otherwise full)
    var viewingUrl: URL? {
        if let sample = sampleUrl, !sample.isEmpty {
            return URL(string: sample)
        }
        return fileUrl.flatMap { URL(string: $0) }
    }
    
    /// Thumbnail URL
    var thumbnailUrl: URL? {
        previewUrl.flatMap { URL(string: $0) }
    }
    
    /// Full resolution URL
    var fullUrl: URL? {
        fileUrl.flatMap { URL(string: $0) }
    }
    
    /// URL to the post page on the booru site
    var postPageUrl: URL? {
        guard let baseUrl = sourceBaseUrl else { return nil }
        // Most boorus use /posts/{id} or /post/show/{id}
        // Danbooru/Gelbooru style
        if baseUrl.contains("danbooru") || baseUrl.contains("safebooru") {
            return URL(string: "\(baseUrl)/posts/\(id)")
        } else if baseUrl.contains("e621") || baseUrl.contains("e926") {
            return URL(string: "\(baseUrl)/posts/\(id)")
        } else if baseUrl.contains("gelbooru") {
            return URL(string: "\(baseUrl)/index.php?page=post&s=view&id=\(id)")
        } else if baseUrl.contains("konachan") || baseUrl.contains("yande.re") {
            return URL(string: "\(baseUrl)/post/show/\(id)")
        }
        // Default fallback
        return URL(string: "\(baseUrl)/posts/\(id)")
    }
    
    /// Aspect ratio
    var aspectRatio: CGFloat {
        guard imageHeight > 0 else { return 1 }
        return CGFloat(imageWidth) / CGFloat(imageHeight)
    }
    
    /// Human readable file size
    var formattedFileSize: String {
        guard let size = fileSize else { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    /// Is this a video/animation?
    var isAnimated: Bool {
        guard let ext = fileExt?.lowercased() else { return false }
        return ["gif", "mp4", "webm", "zip"].contains(ext)
    }
}

// MARK: - Gelbooru/Safebooru Response

/// Post format from Gelbooru-style APIs (Safebooru, Gelbooru)
struct GelbooruPost: Codable {
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
    let image: String?
    let directory: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case score
        case rating
        case width
        case height
        case tags
        case fileUrl = "file_url"
        case previewUrl = "preview_url"
        case sampleUrl = "sample_url"
        case source
        case image
        case directory
    }
    
    var asPost: Post {
        Post(
            id: id,
            score: score ?? 0,
            source: source,
            rating: ContentRating.from(rating),
            imageWidth: width ?? 0,
            imageHeight: height ?? 0,
            tagString: tags ?? "",
            fileUrl: fileUrl,
            previewUrl: previewUrl,
            sampleUrl: sampleUrl
        )
    }
}

/// Response wrapper for Gelbooru-style APIs (some return {post: [...]}, others return [...] directly)
struct GelbooruResponse: Codable {
    let post: [GelbooruPost]?
    
    var posts: [Post] {
        post?.map { $0.asPost } ?? []
    }
}

// MARK: - e621 Response

/// Post format from e621/e926 API (nested structure)
struct E621Post: Codable {
    let id: Int
    let createdAt: String?
    let file: E621File
    let preview: E621Preview
    let sample: E621Sample
    let score: E621Score
    let tags: E621Tags
    let rating: String?
    let sources: [String]?
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case file, preview, sample, score, tags, rating, sources, description
    }
    
    var asPost: Post {
        // Extract all tag categories into a single string
        let allTags = (tags.general + tags.artist + tags.character + tags.species).joined(separator: " ")
        
        return Post(
            id: id,
            score: score.total,
            source: sources?.first,
            rating: ContentRating.from(rating),
            imageWidth: file.width,
            imageHeight: file.height,
            tagString: allTags,
            fileUrl: file.url,
            previewUrl: preview.url,
            sampleUrl: sample.url
        )
    }
}

struct E621File: Codable {
    let width: Int
    let height: Int
    let url: String?
}

struct E621Preview: Codable {
    let url: String?
}

struct E621Sample: Codable {
    let url: String?
    let has: Bool?
}

struct E621Score: Codable {
    let total: Int
}

struct E621Tags: Codable {
    let general: [String]
    let artist: [String]
    let character: [String]
    let species: [String]
}

/// Response wrapper for e621 API
struct E621Response: Codable {
    let posts: [E621Post]
}

