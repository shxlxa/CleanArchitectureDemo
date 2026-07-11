//
//  HotKeyViewModel.swift
//  CleanArchitectureDemo
//
//  Created by cft on 2026/7/11.
//

import UIKit
import Combine

class HotKeyViewModel {
    
    enum State {
        case idle
        case loading
        case loaded([HotKey])
        case error(String)
    }
    
    @Published var state: State = .idle
    
    private let getHotKeysUseCase: GetHotKeysUseCase
    
    init(getHotKeysUseCase: GetHotKeysUseCase) {
        self.getHotKeysUseCase = getHotKeysUseCase
    }
    
    func loadHotKeys() {
        state = .loading
        Task {
            do {
                let hotKeys = try await getHotKeysUseCase.execute()
                print("✅ HotKeys 请求成功，共 \(hotKeys.count) 条：\(hotKeys)")
                state = .loaded(hotKeys)
            } catch {
                print("❌ HotKeys 请求失败：\(error)")
                state = .error(error.localizedDescription)
            }
        }
    }

}
