//
//  MusicLibrarySelectionViewController.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 8/9/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import UIKit
import RKNotificationHub
import NVActivityIndicatorView

class MusicLibrarySelectionViewController: UIViewController, ViewControllerAccessDelegate, SelectionCountBadgePresenting {
    
    private weak var delegate: AddTracksTabBarController!

    @IBOutlet weak var headerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var myLibraryLabel: UILabel!
    @IBOutlet weak var doneButton: UIButton!
    var badge: RKNotificationHub!
    var totalTracksCount: Int {
        let controller = tabBarController! as! AddTracksTabBarController
        return controller.tracksSelected.count + controller.libraryTracksSelected.count
    }
    
    
    @IBOutlet weak var spotifyLibraryButton: UIButton!
    @IBOutlet weak var spotifyActivityIndicator: NVActivityIndicatorView!
    @IBOutlet weak var appleMusicLibraryButton: UIButton!

    private var libraryMusicService: MusicService!
    private var authorizationManager: AuthorizationManager!
    private var isLoadingMostPlayed = false
    private var hasMoreMostPlayed = true
    private var mostPlayedOffset = 0
    private let mostPlayedPageSize = 50
    private let mostPlayedMaxTracks = 200
    var processingLogin = false {
        didSet {
            DispatchQueue.main.async {
                if self.processingLogin && self.libraryMusicService == .spotify {
                    self.spotifyActivityIndicator.startAnimating()
                } else if self.libraryMusicService == .spotify {
                    self.spotifyActivityIndicator.stopAnimating()
                }
            }
        }
    }
    
