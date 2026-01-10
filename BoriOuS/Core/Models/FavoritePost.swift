//
//  FavoritePost.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import Foundation
import SwiftData

/// A locally saved favorite post
@Model
final class FavoritePost {
    var id: UUID
    var postId: Int
    var sourceId: String
    var addedAt: Date
    
    // Cached post data
    var thumbnailUrl: String?
    var sampleUrl: String?
    var fullUrl: String?
    var imageWidth: Int
    var imageHeight: Int
    var rating: String
    var tagString: String
    var score: Int
    
    // Collection membership
    var collectionIds: [String]
    
    init(
        id: UUID = UUID(),
        postId: Int,
        sourceId: String,
        addedAt: Date = Date(),
        thumbnailUrl: String? = nil,
        sampleUrl: String? = nil,
        fullUrl: String? = nil,
        imageWidth: Int = 0,
        imageHeight: Int = 0,
        rating: String = "s",
        tagString: String = "",
        score: Int = 0,
        collectionIds: [String] = []
    ) {
        self.id = id
        self.postId = postId
        self.sourceId = sourceId
        self.addedAt = addedAt
        self.thumbnailUrl = thumbnailUrl
        self.sampleUrl = sampleUrl
        self.fullUrl = fullUrl
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.rating = rating
        self.tagString = tagString
        self.score = score
        self.collectionIds = collectionIds
    }
    
    /// Create from a Post
    static func from(post: Post, sourceId: String) -> FavoritePost {
        FavoritePost(
            postId: post.id,
            sourceId: sourceId,
            thumbnailUrl: post.previewUrl,
            sampleUrl: post.sampleUrl,
            fullUrl: post.fileUrl,
            imageWidth: post.imageWidth,
            imageHeight: post.imageHeight,
            rating: post.rating.rawValue,
            tagString: post.tagString,
            score: post.score
        )
    }
    
    /// Convert back to Post for display
    var asPost: Post {
        Post(
            id: postId,
            score: score,
            rating: ContentRating(rawValue: rating) ?? .safe,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            tagString: tagString,
            fileUrl: fullUrl,
            previewUrl: thumbnailUrl,
            sampleUrl: sampleUrl,
            sourceId: sourceId
        )
    }
}

/// A collection/folder for organizing favorites
@Model
final class Collection {
    var id: UUID
    var name: String
    var iconName: String
    var createdAt: Date
    var order: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "folder",
        createdAt: Date = Date(),
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.createdAt = createdAt
        self.order = order
    }
}
