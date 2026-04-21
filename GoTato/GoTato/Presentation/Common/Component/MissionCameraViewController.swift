//
//  MissionCameraViewController.swift
//  GoTato
//

import AVFoundation
import UIKit
import Vision

// MARK: - CameraMode

enum CameraMode {
    case registration
    case verification(referenceImage: UIImage, observationData: Data)
}

// MARK: - MissionCameraViewController

final class MissionCameraViewController: UIViewController {

    // MARK: - Callbacks

    var onRegistrationComplete: ((UIImage, VNFeaturePrintObservation) -> Void)?
    var onVerificationResult: ((MissionVerificationResult) -> Void)?

    // MARK: - Properties

    private let mode: CameraMode

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let photoOutput = AVCapturePhotoOutput()

    // MARK: - UI

    private let overlayImageView = UIImageView()
    private let captureButton = UIButton(type: .custom)
    private let backButton = UIButton(type: .system)
    private let guideLabel = UILabel()
    private let loadingView = UIActivityIndicatorView(style: .large)

    // MARK: - Init

    init(mode: CameraMode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        captureSession.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input),
              captureSession.canAddOutput(photoOutput) else { return }

        captureSession.addInput(input)
        captureSession.addOutput(photoOutput)

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    // MARK: - UI Setup

    private func setupUI() {
        if case .verification(let refImage, _) = mode {
            overlayImageView.image = refImage
            overlayImageView.alpha = 0.35
            overlayImageView.contentMode = .scaleAspectFill
            overlayImageView.clipsToBounds = true
            overlayImageView.frame = view.bounds
            overlayImageView.isUserInteractionEnabled = false
            view.addSubview(overlayImageView)
        }

        backButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        backButton.tintColor = .white
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        guideLabel.font = .systemFont(ofSize: 14, weight: .medium)
        guideLabel.textColor = .white
        guideLabel.textAlignment = .center
        guideLabel.numberOfLines = 0
        guideLabel.text = guideText
        view.addSubview(guideLabel)
        guideLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            guideLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 12),
            guideLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            guideLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 36
        captureButton.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        captureButton.layer.borderWidth = 4
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        view.addSubview(captureButton)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            captureButton.widthAnchor.constraint(equalToConstant: 72),
            captureButton.heightAnchor.constraint(equalToConstant: 72)
        ])

        loadingView.color = .white
        loadingView.hidesWhenStopped = true
        view.addSubview(loadingView)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private var guideText: String {
        switch mode {
        case .registration:
            return "기준이 될 장소를 촬영해 주세요"
        case .verification:
            return "반투명 기준 사진에 맞춰 구도를 맞춰 촬영해 주세요"
        }
    }

    // MARK: - Actions

    @objc private func backTapped() {
        dismiss(animated: true)
    }

    @objc private func captureTapped() {
        captureButton.isEnabled = false
        loadingView.startAnimating()
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension MissionCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        loadingView.stopAnimating()
        captureButton.isEnabled = true

        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let raw = UIImage(data: data) else {
            showAlert(title: "촬영에 실패했습니다", message: "다시 시도해 주세요.")
            return
        }

        let image = cropToPreviewBounds(raw)

        guard MissionPhotoService.validateImageQuality(image) else {
            showAlert(
                title: "검증할 수 없는 사진입니다",
                message: "피사체가 명확하게 보이도록 다시 촬영해 주세요."
            )
            return
        }

        switch mode {
        case .registration:
            handleRegistration(image: image)
        case .verification(_, let observationData):
            handleVerification(image: image, observationData: observationData)
        }
    }

    private func handleRegistration(image: UIImage) {
        guard let observation = try? MissionPhotoService.extractFeaturePrint(from: image) else {
            showAlert(title: "처리에 실패했습니다", message: "다시 촬영해 주세요.")
            return
        }
        dismiss(animated: true) { [weak self] in
            self?.onRegistrationComplete?(image, observation)
        }
    }

    private func handleVerification(image: UIImage, observationData: Data) {
        let result = MissionPhotoService.verify(referenceData: observationData, capturedImage: image)

        switch result {
        case .pass:
            dismiss(animated: true) { [weak self] in
                self?.onVerificationResult?(.pass)
            }
        case .tooFar:
            showAlert(title: "구도를 조금 더 맞춰보세요", message: "기준 사진의 구도에 더 가깝게 맞춰 다시 촬영해 주세요.")
        case .fail:
            showAlert(title: "다시 촬영해 주세요", message: "기준 사진과 너무 다릅니다. 같은 장소인지 확인해 주세요.")
        case .invalidImage:
            showAlert(title: "검증할 수 없는 사진입니다", message: "피사체가 명확하게 보이도록 다시 촬영해 주세요.")
        }
    }

    private func cropToPreviewBounds(_ image: UIImage) -> UIImage {
        guard let previewLayer,
              let cgImage = image.cgImage else { return image }

        let visibleRect = previewLayer.metadataOutputRectConverted(fromLayerRect: previewLayer.bounds)
        let cropRect = CGRect(
            x: visibleRect.origin.x * CGFloat(cgImage.width),
            y: visibleRect.origin.y * CGFloat(cgImage.height),
            width: visibleRect.size.width * CGFloat(cgImage.width),
            height: visibleRect.size.height * CGFloat(cgImage.height)
        )

        guard let cropped = cgImage.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "다시 촬영", style: .default))
        present(alert, animated: true)
    }
}
