//
//  WifiSelectViewController.swift
//  GoTato
//

import UIKit
import CoreLocation
import SnapKit
import RxSwift
import RxCocoa

final class WifiSelectViewController: BaseViewController {

    // MARK: - Callbacks

    /// (location, routine, wifiSSID?)
    var onWifiConfirmed: ((SelectedLocation, MissionRoutine, String?) -> Void)?
    var onBackRequested: (() -> Void)?

    /// 이전 단계에서 전달받음
    var pendingLocation: SelectedLocation?
    var pendingRoutine: MissionRoutine?

    // MARK: - Properties

    private let viewModel = WifiSelectViewModel()
    private let disposeBag = DisposeBag()

    private let toggleSubject = PublishSubject<Bool>()
    private let captureSubject = PublishSubject<Void>()
    private let ctaSubject = PublishSubject<Void>()

    // MARK: - UI

    private let backButton = UIButton()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()

    private let toggleCard = UIView()
    private let toggleTitleLabel = UILabel()
    private let toggleSwitch = UISwitch()

    private let captureCard = UIView()
    private let captureIconView = UIImageView()
    private let captureSSIDLabel = UILabel()
    private let captureMessageLabel = UILabel()
    private let captureRetryButton = UIButton(type: .system)

    private let ctaButton = GTTMainButton(
        title: "미션 만들기",
        icon: UIImage(systemName: "checkmark"),
        style: .primary
    )

