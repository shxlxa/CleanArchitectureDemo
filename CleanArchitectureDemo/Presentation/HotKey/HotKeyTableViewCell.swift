//
//  HotKeyTableViewCell.swift
//  CleanArchitectureDemo
//
//  Created by cft on 2026/7/11.
//

import UIKit

final class HotKeyTableViewCell: UITableViewCell {

    static let reuseIdentifier = "HotKeyTableViewCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with hotKey: HotKey) {
        textLabel?.text = hotKey.name
    }
}
