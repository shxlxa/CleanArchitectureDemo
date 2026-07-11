//
//  HotKeyViewController.swift
//  CleanArchitectureDemo
//
//  Created by cft on 2026/7/11.
//

import UIKit
import Combine

class HotKeyViewController: UIViewController {

    private let viewModel: HotKeyViewModel
    private var hotKeys: [HotKey] = []
    private var cancellables = Set<AnyCancellable>()

    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.register(HotKeyTableViewCell.self, forCellReuseIdentifier: HotKeyTableViewCell.reuseIdentifier)
//        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    init(viewModel: HotKeyViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "HotKey"
        view.backgroundColor = .systemBackground

        setupUI()
        bindViewModel()
        viewModel.loadHotKeys()
    }
}

// MARK: - UI Setup

private extension HotKeyViewController {

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
        viewModel.loadHotKeys()
    }
}

// MARK: - ViewModel Binding

private extension HotKeyViewController {

    func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.render(state)
            }
            .store(in: &cancellables)
    }

    func render(_ state: HotKeyViewModel.State) {
        switch state {
        case .idle:
            break
        case .loading:
            if tableView.refreshControl?.isRefreshing != true {
                loadingIndicator.startAnimating()
            }
        case .loaded(let hotKeys):
            loadingIndicator.stopAnimating()
            tableView.refreshControl?.endRefreshing()
            self.hotKeys = hotKeys
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
            self?.viewModel.loadHotKeys()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension HotKeyViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        hotKeys.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: HotKeyTableViewCell.reuseIdentifier,
            for: indexPath
        ) as? HotKeyTableViewCell else {
            return UITableViewCell()
        }
        cell.configure(with: hotKeys[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
    }
}
