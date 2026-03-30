//
//  EditMissionSheetViewController.swift
//  GoTato
//

import UIKit
import SnapKit

struct EditMissionResult {
    let newTitle: String?
    let newLocationName: String?
    let newDeadline: Date?
}

final class EditMissionSheetViewController: UIViewController {

    // MARK: - Callback

    var onConfirm: ((EditMissionResult) -> Void)?

    // MARK: - Properties

    private let currentTitle: String
    private let forbiddenTitles: [String]
    private let currentLocationName: String?
    private let currentDeadline: Date
    private let canEditLocationAndDeadline: Bool

    // MARK: - UI — Scroll

    private let scrollView    = UIScrollView()
    private let contentStack  = UIStackView()

    // MARK: - UI — 미션 이름 Section

    private let missionNameCard  = UIView()
    private let missionNameField = UITextField()
    private let missionNameError = UILabel()

    // MARK: - UI — 위치 이름 Section

    private let locationCard  = UIView()
    private let locationField = UITextField()

    // MARK: - UI — 마감 시각 Section

    private let deadlineCard  = UIView()
    private let timePicker    = UIDatePicker()

    // MARK: - Init

    init(
        currentTitle: String,
        forbiddenTitles: [String],
        currentLocationName: String?,
        currentDeadline: Date,
        isMissionEnded: Bool
    ) {
        self.currentTitle               = currentTitle
        self.forbiddenTitles            = forbiddenTitles
        self.currentLocationName        = currentLocationName
        self.currentDeadline            = currentDeadline
        self.canEditLocationAndDeadline = !isMissionEnded
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = GTTColor.surface
        setupNavigationBar()
        setupUI()
        setupHierarchy()
        setupLayout()
        updateConfirmState()
    }

    // MARK: - Setup: Navigation Bar

