//
//  partyNameTextField.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 8/5/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import UIKit

class partyNameTextField: UITextField {
    
    private let bottomLine = CALayer()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        customizeTextField()
    }
    
    func customizeTextField() {
        tintColor = AppConstants.orange
        autocapitalizationType = .words
        returnKeyType = .done
        addBottomBorder()
    }
    
    func addBottomBorder() {
        bottomLine.backgroundColor = AppConstants.orange.cgColor
        borderStyle = .none
        layer.addSublayer(bottomLine)
        updateBottomBorderFrame()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateBottomBorderFrame()
    }
    
    private func updateBottomBorderFrame() {
        bottomLine.frame = CGRect(x: 0, y: bounds.height + 10, width: bounds.width, height: 1)
    }
    
}
