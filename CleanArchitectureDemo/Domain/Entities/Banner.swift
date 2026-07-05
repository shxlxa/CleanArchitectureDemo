//
//  Banner.swift
//  CleanArchitectureDemo
//
//  Domain 实体：纯业务模型，不依赖任何网络 / 存储细节。
//

import Foundation

nonisolated struct Banner: Equatable, Hashable, Sendable {
    let id: Int
    let title: String
    let desc: String
    let imageURL: URL?
    let linkURL: URL?
}