    private func setupNavigationBar() {
        self.title = "미션 수정"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "완료",
            style: .done,
            target: self,
            action: #selector(didTapConfirm)
        )
        navigationItem.rightBarButtonItem?.tintColor = GTTColor.brand
    }

    // MARK: - Setup: UI

    private func setupUI() {
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode  = .interactive

        contentStack.axis    = .vertical
        contentStack.spacing = 24

        // Mission name card
        missionNameCard.backgroundColor   = GTTColor.bgPrimary
        missionNameCard.layer.cornerRadius = 12

        missionNameField.text            = currentTitle
        missionNameField.font            = GTTFont.body.font
        missionNameField.textColor       = GTTColor.textPrimary
        missionNameField.backgroundColor = .clear
        missionNameField.borderStyle     = .none
        missionNameField.clearButtonMode = .whileEditing
        missionNameField.returnKeyType   = .done
        missionNameField.delegate        = self
        missionNameField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)

        missionNameError.font          = GTTFont.caption.font
        missionNameError.textColor     = GTTColor.error
        missionNameError.numberOfLines = 0
        missionNameError.isHidden      = true

        // Location card
        locationCard.backgroundColor   = GTTColor.bgPrimary
        locationCard.layer.cornerRadius = 12

        locationField.text            = currentLocationName ?? ""
        locationField.font            = GTTFont.body.font
        locationField.textColor       = GTTColor.textPrimary
        locationField.backgroundColor = .clear
        locationField.borderStyle     = .none
        locationField.clearButtonMode = .whileEditing
        locationField.returnKeyType   = .done
        locationField.delegate        = self
        locationField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)

        // Deadline card
        deadlineCard.backgroundColor   = GTTColor.bgPrimary
        deadlineCard.layer.cornerRadius = 12
        deadlineCard.clipsToBounds      = true

        timePicker.datePickerMode           = .time
        timePicker.preferredDatePickerStyle = .wheels
        timePicker.locale   = Locale(identifier: "ko_KR")
        timePicker.date     = currentDeadline
        timePicker.backgroundColor = GTTColor.bgPrimary
        timePicker.addTarget(self, action: #selector(timePickerChanged), for: .valueChanged)
    }

    // MARK: - Setup: Hierarchy

    private func setupHierarchy() {
        // Scroll
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        // 미션 이름 section
        missionNameCard.addSubview(missionNameField)
        let titleSection = makeSectionStack(
            headerText: "미션 이름",
            card: missionNameCard,
            footer: missionNameError
        )
        contentStack.addArrangedSubview(titleSection)

        // 위치 이름 section (only if location exists and mission not ended)
        if canEditLocationAndDeadline && currentLocationName != nil {
            locationCard.addSubview(locationField)
            let locationSection = makeSectionStack(
                headerText: "위치 이름",
                card: locationCard
            )
            contentStack.addArrangedSubview(locationSection)
        }

        // 마감 시각 section (only if mission not ended)
        if canEditLocationAndDeadline {
            deadlineCard.addSubview(timePicker)
            let deadlineSection = makeSectionStack(
                headerText: "마감 시각",
                card: deadlineCard
            )
            contentStack.addArrangedSubview(deadlineSection)
        }
    }

    private func makeSectionStack(headerText: String, card: UIView, footer: UIView? = nil) -> UIStackView {
        let label = UILabel()
        label.text      = headerText
        label.font      = GTTFont.captionSmall.font
        label.textColor = GTTColor.textSecondary

        var views: [UIView] = [label, card]
        if let footer { views.append(footer) }

        let stack = UIStackView(arrangedSubviews: views)
        stack.axis    = .vertical
        stack.spacing = 6
        return stack
    }

    // MARK: - Setup: Layout

    private func setupLayout() {
        // Scroll
        scrollView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        contentStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 24, left: 20, bottom: 32, right: 20))
            $0.width.equalTo(scrollView).offset(-40)
        }

        // Text field cards
        missionNameField.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
        }
        missionNameCard.snp.makeConstraints { $0.height.equalTo(50) }

        if currentLocationName != nil {
            locationField.snp.makeConstraints {
                $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
            }
            locationCard.snp.makeConstraints { $0.height.equalTo(50) }
        }

        // Time picker card fills naturally (wheels picker is ~216pt tall)
        if canEditLocationAndDeadline {
            timePicker.snp.makeConstraints { $0.edges.equalToSuperview() }
        }
    }

    // MARK: - Validation

    @objc private func textDidChange() {
        updateConfirmState()
    }

    @objc private func timePickerChanged() {
        updateConfirmState()
    }

    private func updateConfirmState() {
        let rawTitle     = missionNameField.text ?? ""
        let trimmedTitle = rawTitle.trimmingCharacters(in: .whitespaces)

        // Title error check
        var titleError: String? = nil
        if !rawTitle.isEmpty && trimmedTitle.isEmpty {
            titleError = "공백만 입력할 수 없습니다."
        } else if trimmedTitle.count > 20 {
            titleError = "미션 이름은 최대 20자까지 입력 가능합니다."
        } else if forbiddenTitles.contains(trimmedTitle) {
            titleError = "이미 사용 중인 미션 이름입니다."
        }

        setTitleError(titleError)

        let titleChanged = !trimmedTitle.isEmpty && trimmedTitle != currentTitle && titleError == nil

        // Location changed
        var locationChanged = false
        if canEditLocationAndDeadline, let currentLoc = currentLocationName {
            let trimmedLoc = (locationField.text ?? "").trimmingCharacters(in: .whitespaces)
            locationChanged = !trimmedLoc.isEmpty && trimmedLoc != currentLoc
        }

        // Deadline changed
        var deadlineChanged = false
        if canEditLocationAndDeadline {
            deadlineChanged = !Calendar.current.isDate(
                timePicker.date, equalTo: currentDeadline, toGranularity: .minute
            )
        }

        let hasValidChange   = titleChanged || locationChanged || deadlineChanged
        let hasBlockingError = titleError != nil

        let enabled = hasValidChange && !hasBlockingError
        navigationItem.rightBarButtonItem?.isEnabled = enabled
        navigationItem.rightBarButtonItem?.tintColor = enabled ? GTTColor.brand : GTTColor.textMuted
    }

    private func setTitleError(_ message: String?) {
        if let msg = message {
            missionNameError.text    = msg
            missionNameError.isHidden = false
        } else {
            missionNameError.isHidden = true
        }
    }

    // MARK: - Actions

    @objc private func didTapConfirm() {
        let trimmedTitle = (missionNameField.text ?? "").trimmingCharacters(in: .whitespaces)
        let newTitle: String? = (!trimmedTitle.isEmpty && trimmedTitle != currentTitle) ? trimmedTitle : nil

        let newLocationName: String?
        if canEditLocationAndDeadline, let currentLoc = currentLocationName {
            let trimmedLoc = (locationField.text ?? "").trimmingCharacters(in: .whitespaces)
            newLocationName = (!trimmedLoc.isEmpty && trimmedLoc != currentLoc) ? trimmedLoc : nil
        } else {
            newLocationName = nil
        }

        let newDeadline: Date?
        if canEditLocationAndDeadline,
           !Calendar.current.isDate(timePicker.date, equalTo: currentDeadline, toGranularity: .minute) {
            newDeadline = timePicker.date
        } else {
            newDeadline = nil
        }

        onConfirm?(EditMissionResult(
            newTitle: newTitle,
            newLocationName: newLocationName,
            newDeadline: newDeadline
        ))
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension EditMissionSheetViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == missionNameField,
           canEditLocationAndDeadline && currentLocationName != nil {
            locationField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}
