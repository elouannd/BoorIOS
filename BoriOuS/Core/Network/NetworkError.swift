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
            return "Invalid Response"
        case .httpError(let statusCode):
            return "Server Error (\(statusCode))"
        case .decodingError:
            return "Data Error"
        case .networkUnavailable:
            return "No Connection"
        case .rateLimited:
            return "Too Many Requests"
        case .unauthorized:
            return "Authentication Required"
        case .notFound:
            return "Not Found"
        case .serverError:
            return "Server Error"
        case .unknown:
            return "Something Went Wrong"
        }
    }
    
    /// User-friendly recovery suggestion
    var recoverySuggestion: String {
        switch self {
        case .invalidURL:
            return "The source URL appears to be invalid. Try selecting a different source."
        case .invalidResponse:
            return "The server returned an unexpected response. Try again later."
        case .httpError(let statusCode):
            if statusCode == 403 {
                return "Access denied. This source may require an API key."
            } else if statusCode == 404 {
                return "The content could not be found."
            } else if statusCode >= 500 {
                return "The server is experiencing issues. Try again later."
            }
            return "An error occurred. Try refreshing or switching sources."
        case .decodingError:
            return "The data couldn't be read. The source may have changed their format."
        case .networkUnavailable:
            return "Check your internet connection and try again."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Too many requests. Please wait \(Int(seconds)) seconds."
            }
            return "Too many requests. Please wait a moment before trying again."
        case .unauthorized:
            return "This source requires API credentials. Check Settings → Sources."
        case .notFound:
            return "No results found with these tags. Try different search terms."
        case .serverError:
            return "The server is temporarily unavailable. Try again later."
        case .unknown:
            return "An unexpected error occurred. Try refreshing."
        }
    }
    
    /// SF Symbol icon for the error
    var icon: String {
        switch self {
        case .networkUnavailable:
            return "wifi.slash"
        case .unauthorized:
            return "lock.fill"
        case .rateLimited:
            return "clock.badge.exclamationmark"
        case .notFound:
            return "magnifyingglass"
        case .serverError, .httpError:
            return "server.rack"
        case .decodingError:
            return "doc.questionmark"
        default:
            return "exclamationmark.triangle.fill"
        }
    }
    
    /// Whether the error is likely transient and retrying might help
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .rateLimited, .serverError, .unknown:
            return true
        case .httpError(let statusCode):
            return statusCode >= 500
        default:
            return false
        }
    }
}

