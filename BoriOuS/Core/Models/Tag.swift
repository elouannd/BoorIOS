//
//  Tag.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import Foundation
import SwiftUI

/// Tag category types used by boorus
enum TagCategory: Int, Codable, CaseIterable {
    case general = 0
    case artist = 1
    case copyright = 3
    case character = 4
    case meta = 5
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .artist: return "Artist"
        case .copyright: return "Copyright"
        case .character: return "Character"
        case .meta: return "Meta"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .blue
        case .artist: return .red
        case .copyright: return .purple
        case .character: return .green
        case .meta: return .orange
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .artist: return 0
        case .copyright: return 1
        case .character: return 2
        case .general: return 3
        case .meta: return 4
        }
    }
}

/// Represents a tag from a booru
struct Tag: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let category: TagCategory
    let postCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case postCount = "post_count"
    }
    
    init(id: Int, name: String, category: TagCategory, postCount: Int? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.postCount = postCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        // Handle different category formats
        if let categoryInt = try? container.decode(Int.self, forKey: .category) {
            category = TagCategory(rawValue: categoryInt) ?? .general
        } else {
            category = .general
        }
        
        postCount = try? container.decode(Int.self, forKey: .postCount)
    }
    
    /// Format tag name for display (replace underscores with spaces)
    var displayName: String {
        name.replacingOccurrences(of: "_", with: " ")
    }
    
    /// Format post count for display
    var formattedCount: String {
        guard let count = postCount else { return "" }
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Autocomplete Response

/// Autocomplete result from Danbooru
struct AutocompleteTag: Codable {
    let type: String
    let label: String
    let value: String
    let category: Int?
    let postCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case type
        case label
        case value
        case category
        case postCount = "post_count"
    }
    
    var asTag: Tag {
        Tag(
            id: value.hashValue,
            name: value,
            category: category.flatMap { TagCategory(rawValue: $0) } ?? .general,
            postCount: postCount
        )
    }
}
