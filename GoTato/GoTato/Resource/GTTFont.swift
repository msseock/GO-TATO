import UIKit

enum GTTFont {
    case heroTitle      // 34pt, 800 — 대형 숫자, 히어로 타이틀
    case dashboardTitle // 30pt, 700 — 대시보드 메인 타이틀
    case missionTitle   // 28pt, 700 — 미션 상세 제목
    case sectionHeading // 22pt, 700 — 섹션 헤딩
    case cardTitle      // 18pt, 600 — 카드 타이틀, 강조 텍스트
    case subHeading     // 17pt, 600 — 서브 헤딩
    case body           // 16pt, 500 — 본문 텍스트 기본
    case bodySecondary  // 15pt, 500 — 보조 본문 텍스트
    case caption        // 14pt, 500 — 캡션, 메타 정보
    case captionSmall   // 13pt, 500 — 작은 캡션 텍스트
    case badge          // 12pt, 500 — 뱃지, 태그 라벨
    case calendarDay    // 12pt, 600 — 요일 헤더 및 기본 날짜 셀
    case calendarDayBold // 12pt, 700 — 활성 상태 날짜 셀 (status 1/2/3)
    case miniLabel      // 11pt, 700 — 미니 라벨, 섹션 레이블

    var font: UIFont {
        switch self {
        case .heroTitle:      return pretendard(size: 34, weight: .init(rawValue: 800))
        case .dashboardTitle: return pretendard(size: 30, weight: .bold)
        case .missionTitle:   return pretendard(size: 28, weight: .bold)
        case .sectionHeading: return pretendard(size: 22, weight: .bold)
        case .cardTitle:      return pretendard(size: 18, weight: .semibold)
        case .subHeading:     return pretendard(size: 17, weight: .semibold)
        case .body:           return pretendard(size: 16, weight: .medium)
        case .bodySecondary:  return pretendard(size: 15, weight: .medium)
        case .caption:        return pretendard(size: 14, weight: .medium)
        case .captionSmall:   return pretendard(size: 13, weight: .medium)
        case .badge:          return pretendard(size: 12, weight: .medium)
        case .calendarDay:    return pretendard(size: 12, weight: .semibold)
        case .calendarDayBold: return pretendard(size: 12, weight: .bold)
        case .miniLabel:      return pretendard(size: 11, weight: .bold)
        }
    }

    private func pretendard(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let name: String
        switch weight {
        case .init(rawValue: 800): name = "Pretendard-ExtraBold"
        case .bold:                name = "Pretendard-Bold"
        case .semibold:            name = "Pretendard-SemiBold"
        case .medium:              name = "Pretendard-Medium"
        default:                   name = "Pretendard-Regular"
        }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }
}
