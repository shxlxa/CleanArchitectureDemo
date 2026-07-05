//
//  NetworkService.swift
//  CleanArchitectureDemo
//

import Foundation

protocol NetworkServiceProtocol {
    func request<T: Decodable & Sendable>(_ endpoint: APIEndpoint, as type: T.Type) async throws -> T
}

final class NetworkService: NetworkServiceProtocol {

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    func request<T: Decodable & Sendable>(_ endpoint: APIEndpoint, as type: T.Type) async throws -> T {
        let urlRequest = try endpoint.makeURLRequest()
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.statusCode(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
