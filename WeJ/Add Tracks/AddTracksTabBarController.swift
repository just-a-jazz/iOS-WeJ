//
//  AddTracksTabBarController.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 8/9/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import UIKit
import M13Checkbox

class AddTracksTabBarController: UITabBarController, UITabBarControllerDelegate, UITableViewDelegate, UITableViewDataSource {
    
    var myHubController: MusicLibrarySelectionViewController!
    
    fileprivate var expandedLibraryHeaderHeight: CGFloat = 280
    fileprivate var collapsedLibraryHeaderHeight: CGFloat {
        let safeAreaTop = view.window?.safeAreaInsets.top ?? view.safeAreaInsets.top
        let baseOffset: CGFloat = safeAreaTop >= 40 ? 70 : 45
        return safeAreaTop - baseOffset
    }
    
    fileprivate var previousScrollOffset: CGFloat = 0
    fileprivate var isAdjustingLibraryHeaderDuringCurrentDrag = false
    private var manualHeaderStartHeight: CGFloat = 0
    
    var libraryTracksSelected = [Track]() {
        didSet {
            updateBadge(to: libraryTracksSelected.count + tracksSelected.count)
        }
    }
    var playlistsSelected: [MusicService: [IndexPath: M13Checkbox.CheckState]] = [.appleMusic: [:], .spotify: [:]]
    var tracksSelected = [Track]() {
        didSet {
            updateBadge(to: libraryTracksSelected.count + tracksSelected.count)
        }
    }
    
    func configureCustomPresentation() {
        modalPresentationStyle = .custom
        transitioningDelegate = self
    }
    
    func myMusicDoneButtonFrame(in targetView: UIView) -> CGRect? {
        guard let myHubController = myHubController,
              myHubController.isViewLoaded,
              myHubController.doneButton != nil else {
            return nil
        }
        
        myHubController.view.layoutIfNeeded()
        return myHubController.doneButton.convert(myHubController.doneButton.bounds, to: targetView)
    }
    
    private func tracksList(for tableView: UITableView) -> [Track] {
        // Use the calling table view to avoid mismatches during rapid tab switches.
        if let searchController = viewControllers?.compactMap({ $0 as? SearchViewController }).first,
           tableView == searchController.trackTableView {
            return searchController.tracksList
        }

        return myHubController.tracksList
    }
    
    private func updateBadge(to count: Int) {
        if let navigationVC = viewControllers?.first(where: { $0 is UINavigationController }) as? UINavigationController {
            if let controller = navigationVC.viewControllers.first(where: { $0 is MusicLibrarySelectionViewController }) as? MusicLibrarySelectionViewController {
                controller.setBadge(to: count)
            }
            
            if let controller = navigationVC.viewControllers.first(where: { $0 is PlaylistSelectionViewController }) as? PlaylistSelectionViewController {
                controller.setBadge(to: count)
            }
            
            if let controller = navigationVC.viewControllers.first(where: { $0 is PlaylistSubcategorySelectionViewController }) as? PlaylistSubcategorySelectionViewController {
                controller.setBadge(to: count)
            }
            
            if let controller = navigationVC.viewControllers.first(where: { $0 is LibraryTracksViewController }) as? LibraryTracksViewController {
                controller.setBadge(to: count)
            }
        }
        
        if let controller = viewControllers?.first(where: { $0 is SearchViewController }) as? SearchViewController {
            controller.setBadge(to: count)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .dark
        }
        setDelegates()
        
        adjustViews()
        configureTabBarAppearance()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        initializeVariables()
    }
    
    private func setDelegates() {
        delegate = self
    }
    
