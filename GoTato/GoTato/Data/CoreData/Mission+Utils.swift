//
//  Mission+Utils.swift
//  GoTato
//

import CoreData
import Foundation

extension Mission {
    public nonisolated override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
    }

    // MARK: - Selected Days

    /// selectedDaysRaw (String, e.g. "1,2,3,5,6") ↔ Set<Int> 변환.
    /// nil이면 기존 Attendance의 planDate 요일 분포에서 역추론한다.
    var selectedDays: Set<Int> {
        get {
            if let raw = selectedDaysRaw, !raw.isEmpty {
                return Set(raw.split(separator: ",").compactMap { Int($0) })
            }
            // Fallback: 기존 Attendance의 요일에서 역추론
            let attendances = (self.attendances as? Set<Attendance>) ?? []
            guard !attendances.isEmpty else { return Set(1...7) }
            let cal = Calendar.current
            return Set(attendances.compactMap { a -> Int? in
                guard let planDate = a.planDate else { return nil }
                return cal.component(.weekday, from: planDate)
            })
        }
        set {
            selectedDaysRaw = newValue.sorted().map(String.init).joined(separator: ",")
        }
    }
}
