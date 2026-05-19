//
//  QueueViewController.swift
//  
//
//  Created by Ali Siddiqui on 3/15/17.
//
//

import UIKit

class QueueViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    weak var delegate: PartyViewControllerInfoDelegate?

    @IBOutlet weak var upNextLabel: UILabel!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var editButton: UIButton!
    
    @IBOutlet weak var tracksTableView: UITableView!
    private var upNextSeparator: UIView?
    private var visibleTracksQueue = [Track]()

    fileprivate var minHeight: CGFloat {
        return HubAndQueuePageViewController.minHeight
    }
    fileprivate var maxHeight: CGFloat {
        return HubAndQueuePageViewController.maxHeight
    }
    
    fileprivate var previousScrollOffset: CGFloat = 0
        
    override func viewDidLoad() {
        super.viewDidLoad()
        refreshVisibleQueueSnapshot()
        setDelegates()
        adjustFontSizes()
        addUpNextSeparatorIfNeeded()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        changeFontSizeForUpNext()
        updateEditButtonForHeaderState()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Add Tracks",
           let addTracksController = segue.destination as? AddTracksTabBarController {
            addTracksController.configureCustomPresentation()
        }
    }
    
    private func adjustFontSizes() {
        if UIDevice.deviceType == .iPhone4_4s || UIDevice.deviceType == .iPhone5_5s_SE {
            addButton.changeToSmallerFont()
            editButton.changeToSmallerFont()
        }
    }
    
    private func setDelegates() {
        tracksTableView.delegate = self
        tracksTableView.dataSource = self
    }

    private func updateEditButtonForHeaderState() {
        if headerHeightConstraint == maxHeight {
            goIntoEditingMode()
        } else if headerHeightConstraint == minHeight {
            comeOutOfEditingMode()
        }
    }

    private func addUpNextSeparatorIfNeeded() {
        guard upNextSeparator == nil else { return }

        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        view.addSubview(separator)

        let guide = view.safeAreaLayoutGuide
        let horizontalInset: CGFloat = 20

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: upNextLabel.bottomAnchor, constant: 10),
            separator.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: horizontalInset),
            separator.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -horizontalInset),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])

        upNextSeparator = separator
    }
    
    // MARK: - Table
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return visibleTracksQueue.count
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = UIEdgeInsets.zero
        cell.layoutMargins = UIEdgeInsets.zero
        cell.backgroundColor = .clear
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Track In Queue") as! TrackTableViewCell
        
        if let track = visibleTrack(at: indexPath) {
            cell.trackName.text = track.name
            cell.artistName.text = track.artist
            cell.artworkImageView.image = track.lowResArtwork
        } else {
            cell.trackName.text = nil
            cell.artistName.text = nil
            cell.artworkImageView.image = nil
        }
        
        return cell
    }

    @IBAction func editCells(_ sender: UIButton) {
        if sender.titleLabel?.text == NSLocalizedString("Edit", comment: "") {
            tracksTableView.setEditing(true, animated: true)
            animateEditButtonTitle(sender, to: NSLocalizedString("Done", comment: ""))
        } else {
            tracksTableView.setEditing(false, animated: true)
            animateEditButtonTitle(sender, to: NSLocalizedString("Edit", comment: ""))
        }
    }

    private func animateEditButtonTitle(_ button: UIButton, to title: String) {
        guard button.title(for: .normal) != title else { return }
        UIView.transition(with: button, duration: 0.2, options: .transitionCrossDissolve, animations: {
            button.setTitle(title, for: .normal)
        })
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let track = visibleTrack(at: indexPath),
              let delegate = delegate else {
            return false
        }
        return delegate.isHost || delegate.personalQueue.contains(where: { $0.id == track.id })
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return delegate?.isHost == true && visibleTrack(at: indexPath) != nil
    }
    
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard visibleTracksQueue.indices.contains(sourceIndexPath.row),
              visibleTracksQueue.indices.contains(destinationIndexPath.row) else {
            refreshVisibleQueueSnapshot()
            tableView.reloadData()
            return
        }
        
        var reorderedVisibleTracks = visibleTracksQueue
        let itemMoved = reorderedVisibleTracks.remove(at: sourceIndexPath.row)
        reorderedVisibleTracks.insert(itemMoved, at: destinationIndexPath.row)
        
        applyVisibleTracksQueue(reorderedVisibleTracks)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            guard let track = removeTrack(atVisibleIndex: indexPath.row) else {
                refreshVisibleQueueSnapshot()
                tableView.reloadData()
                return
            }
            
            tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath], with: .right)
            tableView.endUpdates()
            delegate?.sendTracksToPeers(forTracks: [track], toRemove: true)
        }
    }
    
    func removeTrack(atVisibleIndex visibleIndex: Int) -> Track? {
        guard visibleTracksQueue.indices.contains(visibleIndex),
              Party.tracksQueue.count > 1 else {
            return nil
        }
        
        let track = visibleTracksQueue[visibleIndex]
        guard let queueIndex = Party.tracksQueue[1...].index(where: { $0.id == track.id }) else {
            return nil
        }
        
        let removedTrack = Party.tracksQueue.remove(at: queueIndex)
        if visibleTracksQueue.indices.contains(visibleIndex) {
            visibleTracksQueue.remove(at: visibleIndex)
        } else {
            refreshVisibleQueueSnapshot()
        }
        return removedTrack
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: NSLocalizedString("Remove", comment: "")) { _, _, completion in
            tableView.dataSource?.tableView?(
                tableView,
                commit: .delete,
                forRowAt: indexPath
            )
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
}