    private func adjustViews() {
        UITabBarItem.appearance().setTitleTextAttributes([
            NSAttributedStringKey.font: UIFont(name: "AvenirNext-Regular", size: 10)!
            ], for: .normal)
        
        tabBar.items?.forEach { item in
            item.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 2)
            item.imageInsets = UIEdgeInsets(top: 2, left: 0, bottom: -2, right: 0)
        }
    }
    
    private func configureTabBarAppearance() {
        tabBar.isTranslucent = false
        tabBar.tintColor = AppConstants.orange
        tabBar.unselectedItemTintColor = .white
        tabBar.barTintColor = AppConstants.darkerBlack
        tabBar.backgroundColor = AppConstants.darkerBlack
        tabBar.shadowImage = UIImage()
        tabBar.backgroundImage = UIImage()
        tabBar.clipsToBounds = true
    }
    
    private func initializeVariables() {
        if let navigationVC = viewControllers?.first(where: { $0 is UINavigationController }) as? UINavigationController {
            myHubController = navigationVC.viewControllers.first(where: { $0 is MusicLibrarySelectionViewController }) as? MusicLibrarySelectionViewController
            myHubController?.loadViewIfNeeded()
            if let headerHeight = myHubController?.headerHeightConstraint?.constant {
                expandedLibraryHeaderHeight = headerHeight
            }
        }
    }
    
    // MARK: - Tab Bar Controller
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if let navigationVC = viewController as? UINavigationController,
            let controller = navigationVC.viewControllers.first(where: { $0 is MusicLibrarySelectionViewController }) as? MusicLibrarySelectionViewController, controller.tracksTableView != nil {
            controller.tracksTableView.reloadData()
        }
        
        if let controller = viewController as? SearchViewController {
            controller.trackTableView.reloadData()
        }
    }
    
    // MARK: - Table
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tracksList(for: tableView).count
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let list = tracksList(for: tableView)
        guard indexPath.row < list.count else { return }
        cell.backgroundColor = .clear

        let track = list[indexPath.row]
        let isSelected = Party.tracksQueue(hasTrack: track)
            || tracksSelected.contains(where: { $0.id == track.id })
            || (isAppleMusicLibrarySelection(for: tableView)
                && libraryTracksSelected.contains(where: { $0.hasSameIdentity(as: track) }))

        if isSelected {
            cell.accessoryType = .checkmark
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        } else {
            cell.accessoryType = .none
            tableView.deselectRow(at: indexPath, animated: false)
        }
        
        if tableView == myHubController.tracksTableView,
           indexPath.row >= list.count - 5 {
            myHubController.loadMoreMostPlayedIfNeeded()
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Track", for: indexPath) as! TrackTableViewCell
        let list = tracksList(for: tableView)
        guard indexPath.row < list.count else { return cell }
        
        // Cell Properties
        cell.trackName.text = list[indexPath.row].name
        cell.artistName.text = list[indexPath.row].artist
        cell.artworkImageView.image = list[indexPath.row].lowResArtwork
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)!
        let list = tracksList(for: tableView)
        guard indexPath.row < list.count else { return }
        let track = list[indexPath.row]
        if isAppleMusicLibrarySelection(for: tableView) {
            addToLibraryQueue(track: track)
        } else {
            addToQueue(track: track)
        }
        UIView.animate(withDuration: 0.35) {
            cell.accessoryType = .checkmark
        }
    }
    
    private func addToQueue(track: Track) {
        if !Party.tracksQueue(hasTrack: track) && !tracksSelected.contains(track) {
            tracksSelected.append(track)
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)!
        let list = tracksList(for: tableView)
        guard indexPath.row < list.count else { return }
        let track = list[indexPath.row]
        if isAppleMusicLibrarySelection(for: tableView) {
            removeFromLibraryQueue(track: track)
        } else {
            removeFromQueue(track: track)
        }
        
        if !Party.tracksQueue(hasTrack: list[indexPath.row]) {
            UIView.animate(withDuration: 0.35) {
                cell.accessoryType = .none
            }
        }
    }

    private func removeFromQueue(track: Track) {
        if let index = tracksSelected.index(where: {$0.id == track.id}) {
            tracksSelected.remove(at: index)
        }
    }

    private func addToLibraryQueue(track: Track) {
        if !Party.tracksQueue(hasTrack: track) && !libraryTracksSelected.contains(where: { $0.hasSameIdentity(as: track) }) {
            libraryTracksSelected.append(track)
        }
    }

    private func removeFromLibraryQueue(track: Track) {
        if let index = libraryTracksSelected.index(where: { $0.hasSameIdentity(as: track) }) {
            libraryTracksSelected.remove(at: index)
        }
    }

    private func isAppleMusicLibrarySelection(for tableView: UITableView) -> Bool {
        return Party.musicService == .appleMusic && tableView == myHubController.tracksTableView
    }

}

extension AddTracksTabBarController: UIViewControllerTransitioningDelegate {
    
