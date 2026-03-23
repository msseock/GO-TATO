//
//  BaseViewController.swift
//  GoTato
//
//  Created by 석민솔 on 3/23/26.
//

import UIKit

class BaseViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        configureHierarchy()
        configureLayout()
        configureView()
        bind()
        view.backgroundColor = .white
    }
    
    // MARK: 기본실행을 위한 편의메서드
    /// 서브뷰 등록
    func configureHierarchy() {
        
    }
    
    /// 레이아웃 설정
    func configureLayout() {
        
    }
    
    /// 뷰 컴포넌트 설정
    func configureView() {
        
    }
    
    /// 뷰모델 input/output 연결
    func bind() {
        
    }    
    
}
