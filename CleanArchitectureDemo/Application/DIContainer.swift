//
//  DIContainer.swift
//  CleanArchitectureDemo
//
//  组装各层依赖：Network → Repository → UseCase → ViewModel → VC。
//  替换数据来源（如本地缓存 / Mock）只需改这里，一处生效。
//

import UIKit

final class DIContainer {

    private lazy var networkService: NetworkServiceProtocol = NetworkService()

    private lazy var bannerRepository: BannerRepository = BannerRepositoryImpl(
        networkService: networkService
    )
    
    private lazy var hotKeyRepository: HotKeyRepository = HotKeyRepositoryImpl(
        networkService: networkService
    )

    func makeHomeViewController() -> HomeViewController {
        let useCase = GetBannersUseCase(repository: bannerRepository)
        let viewModel = HomeViewModel(getBannersUseCase: useCase)
        return HomeViewController(viewModel: viewModel)
    }
    
    // HotKeyViewController
    func makeHotKeyViewController() -> HotKeyViewController {
        let useCase = GetHotKeysUseCase(repository: hotKeyRepository)
        let viewModel = HotKeyViewModel(getHotKeysUseCase: useCase)
        return HotKeyViewController(viewModel: viewModel)
    }
}
