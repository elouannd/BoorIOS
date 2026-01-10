//
//  APIClient.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import Foundation

/// Generic API client for making network requests
actor APIClient {
    static let shared = APIClient()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private var rateLimitedUntil: Date?
    
    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        // Note: NOT using convertFromSnakeCase because Post and other models
        // have explicit CodingKeys for proper field mapping
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    /// Fetch and decode data from an endpoint
    func fetch<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        // Check rate limiting
        if let rateLimitedUntil = rateLimitedUntil, Date() < rateLimitedUntil {
            throw NetworkError.rateLimited(retryAfter: rateLimitedUntil.timeIntervalSinceNow)
        }
        
        guard let url = endpoint.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("BoriOuS/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        
        // Add custom headers
        endpoint.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Handle rate limiting
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap(TimeInterval.init)
            if let seconds = retryAfter {
                rateLimitedUntil = Date().addingTimeInterval(seconds)
            }
            throw NetworkError.rateLimited(retryAfter: retryAfter)
        }
        
        // Handle HTTP status codes
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw NetworkError.unauthorized
        case 404:
            throw NetworkError.notFound
        case 500...599:
            throw NetworkError.serverError
        default:
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    /// Fetch raw data (for images, etc.)
    func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("BoriOuS/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        
        return data
    }
}
