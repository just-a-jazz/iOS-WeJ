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

class MusicLibrarySelectionViewController: UIViewController, ViewControllerAccessDelegate {
    
    private weak var delegate: AddTracksTabBarController!

    @IBOutlet weak var headerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var myLibraryLabel: UILabel!
    @IBOutlet weak var doneButton: UIButton!
    private var badge: RKNotificationHub!
    
    private var totalTracksCount: Int {
        let controller = tabBarController! as! AddTracksTabBarController
        return controller.tracksSelected.count + controller.libraryTracksSelected.count
    }
    
    
    @IBOutlet weak var spotifyLibraryButton: UIButton!
    @IBOutlet weak var spotifyActivityIndicator: NVActivityIndicatorView!
    @IBOutlet weak var appleMusicLibraryButton: UIButton!

    private var libraryMusicService: MusicService!
    private var authorizationManager: AuthorizationManager!
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
    
    func setBadge(to count: Int) {
        badge.count = Int32(count)
        badge.pop()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        hideNavigationBar()
        initializeBadge()
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
    
    private func initializeBadge() {
        badge = RKNotificationHub(view: doneButton.titleLabel)
        badge.count = Int32(totalTracksCount)
        badge.moveCircleBy(x: CGFloat(Float(NSLocalizedString("DoneBadgeConstraint", comment: "")) ?? 51.0), y: 0)
        badge.scaleCircleSize(by: 0.7)
        badge.setCircleColor(AppConstants.orange, label: .white)
    }
    
    private func initializeVariables() {
        SpotifyAuthorizationManager.storyboardSegue = "Show Spotify Library"
        AppleMusicAuthorizationManager.storyboardSegue = "Show Apple Music Library"
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
        
        fetcher.getMostPlayed { [weak self] in
            self?.tracksList = self?.fetcher.tracksList ?? []
        }
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

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let controller = segue.destination as? PlaylistSelectionViewController {
            controller.musicService = libraryMusicService
        }
    }
    
}
