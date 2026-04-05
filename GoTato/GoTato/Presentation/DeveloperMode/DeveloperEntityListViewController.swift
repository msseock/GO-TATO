//
//  DeveloperEntityListViewController.swift
//  GoTato
//

import UIKit
import CoreData

#if DEBUG
final class DeveloperEntityListViewController: BaseViewController {
    private let entityName: String
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var records: [NSManagedObject] = []

    init(entityName: String) {
        self.entityName = entityName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "\(entityName) 리스트"
        setupNavigationBar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchRecords()
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

    private func setupNavigationBar() {
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(didTapAdd))
        navigationItem.rightBarButtonItem = addButton
    }

    private func fetchRecords() {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        do {
            records = try CoreDataStack.shared.viewContext.fetch(request)
            tableView.reloadData()
        } catch {
            print("Fetch Error: \(error)")
        }
    }

    @objc private func didTapAdd() {
        let editVC = DeveloperEntityEditViewController(entityName: entityName)
        navigationController?.pushViewController(editVC, animated: true)
    }
}

extension DeveloperEntityListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return records.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let record = records[indexPath.row]
        
        var text = ""
        if let mission = record as? Mission {
            text = mission.title ?? "Untitled"
        } else if let location = record as? Location {
            text = location.name ?? "Unknown Location"
        } else if let attendance = record as? Attendance {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            text = "Attendance: \(formatter.string(from: attendance.planDate ?? Date()))"
        } else {
            text = "\(record.objectID.uriRepresentation().lastPathComponent)"
        }
        
        cell.textLabel?.text = text
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}

extension DeveloperEntityListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let record = records[indexPath.row]
        let editVC = DeveloperEntityEditViewController(entityName: entityName, record: record)
        navigationController?.pushViewController(editVC, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let record = records[indexPath.row]
            CoreDataStack.shared.viewContext.delete(record)
            CoreDataStack.shared.saveViewContext()
            records.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
}
#endif
