//
//  BannerCell.swift
//  CleanArchitectureDemo
//

import UIKit

final class BannerCell: UITableViewCell {

    static let reuseIdentifier = "BannerCell"

    private let bannerImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .secondarySystemFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var imageLoadTask: Task<Void, Never>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask?.cancel()
        imageLoadTask = nil
        bannerImageView.image = nil
    }

    func configure(with banner: Banner) {
        titleLabel.text = banner.title
        descLabel.text = banner.desc.isEmpty ? banner.linkURL?.absoluteString : banner.desc
        loadImage(from: banner.imageURL)
    }
}

// MARK: - UI Setup

private extension BannerCell {

    func setupUI() {
        selectionStyle = .none
        contentView.addSubview(bannerImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(descLabel)

        NSLayoutConstraint.activate([
            bannerImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            bannerImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bannerImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            bannerImageView.heightAnchor.constraint(equalTo: bannerImageView.widthAnchor, multiplier: 0.45),

            titleLabel.topAnchor.constraint(equalTo: bannerImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: bannerImageView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: bannerImageView.trailingAnchor),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descLabel.leadingAnchor.constraint(equalTo: bannerImageView.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: bannerImageView.trailingAnchor),
            descLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
}

// MARK: - Image Loading

private extension BannerCell {

    func loadImage(from url: URL?) {
        guard let url else { return }
        imageLoadTask = Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data),
                  !Task.isCancelled else { return }
            self?.bannerImageView.image = image
        }
    }
}
