//
//  PhotoSelectViewController.swift
//  GoTato
//

import AVFoundation
import UIKit
import Vision
import SnapKit
import RxSwift
import RxCocoa

final class PhotoSelectViewController: BaseViewController {

    // MARK: - Callbacks

    var onPhotoConfirmed: ((SelectedLocation, MissionRoutine, UIImage, VNFeaturePrintObservation) -> Void)?
    var onBackRequested: (() -> Void)?

    var pendingLocation: SelectedLocation?
    var pendingRoutine: MissionRoutine?

    // MARK: - Properties

    private let viewModel = PhotoSelectViewModel()
    private let disposeBag = DisposeBag()

    private let retakeSubject = PublishSubject<Void>()
    private let ctaSubject = PublishSubject<Void>()
    private let photoCapturedSubject = PublishSubject<(UIImage, VNFeaturePrintObservation)>()

    // MARK: - UI

    private let backButton = UIButton()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()

    private let photoCard = UIView()
    private let photoPreviewImageView = UIImageView()
    private let photoPlaceholderStack = UIStackView()
    private let photoPlaceholderIcon = UIImageView()
    private let photoPlaceholderLabel = UILabel()
    private let retakeButton = UIButton(type: .system)


    private let captureButton = GTTMainButton(
        title: "기준 사진 촬영하기",
        icon: UIImage(systemName: "camera"),
        style: .primary
    )

    private let ctaButton = GTTMainButton(
        title: "미션 만들기",
        icon: UIImage(systemName: "checkmark"),
        style: .primary
    )

    // MARK: - Lifecycle

    override func configureHierarchy() {
        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(photoCard)
        photoCard.addSubview(photoPreviewImageView)
        photoCard.addSubview(photoPlaceholderStack)
        photoCard.addSubview(retakeButton)
        view.addSubview(captureButton)
        view.addSubview(ctaButton)

        photoPlaceholderStack.addArrangedSubview(photoPlaceholderIcon)
        photoPlaceholderStack.addArrangedSubview(photoPlaceholderLabel)
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
        photoCard.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(200)
        }
        photoPreviewImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        photoPlaceholderStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        retakeButton.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview().inset(12)
            make.height.equalTo(32)
        }
        captureButton.snp.makeConstraints { make in
            make.top.equalTo(photoCard.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(52)
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

        titleLabel.text = "사진 인증도\n추가해볼까요?"
        titleLabel.font = GTTFont.dashboardTitle.font
        titleLabel.textColor = GTTColor.textPrimary
        titleLabel.numberOfLines = 2

        descriptionLabel.text = "출근 장소를 촬영해두면 체크인 시 같은 장소인지 사진으로 확인해요. (선택)"
        descriptionLabel.font = GTTFont.calendarDay.font
        descriptionLabel.textColor = GTTColor.textSecondary
        descriptionLabel.numberOfLines = 0

        photoCard.backgroundColor = GTTColor.white
        photoCard.layer.cornerRadius = 16
        photoCard.layer.borderColor = GTTColor.divider.cgColor
        photoCard.layer.borderWidth = 1.5
        photoCard.clipsToBounds = true

        photoPreviewImageView.contentMode = .scaleAspectFit
        photoPreviewImageView.clipsToBounds = true
        photoPreviewImageView.isHidden = true

        photoPlaceholderStack.axis = .vertical
        photoPlaceholderStack.spacing = 8
        photoPlaceholderStack.alignment = .center

        photoPlaceholderIcon.image = UIImage(systemName: "camera.fill")
        photoPlaceholderIcon.tintColor = GTTColor.textMuted
        photoPlaceholderIcon.contentMode = .scaleAspectFit
        photoPlaceholderIcon.snp.makeConstraints { make in make.size.equalTo(32) }

        photoPlaceholderLabel.text = "아직 촬영된 기준 사진이 없어요"
        photoPlaceholderLabel.font = GTTFont.calendarDay.font
        photoPlaceholderLabel.textColor = GTTColor.textSecondary

        retakeButton.setTitle("다시 찍기", for: .normal)
        retakeButton.setTitleColor(GTTColor.brand, for: .normal)
        retakeButton.titleLabel?.font = GTTFont.calendarDay.font
        retakeButton.isHidden = true
        retakeButton.addTarget(self, action: #selector(retakeTapped), for: .touchUpInside)

        captureButton.onTap = { [weak self] in self?.openCamera() }
        ctaButton.onTap = { [weak self] in self?.ctaSubject.onNext(()) }
        ctaButton.isEnabled = false
    }

    override func bind() {
        let input = PhotoSelectViewModel.Input(
            retakeTapped: retakeSubject.asObservable(),
            ctaTapped: ctaSubject.asObservable(),
            photoCaptured: photoCapturedSubject.asObservable()
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
            .emit(onNext: { [weak self] image, observation in
                guard let self,
                      let location = self.pendingLocation,
                      let routine = self.pendingRoutine
                else { return }
                self.onPhotoConfirmed?(location, routine, image, observation)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Actions

    @objc private func backTapped() {
        onBackRequested?()
    }

    @objc private func retakeTapped() {
        retakeSubject.onNext(())
        openCamera()
    }

    private func openCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentCameraVC()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.presentCameraVC() }
                }
            }
        case .denied, .restricted:
            let alert = UIAlertController(
                title: "카메라 접근 권한이 필요해요",
                message: "사진 인증 미션을 위해 카메라 권한을 허용해 주세요.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "취소", style: .cancel))
            alert.addAction(UIAlertAction(title: "설정으로 이동", style: .default) { _ in
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            })
            present(alert, animated: true)
        @unknown default:
            break
        }
    }

    private func presentCameraVC() {
        let cameraVC = MissionCameraViewController(mode: .registration)
        cameraVC.onRegistrationComplete = { [weak self] image, observation in
            self?.photoCapturedSubject.onNext((image, observation))
        }
        present(cameraVC, animated: true)
    }

    // MARK: - Render

    private func render(state: PhotoSelectViewModel.CaptureState) {
        switch state {
        case .idle:
            photoPreviewImageView.isHidden = true
            photoPreviewImageView.image = nil
            photoPlaceholderStack.isHidden = false
            retakeButton.isHidden = true
            captureButton.configure(title: "기준 사진 촬영하기")
        case .captured(let image):
            photoPreviewImageView.image = image
            photoPreviewImageView.isHidden = false
            photoPlaceholderStack.isHidden = true
            retakeButton.isHidden = false
            captureButton.configure(title: "다시 촬영하기")
        case .failed:
            break
        }
    }
}
