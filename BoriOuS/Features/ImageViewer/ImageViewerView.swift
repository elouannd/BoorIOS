//
//  ImageViewerView.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import SwiftUI
import SwiftData

/// Full-screen image viewer with gestures
struct ImageViewerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [FavoritePost]
    
    let post: Post
    let posts: [Post]
    let onDismiss: () -> Void
    let sourceId: String
    let onSelectTag: ((String) -> Void)?
    
    @State private var currentIndex: Int
    @State private var showInfo = false
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var isDownloading = false
    @State private var downloadError: String?
    @State private var showShareSheet = false
    @State private var imageToShare: UIImage?
    @State private var showDownloadSuccess = false
    
    @GestureState private var magnifyBy: CGFloat = 1.0
    
    private let downloadService = DownloadService.shared
    
    init(post: Post, posts: [Post], sourceId: String = "", onDismiss: @escaping () -> Void, onSelectTag: ((String) -> Void)? = nil) {
        self.post = post
        self.posts = posts
        self.sourceId = sourceId
        self.onDismiss = onDismiss
        self.onSelectTag = onSelectTag
        self._currentIndex = State(initialValue: posts.firstIndex(where: { $0.id == post.id }) ?? 0)
    }
    
    
    private var currentPost: Post {
        guard currentIndex >= 0 && currentIndex < posts.count else {
            return post
        }
        return posts[currentIndex]
    }
    
    private var isCurrentPostFavorited: Bool {
        favorites.contains { $0.postId == currentPost.id && $0.sourceId == sourceId }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Image pager
            TabView(selection: $currentIndex) {
                ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                    ZoomableImageView(post: post)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            
            // Overlays
            VStack {
                // Top bar
                topBar
                
                Spacer()
                
                // Bottom bar
                if showInfo {
                    infoPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                bottomBar
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .gesture(
            TapGesture(count: 1)
                .onEnded {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showInfo.toggle()
                    }
                }
        )
    }
    
    // MARK: - Subviews
    
    private var topBar: some View {
        HStack {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            
            Spacer()
            
            // Download success indicator
            if showDownloadSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Saved!")
                }
                .font(.subheadline)
                .foregroundStyle(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .transition(.scale.combined(with: .opacity))
            } else {
                Text("\(currentIndex + 1) / \(posts.count)")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            
            Spacer()
            
            Menu {
                Button {
                    downloadImage()
                } label: {
                    if isDownloading {
                        Label("Downloading...", systemImage: "arrow.down.circle")
                    } else {
                        Label("Save to Photos", systemImage: "square.and.arrow.down")
                    }
                }
                .disabled(isDownloading)
                
                Button {
                    prepareShare()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Divider()
                
                Button {
                    toggleFavorite()
                } label: {
                    Label(isCurrentPostFavorited ? "Remove from Favorites" : "Add to Favorites", 
                          systemImage: isCurrentPostFavorited ? "heart.fill" : "heart")
                }
                
                if let source = currentPost.source, let url = URL(string: source) {
                    Divider()
                    Link(destination: url) {
                        Label("View Source", systemImage: "link")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding()
        .animation(.easeInOut(duration: 0.2), value: showDownloadSuccess)
    }
    
    private var bottomBar: some View {
        HStack(spacing: 24) {
            // Score
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                Text("\(currentPost.score)")
            }
            .font(.subheadline)
            .foregroundStyle(.white)
            
            Spacer()
            
            // Download button
            Button {
                downloadImage()
            } label: {
                if isDownloading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .disabled(isDownloading)
            
            // Favorite button
            Button {
                toggleFavorite()
            } label: {
                Image(systemName: isCurrentPostFavorited ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundStyle(isCurrentPostFavorited ? .red : .white)
                    .symbolEffect(.bounce, value: isCurrentPostFavorited)
            }
            
            // Info button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showInfo.toggle()
                }
            } label: {
                Image(systemName: "info.circle")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Dimensions
            HStack {
                Label("\(currentPost.imageWidth) × \(currentPost.imageHeight)", systemImage: "aspectratio")
                Spacer()
                if !currentPost.formattedFileSize.isEmpty {
                    Label(currentPost.formattedFileSize, systemImage: "doc")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            // Tags
            if !currentPost.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(currentPost.tags.prefix(20), id: \.self) { tag in
                            Button {
                                onSelectTag?(tag)
                            } label: {
                                Text(tag.replacingOccurrences(of: "_", with: " "))
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        if currentPost.tags.count > 20 {
                            Text("+\(currentPost.tags.count - 20) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Actions
    
    private func downloadImage() {
        guard let url = currentPost.fullUrl ?? currentPost.viewingUrl else { return }
        
        isDownloading = true
        
        Task {
            do {
                try await downloadService.saveToPhotos(from: url)
                
                await MainActor.run {
                    isDownloading = false
                    showDownloadSuccess = true
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // Hide success message after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showDownloadSuccess = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    downloadError = error.localizedDescription
                    
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
    
    private func prepareShare() {
        guard let url = currentPost.viewingUrl else { return }
        
        Task {
            do {
                let image = try await downloadService.getShareableImage(from: url)
                await MainActor.run {
                    imageToShare = image
                    showShareSheet = true
                }
            } catch {
                // Handle error silently
            }
        }
    }
    
    private func toggleFavorite() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if let existing = favorites.first(where: { $0.postId == currentPost.id && $0.sourceId == sourceId }) {
            modelContext.delete(existing)
        } else {
            let favorite = FavoritePost.from(post: currentPost, sourceId: sourceId)
            modelContext.insert(favorite)
        }
    }
}

// MARK: - Zoomable Image View

struct ZoomableImageView: View {
    let post: Post
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isLoading = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let url = post.viewingUrl {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(magnificationGesture)
                                .gesture(dragGesture)
                                .gesture(doubleTapGesture(in: geometry.size))
                                .onAppear { isLoading = false }
                        case .failure:
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                Text("Failed to load image")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.white)
                        @unknown default:
                            ProgressView()
                                .tint(.white)
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale = min(max(scale * delta, 1), 5)
            }
            .onEnded { _ in
                lastScale = 1.0
                if scale < 1 {
                    withAnimation(.spring(response: 0.3)) {
                        scale = 1
                        offset = .zero
                    }
                }
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
    
    private func doubleTapGesture(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation(.spring(response: 0.3)) {
                    if scale > 1 {
                        scale = 1
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2.5
                    }
                }
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
        tagString: "landscape scenery sky clouds",
        sampleUrl: "https://via.placeholder.com/1920x1080"
    )
    
    ImageViewerView(post: samplePost, posts: [samplePost]) {}
}
