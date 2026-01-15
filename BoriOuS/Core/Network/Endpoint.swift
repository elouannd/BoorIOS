//
//  Endpoint.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import Foundation

/// HTTP methods supported by the API client
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// Protocol defining an API endpoint
protocol Endpoint {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem]? { get }
    var headers: [String: String]? { get }
}

extension Endpoint {
    var url: URL? {
        var components = URLComponents(string: baseURL)
        components?.path = path
        components?.queryItems = queryItems?.filter { $0.value != nil }
        return components?.url
    }
    
    var headers: [String: String]? { nil }
}

/// Booru-specific endpoints
enum BooruEndpoint: Endpoint {
    // Danbooru endpoints
    case danbooruPosts(baseURL: String, tags: String?, page: Int, limit: Int)
    case danbooruPost(baseURL: String, id: Int)
    case danbooruTags(baseURL: String, query: String, limit: Int)
    case danbooruAutocomplete(baseURL: String, query: String)
    
    // Safebooru endpoints
    case safebooruPosts(baseURL: String, tags: String?, page: Int, limit: Int)
    case safebooruTags(baseURL: String, query: String, limit: Int)
    
    // Gelbooru endpoints
    case gelbooruPosts(baseURL: String, tags: String?, page: Int, limit: Int, apiKey: String?, userId: String?)
    case gelbooruTags(baseURL: String, query: String, limit: Int)
    
    var baseURL: String {
        switch self {
        case .danbooruPosts(let url, _, _, _),
             .danbooruPost(let url, _),
             .danbooruTags(let url, _, _),
             .danbooruAutocomplete(let url, _):
            return url
            
        case .safebooruPosts(let url, _, _, _),
             .safebooruTags(let url, _, _):
            return url
            
        case .gelbooruPosts(let url, _, _, _, _, _),
             .gelbooruTags(let url, _, _):
            return url
        }
    }
    
    var path: String {
        switch self {
        case .danbooruPosts:
            return "/posts.json"
        case .danbooruPost(let id):
            return "/posts/\(id).json"
        case .danbooruTags:
            return "/tags.json"
        case .danbooruAutocomplete:
            return "/autocomplete.json"
        case .safebooruPosts, .gelbooruPosts:
            return "/index.php"
        case .safebooruTags, .gelbooruTags:
            return "/index.php"
        }
    }
    
    var method: HTTPMethod { .get }
    
    var queryItems: [URLQueryItem]? {
        switch self {
        case .danbooruPosts(_, let tags, let page, let limit):
            var items: [URLQueryItem] = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
            if let tags = tags, !tags.isEmpty {
                items.append(URLQueryItem(name: "tags", value: tags))
            }
            return items
            
        case .danbooruPost:
            return nil
            
        case .danbooruTags(_, let query, let limit):
            return [
                URLQueryItem(name: "search[name_matches]", value: "\(query)*"),
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "search[order]", value: "count")
            ]
            
        case .danbooruAutocomplete(_, let query):
            return [
                URLQueryItem(name: "search[query]", value: query),
                URLQueryItem(name: "search[type]", value: "tag_query"),
                URLQueryItem(name: "limit", value: "10")
            ]
            
        case .safebooruPosts(_, let tags, let page, let limit):
            var items: [URLQueryItem] = [
                URLQueryItem(name: "page", value: "dapi"),
                URLQueryItem(name: "s", value: "post"),
                URLQueryItem(name: "q", value: "index"),
                URLQueryItem(name: "json", value: "1"),
                URLQueryItem(name: "pid", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
            if let tags = tags, !tags.isEmpty {
                items.append(URLQueryItem(name: "tags", value: tags))
            }
            return items
            
        case .safebooruTags(_, let query, let limit):
            return [
                URLQueryItem(name: "page", value: "dapi"),
                URLQueryItem(name: "s", value: "tag"),
                URLQueryItem(name: "q", value: "index"),
                URLQueryItem(name: "json", value: "1"),
                URLQueryItem(name: "name_pattern", value: "\(query)%"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
            
        case .gelbooruPosts(_, let tags, let page, let limit, let apiKey, let userId):
            var items: [URLQueryItem] = [
                URLQueryItem(name: "page", value: "dapi"),
                URLQueryItem(name: "s", value: "post"),
                URLQueryItem(name: "q", value: "index"),
                URLQueryItem(name: "json", value: "1"),
                URLQueryItem(name: "pid", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
            if let tags = tags, !tags.isEmpty {
                items.append(URLQueryItem(name: "tags", value: tags))
            }
            if let apiKey = apiKey {
                items.append(URLQueryItem(name: "api_key", value: apiKey))
            }
            if let userId = userId {
                items.append(URLQueryItem(name: "user_id", value: userId))
            }
            return items
            
        case .gelbooruTags(_, let query, let limit):
            return [
                URLQueryItem(name: "page", value: "dapi"),
                URLQueryItem(name: "s", value: "tag"),
                URLQueryItem(name: "q", value: "index"),
                URLQueryItem(name: "json", value: "1"),
                URLQueryItem(name: "name_pattern", value: "\(query)%"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        }
    }
}
