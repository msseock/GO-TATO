//
//  EditMissionSheetViewController.swift
//  GoTato
//

import UIKit
import Vision
import SnapKit

struct EditMissionResult {
    let newTitle: String?
    let newLocationName: String?
    let newDeadline: Date?
    let newSelectedDays: Set<Int>?
    let wifiEdit: WifiEdit
    let photoEdit: PhotoEdit
}

enum WifiEdit {
    case unchanged
    case set(String)
    case remove
}

enum PhotoEdit {
    case unchanged
    case set(UIImage, VNFeaturePrintObservation)
    case remove
}

final class EditMissionSheetViewController: UIViewController {

    // MARK: - Callback

    var onConfirm: ((EditMissionResult) -> Void)?

    // MARK: - Properties

    private let currentTitle: String
    private let forbiddenTitles: [String]
    private let currentLocationName: String?
    private let currentDeadline: Date
    private let currentSelectedDays: Set<Int>
    private let currentWifiSSID: String?
    private let missionID: UUID?
    private let missionEndDate: Date
    private let canEditLocationAndDeadline: Bool
    private let canEditWifi: Bool
    private let canEditPhoto: Bool

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

    // MARK: - UI — 반복 요일 Section

    private let daySelector = DaySelector()

    // MARK: - UI — WiFi Section

    private let wifiCard          = UIView()
    private let wifiContentStack  = UIStackView()
    private let wifiPrimaryLabel  = UILabel()
    private let wifiMessageLabel  = UILabel()
    private let wifiButtonStack   = UIStackView()
    private let wifiPrimaryButton = UIButton(type: .system)
    private let wifiSecondaryButton = UIButton(type: .system)

    // MARK: - UI — Photo Section

    private let photoCard             = UIView()
    private let photoContentStack     = UIStackView()
    private let photoPreviewImageView = UIImageView()
    private let photoStatusLabel      = UILabel()
    private let photoMessageLabel     = UILabel()
    private let photoButtonStack      = UIStackView()
    private let photoRetakeButton     = UIButton(type: .system)
    private let photoRemoveButton     = UIButton(type: .system)

    // MARK: - State

    private var editedSelectedDays: Set<Int>
    private var wifiEdit: WifiEdit = .unchanged
    private var wifiCaptureFailed: Bool = false
    private var photoEdit: PhotoEdit = .unchanged
    private var photoAspectConstraint: Constraint?

    // MARK: - Init

