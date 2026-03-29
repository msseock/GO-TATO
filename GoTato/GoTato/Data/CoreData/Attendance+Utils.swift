//
//  Attendance+Utils.swift
//  GoTato
//
//  Created by 석민솔 on 3/24/26.
//

import Foundation
import CoreData

// Attendance+Utils.swift
extension Attendance {
    public nonisolated override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
    }

    var attendanceStatus: AttendanceStatus {
        get { AttendanceStatus(rawValue: self.status) ?? .pending }
        set { self.status = newValue.rawValue }
    }
}

enum AttendanceStatus: Int16 {
    case pending = 0, success = 1, late = 2, fail = 3, failCommitted = 4
}
