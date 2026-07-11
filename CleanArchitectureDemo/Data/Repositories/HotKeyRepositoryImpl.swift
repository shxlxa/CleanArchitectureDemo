//
//  HotKeyRepositoryImpl.swift
//  CleanArchitectureDemo
//
//  Created by cft on 2026/7/11.
//

import Foundation

final class HotKeyRepositoryImpl: HotKeyRepository {
    private let networkService: NetworkServiceProtocol
    
    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }

    func fetchHotKeys() async throws -> [HotKey] {
        let response = try await networkService.request(
            .hotKey,
            as: WanAndroidResponseDTO<[HotKeyDTO]>.self
        )
        guard response.errorCode == 0 else {
            throw NetworkError.serverError(code: response.errorCode, message: response.errorMsg)
        }
        
        return (response.data ?? []).map { $0.toDomain()}
        
    }


}
