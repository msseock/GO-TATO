//
//  MissionPhotoService.swift
//  GoTato
//

import UIKit
import Vision

enum MissionPhotoError: Error {
    case invalidImage
    case extractionFailed
    case invalidReference
    case imageProcessingFailed
    case lowQuality
}

enum MissionVerificationResult: Equatable {
    case pass
    case tooFar      // "구도를 조금 더 맞춰보세요"
    case fail        // "다시 촬영해 주세요"
    case invalidImage
}

enum MissionPhotoService {

    // MARK: - Image Quality Validation

    /// 블러 및 피사체 없음을 감지. false면 재촬영 요청.
    static func validateImageQuality(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }

        guard calculateLaplacianVariance(cgImage) > 50.0 else { return false }

        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return false
        }

        guard let result = request.results?.first as? VNSaliencyImageObservation,
              !(result.salientObjects?.isEmpty ?? true) else {
            return false
        }

        return true
    }

    // MARK: - Feature Print

    /// 이미지에서 VNFeaturePrintObservation을 추출한다. Vision 처리는 512×512로 정규화.
    static func extractFeaturePrint(from image: UIImage) throws -> VNFeaturePrintObservation {
        let visionSize = CGSize(width: 512, height: 512)
        guard let cgImage = image.fixedOrientation().resized(to: visionSize).cgImage else {
            throw MissionPhotoError.invalidImage
        }

        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            throw MissionPhotoError.extractionFailed
        }
        return observation
    }

    // MARK: - Verification

    /// 촬영된 사진과 저장된 레퍼런스 Observation을 비교한다.
    static func verify(referenceData: Data, capturedImage: UIImage) -> MissionVerificationResult {
        guard validateImageQuality(capturedImage) else { return .invalidImage }

        guard let observation = try? extractFeaturePrint(from: capturedImage) else {
            return .invalidImage
        }

        guard let reference = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: VNFeaturePrintObservation.self,
            from: referenceData
        ) else {
            return .fail
        }

        var distance: Float = 0
        do {
            try reference.computeDistance(&distance, to: observation)
        } catch {
            return .fail
        }

        return judge(distance: distance)
    }

    // MARK: - Image Resizing

    /// 원본 비율 그대로 JPEG 데이터 반환. 저장용.
    static func prepareImageData(_ image: UIImage) -> Data? {
        image.fixedOrientation().jpegData(compressionQuality: 0.8)
    }

    // MARK: - Private

    private static func judge(distance: Float) -> MissionVerificationResult {
        switch distance {
        case ..<0.25: return .pass
        case ..<0.40: return .tooFar
        default:      return .fail
        }
    }

    private static func calculateLaplacianVariance(_ cgImage: CGImage) -> Double {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 2, height > 2 else { return 0 }

        let bytesPerPixel = 1
        let bytesPerRow = bytesPerPixel * width
        var pixelBuffer = [UInt8](repeating: 0, count: width * height)

        guard let context = CGContext(
            data: &pixelBuffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 3×3 라플라시안 커널 적용
        var sum: Double = 0
        var sumSq: Double = 0
        var count: Double = 0

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let lap = -4.0 * Double(pixelBuffer[y * width + x])
                    + Double(pixelBuffer[(y - 1) * width + x])
                    + Double(pixelBuffer[(y + 1) * width + x])
                    + Double(pixelBuffer[y * width + (x - 1)])
                    + Double(pixelBuffer[y * width + (x + 1)])
                sum += lap
                sumSq += lap * lap
                count += 1
            }
        }

        guard count > 0 else { return 0 }
        let mean = sum / count
        return sumSq / count - mean * mean
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return normalized
    }

    func resized(to targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
