//
//  NaverLocalSearchResponse.swift
//  GoTato
//

import Foundation

// MARK: - Response

struct NaverLocalSearchResponse: Decodable {
    let lastBuildDate: String
    let total: Int
    let start: Int
    let display: Int
    let items: [NaverLocalItem]
}

// MARK: - Item

struct NaverLocalItem: Decodable {
    let title: String
    let link: String
    let category: String
    let description: String
    let telephone: String
    let address: String
    let roadAddress: String
    let mapx: String
    let mapy: String

    var cleanTitle: String {
        title
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
    }
}
