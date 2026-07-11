//
//  HotKeyDTO.swift
//  CleanArchitectureDemo
//
//  Created by cft on 2026/7/11.
//

import Foundation

nonisolated struct HotKeyDTO: Decodable, Equatable, Hashable, Sendable {
    let id: Int
    let link: String
    let name: String
    let order: Int
    let visible: Int

    func toDomain() -> HotKey {
        HotKey(id: id, link: link, name: name, order: order, visible: visible)
    }
}

