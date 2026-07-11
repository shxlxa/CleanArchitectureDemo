//
//  HotKey.swift
//  CleanArchitectureDemo
//
//  Created by cft on 2026/7/11.
//

import Foundation

nonisolated struct HotKey: Equatable, Hashable, Sendable {
    let id: Int
    let link: String
    let name: String
    let order: Int
    let visible: Int
}
