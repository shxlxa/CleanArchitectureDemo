//
//  GetBannersUseCase.swift
//  CleanArchitectureDemo
//

import Foundation

final class GetBannersUseCase {

    private let repository: BannerRepository

    init(repository: BannerRepository) {
        self.repository = repository
    }

    func execute() async throws -> [Banner] {
        try await repository.fetchBanners()
    }
}
