//
//  PartyConnection.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 7/27/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import Foundation
import MultipeerConnectivity

extension PartyViewController {
    
    func displayAlert() {
        view.layoutSubviews()
        UIView.animate(withDuration: 1) {
            if #available(iOS 11.0, *), UIDevice.deviceType == .iPhoneX {
                let bottomInset = self.view.window?.safeAreaInsets.bottom ?? self.view.safeAreaInsets.bottom
                self.alertViewConstraint.constant = -bottomInset
            } else {
                self.alertViewConstraint.constant = -34
            }
            self.view.layoutSubviews()
        }
    }
    
    func changeStatusIndicatorView(toColor color: UIColor) {
        UIView.animate(withDuration: 0.3) {
            self.statusIndicatorView.backgroundColor = color
        }
    }
    
    func hideAlert(completionHandler: ((Bool) -> Void)? = nil) {
        view.layoutSubviews()
        UIView.animate(withDuration: 1, animations: {
            self.alertViewConstraint.constant = -130
            self.view.layoutSubviews()
        }, completion: completionHandler)
    }
    
    func showConnectionRelatedViewsOnAlert() {
        alertLabelConstraint.constant = 15
        reconnectButton.isHidden = false
        statusIndicatorView.isHidden = false
        resendButton.isHidden = true
    }
    
    func hideConnectionRelatedViewsOnAlert() {
        alertLabelConstraint.constant = -5
        reconnectButton.isHidden = true
        statusIndicatorView.isHidden = true
    }
    
}
