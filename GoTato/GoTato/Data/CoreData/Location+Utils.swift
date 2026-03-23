//
//  Location+Utils.swift
//  GoTato
//

import CoreData
import Foundation

extension Location {
    public nonisolated override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
    }
}
