//
//  DeveloperModeViewController.swift
//  GoTato
//

import UIKit

#if DEBUG
final class DeveloperModeViewController: BaseViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let entities = ["Attendance", "Location", "Mission"]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "개발자 모드 (CoreData)"
    }

    override func configureHierarchy() {
        view.addSubview(tableView)
    }

    override func configureLayout() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func configureView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
}

extension DeveloperModeViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return entities.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = entities[indexPath.row]
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}

extension DeveloperModeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let entityName = entities[indexPath.row]
        let listVC = DeveloperEntityListViewController(entityName: entityName)
        navigationController?.pushViewController(listVC, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
#endif
