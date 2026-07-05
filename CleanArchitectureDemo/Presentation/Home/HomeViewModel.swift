//
//  HomeViewModel.swift
//  CleanArchitectureDemo
//
//  ViewModel 只依赖 UseCase，不知道数据来自网络还是本地。
//

import Foundation
import Combine

@MainActor
final class HomeViewModel {

    enum State: Equatable {
        case idle
        case loading
        case loaded([Banner])
        case error(String)
    }

    @Published private(set) var state: State = .idle

    private let getBannersUseCase: GetBannersUseCase

    init(getBannersUseCase: GetBannersUseCase) {
        self.getBannersUseCase = getBannersUseCase
    }

    func loadBanners() {
        state = .loading
        Task {
            do {
                let banners = try await getBannersUseCase.execute()
                state = .loaded(banners)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}
