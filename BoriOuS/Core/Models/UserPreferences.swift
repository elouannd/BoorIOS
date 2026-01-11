//
//  UserPreferences.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import Foundation
import SwiftData

/// Appearance mode for the app
enum AppearanceMode: String, Codable, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

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
    
    // Appearance - optional for backwards compatibility
    var appearanceModeRaw: String?
    var accentColorHex: String
    
    var appearanceMode: AppearanceMode {
        get { 
            guard let raw = appearanceModeRaw else { return .dark }
            return AppearanceMode(rawValue: raw) ?? .dark
        }
        set { appearanceModeRaw = newValue.rawValue }
    }
    
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
        appearanceMode: AppearanceMode = .dark,
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
        self.appearanceModeRaw = appearanceMode.rawValue
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
