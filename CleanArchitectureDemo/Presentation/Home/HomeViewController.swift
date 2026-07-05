//
//  HomeViewController.swift
//  CleanArchitectureDemo
//
//  VC 只与 ViewModel 交互，通过 Combine 订阅状态刷新 UI。
//

import UIKit
import Combine

final class HomeViewController: UIViewController {

    private let viewModel: HomeViewModel
    private var banners: [Banner] = []
    private var cancellables = Set<AnyCancellable>()

    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.register(BannerCell.self, forCellReuseIdentifier: BannerCell.reuseIdentifier)
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Banner"
        view.backgroundColor = .systemBackground
        setupUI()
        bindViewModel()
        viewModel.loadBanners()
    }
}

// MARK: - UI Setup

private extension HomeViewController {

    func setupUI() {
        view.addSubview(tableView)
        view.addSubview(loadingIndicator)
        tableView.dataSource = self

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }

    @objc func handleRefresh() {
        viewModel.loadBanners()
    }
}

// MARK: - ViewModel Binding

private extension HomeViewController {

    func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.render(state)
            }
            .store(in: &cancellables)
    }

    func render(_ state: HomeViewModel.State) {
        switch state {
        case .idle:
            break
        case .loading:
            if tableView.refreshControl?.isRefreshing != true {
                loadingIndicator.startAnimating()
            }
        case .loaded(let banners):
            loadingIndicator.stopAnimating()
            tableView.refreshControl?.endRefreshing()
            self.banners = banners
            tableView.reloadData()
        case .error(let message):
            loadingIndicator.stopAnimating()
            tableView.refreshControl?.endRefreshing()
            presentError(message)
        }
    }

    func presentError(_ message: String) {
        let alert = UIAlertController(title: "加载失败", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
            self?.viewModel.loadBanners()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension HomeViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        banners.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: BannerCell.reuseIdentifier,
            for: indexPath
        ) as? BannerCell else {
            return UITableViewCell()
        }
        cell.configure(with: banners[indexPath.row])
        return cell
    }
}