    init(
        currentTitle: String,
        forbiddenTitles: [String],
        currentLocationName: String?,
        currentDeadline: Date,
        currentSelectedDays: Set<Int>,
        currentWifiSSID: String?,
        missionID: UUID?,
        missionEndDate: Date,
        isMissionEnded: Bool
    ) {
        self.currentTitle               = currentTitle
        self.forbiddenTitles            = forbiddenTitles
        self.currentLocationName        = currentLocationName
        self.currentDeadline            = currentDeadline
        self.currentSelectedDays        = currentSelectedDays
        self.currentWifiSSID            = currentWifiSSID
        self.missionID                  = missionID
        self.missionEndDate             = missionEndDate
        self.canEditLocationAndDeadline = !isMissionEnded
        self.canEditWifi                = !isMissionEnded && currentLocationName != nil
        self.canEditPhoto               = !isMissionEnded
        self.editedSelectedDays         = currentSelectedDays
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

        // Day selector
        setupDaySelector()

        // WiFi card
        wifiCard.backgroundColor    = GTTColor.bgPrimary
        wifiCard.layer.cornerRadius = 12

        wifiContentStack.axis    = .vertical
        wifiContentStack.spacing = 10
        wifiContentStack.alignment = .fill

        wifiPrimaryLabel.font          = GTTFont.body.font
        wifiPrimaryLabel.textColor     = GTTColor.textPrimary
        wifiPrimaryLabel.numberOfLines = 0

        wifiMessageLabel.font          = GTTFont.caption.font
        wifiMessageLabel.textColor     = GTTColor.textSecondary
        wifiMessageLabel.numberOfLines = 0

        wifiButtonStack.axis    = .horizontal
        wifiButtonStack.spacing = 12
        wifiButtonStack.alignment = .center

        wifiPrimaryButton.titleLabel?.font = GTTFont.caption.font
        wifiPrimaryButton.setTitleColor(GTTColor.brand, for: .normal)
        wifiPrimaryButton.addTarget(self, action: #selector(didTapWifiPrimary), for: .touchUpInside)

        wifiSecondaryButton.titleLabel?.font = GTTFont.caption.font
        wifiSecondaryButton.setTitleColor(GTTColor.error, for: .normal)
        wifiSecondaryButton.addTarget(self, action: #selector(didTapWifiSecondary), for: .touchUpInside)
    }

    private func setupDaySelector() {
        let availableDays = computeAvailableDays()
        daySelector.updateAvailableDays(availableDays)
        daySelector.updateSelectedDays(currentSelectedDays.intersection(availableDays))
        editedSelectedDays = currentSelectedDays.intersection(availableDays)

        daySelector.onDayToggled = { [weak self] day in
            guard let self else { return }
            if self.editedSelectedDays.contains(day) {
                self.editedSelectedDays.remove(day)
            } else {
                self.editedSelectedDays.insert(day)
            }
            self.daySelector.updateSelectedDays(self.editedSelectedDays)
            self.updateConfirmState()
        }

        daySelector.onAllToggled = { [weak self] in
            guard let self else { return }
            let available = self.computeAvailableDays()
            let allSelected = available.isSubset(of: self.editedSelectedDays)
            if allSelected {
                self.editedSelectedDays.subtract(available)
            } else {
                self.editedSelectedDays.formUnion(available)
            }
            self.daySelector.updateSelectedDays(self.editedSelectedDays)
            self.updateConfirmState()
        }
    }

    /// 오늘~endDate 범위에 실제 존재하는 요일만 available로 반환
    private func computeAvailableDays() -> Set<Int> {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: missionEndDate)
        guard today <= end else { return [] }

        var available = Set<Int>()
        var current = today
        // 최대 7일만 확인하면 모든 요일 커버
        let limit = min(cal.date(byAdding: .day, value: 7, to: today)!, end)
        while current <= limit {
            available.insert(cal.component(.weekday, from: current))
            current = cal.date(byAdding: .day, value: 1, to: current)!
        }
        return available
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

        // 반복 요일 section (only if mission not ended)
        if canEditLocationAndDeadline {
            let daySection = makeSectionStack(
                headerText: "반복 요일",
                card: daySelector
            )
            contentStack.addArrangedSubview(daySection)
        }

        // WiFi 인증 section (only if mission not ended and has location)
        if canEditWifi {
            wifiCard.addSubview(wifiContentStack)
            wifiContentStack.addArrangedSubview(wifiPrimaryLabel)
            wifiContentStack.addArrangedSubview(wifiMessageLabel)
            wifiButtonStack.addArrangedSubview(wifiPrimaryButton)
            wifiButtonStack.addArrangedSubview(wifiSecondaryButton)
            wifiButtonStack.addArrangedSubview(UIView())
            wifiContentStack.addArrangedSubview(wifiButtonStack)

            let wifiSection = makeSectionStack(
                headerText: "WiFi 인증",
                card: wifiCard
            )
            contentStack.addArrangedSubview(wifiSection)
            renderWifiSection()
        }

        // 사진 인증 section (only if mission not ended)
        if canEditPhoto {
            setupPhotoCardUI()

            photoCard.addSubview(photoContentStack)
            photoContentStack.addArrangedSubview(photoPreviewImageView)
            photoContentStack.addArrangedSubview(photoStatusLabel)
            photoContentStack.addArrangedSubview(photoMessageLabel)
            photoButtonStack.addArrangedSubview(photoRetakeButton)
            photoButtonStack.addArrangedSubview(photoRemoveButton)
            photoButtonStack.addArrangedSubview(UIView())
            photoContentStack.addArrangedSubview(photoButtonStack)

            let photoSection = makeSectionStack(headerText: "사진 인증", card: photoCard)
            contentStack.addArrangedSubview(photoSection)
            renderPhotoSection()
        }
    }

    private func setupPhotoCardUI() {
        photoCard.backgroundColor    = GTTColor.bgPrimary
        photoCard.layer.cornerRadius = 12
        photoCard.clipsToBounds      = true

        photoContentStack.axis      = .vertical
        photoContentStack.spacing   = 10
        photoContentStack.alignment = .fill

        photoPreviewImageView.contentMode        = .scaleAspectFill
        photoPreviewImageView.clipsToBounds      = true
        photoPreviewImageView.layer.cornerRadius = 8
        photoPreviewImageView.isHidden           = true

        photoStatusLabel.font          = GTTFont.body.font
        photoStatusLabel.textColor     = GTTColor.textPrimary
        photoStatusLabel.numberOfLines = 0

        photoMessageLabel.font          = GTTFont.caption.font
        photoMessageLabel.textColor     = GTTColor.textSecondary
        photoMessageLabel.numberOfLines = 0
        photoMessageLabel.isHidden      = true

        photoButtonStack.axis      = .horizontal
        photoButtonStack.spacing   = 16
        photoButtonStack.alignment = .center

        photoRetakeButton.setTitleColor(GTTColor.brand, for: .normal)
        photoRetakeButton.titleLabel?.font = GTTFont.caption.font
        photoRetakeButton.addTarget(self, action: #selector(didTapPhotoRetake), for: .touchUpInside)

        photoRemoveButton.setTitleColor(GTTColor.error, for: .normal)
        photoRemoveButton.titleLabel?.font = GTTFont.caption.font
        photoRemoveButton.addTarget(self, action: #selector(didTapPhotoRemove), for: .touchUpInside)
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

        if canEditLocationAndDeadline && currentLocationName != nil {
            locationField.snp.makeConstraints {
                $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
            }
            locationCard.snp.makeConstraints { $0.height.equalTo(50) }
        }

        // Time picker card fills naturally (wheels picker is ~216pt tall)
        if canEditLocationAndDeadline {
            timePicker.snp.makeConstraints { $0.edges.equalToSuperview() }
        }

        if canEditWifi {
            wifiContentStack.snp.makeConstraints {
                $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
            }
        }

        if canEditPhoto {
            photoContentStack.snp.makeConstraints {
                $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
            }
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

        // Selected days changed
        var daysChanged = false
        if canEditLocationAndDeadline {
            daysChanged = editedSelectedDays != currentSelectedDays && !editedSelectedDays.isEmpty
        }

        // WiFi changed
        var wifiChanged = false
        if canEditWifi {
            switch wifiEdit {
            case .unchanged: wifiChanged = false
            case .set(let s): wifiChanged = s != currentWifiSSID
            case .remove:    wifiChanged = currentWifiSSID != nil
            }
        }

        var photoChanged = false
        if canEditPhoto {
            switch photoEdit {
            case .unchanged: photoChanged = false
            case .set, .remove: photoChanged = true
            }
        }

        let hasValidChange   = titleChanged || locationChanged || deadlineChanged || daysChanged || wifiChanged || photoChanged
        let hasBlockingError = titleError != nil || (canEditWifi && wifiCaptureFailed)

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

        let newSelectedDays: Set<Int>?
        if canEditLocationAndDeadline,
           editedSelectedDays != currentSelectedDays && !editedSelectedDays.isEmpty {
            newSelectedDays = editedSelectedDays
        } else {
            newSelectedDays = nil
        }

        let resolvedWifiEdit: WifiEdit
        if canEditWifi {
            switch wifiEdit {
            case .unchanged:
                resolvedWifiEdit = .unchanged
            case .set(let s):
                resolvedWifiEdit = (s == currentWifiSSID) ? .unchanged : .set(s)
            case .remove:
                resolvedWifiEdit = (currentWifiSSID == nil) ? .unchanged : .remove
            }
        } else {
            resolvedWifiEdit = .unchanged
        }

        onConfirm?(EditMissionResult(
            newTitle: newTitle,
            newLocationName: newLocationName,
            newDeadline: newDeadline,
            newSelectedDays: newSelectedDays,
            wifiEdit: resolvedWifiEdit,
            photoEdit: photoEdit
        ))
        navigationController?.popViewController(animated: true)
    }

    // MARK: - WiFi Section

    private func renderWifiSection() {
        wifiMessageLabel.isHidden = true
        wifiSecondaryButton.isHidden = true
        wifiPrimaryButton.isHidden = false
        wifiPrimaryButton.setTitleColor(GTTColor.brand, for: .normal)
        wifiSecondaryButton.setTitleColor(GTTColor.error, for: .normal)

        if wifiCaptureFailed {
            wifiPrimaryLabel.text = "WiFi 정보를 가져올 수 없어요"
            wifiPrimaryLabel.textColor = GTTColor.textPrimary
            wifiMessageLabel.isHidden = false
            wifiMessageLabel.text = "위치 권한을 \"항상 허용\"과 \"정확한 위치\"로 설정한 뒤, 출근 장소의 WiFi에 연결해 다시 시도해주세요. (시뮬레이터에서는 동작하지 않습니다)"
            wifiPrimaryButton.setTitle("다시 시도", for: .normal)
            wifiSecondaryButton.isHidden = false
            wifiSecondaryButton.setTitle("취소", for: .normal)
            wifiSecondaryButton.setTitleColor(GTTColor.textSecondary, for: .normal)
            return
        }

        switch wifiEdit {
        case .unchanged:
            if let ssid = currentWifiSSID {
                wifiPrimaryLabel.text = ssid
                wifiPrimaryLabel.textColor = GTTColor.textPrimary
                wifiPrimaryButton.setTitle("재캡처", for: .normal)
                wifiSecondaryButton.isHidden = false
                wifiSecondaryButton.setTitle("삭제", for: .normal)
            } else {
                wifiPrimaryLabel.text = "WiFi 인증이 설정되지 않았어요"
                wifiPrimaryLabel.textColor = GTTColor.textSecondary
                wifiPrimaryButton.setTitle("WiFi 인증 추가하기", for: .normal)
            }
        case .set(let ssid):
            wifiPrimaryLabel.text = ssid
            wifiPrimaryLabel.textColor = GTTColor.textPrimary
            wifiMessageLabel.isHidden = false
            wifiMessageLabel.text = currentWifiSSID == nil ? "새로 추가됩니다" : "변경됩니다"
            wifiPrimaryButton.setTitle("재캡처", for: .normal)
            wifiSecondaryButton.isHidden = false
            wifiSecondaryButton.setTitle("되돌리기", for: .normal)
            wifiSecondaryButton.setTitleColor(GTTColor.textSecondary, for: .normal)
        case .remove:
            wifiPrimaryLabel.text = "WiFi 인증이 삭제됩니다"
            wifiPrimaryLabel.textColor = GTTColor.textPrimary
            wifiPrimaryButton.setTitle("되돌리기", for: .normal)
            wifiPrimaryButton.setTitleColor(GTTColor.textSecondary, for: .normal)
        }
    }

    @objc private func didTapWifiPrimary() {
        view.endEditing(true)
        if wifiCaptureFailed {
            captureWifiSSID()
            return
        }
        switch wifiEdit {
        case .unchanged:
            if currentWifiSSID == nil {
                captureWifiSSID()
            } else {
                captureWifiSSID()
            }
        case .set:
            captureWifiSSID()
        case .remove:
            wifiEdit = .unchanged
            renderWifiSection()
            updateConfirmState()
        }
    }

    @objc private func didTapWifiSecondary() {
        view.endEditing(true)
        if wifiCaptureFailed {
            wifiCaptureFailed = false
            renderWifiSection()
            updateConfirmState()
            return
        }
        switch wifiEdit {
        case .unchanged:
            // 기존 SSID 삭제
            wifiEdit = .remove
        case .set:
            wifiEdit = .unchanged
        case .remove:
            wifiEdit = .unchanged
        }
        renderWifiSection()
        updateConfirmState()
    }

    private func captureWifiSSID() {
        WifiService.fetchCurrentSSID { [weak self] ssid in
            guard let self else { return }
            DispatchQueue.main.async {
                if let ssid = ssid {
                    self.wifiCaptureFailed = false
                    self.wifiEdit = .set(ssid)
                } else {
                    self.wifiCaptureFailed = true
                }
                self.renderWifiSection()
                self.updateConfirmState()
            }
        }
    }

    // MARK: - Photo Section

    private func renderPhotoSection() {
        photoMessageLabel.isHidden = true
        photoRemoveButton.isHidden = false

        switch photoEdit {
        case .unchanged:
            if let missionID, let image = MissionPhotoRepository.shared.loadReferenceImage(for: missionID) {
                showPhotoPreview(image)
                photoStatusLabel.text = "현재 등록된 기준 사진"
                photoStatusLabel.textColor = GTTColor.textPrimary
                photoRetakeButton.setTitle("다시 찍기", for: .normal)
                photoRemoveButton.setTitle("삭제", for: .normal)
            } else {
                photoPreviewImageView.isHidden = true
                photoStatusLabel.text = "사진 인증이 설정되지 않았어요"
                photoStatusLabel.textColor = GTTColor.textSecondary
                photoRetakeButton.setTitle("사진 인증 추가하기", for: .normal)
                photoRemoveButton.isHidden = true
            }
        case .set(let image, _):
            showPhotoPreview(image)
            photoStatusLabel.text = "새 기준 사진"
            photoStatusLabel.textColor = GTTColor.textPrimary
            photoMessageLabel.isHidden = false
            photoMessageLabel.text = "저장하면 변경됩니다"
            photoRetakeButton.setTitle("다시 찍기", for: .normal)
            photoRemoveButton.setTitle("되돌리기", for: .normal)
        case .remove:
            photoPreviewImageView.isHidden = true
            photoStatusLabel.text = "사진 인증이 삭제됩니다"
            photoStatusLabel.textColor = GTTColor.textPrimary
            photoRetakeButton.setTitle("되돌리기", for: .normal)
            photoRemoveButton.isHidden = true
        }
    }

    private func showPhotoPreview(_ image: UIImage) {
        photoPreviewImageView.image = image
        photoPreviewImageView.isHidden = false

        photoAspectConstraint?.deactivate()
        let ratio = image.size.width > 0 ? image.size.height / image.size.width : 1
        photoPreviewImageView.snp.makeConstraints { make in
            photoAspectConstraint = make.height.equalTo(photoPreviewImageView.snp.width).multipliedBy(ratio).constraint
        }
    }

    @objc private func didTapPhotoRetake() {
        view.endEditing(true)
        if case .remove = photoEdit {
            photoEdit = .unchanged
            renderPhotoSection()
            updateConfirmState()
            return
        }
        let cameraVC = MissionCameraViewController(mode: .registration)
        cameraVC.onRegistrationComplete = { [weak self] image, observation in
            self?.photoEdit = .set(image, observation)
            self?.renderPhotoSection()
            self?.updateConfirmState()
        }
        navigationController?.present(cameraVC, animated: true)
    }

    @objc private func didTapPhotoRemove() {
        view.endEditing(true)
        if case .set = photoEdit {
            photoEdit = .unchanged
        } else {
            photoEdit = .remove
        }
        renderPhotoSection()
        updateConfirmState()
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
