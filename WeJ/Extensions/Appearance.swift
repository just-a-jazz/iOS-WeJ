//
//  Appearance.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 7/26/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import Foundation
import UIKit
import M13Checkbox

extension UIViewController {
    
    func applyAddTracksPushedPageAppearance() {
        view.backgroundColor = AppConstants.darkerBlack
        navigationController?.view.backgroundColor = AppConstants.darkerBlack
        tabBarController?.view.backgroundColor = AppConstants.darkerBlack
        
        [tabBarController?.view, navigationController?.view, view].forEach { containerView in
            guard let containerView = containerView else { return }
            if #available(iOS 26.0, *) {
                containerView.layer.cornerRadius = 32
                containerView.layer.cornerCurve = .continuous
                containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                containerView.layer.masksToBounds = true
            }
        }
    }
    
}

extension UIView {
    
    func makeBorder() {
        layer.borderWidth = 1
        layer.borderColor = AppConstants.orange.cgColor
        layer.cornerRadius = 30
    }
    
    func removeBorder() {
        layer.borderWidth = 0
    }
    
}

// Code taken from: https://stackoverflow.com/questions/808503/uibutton-making-the-hit-area-larger-than-the-default-hit-area 
fileprivate let minimumHitArea = CGSize(width: 44, height: 44)

extension UIButton {

    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // if the button is hidden/disabled/transparent it can't be hit
        if self.isHidden || !self.isUserInteractionEnabled || self.alpha < 0.01 { return nil }
        
        // increase the hit frame to be at least as big as `minimumHitArea`
        let buttonSize = self.bounds.size
        let widthToAdd = max(minimumHitArea.width - buttonSize.width, 0)
        let heightToAdd = max(minimumHitArea.height - buttonSize.height, 0)
        let largerFrame = self.bounds.insetBy(dx: -widthToAdd / 2, dy: -heightToAdd / 2)
        
        // perform hit test on larger frame
        return (largerFrame.contains(point)) ? self : nil
    }

}

extension M13Checkbox {
    
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // if the button is hidden/disabled/transparent it can't be hit
        if self.isHidden || !self.isUserInteractionEnabled || self.alpha < 0.01 { return nil }
        
        // increase the hit frame to be at least as big as `minimumHitArea`
        let buttonSize = self.bounds.size
        let widthToAdd = max(minimumHitArea.width - buttonSize.width, 0)
        let heightToAdd = max(minimumHitArea.height - buttonSize.height, 0)
        let largerFrame = self.bounds.insetBy(dx: -widthToAdd / 2, dy: -heightToAdd / 2)
        
        // perform hit test on larger frame
        return (largerFrame.contains(point)) ? self : nil
    }
    
}

extension UIImage {
    
    func addGradient() -> UIImage {
        UIGraphicsBeginImageContext(self.size)
        let context = UIGraphicsGetCurrentContext()
        
        self.draw(at: CGPoint(x: 0, y: 0))
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let locations: [CGFloat] = [0.0, 1.0]
        
        let bottom = UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 1).cgColor
        let top = UIColor(red: 0, green: 0, blue: 0, alpha: 0.2).cgColor
        
        let colors = [top, bottom] as CFArray
        
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations)
        
        let startPoint = CGPoint(x: self.size.width/2, y: 0)
        let endPoint = CGPoint(x: self.size.width/2, y: self.size.height)
        
        context!.drawLinearGradient(gradient!, start: startPoint, end: endPoint, options: CGGradientDrawingOptions(rawValue: UInt32(0)))
        
        let imageToReturn = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return imageToReturn!
    }
    
}
