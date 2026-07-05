//
//  BannerRepositoryImpl.swift
//  CleanArchitectureDemo
//
//  BannerRepository 的网络实现。如需本地缓存 / Mock，
//  只需新增另一个实现并在 DIContainer 中替换，上层无感知。
//

import Foundation

final class BannerRepositoryImpl: BannerRepository {

    private let networkService: NetworkServiceProtocol

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }

    func fetchBanners() async throws -> [Banner] {
        let response = try await networkService.request(
            .banner,
            as: WanAndroidResponseDTO<[BannerDTO]>.self
        )
        guard response.errorCode == 0 else {
            throw NetworkError.serverError(code: response.errorCode, message: response.errorMsg)
        }
        return (response.data ?? []).map { $0.toDomain() }
    }
}