    // MARK: - Lifecycle

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // SSID 조회 시 LocationManager가 활성 상태여야 동작하는 케이스가 있어 강제로 활성화
        LocationService.shared.startUpdatingLocation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        LocationService.shared.stopUpdatingLocation()
    }

    override func configureHierarchy() {
        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(toggleCard)
        toggleCard.addSubview(toggleTitleLabel)
        toggleCard.addSubview(toggleSwitch)
        view.addSubview(captureCard)
        captureCard.addSubview(captureIconView)
        captureCard.addSubview(captureSSIDLabel)
        captureCard.addSubview(captureMessageLabel)
        captureCard.addSubview(captureRetryButton)
        view.addSubview(ctaButton)
    }

    override func configureLayout() {
        backButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(12)
            make.leading.equalToSuperview().offset(16)
            make.size.equalTo(44)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(backButton.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        toggleCard.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(64)
        }
        toggleTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
        }
        toggleSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(20)
            make.centerY.equalToSuperview()
        }
        captureCard.snp.makeConstraints { make in
            make.top.equalTo(toggleCard.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        captureIconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().offset(20)
            make.size.equalTo(24)
        }
        captureSSIDLabel.snp.makeConstraints { make in
            make.centerY.equalTo(captureIconView)
            make.leading.equalTo(captureIconView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(20)
        }
        captureMessageLabel.snp.makeConstraints { make in
            make.top.equalTo(captureIconView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        captureMessageLabel.snp.makeConstraints { make in
            make.top.equalTo(captureIconView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        captureRetryButton.snp.makeConstraints { make in
            make.top.equalTo(captureMessageLabel.snp.bottom).offset(12)
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().inset(20)
            make.height.equalTo(32)
        }
        ctaButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(24)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(52)
        }
    }

    override func configureView() {
        view.backgroundColor = GTTColor.white

        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = GTTColor.textPrimary
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        titleLabel.text = "WiFi 인증도\n추가해볼까요?"
        titleLabel.font = GTTFont.dashboardTitle.font
        titleLabel.textColor = GTTColor.textPrimary
        titleLabel.numberOfLines = 2

        descriptionLabel.text = "출근 장소의 WiFi에 연결되어 있어야만 인증되도록 설정할 수 있어요. (선택)"
        descriptionLabel.font = GTTFont.calendarDay.font
        descriptionLabel.textColor = GTTColor.textSecondary
        descriptionLabel.numberOfLines = 0

        toggleCard.backgroundColor = GTTColor.white
        toggleCard.layer.cornerRadius = 16
        toggleCard.layer.borderColor = GTTColor.divider.cgColor
        toggleCard.layer.borderWidth = 1.5

        toggleTitleLabel.text = "WiFi 인증 추가하기"
        toggleTitleLabel.font = GTTFont.subHeading.font
        toggleTitleLabel.textColor = GTTColor.textPrimary

        toggleSwitch.onTintColor = GTTColor.brand
        toggleSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)

        captureCard.backgroundColor = GTTColor.white
        captureCard.layer.cornerRadius = 16
        captureCard.layer.borderColor = GTTColor.divider.cgColor
        captureCard.layer.borderWidth = 1.5
        captureCard.isHidden = true

        captureIconView.image = UIImage(systemName: "wifi")
        captureIconView.tintColor = GTTColor.brand
        captureIconView.contentMode = .scaleAspectFit

        captureSSIDLabel.font = GTTFont.subHeading.font
        captureSSIDLabel.textColor = GTTColor.textPrimary

        captureMessageLabel.font = GTTFont.calendarDay.font
        captureMessageLabel.textColor = GTTColor.textSecondary
        captureMessageLabel.numberOfLines = 0

        captureRetryButton.setTitleColor(GTTColor.brand, for: .normal)
        captureRetryButton.titleLabel?.font = GTTFont.calendarDay.font
        captureRetryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        ctaButton.onTap = { [weak self] in self?.ctaSubject.onNext(()) }
    }

    override func bind() {
        let input = WifiSelectViewModel.Input(
            toggleChanged: toggleSubject.asObservable(),
            captureTapped: captureSubject.asObservable(),
            ctaTapped: ctaSubject.asObservable()
        )
        let output = viewModel.transform(input: input)

        output.captureState
            .drive(onNext: { [weak self] state in
                self?.render(state: state)
            })
            .disposed(by: disposeBag)

        output.isCtaEnabled
            .drive(onNext: { [weak self] enabled in
                self?.ctaButton.isEnabled = enabled
            })
            .disposed(by: disposeBag)

        output.confirmed
            .emit(onNext: { [weak self] ssid in
                guard let self,
                      let location = self.pendingLocation,
                      let routine = self.pendingRoutine
                else { return }
                self.onWifiConfirmed?(location, routine, ssid)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Actions

    @objc private func backTapped() {
        onBackRequested?()
    }

    @objc private func switchChanged() {
        if toggleSwitch.isOn {
            // SSID 캡처는 위치 권한(WhenInUse 이상)이 있어야만 가능 (iOS 13+).
            // 권한 미확정 상태면 먼저 요청하고, 결과를 받은 뒤 캡처 시도.
            ensureLocationAuthorization { [weak self] granted in
                guard let self else { return }
                if !granted {
                    print("[WiFi] ⚠️ 위치 권한 없음 — SSID 캡처 불가")
                }
                self.toggleSubject.onNext(true)
            }
        } else {
            toggleSubject.onNext(false)
        }
    }

    private func ensureLocationAuthorization(completion: @escaping (Bool) -> Void) {
        let status = LocationService.shared.authorizationStatus.value
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            completion(true)
        case .notDetermined:
            // 권한 요청 후 변경 이벤트를 1회 구독해서 결과 전달
            LocationService.shared.authorizationStatus
                .skip(1)
                .take(1)
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { newStatus in
                    completion(newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways)
                })
                .disposed(by: disposeBag)
            LocationService.shared.checkLocationAuthorization()
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    @objc private func retryTapped() {
        captureSubject.onNext(())
    }

    // MARK: - Render

    private func render(state: WifiSelectViewModel.CaptureState) {
        switch state {
        case .idle:
            captureCard.isHidden = true
        case .captured(let ssid):
            captureCard.isHidden = false
            captureIconView.image = UIImage(systemName: "wifi")
            captureIconView.tintColor = GTTColor.brand
            captureSSIDLabel.text = ssid
            captureSSIDLabel.isHidden = false
            captureMessageLabel.text = "현재 연결된 WiFi가 등록돼요."
            captureRetryButton.setTitle("다시 캡처", for: .normal)
        case .failed:
            captureCard.isHidden = false
            captureIconView.image = UIImage(systemName: "wifi.exclamationmark")
            captureIconView.tintColor = GTTColor.textMuted
            captureSSIDLabel.text = "WiFi 정보를 가져올 수 없어요"
            captureSSIDLabel.isHidden = false
            captureMessageLabel.text = "출근 장소의 WiFi에 연결한 후 다시 시도해주세요. (시뮬레이터에서는 동작하지 않습니다)"
            captureRetryButton.setTitle("다시 시도", for: .normal)
        }
    }
}
