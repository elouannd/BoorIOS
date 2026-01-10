//
//  BooruSource.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import Foundation
import SwiftData

/// Type of booru API
enum BooruAPIType: String, Codable, CaseIterable {
    case danbooru
    case gelbooru
    case moebooru
    case e621
    
    var displayName: String {
        switch self {
        case .danbooru: return "Danbooru"
        case .gelbooru: return "Gelbooru"
        case .moebooru: return "Moebooru"
        case .e621: return "e621"
        }
    }
}

/// Content rating levels
enum ContentRating: String, Codable, CaseIterable {
    case safe = "s"
    case questionable = "q"
    case explicit = "e"
    case general = "g"
    case sensitive = "sensitive"
    
    var displayName: String {
        switch self {
        case .safe: return "Safe"
        case .questionable: return "Questionable"
        case .explicit: return "Explicit"
        case .general: return "General"
        case .sensitive: return "Sensitive"
        }
    }
    
    var color: String {
        switch self {
        case .safe, .general: return "green"
        case .questionable, .sensitive: return "yellow"
        case .explicit: return "red"
        }
    }
    
    /// Parse rating from various formats (s/q/e/g or safe/general/questionable/explicit/sensitive)
    static func from(_ string: String?) -> ContentRating {
        guard let string = string?.lowercased() else { return .safe }
        
        switch string {
        case "s", "safe": return .safe
        case "g", "general": return .general
        case "q", "questionable": return .questionable
        case "e", "explicit": return .explicit
        case "sensitive": return .sensitive
        default: return .safe
        }
    }
}

/// Configuration for a booru source
@Model
final class BooruSource {
    var id: UUID
    var name: String
    var baseURL: String
    var apiType: BooruAPIType
    var isEnabled: Bool
    var isSFW: Bool
    var apiKey: String?
    var userId: String?
    var iconName: String
    var order: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        apiType: BooruAPIType,
        isEnabled: Bool = true,
        isSFW: Bool = true,
        apiKey: String? = nil,
        userId: String? = nil,
        iconName: String = "photo.stack",
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.apiType = apiType
        self.isEnabled = isEnabled
        self.isSFW = isSFW
        self.apiKey = apiKey
        self.userId = userId
        self.iconName = iconName
        self.order = order
    }
}

// MARK: - Default Sources

extension BooruSource {
    static let defaultSources: [BooruSource] = [
        BooruSource(
            name: "Safebooru",
            baseURL: "https://safebooru.org",
            apiType: .gelbooru,
            isSFW: true,
            iconName: "shield.checkered",
            order: 0
        ),
        BooruSource(
            name: "Danbooru",
            baseURL: "https://danbooru.donmai.us",
            apiType: .danbooru,
            isSFW: false,
            iconName: "sparkles",
            order: 1
        ),
        BooruSource(
            name: "Gelbooru",
            baseURL: "https://gelbooru.com",
            apiType: .gelbooru,
            isEnabled: false,  // Requires API key
            isSFW: false,
            iconName: "star.circle",
            order: 2
        ),
        BooruSource(
            name: "Konachan",
            baseURL: "https://konachan.com",
            apiType: .moebooru,
            isSFW: false,
            iconName: "photo.artframe",
            order: 3
        ),
        BooruSource(
            name: "Yande.re",
            baseURL: "https://yande.re",
            apiType: .moebooru,
            isSFW: false,
            iconName: "paintpalette",
            order: 4
        ),
        BooruSource(
            name: "e621",
            baseURL: "https://e621.net",
            apiType: .e621,
            isSFW: false,
            iconName: "pawprint.fill",
            order: 5
        ),
        BooruSource(
            name: "e926",
            baseURL: "https://e926.net",
            apiType: .e621,
            isSFW: true,
            iconName: "pawprint",
            order: 6
        ),
        BooruSource(
            name: "Rule34",
            baseURL: "https://api.rule34.xxx",
            apiType: .gelbooru,
            isEnabled: false, // Requires auth
            isSFW: false,
            iconName: "18.circle",
            order: 7
        )
    ]
}
