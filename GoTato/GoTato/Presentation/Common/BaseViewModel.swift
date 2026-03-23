//
//  BaseViewModel.swift
//  GoTato
//
//  Created by 석민솔 on 3/23/26.
//

import Foundation

protocol BaseViewModel {
    associatedtype Input
    associatedtype Output

    func transform(input: Input) -> Output
}
