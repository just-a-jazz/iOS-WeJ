//
//  LyricsAndQueuePageViewController.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 3/15/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import UIKit

protocol TracksTableModifierDelegate: class {
    func showAddButton()
}

class HubAndQueuePageViewController: UIPageViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource, TracksTableModifierDelegate {
    
    weak var partyDelegate: PartyViewControllerInfoDelegate?
    private var allViewControllers = [UIViewController]()
    
    static var minHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        let hasNotch = (window?.safeAreaInsets.bottom ?? 0) > 0
        return (hasNotch ? 0.47 : 0.56) * screenHeight
    }
    static var maxHeight: CGFloat {
        guard !Party.tracksQueue.isEmpty else { return 0.0 }
        let screenHeight = UIScreen.main.bounds.height
        return max(120.0, screenHeight * 0.16)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setDelegates()
        populateListOfViewControllers()
        configureScrollViewTouchDelays()
    }
    
    private func setDelegates() {
        delegate = self
        dataSource = self
    }
    
    // Ensure skip's button touches are not delayed by the page view controller scroll view.
    private func configureScrollViewTouchDelays() {
        for subview in view.subviews {
            if let scrollView = subview as? UIScrollView {
                scrollView.delaysContentTouches = false
                scrollView.canCancelContentTouches = true
            }
        }
    }
    
    private func populateListOfViewControllers() {
        let hubViewController = storyboard!.instantiateViewController(withIdentifier: "Hub")
        let tracksQueueViewController = storyboard!.instantiateViewController(withIdentifier: "Queue")
        
        allViewControllers.append(hubViewController)
        allViewControllers.append(tracksQueueViewController)
        
        let vc1 = allViewControllers[0] as! HubViewController
        vc1.delegate = partyDelegate!
        vc1.tracksTableModifierDelegate = self
        
        let vc2 = allViewControllers[1] as! QueueViewController
        vc2.delegate = partyDelegate!
        
        setViewControllers([tracksQueueViewController], direction: .reverse, animated: true, completion: nil)
    }
    
    func updateHubTitle() {
        if let vc = allViewControllers[0] as? HubViewController {
            vc.updateHubTitle()
        }
    }
    
    func updateTable() {
        if let vc = allViewControllers[1] as? QueueViewController {
            vc.updateTable()
        }
    }
    
    func showAddButton() {
        if let vc = allViewControllers[1] as? QueueViewController {
            vc.showAddButton()
        }
    }
    
    func hideAddButton() {
        if let vc = allViewControllers[1] as? QueueViewController {
            vc.hideAddButton()
        }
    }
    
    func expandTracksTable() {
        if let vc = allViewControllers[1] as? QueueViewController {
            vc.makeTracksTableTaller()
        }
    }
    
    func minimizeTracksTable() {
        if let vc = allViewControllers[1] as? QueueViewController {
            vc.makeTracksTableShorter()
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        let index = allViewControllers.index(of: viewController)
        return index == 0 ? nil : allViewControllers[0]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        let index = allViewControllers.index(of: viewController)
        return index == 1 ? nil : allViewControllers[1]
    }
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return allViewControllers.count
    }
    
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        return 1
    }

}
