//
//  SelectionCountBadgePresenting.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 2/19/26.
//

import UIKit
import RKNotificationHub

protocol SelectionCountBadgePresenting: AnyObject {
    var doneButton: UIButton! { get }
    var badge: RKNotificationHub! { get set }
    var totalTracksCount: Int { get }
}

extension SelectionCountBadgePresenting where Self: UIViewController {
    func setupSelectionCountBadge() {
        doneButton.clipsToBounds = false
        doneButton.titleLabel?.layer.zPosition = -1
        badge = RKNotificationHub(view: doneButton)
        badge.count = Int32(totalTracksCount)
        badge.scaleCircleSize(by: 0.6)
        badge.moveCircleBy(x: -4, y: 4)
        badge.setCircleColor(AppConstants.orange, label: .white)
        updateSelectionCountBadge(to: totalTracksCount)
    }
    
    func updateSelectionCountBadge(to count: Int) {
        guard badge != nil else { return }
        badge.count = Int32(count)
        badge.pop()
        let titleKey = count > 0 ? "Add" : "Done"
        doneButton.setTitle(NSLocalizedString(titleKey, comment: ""), for: .normal)
    }
    
    func setBadge(to count: Int) {
        updateSelectionCountBadge(to: count)
    }
}
