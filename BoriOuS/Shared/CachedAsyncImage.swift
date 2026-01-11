//
//  CachedAsyncImage.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import SwiftUI
import CryptoKit

/// Custom async image loader that handles booru-specific requirements
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var hasFailed = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else if hasFailed {
                placeholder()
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        isLoading = true
        
        Task {
            // Check memory cache first (fastest)
            if let cached = ImageCache.shared.getFromMemory(for: url) {
                await MainActor.run {
                    self.image = cached
                    self.isLoading = false
                }
                return
            }
            
            // Check disk cache second
            if let cached = await ImageCache.shared.getFromDisk(for: url) {
                await MainActor.run {
                    self.image = cached
                    self.isLoading = false
                }
                return
            }
            
            // Download from network
            var request = URLRequest(url: url)
            request.setValue("BoriOuS/1.1 (iOS; Booru Viewer)", forHTTPHeaderField: "User-Agent")
            request.setValue("image/*", forHTTPHeaderField: "Accept")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let uiImage = UIImage(data: data) else {
                    await MainActor.run {
                        hasFailed = true
                        isLoading = false
                    }
                    return
                }
                
                // Cache to both memory and disk
                await ImageCache.shared.set(uiImage, for: url)
                
                await MainActor.run {
                    self.image = uiImage
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    hasFailed = true
                    isLoading = false
                }
            }
        }
    }
}

/// Thread-safe memory cache storage that can be used nonisolated
final class MemoryCacheStorage: @unchecked Sendable {
    private let cache = NSCache<NSString, UIImage>()
    
    init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024  // 50 MB
    }
    
    func get(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func removeAll() {
        cache.removeAllObjects()
    }
}

/// Hybrid memory + disk image cache
actor ImageCache {
    static let shared = ImageCache()
    
    // Memory cache (fast, limited) - thread-safe separate class
    private nonisolated let memoryCache = MemoryCacheStorage()
    
    // Disk cache directory
    private let diskCacheURL: URL
    
    // Configuration
    private let maxDiskCacheSize: Int64 = 200 * 1024 * 1024  // 200 MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60  // 7 days
    
    private init() {
        // Use Caches directory (system can purge if needed)
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = cacheDir.appendingPathComponent("ImageCache", isDirectory: true)
        
        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Clean old cache entries on startup
        Task {
            await cleanOldCacheEntries()
        }
    }
    
    // MARK: - Memory Cache
    
    nonisolated func getFromMemory(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)
        return memoryCache.get(forKey: key)
    }
    
    private nonisolated func setMemoryCache(_ image: UIImage, forKey key: String) {
        memoryCache.set(image, forKey: key)
    }
    
    // MARK: - Disk Cache
    
    func getFromDisk(for url: URL) async -> UIImage? {
        let fileURL = diskURL(for: url)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        // Promote to memory cache
        let key = cacheKey(for: url)
        setMemoryCache(image, forKey: key)
        
        // Update access time
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: fileURL.path
        )
        
        return image
    }
    
    func set(_ image: UIImage, for url: URL) async {
        let key = cacheKey(for: url)
        
        // Save to memory cache
        setMemoryCache(image, forKey: key)
        
        // Save to disk asynchronously
        let fileURL = diskURL(for: url)
        
        // Use JPEG for smaller file sizes (0.8 quality)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL, options: .atomic)
        }
        
        // Check if we need to evict old entries
        await evictIfNeeded()
    }
    
    // MARK: - Cache Key Generation
    
    private nonisolated func cacheKey(for url: URL) -> String {
        // Use SHA256 hash of URL for consistent, safe filenames
        let data = Data(url.absoluteString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private nonisolated func diskURL(for url: URL) -> URL {
        let key = cacheKey(for: url)
        return diskCacheURL.appendingPathComponent(key + ".jpg")
    }
    
    // MARK: - Cache Eviction
    
    private func evictIfNeeded() async {
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return }
        
        // Calculate total size
        var totalSize: Int64 = 0
        var files: [(url: URL, size: Int64, date: Date)] = []
        
        for file in contents {
            guard let attrs = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let size = attrs.fileSize,
                  let date = attrs.contentModificationDate else { continue }
            
            totalSize += Int64(size)
            files.append((file, Int64(size), date))
        }
        
        // If under limit, no eviction needed
        guard totalSize > maxDiskCacheSize else { return }
        
        // Sort by date (oldest first)
        files.sort { $0.date < $1.date }
        
        // Delete oldest files until under 80% of limit
        let targetSize = Int64(Double(maxDiskCacheSize) * 0.8)
        for file in files {
            guard totalSize > targetSize else { break }
            try? fileManager.removeItem(at: file.url)
            totalSize -= file.size
        }
    }
    
    private func cleanOldCacheEntries() async {
        let fileManager = FileManager.default
        let cutoffDate = Date().addingTimeInterval(-maxCacheAge)
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        
        for file in contents {
            guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                  let date = attrs.contentModificationDate,
                  date < cutoffDate else { continue }
            
            try? fileManager.removeItem(at: file)
        }
    }
    
    // MARK: - Public API
    
    func clearMemoryCache() {
        memoryCache.removeAll()
    }
    
    func clearAllCache() async {
        memoryCache.removeAll()
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    func diskCacheSize() async -> Int64 {
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        
        return contents.reduce(0) { sum, file in
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + Int64(size)
        }
    }
}

// Convenience extension for simple usage
extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(url: url, content: content, placeholder: { ProgressView() })
    }
}

