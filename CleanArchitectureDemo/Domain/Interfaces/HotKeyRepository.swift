//
//  HotKeyRepositoory.swift
//  CleanArchitectureDemo
//
//  Created by cft on 2026/7/11.
//

import Foundation

protocol HotKeyRepository {
    func fetchHotKeys() async throws -> [HotKey]
}