    @IBOutlet weak var playlistsButton: UIButton!
    @IBOutlet weak var tracksTableView: UITableView!
    @IBOutlet weak var playlistsActivityIndicator: NVActivityIndicatorView!
    private let fetcher: Fetcher = Party.musicService == .spotify ? SpotifyFetcher() : AppleMusicFetcher()
    var tracksList = [Track]() {
        didSet {
            DispatchQueue.main.async {
                self.tracksTableView.reloadData()
                self.playlistsActivityIndicator.stopAnimating()
                self.fetchArtworkForRestOfTracks()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppConstants.darkerBlack
        view.isOpaque = true
        navigationController?.view.backgroundColor = AppConstants.darkerBlack
        hideNavigationBar()
        setupSelectionCountBadge()
        initializeVariables()
        
        setDelegates()
        adjustViews()
        adjustFontSizes()
        
        getTrending()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setBadge(to: totalTracksCount)
    }
    
    private func hideNavigationBar() {
        navigationController?.navigationBar.isHidden = true
    }
    
    private func initializeVariables() {
        SpotifyAuthorizationManager.storyboardSegue = "Show Spotify Library"
        AppleMusicAuthorizationManager.storyboardSegue = "Show Apple Music Library"
        configureMostPlayedConstraints()
    }
    
    private func setDelegates() {
        delegate = (navigationController?.tabBarController! as! AddTracksTabBarController)
        
        SpotifyAuthorizationManager.delegate = self
        AppleMusicAuthorizationManager.delegate = self
        tracksTableView.delegate = delegate
        tracksTableView.dataSource = delegate
    }
    
    private func adjustViews() {
        tracksTableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        tracksTableView.backgroundColor = AppConstants.darkerBlack
    }

    private var mostPlayedTopConstraint: NSLayoutConstraint?
    private var doneButtonTopConstraint: NSLayoutConstraint?

    private func configureMostPlayedConstraints() {
        mostPlayedTopConstraint = view.constraints.first {
            ($0.firstItem as? UIButton) == playlistsButton && $0.firstAttribute == .top
        }
        doneButtonTopConstraint = view.constraints.first {
            ($0.firstItem as? UIButton) == doneButton && $0.firstAttribute == .top
        }
        doneButtonTopConstraint?.priority = .required
    }
    
    private func adjustFontSizes() {
        if UIDevice.deviceType == .iPhone4_4s || UIDevice.deviceType == .iPhone5_5s_SE {
            myLibraryLabel.changeToSmallerFont()
            doneButton.changeToSmallerFont()
            spotifyLibraryButton.changeToSmallerFont()
            appleMusicLibraryButton.changeToSmallerFont()
            playlistsButton.changeToSmallerFont()
        }
    }
    
    private func getTrending() {
        playlistsActivityIndicator.startAnimating()
        loadMostPlayed(reset: true)
    }
    
    private func fetchArtworkForRestOfTracks() {
        let tracksCaptured = tracksList
        for track in tracksList where tracksList == tracksCaptured && track.lowResArtwork == nil {
            DispatchQueue.global(qos: .userInitiated).async {
                track.fetchImage(fromURL: track.lowResArtworkURL) { [weak self, weak track] (image) in
                    track?.lowResArtwork = image
                    self?.tracksTableView.reloadData()
                }
            }
        }
    }
    
    func loadMoreMostPlayedIfNeeded() {
        guard libraryMusicService == .spotify else { return }
        guard !isLoadingMostPlayed, hasMoreMostPlayed else { return }
        loadMostPlayed(reset: false)
    }
    
    private func loadMostPlayed(reset: Bool) {
        if libraryMusicService == .spotify {
            loadSpotifyMostPlayed(reset: reset)
        } else {
            loadAppleMusicMostPlayed()
        }
    }

    private func loadAppleMusicMostPlayed() {
        isLoadingMostPlayed = true
        fetcher.getMostPlayed { [weak self] in
            guard let self = self else { return }
            self.tracksList = self.fetcher.tracksList
            self.isLoadingMostPlayed = false
        }
    }
    
    private func loadSpotifyMostPlayed(reset: Bool) {
        guard let fetcher = fetcher as? SpotifyFetcher else { return }
        if reset {
            fetcher.tracksList.removeAll()
            tracksList.removeAll()
            mostPlayedOffset = 0
            hasMoreMostPlayed = true
        }
        
        guard hasMoreMostPlayed, tracksList.count < mostPlayedMaxTracks else { return }
        
        isLoadingMostPlayed = true
        let remaining = mostPlayedMaxTracks - tracksList.count
        let limit = min(mostPlayedPageSize, remaining)
        
        fetcher.getMostPlayed(atOffset: mostPlayedOffset, limit: limit) { [weak self] newCount in
            guard let self = self else { return }
            self.mostPlayedOffset += newCount
            self.hasMoreMostPlayed = newCount == limit
            self.tracksList = fetcher.tracksList
            self.isLoadingMostPlayed = false
        }
    }

    // MARK: - Navigation 
    
    @IBAction func showSpotifyLibrary() {
        guard !processingLogin else { return }
        authorizationManager = SpotifyAuthorizationManager.shared
        libraryMusicService = .spotify
        authorizationManager.requestAuthorization()
    }
    
    @IBAction func showAppleMusicLibrary() {
        guard !processingLogin else { return }
        authorizationManager = AppleMusicAuthorizationManager()
        libraryMusicService = .appleMusic
        authorizationManager.requestAuthorization()
    }
    
    func tryAgain() {
        if libraryMusicService == .spotify {
            showSpotifyLibrary()
        } else {
            showAppleMusicLibrary()
        }
    }
    
    func completeAuthorization(withSegueIdentifier identifier: String) {
        guard identifier == "Show Spotify Library" || identifier == "Show Apple Music Library" else {
            performSegue(withIdentifier: identifier, sender: nil)
            return
        }
        
        guard let controller = storyboard?.instantiateViewController(withIdentifier: "PlaylistSelection") as? PlaylistSelectionViewController else {
            performSegue(withIdentifier: identifier, sender: nil)
            return
        }
        
        controller.musicService = libraryMusicService
        navigationController?.pushViewController(controller, animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let controller = segue.destination as? PlaylistSelectionViewController {
            controller.musicService = libraryMusicService
        }
    }
    
}