private extension QueueViewController {
    
    var currentVisibleTracksQueue: [Track] {
        guard Party.tracksQueue.count > 1 else { return [] }
        return Array(Party.tracksQueue.dropFirst())
    }
    
    func refreshVisibleQueueSnapshot() {
        visibleTracksQueue = currentVisibleTracksQueue
    }
    
    func visibleTrack(at indexPath: IndexPath) -> Track? {
        guard visibleTracksQueue.indices.contains(indexPath.row) else { return nil }
        return visibleTracksQueue[indexPath.row]
    }
    
    func applyVisibleTracksQueue(_ reorderedVisibleTracks: [Track]) {
        guard let currentTrack = Party.tracksQueue.first else {
            visibleTracksQueue = reorderedVisibleTracks
            Party.tracksQueue = reorderedVisibleTracks
            return
        }
        
        let latestVisibleTracks = currentVisibleTracksQueue
        let latestVisibleTrackIDs = Set(latestVisibleTracks.map { $0.id })
        let reorderedTracksStillInQueue = reorderedVisibleTracks.filter { latestVisibleTrackIDs.contains($0.id) }
        let reorderedTrackIDs = Set(reorderedTracksStillInQueue.map { $0.id })
        let tracksAddedAfterSnapshot = latestVisibleTracks.filter { !reorderedTrackIDs.contains($0.id) }
        
        visibleTracksQueue = reorderedTracksStillInQueue + tracksAddedAfterSnapshot
        Party.tracksQueue = [currentTrack] + visibleTracksQueue
    }
    
}

extension QueueViewController {
    
    private var headerHeightConstraint: CGFloat {
        get {
            return delegate?.tableHeight ?? maxHeight
        }
        
        set {
            delegate?.tableHeight = newValue
            if headerHeightConstraint == maxHeight {
                goIntoEditingMode()
            } else if headerHeightConstraint == minHeight {
                comeOutOfEditingMode()
            }
        }
    }
    
    // Code taken from https://michiganlabs.com/ios/development/2016/05/31/ios-animating-uitableview-header/
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let scrollDiff = scrollView.contentOffset.y - previousScrollOffset
        
        let absoluteTop: CGFloat = 0
        
        let isScrollingDown = scrollDiff > 0 && scrollView.contentOffset.y > absoluteTop
        let isScrollingUp = scrollDiff < 0 && scrollView.contentOffset.y < absoluteTop && !Party.tracksQueue.isEmpty
        
        var newHeight = headerHeightConstraint
        
        if isScrollingDown {
            newHeight = max(maxHeight, headerHeightConstraint - abs(scrollDiff))
            if newHeight != headerHeightConstraint {
                headerHeightConstraint = newHeight
                changeFontSizeForUpNext()
                setScrollPosition(forOffset: previousScrollOffset)
            }
            
        } else if isScrollingUp {
            newHeight = min(minHeight, headerHeightConstraint + abs(scrollDiff))
            if newHeight != headerHeightConstraint && tracksTableView.contentOffset.y < 2 {
                headerHeightConstraint = newHeight
                changeFontSizeForUpNext()
                setScrollPosition(forOffset: previousScrollOffset)
            }
        }
        
