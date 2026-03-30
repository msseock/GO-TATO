//
//  EditLocationNameSheetViewController.swift
//  GoTato
//

import UIKit
import SnapKit

final class EditLocationNameSheetViewController: UIViewController {

    // MARK: - Callback

    var onConfirm: ((String) -> Void)?

    // MARK: - UI

    private let titleLabel    = UILabel()
    private let textField     = UITextField()
    private let errorLabel    = UILabel()
    private let cancelButton  = UIButton(type: .system)
    private let confirmButton = UIButton(type: .system)

    // MARK: - Properties

    private let currentName: String

    // MARK: - Init

    init(currentName: String) {
        self.currentName = currentName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = GTTColor.bgPrimary
        setupUI()
        setupLayout()
        updateConfirmState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textField.becomeFirstResponder()
    }

    // MARK: - Setup

    private func setupUI() {
        titleLabel.text      = "위치 이름 수정"
        titleLabel.font      = GTTFont.subHeading.font
        titleLabel.textColor = GTTColor.textPrimary
        titleLabel.textAlignment = .center

        textField.text            = currentName
        textField.font            = GTTFont.body.font
        textField.textColor       = GTTColor.textPrimary
        textField.borderStyle     = .roundedRect
        textField.backgroundColor = GTTColor.surface
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType   = .done
        textField.delegate        = self
        textField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)

        errorLabel.font      = GTTFont.caption.font
        errorLabel.textColor = GTTColor.error
        errorLabel.isHidden  = true

        cancelButton.setTitle("취소", for: .normal)
        cancelButton.titleLabel?.font = GTTFont.body.font
        cancelButton.setTitleColor(GTTColor.textSecondary, for: .normal)
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)

        confirmButton.setTitle("확인", for: .normal)
        confirmButton.titleLabel?.font = GTTFont.subHeading.font
        confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)

        [titleLabel, textField, errorLabel, cancelButton, confirmButton].forEach { view.addSubview($0) }
    }

    private func setupLayout() {
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(24)
            $0.centerX.equalToSuperview()
        }
        textField.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(20)
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.height.equalTo(48)
        }
        errorLabel.snp.makeConstraints {
            $0.top.equalTo(textField.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview().inset(24)
        }
        cancelButton.snp.makeConstraints {
            $0.top.equalTo(errorLabel.snp.bottom).offset(20)
            $0.leading.equalToSuperview().inset(24)
            $0.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).inset(20)
        }
        confirmButton.snp.makeConstraints {
            $0.centerY.equalTo(cancelButton)
            $0.trailing.equalToSuperview().inset(24)
        }
    }

    // MARK: - Validation

    @objc private func textDidChange() {
        updateConfirmState()
    }

    private func updateConfirmState() {
        let trimmed = (textField.text ?? "").trimmingCharacters(in: .whitespaces)
        let isValid = !trimmed.isEmpty && trimmed != currentName
        confirmButton.isEnabled = isValid
        confirmButton.setTitleColor(isValid ? GTTColor.brand : GTTColor.textMuted, for: .normal)

        if !trimmed.isEmpty && trimmed.isEmpty {
            errorLabel.text    = "빈 이름은 사용할 수 없습니다."
            errorLabel.isHidden = false
        } else {
            errorLabel.isHidden = true
        }
    }

    // MARK: - Actions

    @objc private func didTapConfirm() {
        guard let trimmed = textField.text?.trimmingCharacters(in: .whitespaces),
              !trimmed.isEmpty else { return }
        onConfirm?(trimmed)
        dismiss(animated: true)
    }

    @objc private func didTapCancel() {
        dismiss(animated: true)
    }
}

extension EditLocationNameSheetViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if confirmButton.isEnabled { didTapConfirm() }
        return true
    }
}
