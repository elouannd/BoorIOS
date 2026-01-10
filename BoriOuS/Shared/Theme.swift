//
//  Theme.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import SwiftUI

/// App theme colors and styling
enum Theme {
    // MARK: - Colors
    
    static let primary = Color(hex: "#6366F1")
    static let accent = Color(hex: "#F472B6")
    
    static let backgroundDark = Color(hex: "#0A0A0F")
    static let surfaceDark = Color(hex: "#16161D")
    static let backgroundLight = Color(hex: "#FAFAFA")
    static let surfaceLight = Color(hex: "#FFFFFF")
    
    // Tag category colors
    static let tagGeneral = Color(hex: "#3B82F6")
    static let tagArtist = Color(hex: "#EF4444")
    static let tagCopyright = Color(hex: "#A855F7")
    static let tagCharacter = Color(hex: "#22C55E")
    static let tagMeta = Color(hex: "#F97316")
    
    // Rating colors
    static let ratingSafe = Color(hex: "#22C55E")
    static let ratingQuestionable = Color(hex: "#EAB308")
    static let ratingExplicit = Color(hex: "#EF4444")
    
    // MARK: - Gradients
    
    static let primaryGradient = LinearGradient(
        colors: [primary, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let darkOverlay = LinearGradient(
        colors: [.clear, .black.opacity(0.6)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else {
            return "#000000"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    func tagPillStyle(category: TagCategory) -> some View {
        self
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(category.color.opacity(0.15))
            .foregroundStyle(category.color)
            .clipShape(Capsule())
    }
}
