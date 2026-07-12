//
//  HotKeyViewModel.swift
//  CleanArchitectureDemo
//
//  Created by cft on 2026/7/11.
//

import Foundation

class HotKeyViewModel {
    
    enum State {
        case idle
        case loading
        case loaded([HotKey])
        case error(String)
    }
    
    var onStateChanged: ((State) -> Void)?
    
    private var _state: State = .idle {
        didSet { onStateChanged?(_state) }
    }
    
    var state: State { _state }
    
    private let getHotKeysUseCase: GetHotKeysUseCase
    
    init(getHotKeysUseCase: GetHotKeysUseCase) {
        self.getHotKeysUseCase = getHotKeysUseCase
    }
    
    func loadHotKeys() {
        _state = .loading
        Task {
            do {
                let hotKeys = try await getHotKeysUseCase.execute()
                print("✅ HotKeys 请求成功，共 \(hotKeys.count) 条：\(hotKeys)")
                _state = .loaded(hotKeys)
            } catch {
                print("❌ HotKeys 请求失败：\(error)")
                _state = .error(error.localizedDescription)
            }
        }
    }

}
