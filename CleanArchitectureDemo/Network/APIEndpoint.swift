//
//  APIEndpoint.swift
//  CleanArchitectureDemo
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

struct APIEndpoint {
    let path: String
    let method: HTTPMethod

    static let baseURL = URL(string: "https://www.wanandroid.com")!

    func makeURLRequest() throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: Self.baseURL) else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        return request
    }
}

// MARK: - Endpoints

extension APIEndpoint {
    static let banner = APIEndpoint(path: "/banner/json", method: .get)
    
    static let hotKey = APIEndpoint(path: "/hotkey/json", method: .get)
}
