//
//  GetHotKeysUseCase.swift
//  CleanArchitectureDemo
//
//  Created by cft on 2026/7/11.
//

import Foundation

final class GetHotKeysUseCase {
    private let repository: HotKeyRepository
    
    init(repository: HotKeyRepository) {
        self.repository = repository
    }
    
    func execute() async throws -> [HotKey] {
        return try await repository.fetchHotKeys()
    }
}


