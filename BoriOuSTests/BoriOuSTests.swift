//
//  BoriOuSTests.swift
//  BoriOuSTests
//
//  Created by Elouann Domenech on 2026-01-10.
//

import Testing
import Foundation
@testable import BoriOuS

// MARK: - ContentRating Tests

struct ContentRatingTests {
    
    @Test func parseShortRatings() {
        #expect(ContentRating.from("s") == .safe)
        #expect(ContentRating.from("g") == .general)
        #expect(ContentRating.from("q") == .questionable)
        #expect(ContentRating.from("e") == .explicit)
    }
    
    @Test func parseLongRatings() {
        #expect(ContentRating.from("safe") == .safe)
        #expect(ContentRating.from("general") == .general)
        #expect(ContentRating.from("questionable") == .questionable)
        #expect(ContentRating.from("explicit") == .explicit)
        #expect(ContentRating.from("sensitive") == .sensitive)
    }
    
    @Test func parseCaseInsensitive() {
        #expect(ContentRating.from("SAFE") == .safe)
        #expect(ContentRating.from("Explicit") == .explicit)
        #expect(ContentRating.from("QUESTIONABLE") == .questionable)
    }
    
    @Test func parseInvalidReturnsDefault() {
        #expect(ContentRating.from(nil) == .safe)
        #expect(ContentRating.from("") == .safe)
        #expect(ContentRating.from("invalid") == .safe)
        #expect(ContentRating.from("xyz") == .safe)
    }
    
    @Test func displayNames() {
        #expect(ContentRating.safe.displayName == "Safe")
        #expect(ContentRating.explicit.displayName == "Explicit")
        #expect(ContentRating.questionable.displayName == "Questionable")
        #expect(ContentRating.general.displayName == "General")
        #expect(ContentRating.sensitive.displayName == "Sensitive")
    }
}

// MARK: - Post Decoding Tests

struct PostDecodingTests {
    
    @Test func decodeDanbooruPost() throws {
        let json = """
        {
            "id": 12345,
            "score": 100,
            "rating": "s",
            "image_width": 1920,
            "image_height": 1080,
            "tag_string": "tag1 tag2 tag3",
            "file_url": "https://example.com/image.jpg",
            "preview_file_url": "https://example.com/preview.jpg",
            "large_file_url": "https://example.com/sample.jpg",
            "file_ext": "jpg",
            "file_size": 102400,
            "source": "https://twitter.com/artist",
            "uploader_name": "uploader123"
        }
        """
        
        let data = json.data(using: .utf8)!
        let post = try JSONDecoder().decode(Post.self, from: data)
        
        #expect(post.id == 12345)
        #expect(post.score == 100)
        #expect(post.rating == .safe)
        #expect(post.imageWidth == 1920)
        #expect(post.imageHeight == 1080)
        #expect(post.tagString == "tag1 tag2 tag3")
        #expect(post.fileUrl == "https://example.com/image.jpg")
        #expect(post.previewUrl == "https://example.com/preview.jpg")
        #expect(post.sampleUrl == "https://example.com/sample.jpg")
    }
    
    @Test func decodeMinimalPost() throws {
        let json = """
        {
            "id": 1
        }
        """
        
        let data = json.data(using: .utf8)!
        let post = try JSONDecoder().decode(Post.self, from: data)
        
        #expect(post.id == 1)
        #expect(post.score == 0)
        #expect(post.rating == .safe)
        #expect(post.imageWidth == 0)
        #expect(post.imageHeight == 0)
        #expect(post.tagString == "")
        #expect(post.fileUrl == nil)
    }
    
    @Test func postTags() {
        let post = Post(id: 1, tagString: "cat dog bird")
        #expect(post.tags == ["cat", "dog", "bird"])
    }
    
    @Test func postAspectRatio() {
        let post = Post(id: 1, imageWidth: 1920, imageHeight: 1080)
        #expect(post.aspectRatio == 1920.0 / 1080.0)
    }
    
    @Test func postAspectRatioZeroHeight() {
        let post = Post(id: 1, imageWidth: 100, imageHeight: 0)
        #expect(post.aspectRatio == 1)
    }
    
    @Test func postIsAnimated() {
        #expect(Post(id: 1, fileExt: "gif").isAnimated == true)
        #expect(Post(id: 1, fileExt: "mp4").isAnimated == true)
        #expect(Post(id: 1, fileExt: "webm").isAnimated == true)
        #expect(Post(id: 1, fileExt: "jpg").isAnimated == false)
        #expect(Post(id: 1, fileExt: "png").isAnimated == false)
        #expect(Post(id: 1, fileExt: nil).isAnimated == false)
    }
}

// MARK: - GelbooruPost Tests

struct GelbooruPostTests {
    
    @Test func convertToPost() throws {
        let json = """
        {
            "id": 5678,
            "score": 50,
            "rating": "explicit",
            "width": 800,
            "height": 600,
            "tags": "landscape nature",
            "file_url": "https://safebooru.org/image.png",
            "preview_url": "https://safebooru.org/preview.png",
            "sample_url": "https://safebooru.org/sample.png",
            "source": "pixiv"
        }
        """
        
        let data = json.data(using: .utf8)!
        let gelbooruPost = try JSONDecoder().decode(GelbooruPost.self, from: data)
        let post = gelbooruPost.asPost
        
        #expect(post.id == 5678)
        #expect(post.score == 50)
        #expect(post.rating == .explicit)
        #expect(post.imageWidth == 800)
        #expect(post.imageHeight == 600)
        #expect(post.tagString == "landscape nature")
    }
}

// MARK: - E621Post Tests

struct E621PostTests {
    
    @Test func convertToPost() throws {
        let json = """
        {
            "id": 9999,
            "created_at": null,
            "file": {
                "width": 2048,
                "height": 1536,
                "url": "https://e621.net/file.jpg"
            },
            "preview": {
                "url": "https://e621.net/preview.jpg"
            },
            "sample": {
                "url": "https://e621.net/sample.jpg",
                "has": true
            },
            "score": {
                "total": 200
            },
            "tags": {
                "general": ["tag1", "tag2"],
                "artist": ["artist_name"],
                "character": ["character_name"],
                "species": ["species_name"]
            },
            "rating": "q",
            "sources": ["https://source.com"],
            "description": "A test image"
        }
        """
        
        let data = json.data(using: .utf8)!
        let e621Post = try JSONDecoder().decode(E621Post.self, from: data)
        let post = e621Post.asPost
        
        #expect(post.id == 9999)
        #expect(post.score == 200)
        #expect(post.rating == .questionable)
        #expect(post.imageWidth == 2048)
        #expect(post.imageHeight == 1536)
        #expect(post.tags.contains("tag1"))
        #expect(post.tags.contains("artist_name"))
    }
}

// MARK: - BooruAPIType Tests

struct BooruAPITypeTests {
    
    @Test func displayNames() {
        #expect(BooruAPIType.danbooru.displayName == "Danbooru")
        #expect(BooruAPIType.gelbooru.displayName == "Gelbooru")
        #expect(BooruAPIType.moebooru.displayName == "Moebooru")
        #expect(BooruAPIType.e621.displayName == "e621")
    }
    
    @Test func allCases() {
        #expect(BooruAPIType.allCases.count == 4)
    }
}
