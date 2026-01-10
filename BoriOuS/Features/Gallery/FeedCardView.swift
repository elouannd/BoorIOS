//
//  FeedCardView.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import SwiftUI
import SwiftData

/// Instagram/Reddit style card for single column feed view
struct FeedCardView: View {
    let post: Post
    let sourceName: String
    let onTap: () -> Void
    let onFavorite: () -> Void
    
    @State private var isFavorited = false
    @State private var showFullTags = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header
            
            // Image
            imageContent
                .onTapGesture(perform: onTap)
            
            // Action bar
            actionBar
            
            // Info
            infoSection
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            // Source icon
            Image(systemName: "photo.stack")
                .foregroundStyle(.secondary)
            
            Text(sourceName)
                .font(.subheadline.weight(.medium))
            
            Spacer()
            
            // Rating badge
            Text(post.rating.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ratingColor.opacity(0.2))
                .foregroundStyle(ratingColor)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    // MARK: - Image
    
    private var imageContent: some View {
        GeometryReader { geometry in
            CachedAsyncImage(url: post.viewingUrl ?? post.thumbnailUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width)
            } placeholder: {
                ZStack {
                    Color(.systemGray5)
                    ProgressView()
                }
            }
        }
        .aspectRatio(post.aspectRatio, contentMode: .fit)
    }
    
    // MARK: - Action Bar
    
    private var actionBar: some View {
        HStack(spacing: 20) {
            // Favorite button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isFavorited.toggle()
                }
                onFavorite()
            } label: {
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundStyle(isFavorited ? .red : .primary)
                    .symbolEffect(.bounce, value: isFavorited)
            }
            
            // Score
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.caption)
                Text("\(post.score)")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.secondary)
            
            Spacer()
            
            // Dimensions
            Text("\(post.imageWidth) × \(post.imageHeight)")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            // Download placeholder
            Button {
                // Download action
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tags
            if !post.tags.isEmpty {
                TagFlowView(tags: Array(post.tags.prefix(showFullTags ? 50 : 8))) { tag in
                    // Tag tap action - could trigger search
                }
                
                if post.tags.count > 8 {
                    Button {
                        withAnimation {
                            showFullTags.toggle()
                        }
                    } label: {
                        Text(showFullTags ? "Show less" : "+\(post.tags.count - 8) more tags")
                            .font(.caption)
                            .foregroundStyle(Theme.primary)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    
    private var ratingColor: Color {
        switch post.rating {
        case .safe, .general: return .green
        case .questionable, .sensitive: return .yellow
        case .explicit: return .red
        }
    }
}

// MARK: - Tag Flow View

struct TagFlowView: View {
    let tags: [String]
    let onTagTap: (String) -> Void
    
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Button {
                    onTagTap(tag)
                } label: {
                    Text(tag.replacingOccurrences(of: "_", with: " "))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0
        
        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            
            height = y + rowHeight
        }
    }
}

#Preview {
    let samplePost = Post(
        id: 1,
        score: 150,
        rating: .safe,
        imageWidth: 1920,
        imageHeight: 1080,
        tagString: "landscape scenery sky clouds beautiful nature artwork digital_art",
        sampleUrl: "https://via.placeholder.com/800x450"
    )
    
    ScrollView {
        FeedCardView(
            post: samplePost,
            sourceName: "Safebooru",
            onTap: {},
            onFavorite: {}
        )
        .padding()
    }
}
