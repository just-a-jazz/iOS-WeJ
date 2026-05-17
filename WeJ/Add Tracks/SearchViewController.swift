//
//  SearchViewController.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 1/19/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import UIKit
import RKNotificationHub
import NVActivityIndicatorView

class SearchViewController: UIViewController, UITextFieldDelegate, SelectionCountBadgePresenting {
    
    private weak var delegate: AddTracksTabBarController!
    
    // MARK: - Storyboard Variables
    
    @IBOutlet weak var searchTracksField: searchTextField!
    @IBOutlet weak var doneButton: UIButton!
    var badge: RKNotificationHub!
    var totalTracksCount: Int {
        let controller = tabBarController! as! AddTracksTabBarController
        return controller.tracksSelected.count + controller.libraryTracksSelected.count
    }
    
    @IBOutlet weak var trackTableView: UITableView!
    
    // MARK: - General Variables
    var tracksList = [Track]() {
        didSet {
            DispatchQueue.main.async {
                self.trackTableView.reloadData()
                self.activityIndicator.stopAnimating()
                self.fetchArtworkForRestOfTracks()
            }
        }
    }
    private var fetcher: Fetcher!
    @IBOutlet weak var activityIndicator: NVActivityIndicatorView!
    @IBOutlet weak var noTracksFoundLabel: UILabel!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppConstants.darkerBlack
        view.isOpaque = true
        navigationController?.view.backgroundColor = AppConstants.darkerBlack
        setupSelectionCountBadge()
        initializeVariables()
        
        setDelegates()
        adjustViews()
        adjustFontSizes()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setBadge(to: totalTracksCount)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchTracksField.resignFirstResponder()
    }
    
    // MARK: - Functions
    
    private func initializeVariables() {
        delegate = tabBarController as? AddTracksTabBarController
    }
    
    private func setDelegates() {
        searchTracksField.delegate = self
        trackTableView.delegate    = delegate
        trackTableView.dataSource  = delegate
    }
    
    private func adjustViews() {
        navigationItem.hidesBackButton = true
        
        let placeholderText = NSLocalizedString("Search", comment: "") + " " + Party.musicService.toString()
        searchTracksField.attributedPlaceholder = NSAttributedString(string: placeholderText, attributes: [NSAttributedStringKey.foregroundColor: UIColor.lightGray])
        
        trackTableView.backgroundColor = AppConstants.darkerBlack
        trackTableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
    }
    
    private func adjustFontSizes() {
        if UIDevice.deviceType == .iPhone4_4s || UIDevice.deviceType == .iPhone5_5s_SE {
            searchTracksField.changeToSmallerFont()
            doneButton.changeToSmallerFont()
        }
    }
    
    func textFieldShouldReturn(_ searchSongsField: UITextField) -> Bool {
        searchTracksField.resignFirstResponder()
        searchTracksField.hideHintsTableView()
        if !searchTracksField.text!.isEmpty {
            trackTableView.isHidden = true
            fetchResults(forTerm: searchSongsField.text!)
        }
        return true
    }
    
    private func fetchResults(forTerm term: String) {
        fetcher = Party.musicService == .spotify ? SpotifyFetcher() : AppleMusicFetcher()
        activityIndicator.startAnimating()
        
        fetcher.searchCatalog(forTerm: term) { [weak self] in
            self?.populateTracksList()
            self?.showTableView()
            self?.scrollUp()
        }
    }
    
    private func populateTracksList() {
        tracksList = fetcher.tracksList
        DispatchQueue.main.async {
            if self.tracksList.isEmpty {
                self.displayNoTracksLabel()
            } else {
                self.removeNoTracksFoundLabel()
            }
        }
    }
    
    private func showTableView() {
        DispatchQueue.main.async {
            self.trackTableView.isHidden = false
        }
    }
    
    private func scrollUp() {
        DispatchQueue.main.async {
            if !self.tracksList.isEmpty {
                self.trackTableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
            }
        }
    }
    
    private func displayNoTracksLabel() {
        noTracksFoundLabel.isHidden = false
        UIView.animate(withDuration: 0.5) { [weak self] in
            self?.noTracksFoundLabel.alpha = 0.6
        }
    }
    
    private func removeNoTracksFoundLabel() {
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            self?.noTracksFoundLabel.alpha = 0
        }, completion: { [weak self] _ in
            self?.noTracksFoundLabel.isHidden = true
        })
    }
    
    private func fetchArtworkForRestOfTracks() {
        let tracksCaptured = tracksList
        for track in tracksList where tracksList == tracksCaptured && track.lowResArtwork == nil {
            DispatchQueue.global(qos: .userInitiated).async {
                track.fetchImage(fromURL: track.lowResArtworkURL) { [weak self, weak track] (image) in
                    track?.lowResArtwork = image
                    self?.trackTableView.reloadData()
                }
            }
        }
    }

}
