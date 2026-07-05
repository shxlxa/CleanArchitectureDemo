//
//  BannerDTO.swift
//  CleanArchitectureDemo
//
//  Data 层 DTO：与 wanandroid API 的 JSON 结构一一对应，
//  通过 toDomain() 转换为 Domain 实体，隔离网络模型与业务模型。
//

import Foundation

nonisolated struct WanAndroidResponseDTO<T: Decodable & Sendable>: Decodable, Sendable {
    let data: T?
    let errorCode: Int
    let errorMsg: String
}

nonisolated struct BannerDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let desc: String
    let imagePath: String
    let url: String

    func toDomain() -> Banner {
        Banner(
            id: id,
            title: title,
            desc: desc,
            imageURL: URL(string: imagePath),
            linkURL: URL(string: url)
        )
    }
}
