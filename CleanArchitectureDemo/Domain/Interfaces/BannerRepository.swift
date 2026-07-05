//
//  BannerRepository.swift
//  CleanArchitectureDemo
//
//  Domain 层只定义抽象，具体实现（网络 / 本地）由 Data 层提供 —— 依赖倒置。
//

import Foundation

protocol BannerRepository {
    func fetchBanners() async throws -> [Banner]
}