    func presentationController(forPresented presented: UIViewController,
                                presenting: UIViewController?,
                                source: UIViewController) -> UIPresentationController? {
        return AddTracksPresentationController(presentedViewController: presented, presenting: presenting)
    }
    
    func animationController(forPresented presented: UIViewController,
                             presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return AddTracksPresentationAnimator()
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return AddTracksDismissalAnimator()
    }
    
}

private final class AddTracksPresentationController: UIPresentationController, UIGestureRecognizerDelegate {
    
    private let backdropView = UIView()
    private var dismissalPanGesture: UIPanGestureRecognizer?
    private weak var activeDismissalScrollView: UIScrollView?
    private var presentedFrame: CGRect = .zero
    private var isPresenting = false
    private var isTrackingDismissal = false
    
    override var shouldPresentInFullscreen: Bool {
        return false
    }
    
    override var shouldRemovePresentersView: Bool {
        return false
    }
    
    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
        backdropView.backgroundColor = AppConstants.darkerBlack
    }
    
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else { return .zero }
        
        let topInset = containerView.safeAreaInsets.top
        let topOffset: CGFloat = topInset >= 40 ? 70 : 45
        let yOrigin = min(topOffset, containerView.bounds.height)
        let height = containerView.bounds.height - yOrigin
        return CGRect(x: 0,
                      y: yOrigin,
                      width: containerView.bounds.width,
                      height: height)
    }
    
    override func presentationTransitionWillBegin() {
        guard let containerView = containerView else { return }
        
        isPresenting = true
        presentedFrame = frameOfPresentedViewInContainerView
        backdropView.frame = offscreenFrame(from: presentedFrame, in: containerView)
        containerView.insertSubview(backdropView, at: 0)
        configurePresentedViewAppearance()
        addDismissalGestureIfNeeded()
        
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            self.backdropView.frame = self.presentedFrame
        })
    }
    
    override func dismissalTransitionWillBegin() {
        guard let containerView = containerView else { return }
        
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            self.backdropView.frame.origin.y = containerView.bounds.height
        })
    }
    
    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        presentedFrame = frameOfPresentedViewInContainerView
        if !isPresenting {
            backdropView.frame = presentedFrame
            if !isTrackingDismissal {
                presentedView?.frame = presentedFrame
            }
        }
        configurePresentedViewAppearance()
    }
    
    override func presentationTransitionDidEnd(_ completed: Bool) {
        isPresenting = false
        if !completed {
            backdropView.removeFromSuperview()
        }
    }
    
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed {
            backdropView.removeFromSuperview()
        }
    }
    
    private func addDismissalGestureIfNeeded() {
        guard dismissalPanGesture == nil, let containerView = containerView else { return }
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDismissalPan(_:)))
        panGesture.delegate = self
        panGesture.cancelsTouchesInView = false
        containerView.addGestureRecognizer(panGesture)
        dismissalPanGesture = panGesture
    }
    
    private func configurePresentedViewAppearance() {
        guard let presentedView = presentedView else { return }
        
        configureRoundedTopCorners(for: backdropView)
        configureRoundedTopCorners(for: presentedView)
    }
    
    private func offscreenFrame(from frame: CGRect, in containerView: UIView) -> CGRect {
        return frame.offsetBy(dx: 0, dy: containerView.bounds.height - frame.minY)
    }
    
    private func configureRoundedTopCorners(for view: UIView) {
        if #available(iOS 26.0, *) {
            view.layer.cornerRadius = 32
            view.layer.cornerCurve = .continuous
            view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            view.layer.masksToBounds = true
        } else {
            view.layer.cornerRadius = 0
            view.layer.masksToBounds = false
        }
    }
    
    @objc private func handleDismissalPan(_ gesture: UIPanGestureRecognizer) {
        guard let presentedView = presentedView,
              let containerView = containerView else { return }
        
        let translationY = max(gesture.translation(in: containerView).y, 0)
        switch gesture.state {
        case .began:
            isTrackingDismissal = true
            presentedFrame = presentedView.frame
            activeDismissalScrollView = scrollViewAtDismissalPanLocation(gesture)
            activeDismissalScrollView?.isScrollEnabled = false
        case .changed:
            presentedView.frame = presentedFrame.offsetBy(dx: 0, dy: translationY)
            backdropView.frame = presentedView.frame
        case .ended, .cancelled, .failed:
            let velocityY = gesture.velocity(in: containerView).y
            if translationY > 120 || velocityY > 900 {
                let remainingDistance = containerView.bounds.height - presentedView.frame.minY
                let duration = max(0.12, min(0.28, TimeInterval(remainingDistance / max(velocityY, 900))))
                UIView.animate(withDuration: duration,
                               delay: 0,
                               options: [.curveEaseOut],
                               animations: {
                    presentedView.frame.origin.y = containerView.bounds.height
                    self.backdropView.frame = presentedView.frame
                }, completion: { _ in
                    self.isTrackingDismissal = false
                    self.activeDismissalScrollView?.isScrollEnabled = true
                    self.activeDismissalScrollView = nil
                    self.presentedViewController.dismiss(animated: false)
                })
            } else {
                UIView.animate(withDuration: 0.2, animations: {
                    presentedView.frame = self.presentedFrame
                    self.backdropView.frame = self.presentedFrame
                }, completion: { _ in
                    self.isTrackingDismissal = false
                    self.activeDismissalScrollView?.isScrollEnabled = true
                    self.activeDismissalScrollView = nil
                })
            }
        default:
            break
        }
    }
    
    private var addTracksController: AddTracksTabBarController? {
        return presentedViewController as? AddTracksTabBarController
    }
    
    private func canBeginInteractiveDismissal(from panGesture: UIPanGestureRecognizer) -> Bool {
        guard let controller = addTracksController,
              let hubController = controller.myHubController else {
            return false
        }
        
        let topLibraryController = (controller.selectedViewController as? UINavigationController)?.topViewController
        let isOnLibraryRoot = topLibraryController === hubController
        let isLibraryHeaderExpanded = hubController.headerHeightConstraint.constant >= 279.5
        
        if let touchedScrollView = scrollViewAtDismissalPanLocation(panGesture) {
            if touchedScrollView === hubController.tracksTableView && isOnLibraryRoot {
                return isLibraryHeaderExpanded && isAtTop(touchedScrollView)
            }
            return isAtTop(touchedScrollView)
        }
        
        if topLibraryController is PlaylistSelectionViewController {
            return true
        }
        
        return isOnLibraryRoot && isLibraryHeaderExpanded
    }
    
    private func scrollViewAtDismissalPanLocation(_ panGesture: UIPanGestureRecognizer) -> UIScrollView? {
        guard let containerView = containerView else { return nil }
        let location = panGesture.location(in: containerView)
        return enclosingScrollView(from: containerView.hitTest(location, with: nil))
    }
    
    private func enclosingScrollView(from view: UIView?) -> UIScrollView? {
        var currentView = view
        while let view = currentView {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            currentView = view.superview
        }
        return nil
    }
    
    private func isAtTop(_ scrollView: UIScrollView) -> Bool {
        let topOffset = -scrollView.adjustedContentInset.top
        return scrollView.contentOffset.y <= topOffset + 0.5
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == dismissalPanGesture,
              let panGesture = gestureRecognizer as? UIPanGestureRecognizer,
              let containerView = containerView else {
            return true
        }
        
        let velocity = panGesture.velocity(in: containerView)
        return velocity.y > abs(velocity.x) && canBeginInteractiveDismissal(from: panGesture)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == dismissalPanGesture,
              let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
            return false
        }
        return canBeginInteractiveDismissal(from: panGesture)
    }
    
}

