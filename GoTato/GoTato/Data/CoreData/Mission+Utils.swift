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
}
