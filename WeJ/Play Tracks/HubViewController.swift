//
//  LyricsViewController.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 3/15/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import UIKit

class HubViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    weak var delegate: PartyViewControllerInfoDelegate?
    weak var tracksTableModifierDelegate: TracksTableModifierDelegate?
    
    fileprivate var minHeight: CGFloat {
        return HubAndQueuePageViewController.minHeight
    }
    fileprivate var maxHeight: CGFloat {
        return HubAndQueuePageViewController.maxHeight
    }
    fileprivate var previousScrollOffset: CGFloat = 0
    
    @IBOutlet weak var hubTitle: UILabel?
    private let hubOptions = [NSLocalizedString("View Lyrics", comment: ""), NSLocalizedString("Leave Party", comment: "")]
    private let hubIcons = [#imageLiteral(resourceName: "lyricsIcon"), #imageLiteral(resourceName: "leavePartyIcon")]
    @IBOutlet weak var hubTableView: UITableView!
    @IBOutlet weak var hubLabel: UILabel!
    private var hubTitleSeparator: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setDelegates()
        adjustViews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        changeFontSizeForHub()
    }
    
    private func setDelegates() {
        hubTableView.delegate = self
        hubTableView.dataSource = self
    }
    
    func adjustViews() {
        updateHubTitle()
        hubTableView.tableFooterView = UIView()
        addHubTitleSeparatorIfNeeded()
    }

    private func addHubTitleSeparatorIfNeeded() {
        guard hubTitleSeparator == nil, let titleLabel = hubTitle else { return }

        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        view.addSubview(separator)

        let guide = view.safeAreaLayoutGuide
        let horizontalInset: CGFloat = 20

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            separator.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: horizontalInset),
            separator.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -horizontalInset),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])

        hubTitleSeparator = separator
    }
    
    // MARK: - Table
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return hubOptions.count
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = .zero
        cell.layoutMargins = .zero
        cell.backgroundColor = .clear
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Hub Cell") as! HubTableViewCell
        
        cell.hubLabel.text = hubOptions[indexPath.row]
        cell.iconView?.image = hubIcons[indexPath.row]
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if hubOptions[indexPath.row] == NSLocalizedString("Leave Party", comment: "") {
            leaveParty()
        } else if let position = delegate?.currentTrackPosition, let currentTrack = Party.tracksQueue.first {
            MXMLyricsAction.sharedExtension().findLyricsForSong(
                withTitle: currentTrack.name,
                artist: currentTrack.artist,
                album: "",
                artWork: currentTrack.highResArtwork,
                currentProgress: position,
                trackDuration: currentTrack.length ?? 0,
                for: self,
                sender: tableView.cellForRow(at: indexPath) ?? tableView,
                competionHandler: nil)
        } else {
            postAlertForNoTracks()
        }
    }
    
    private func postAlertForNoTracks() {
        let alert = UIAlertController(title: NSLocalizedString("No Track Playing", comment: ""), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
        
        present(alert, animated: true)
    }
    
    // MARK: = Navigation
    
    private func leaveParty() {
        let _ = navigationController?.popToRootViewController(animated: true)
    }
    
}

extension HubViewController {
    
    private var headerHeightConstraint: CGFloat {
        get {
            return delegate!.tableHeight
        }
        
        set {
            delegate?.tableHeight = newValue
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
                changeFontSizeForHub()
                setScrollPosition(forOffset: previousScrollOffset)
            }
            
        } else if isScrollingUp {
            newHeight = min(minHeight, headerHeightConstraint + abs(scrollDiff))
            if newHeight != headerHeightConstraint && hubTableView.contentOffset.y < 2 {
                headerHeightConstraint = newHeight
                changeFontSizeForHub()
                setScrollPosition(forOffset: previousScrollOffset)
            }
        }
        
        
        previousScrollOffset = scrollView.contentOffset.y
    }
    
    fileprivate func changeFontSizeForHub() {
        UIView.animate(withDuration: 0.3) {
            self.hubLabel.font = self.hubLabel.font.withSize(20 - UILabel.smallerTitleFontSize * (self.headerHeightConstraint / self.minHeight))
        }
    }
    
    private func setScrollPosition(forOffset offset: CGFloat) {
        hubTableView.contentOffset = CGPoint(x: hubTableView.contentOffset.x, y: offset)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollViewDidStopScrolling()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            scrollViewDidStopScrolling()
        }
    }
    
    private func scrollViewDidStopScrolling() {
        let range = maxHeight - minHeight
        let midPoint = minHeight + (range / 2)
        
        delegate?.layout()
        if headerHeightConstraint > midPoint {
            tracksTableModifierDelegate?.showAddButton()
            makeTracksTableShorter()
        } else {
            makeTracksTableTaller()
        }
    }
    
    func makeTracksTableShorter() {
        DispatchQueue.main.async {
            self.delegate?.layout()
            UIView.animate(withDuration: 0.2, animations: {
                self.headerHeightConstraint = self.minHeight
                self.changeFontSizeForHub()
                self.delegate?.layout()
            })
        }
    }
    
    func makeTracksTableTaller() {
        DispatchQueue.main.async {
            self.delegate?.layout()
            UIView.animate(withDuration: 0.2, animations: {
                self.headerHeightConstraint = self.maxHeight
                self.changeFontSizeForHub()
                self.delegate?.layout()
            })
        }
    }
    
    func updateHubTitle() {
        DispatchQueue.main.async {
            self.hubTitle?.text = Party.name ?? NSLocalizedString("Party", comment: "")
        }
    }
    
}
