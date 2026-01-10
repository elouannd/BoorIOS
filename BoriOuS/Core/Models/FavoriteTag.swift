//
//  FavoriteTag.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import Foundation
import SwiftData

/// A favorite tag saved by the user for quick access
@Model
final class FavoriteTag {
    var id: UUID
    var name: String
    var displayName: String
    var category: Int  // Tag category (0=general, 1=artist, 3=copyright, 4=character, 5=meta)
    var usageCount: Int
    var addedAt: Date
    var order: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        displayName: String? = nil,
        category: Int = 0,
        usageCount: Int = 0,
        addedAt: Date = Date(),
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName ?? name.replacingOccurrences(of: "_", with: " ")
        self.category = category
        self.usageCount = usageCount
        self.addedAt = addedAt
        self.order = order
    }
    
    /// Create from a Tag
    static func from(tag: Tag) -> FavoriteTag {
        FavoriteTag(
            name: tag.name,
            displayName: tag.name.replacingOccurrences(of: "_", with: " "),
            category: tag.category.rawValue
        )
    }
    
    /// Category color for display
    var categoryColor: String {
        switch category {
        case 1: return "red"      // Artist
        case 3: return "purple"   // Copyright
        case 4: return "green"    // Character
        case 5: return "orange"   // Meta
        default: return "blue"    // General
        }
    }
}
