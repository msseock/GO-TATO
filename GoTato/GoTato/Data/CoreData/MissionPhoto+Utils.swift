//
//  MissionPhoto+Utils.swift
//  GoTato
//

import CoreData
import Foundation

extension MissionPhoto {
    public nonisolated override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "createdAt")
    }
}
