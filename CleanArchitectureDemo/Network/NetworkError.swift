//
//  NetworkError.swift
//  CleanArchitectureDemo
//

import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case statusCode(Int)
    case decodingFailed(Error)
    case serverError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的响应"
        case .statusCode(let code):
            return "HTTP 错误：\(code)"
        case .decodingFailed(let error):
            return "解析失败：\(error.localizedDescription)"
        case .serverError(let code, let message):
            return "服务端错误（\(code)）：\(message)"
        }
    }
}
