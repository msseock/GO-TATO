//
//  GTTDateService.swift
//  GoTato
//
//  Created by 석민솔 on 3/24/26.
//

import Foundation

/// 날짜 계산, 유효성 검증, 포맷팅을 담당하는 앱 전역 날짜 서비스
final class GTTDateService {
    static let shared = GTTDateService()

    private init() { }

    // MARK: - Repository 헬퍼

    /// startDate부터 endDate까지 각 날짜의 자정(startOfDay) 배열 반환 (양 끝 포함)
    func calendarDays(from startDate: Date, through endDate: Date) -> [Date] {
        let calendar = Calendar.current
        var days: [Date] = []
        var current = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        while current <= end {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }

    /// date의 연/월/일 + timeSource의 시/분을 결합하여 반환
    /// Attendance.planDate 생성 및 deadline 수정 시 사용
    func combining(date: Date, timeFrom timeSource: Date) -> Date {
        let calendar = Calendar.current
        let dateParts = calendar.dateComponents([.year, .month, .day], from: date)
        let timeParts = calendar.dateComponents([.hour, .minute], from: timeSource)
        var combined = DateComponents()
        combined.year   = dateParts.year
        combined.month  = dateParts.month
        combined.day    = dateParts.day
        combined.hour   = timeParts.hour
        combined.minute = timeParts.minute
        combined.second = 0
        return calendar.date(from: combined) ?? date
    }

    /// 주어진 날짜가 속한 달의 (시작, 다음달 시작) 반환
    func monthBounds(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let end   = calendar.date(byAdding: .month, value: 1, to: start)!
        return (start, end)
    }

    /// 두 Date의 시:분 차이를 분 단위 절댓값으로 반환 (날짜 무관, 원형 시간 차이)
    /// 예: 23:58과 00:02 → 4분
    func minutesBetweenTimesOfDay(_ date1: Date, _ date2: Date) -> Int {
        let calendar = Calendar.current
        let c1 = calendar.dateComponents([.hour, .minute], from: date1)
        let c2 = calendar.dateComponents([.hour, .minute], from: date2)
        let m1 = (c1.hour ?? 0) * 60 + (c1.minute ?? 0)
        let m2 = (c2.hour ?? 0) * 60 + (c2.minute ?? 0)
        let diff = abs(m1 - m2)
        return min(diff, 1440 - diff)   // 원형: 하루 1440분 기준
    }

    /// 오늘의 (자정, 내일 자정) 반환
    func todayBounds() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end   = calendar.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }

    /// Date를 '3월 30일 월요일' 형식의 한글 문자열로 변환
    func formatToKoreanFullDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: date)
    }
}
