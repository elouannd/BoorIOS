//
//  NetworkError.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import Foundation

/// Errors that can occur during network operations
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkUnavailable
    case rateLimited(retryAfter: TimeInterval?)
    case unauthorized
    case notFound
    case serverError
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkUnavailable:
            return "Network unavailable"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Retry after \(Int(seconds)) seconds"
            }
            return "Rate limited. Please try again later"
        case .unauthorized:
            return "Unauthorized. Check your API credentials"
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error. Please try again later"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
