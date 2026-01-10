//
//  UserPreferences.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import Foundation
import SwiftData

/// User preferences stored with SwiftData
@Model
final class UserPreferences {
    var id: UUID
    
    // Content Filtering
    var showSafeContent: Bool
    var showQuestionableContent: Bool
    var showExplicitContent: Bool
    var blurNSFWThumbnails: Bool
    
    // Display Settings
    var gridColumnCount: Int
    var preferHighQualityThumbnails: Bool
    var autoPlayAnimations: Bool
    
    // Blacklist
    var blacklistedTags: [String]
    
    // Search History
    var searchHistory: [String]
    var maxSearchHistoryCount: Int
    
    // Appearance
    var prefersDarkMode: Bool
    var accentColorHex: String
    
    // Active Source
    var activeSourceId: String?
    
    init(
        id: UUID = UUID(),
        showSafeContent: Bool = true,
        showQuestionableContent: Bool = false,
        showExplicitContent: Bool = false,
        blurNSFWThumbnails: Bool = true,
        gridColumnCount: Int = 3,
        preferHighQualityThumbnails: Bool = false,
        autoPlayAnimations: Bool = true,
        blacklistedTags: [String] = [],
        searchHistory: [String] = [],
        maxSearchHistoryCount: Int = 50,
        prefersDarkMode: Bool = true,
        accentColorHex: String = "#6366F1",
        activeSourceId: String? = nil
    ) {
        self.id = id
        self.showSafeContent = showSafeContent
        self.showQuestionableContent = showQuestionableContent
        self.showExplicitContent = showExplicitContent
        self.blurNSFWThumbnails = blurNSFWThumbnails
        self.gridColumnCount = gridColumnCount
        self.preferHighQualityThumbnails = preferHighQualityThumbnails
        self.autoPlayAnimations = autoPlayAnimations
        self.blacklistedTags = blacklistedTags
        self.searchHistory = searchHistory
        self.maxSearchHistoryCount = maxSearchHistoryCount
        self.prefersDarkMode = prefersDarkMode
        self.accentColorHex = accentColorHex
        self.activeSourceId = activeSourceId
    }
    
    /// Add a search term to history
    func addToSearchHistory(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Remove if already exists
        searchHistory.removeAll { $0.lowercased() == trimmed.lowercased() }
        
        // Insert at beginning
        searchHistory.insert(trimmed, at: 0)
        
        // Trim to max count
        if searchHistory.count > maxSearchHistoryCount {
            searchHistory = Array(searchHistory.prefix(maxSearchHistoryCount))
        }
    }
    
    /// Check if a post should be shown based on rating preferences
    func shouldShow(rating: ContentRating) -> Bool {
        switch rating {
        case .safe, .general:
            return showSafeContent
        case .questionable, .sensitive:
            return showQuestionableContent
        case .explicit:
            return showExplicitContent
        }
    }
    
    /// Check if tags contain blacklisted items
    func containsBlacklistedTag(_ tags: [String]) -> Bool {
        let lowercasedBlacklist = Set(blacklistedTags.map { $0.lowercased() })
        return tags.contains { lowercasedBlacklist.contains($0.lowercased()) }
    }
}
