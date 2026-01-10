//
//  GalleryGridItem.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import SwiftUI

/// A single item in the gallery grid
struct GalleryGridItem: View {
    let post: Post
    let showRatingBadge: Bool
    let useHighQuality: Bool
    
    @State private var isLoaded = false
    
    init(post: Post, showRatingBadge: Bool = true, useHighQuality: Bool = false) {
        self.post = post
        self.showRatingBadge = showRatingBadge
        self.useHighQuality = useHighQuality
    }
    
    /// URL to use based on quality setting
    private var displayUrl: URL? {
        if useHighQuality {
            // Use sample URL for higher quality, fallback to thumbnail
            return post.viewingUrl ?? post.thumbnailUrl
        }
        return post.thumbnailUrl
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                // Thumbnail
                if let url = displayUrl {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .onAppear {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isLoaded = true
                                }
                            }
                    } placeholder: {
                        placeholderView
                    }
                } else {
                    errorView
                }
                
                // Overlays
                VStack(alignment: .trailing, spacing: 4) {
                    // Video indicator
                    if post.isAnimated {
                        Image(systemName: "play.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                    
                    // Rating badge
                    if showRatingBadge && post.rating != .safe && post.rating != .general {
                        ratingBadge
                    }
                }
                .padding(6)
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(isLoaded ? 1 : 0.7)
    }
    
    private var placeholderView: some View {
        ZStack {
            Color(.systemGray5)
            ProgressView()
                .tint(.gray)
        }
    }
    
    private var errorView: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(.gray)
        }
    }
    
    private var ratingBadge: some View {
        Text(post.rating.rawValue.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(ratingColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    private var ratingColor: Color {
        switch post.rating {
        case .safe, .general:
            return .green
        case .questionable, .sensitive:
            return .yellow
        case .explicit:
            return .red
        }
    }
}

#Preview {
    let samplePost = Post(
        id: 1,
        score: 100,
        rating: .safe,
        imageWidth: 800,
        imageHeight: 600,
        previewUrl: "https://cdn.donmai.us/preview/sample.jpg"
    )
    
    GalleryGridItem(post: samplePost)
        .frame(width: 120, height: 120)
}