        previousScrollOffset = scrollView.contentOffset.y
    }
    
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        makeTracksTableShorter()
    }
    
    fileprivate func changeFontSizeForUpNext() {
        UIView.animate(withDuration: 0.3) {
            self.upNextLabel.font = self.upNextLabel.font.withSize(20 - UILabel.smallerTitleFontSize * (self.headerHeightConstraint / self.minHeight))
        }
    }
    
    private func setScrollPosition(forOffset offset: CGFloat) {
        tracksTableView.contentOffset = CGPoint(x: tracksTableView.contentOffset.x, y: offset)
    }
    
    fileprivate func goIntoEditingMode() {
        if (delegate!.isHost && !currentVisibleTracksQueue.isEmpty) || tracksQueueHasEditableTracks() {
            if addButton.isHidden {
                editButton.isHidden = false
            } else {
                editButton.alpha = 0
                editButton.isHidden = false
                UIView.animate(withDuration: 0.1, animations: {
                    self.addButton.alpha = 0
                }) { _ in
                    self.addButton.isHidden = true
                    UIView.animate(withDuration: 0.1) {
                        self.editButton.alpha = 1
                    }
                }
            }
            let targetTitle = tracksTableView.isEditing ? NSLocalizedString("Done", comment: "") : NSLocalizedString("Edit", comment: "")
            animateEditButtonTitle(editButton, to: targetTitle)
        }
    }
    
    private func tracksQueueHasEditableTracks() -> Bool {
        for track in currentVisibleTracksQueue {
            if delegate!.personalQueue.contains(where: { $0.id == track.id }) {
                return true
            }
        }
        return false
    }
    
    fileprivate func comeOutOfEditingMode() {
        tracksTableView.setEditing(false, animated: true)
        if editButton.isHidden {
            addButton.isHidden = false
        } else {
            addButton.alpha = 0
            addButton.isHidden = false
            UIView.animate(withDuration: 0.1, animations: {
                self.editButton.alpha = 0
            }) { _ in
                self.editButton.isHidden = true
                UIView.animate(withDuration: 0.1) {
                    self.addButton.alpha = 1
                }
            }
        }
        animateEditButtonTitle(editButton, to: NSLocalizedString("Edit", comment: ""))
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollViewDidStopScrolling()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            scrollViewDidStopScrolling()
        }
    }
    
    func scrollViewDidStopScrolling() {
        let range = maxHeight - minHeight
        let midPoint = minHeight + (range / 2)
        
        delegate?.layout()
        if headerHeightConstraint > midPoint {
            makeTracksTableShorter()
            self.displayRatingsView()
        } else {
            makeTracksTableTaller()
        }
    }
    
    // MARK: - Party Control
    
    func updateTable() {
        DispatchQueue.main.async {
            self.refreshVisibleQueueSnapshot()
            self.tracksTableView.reloadData()
        }
    }
    
    func showAddButton() {
        DispatchQueue.main.async {
            self.addButton.isHidden = false
            self.editButton.isHidden = true
            self.comeOutOfEditingMode()
            UIView.animate(withDuration: 0.3, animations: { self.addButton.alpha = 1 })
        }
    }
    
    func hideAddButton() {
        UIView.animate(withDuration: 0.3, animations: { self.addButton.alpha = 0 }) { _ in
            self.addButton.isHidden = true
        }
    }
    
    func makeTracksTableTaller() {
        DispatchQueue.main.async {
            self.delegate?.layout()
            UIView.animate(withDuration: 0.4) {
                self.headerHeightConstraint = self.maxHeight
                self.changeFontSizeForUpNext()
                self.delegate?.layout()
            }
        }
    }
    
    func makeTracksTableShorter() {
        DispatchQueue.main.async {
            self.delegate?.layout()
            UIView.animate(withDuration: 0.4) {
                self.headerHeightConstraint = self.minHeight
                self.changeFontSizeForUpNext()
                self.delegate?.layout()
            }
        }
    }
    
    func displayRatingsView() {
        if #available(iOS 10.3, *),
            UserDefaults.standard.integer(forKey: "launchCount") > AppConstants.minimumLaunchesBeforeReview &&
                !Party.tracksQueue.isEmpty &&
                delegate!.connectedUsers > 0 {
//            SKStoreReviewController.requestReview()
        }
    }
    
}
