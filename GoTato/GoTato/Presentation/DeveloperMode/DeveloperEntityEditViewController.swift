//
//  DeveloperEntityEditViewController.swift
//  GoTato
//

import UIKit
import CoreData

#if DEBUG
final class DeveloperEntityEditViewController: BaseViewController {
    private let entityName: String
    private var record: NSManagedObject?
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var inputFields: [String: UIView] = [:]

    init(entityName: String, record: NSManagedObject? = nil) {
        self.entityName = entityName
        self.record = record
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = record == nil ? "New \(entityName)" : "Edit \(entityName)"
        setupNavigationBar()
    }

    override func configureHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
    }

    override func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    override func configureView() {
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.distribution = .fill
        
        setupFields()
    }

    private func setupFields() {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: CoreDataStack.shared.viewContext) else { return }
        
        for (name, attribute) in entity.attributesByName {
            let label = UILabel()
            label.text = name
            label.font = .systemFont(ofSize: 14, weight: .bold)
            stackView.addArrangedSubview(label)

            let inputView: UIView
            switch attribute.attributeType {
            case .dateAttributeType:
                let picker = UIDatePicker()
                picker.datePickerMode = .dateAndTime
                if let date = record?.value(forKey: name) as? Date {
                    picker.date = date
                }
                inputView = picker
            case .UUIDAttributeType:
                let textField = UITextField()
                textField.borderStyle = .roundedRect
                if let uuid = record?.value(forKey: name) as? UUID {
                    textField.text = uuid.uuidString
                } else if record == nil && name == "id" {
                    textField.text = UUID().uuidString
                }
                textField.placeholder = "UUID String"
                inputView = textField
            case .stringAttributeType:
                let textField = UITextField()
                textField.borderStyle = .roundedRect
                textField.text = record?.value(forKey: name) as? String
                textField.placeholder = "Enter \(name)"
                inputView = textField
            case .doubleAttributeType, .floatAttributeType, .integer16AttributeType, .integer32AttributeType, .integer64AttributeType, .decimalAttributeType:
                let textField = UITextField()
                textField.borderStyle = .roundedRect
                textField.keyboardType = .decimalPad
                if let value = record?.value(forKey: name) {
                    textField.text = "\(value)"
                }
                textField.placeholder = "Number"
                inputView = textField
            default:
                let textField = UITextField()
                textField.borderStyle = .roundedRect
                textField.isEnabled = false
                textField.text = "Unsupported Type"
                inputView = textField
            }
            
            stackView.addArrangedSubview(inputView)
            inputFields[name] = inputView
        }
    }

    private func setupNavigationBar() {
        let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
        navigationItem.rightBarButtonItem = saveButton
    }

    @objc private func didTapSave() {
        let context = CoreDataStack.shared.viewContext
        let objectToSave: NSManagedObject
        
        if let existing = record {
            objectToSave = existing
        } else {
            objectToSave = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        }
        
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else { return }
        
        for (name, attribute) in entity.attributesByName {
            guard let inputView = inputFields[name] else { continue }
            
            var value: Any?
            switch attribute.attributeType {
            case .dateAttributeType:
                value = (inputView as? UIDatePicker)?.date
            case .UUIDAttributeType:
                if let text = (inputView as? UITextField)?.text {
                    value = UUID(uuidString: text)
                }
            case .stringAttributeType:
                value = (inputView as? UITextField)?.text
            case .doubleAttributeType, .floatAttributeType, .decimalAttributeType:
                if let text = (inputView as? UITextField)?.text {
                    value = Double(text)
                }
            case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
                if let text = (inputView as? UITextField)?.text {
                    value = Int(text)
                }
            default:
                break
            }
            
            if let value = value {
                objectToSave.setValue(value, forKey: name)
            }
        }
        
        CoreDataStack.shared.saveViewContext()
        navigationController?.popViewController(animated: true)
    }
}
#endif