private final class AddTracksPresentationAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.28
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let presentedView = transitionContext.view(forKey: .to),
              let presentedController = transitionContext.viewController(forKey: .to) else {
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            return
        }
        
        let containerView = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: presentedController)
        presentedView.frame = finalFrame.offsetBy(dx: 0, dy: containerView.bounds.height - finalFrame.minY)
        containerView.addSubview(presentedView)
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext),
                       delay: 0,
                       options: [.curveEaseOut],
                       animations: {
            presentedView.frame = finalFrame
        }, completion: { finished in
            transitionContext.completeTransition(finished && !transitionContext.transitionWasCancelled)
        })
    }
    
}

private final class AddTracksDismissalAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.25
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let dismissedView = transitionContext.view(forKey: .from),
              let dismissedController = transitionContext.viewController(forKey: .from) else {
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            return
        }
        
        let viewToAnimate = (dismissedController as? AddTracksTabBarController)?.view
            ?? dismissedController.tabBarController?.view
            ?? dismissedView
        
        let duration = transitionDuration(using: transitionContext)
        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: [.curveEaseInOut],
                       animations: {
            viewToAnimate.frame.origin.y = transitionContext.containerView.bounds.height
        }, completion: { finished in
            transitionContext.completeTransition(finished && !transitionContext.transitionWasCancelled)
        })
    }
    
}

extension AddTracksTabBarController {

    func beginManualHeaderAdjustment() {
        manualHeaderStartHeight = myHubController.headerHeightConstraint.constant
    }

    func updateManualHeaderAdjustment(translationY: CGFloat) {
        let newHeight = min(expandedLibraryHeaderHeight,
                            max(collapsedLibraryHeaderHeight, manualHeaderStartHeight + translationY))
        if newHeight != myHubController.headerHeightConstraint.constant {
            myHubController.headerHeightConstraint.constant = newHeight
            myHubController.view.layoutIfNeeded()
        }
    }

    func endManualHeaderAdjustment() {
        scrollViewDidStopScrolling()
    }
    
    // Code taken from https://michiganlabs.com/ios/development/2016/05/31/ios-animating-uitableview-header/
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == myHubController.tracksTableView else { return }
        
        let scrollDiff = scrollView.contentOffset.y - previousScrollOffset
        
        let absoluteTop = -scrollView.adjustedContentInset.top
        
        let isScrollingDown = scrollDiff > 0 && scrollView.contentOffset.y > absoluteTop
        let isPullingDown = scrollView.panGestureRecognizer.velocity(in: scrollView).y > 0
        let isScrollingUp = scrollDiff < 0
            && isPullingDown
            && (scrollView.contentOffset.y <= absoluteTop || isAdjustingLibraryHeaderDuringCurrentDrag)
        
        var newHeight = myHubController.headerHeightConstraint.constant
        
        if isScrollingDown {
            newHeight = max(collapsedLibraryHeaderHeight, myHubController.headerHeightConstraint.constant - abs(scrollDiff))
            if newHeight != myHubController.headerHeightConstraint.constant {
                isAdjustingLibraryHeaderDuringCurrentDrag = true
                myHubController.headerHeightConstraint.constant = newHeight
                setScrollPosition(forOffset: previousScrollOffset)
            }
            
        } else if isScrollingUp {
            newHeight = min(expandedLibraryHeaderHeight, myHubController.headerHeightConstraint.constant + abs(scrollDiff))
            if newHeight != myHubController.headerHeightConstraint.constant {
                isAdjustingLibraryHeaderDuringCurrentDrag = true
                myHubController.headerHeightConstraint.constant = newHeight
                setScrollPosition(forOffset: previousScrollOffset)
            }
        }
        
        previousScrollOffset = scrollView.contentOffset.y
    }
    
    private func setScrollPosition(forOffset offset: CGFloat) {
        myHubController.tracksTableView.contentOffset = CGPoint(x: myHubController.tracksTableView.contentOffset.x, y: offset)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if scrollView == myHubController.tracksTableView {
            isAdjustingLibraryHeaderDuringCurrentDrag = false
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollViewDidStopScrolling()
        if scrollView == myHubController.tracksTableView {
            isAdjustingLibraryHeaderDuringCurrentDrag = false
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            scrollViewDidStopScrolling()
            if scrollView == myHubController.tracksTableView {
                isAdjustingLibraryHeaderDuringCurrentDrag = false
            }
        }
    }
    
    func scrollViewDidStopScrolling() {
        let range = collapsedLibraryHeaderHeight - expandedLibraryHeaderHeight
        let midPoint = expandedLibraryHeaderHeight + (range / 2)
        
        
        myHubController.view.layoutIfNeeded()
        if myHubController.headerHeightConstraint.constant > midPoint {
            UIView.animate(withDuration: 0.2, animations: {
                self.myHubController.headerHeightConstraint.constant = self.expandedLibraryHeaderHeight
                self.myHubController.view.layoutIfNeeded()
            })
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.myHubController.headerHeightConstraint.constant = self.collapsedLibraryHeaderHeight
                self.myHubController.view.layoutIfNeeded()
            })
        }
    }
    
}
