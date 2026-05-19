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

class MusicLibrarySelectionViewController: UIViewController, ViewControllerAccessDelegate, SelectionCountBadgePresenting, UIGestureRecognizerDelegate {
    
    private weak var delegate: AddTracksTabBarController!
    private var topAreaPanGestureRecognizer: UIPanGestureRecognizer!
    private var isTopAreaPanActive = false

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
    private enum LibraryDestination {
        case albums
        case artists
        case playlists
        case allSongs
    }

    private var authorizationManager: AuthorizationManager!
    private var libraryDestination: LibraryDestination?
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
        view.backgroundColor = AppConstants.black
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
        AppleMusicAuthorizationManager.storyboardSegue = "Show Apple Music Library"
        libraryMusicService = .appleMusic
        configureMostPlayedConstraints()
    }

    
    private func setDelegates() {
        delegate = (navigationController?.tabBarController! as! AddTracksTabBarController)

        topAreaPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleTopAreaPanGesture(_:)))
        topAreaPanGestureRecognizer.delegate = self
        view.addGestureRecognizer(topAreaPanGestureRecognizer)

        AppleMusicAuthorizationManager.delegate = self
        tracksTableView.delegate = delegate
        tracksTableView.dataSource = delegate
    }
    
    private func adjustViews() {
        tracksTableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        tracksTableView.backgroundColor = .clear
        configureLibraryButtons()
    }

    private func configureLibraryButtons() {
        let buttons = [spotifyLibraryButton, appleMusicLibraryButton] + libraryButtonsFromStackView()
        let iconNames = ["albumsIcon", "artistsIcon", "playlistsIcon", "allSongsIcon"]
        let highlightedIconNames = ["albumsIconHighlighted", "artistsIconHighlighted", "playlistsIconHighlighted", "allSongsIconHighlighted"]

        let scale: CGFloat = 0.9
        let normalIcons = iconNames.compactMap { UIImage(named: $0) }
        let maxIconWidth = (normalIcons.map { $0.size.width }.max() ?? 0) * scale
        let gap: CGFloat = 12

        for (index, button) in buttons.enumerated() where index < iconNames.count {
            guard let button else { continue }
            let normalIcon = paddedIcon(named: iconNames[index], toWidth: maxIconWidth, scale: scale)
            let highlightedIcon = paddedIcon(named: highlightedIconNames[index], toWidth: maxIconWidth, scale: scale)

            button.setImage(normalIcon, for: .normal)
            button.setImage(highlightedIcon, for: .highlighted)
            button.contentHorizontalAlignment = .left
            button.semanticContentAttribute = .forceLeftToRight
            button.tintColor = .white
            if let font = button.titleLabel?.font {
                button.titleLabel?.font = font.withSize(font.pointSize * scale)
            }
            button.titleLabel?.lineBreakMode = .byClipping
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.75
            var configuration = button.configuration ?? .plain()
            configuration.contentInsets = .zero
            configuration.imagePadding = gap
            button.configuration = configuration
        }
    }

    private func paddedIcon(named name: String, toWidth width: CGFloat, scale: CGFloat) -> UIImage? {
        guard let image = UIImage(named: name) else { return nil }
        let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let paddedSize = CGSize(width: width, height: scaledSize.height)

        UIGraphicsBeginImageContextWithOptions(paddedSize, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: scaledSize))
        let paddedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return paddedImage
    }

    private func libraryButtonsFromStackView() -> [UIButton] {
        guard let stackView = spotifyLibraryButton.superview as? UIStackView else { return [] }
        return stackView.arrangedSubviews.compactMap { $0 as? UIButton }.filter { $0 != spotifyLibraryButton && $0 != appleMusicLibraryButton }
    }

    @objc private func handleTopAreaPanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            isTopAreaPanActive = true
            delegate.beginManualHeaderAdjustment()
        case .changed:
            guard isTopAreaPanActive else { return }
            let translationY = gestureRecognizer.translation(in: view).y
            delegate.updateManualHeaderAdjustment(translationY: translationY)
        case .ended, .cancelled, .failed:
            guard isTopAreaPanActive else { return }
            isTopAreaPanActive = false
            delegate.endManualHeaderAdjustment()
        default:
            break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === topAreaPanGestureRecognizer else { return true }
        let location = gestureRecognizer.location(in: view)
        return location.y < tracksTableView.frame.minY
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

    @IBAction func showLibraryAlbums() {
        requestLibraryAuthorization(for: .albums)
    }

    @IBAction func showLibraryArtists() {
        requestLibraryAuthorization(for: .artists)
    }

    @IBAction func showLibraryPlaylists() {
        requestLibraryAuthorization(for: .playlists)
    }

    @IBAction func showLibraryAllSongs() {
        requestLibraryAuthorization(for: .allSongs)
    }

    private func requestLibraryAuthorization(for destination: LibraryDestination) {
        guard !processingLogin else { return }
        libraryDestination = destination
        authorizationManager = AppleMusicAuthorizationManager()
        libraryMusicService = .appleMusic
        authorizationManager.requestAuthorization()
    }

    func tryAgain() {
        if let destination = libraryDestination {
            requestLibraryAuthorization(for: destination)
        }
    }

    func completeAuthorization(withSegueIdentifier identifier: String) {
        guard identifier == "Show Apple Music Library" else { return }

        switch libraryDestination {
        case .albums:
            showLibrarySubcategory(.albums)
        case .artists:
            showLibrarySubcategory(.artists)
        case .playlists:
            showLibrarySubcategory(.playlists)
        case .allSongs:
            showAllSongs()
        case .none:
            break
        }
    }

    private func showLibrarySubcategory(_ playlistType: PlaylistType) {
        guard let controller = storyboard?.instantiateViewController(withIdentifier: "57W-ks-AM8") as? PlaylistSubcategorySelectionViewController else { return }
        controller.musicService = .appleMusic
        controller.playlistType = playlistType
        navigationController?.pushViewController(controller, animated: true)
    }

    private func showAllSongs() {
        guard let controller = storyboard?.instantiateViewController(withIdentifier: "9L9-Hk-w7d") as? LibraryTracksViewController else { return }
        controller.musicService = .appleMusic
        controller.playlistType = .all
        controller.playlistName = NSLocalizedString("All Songs", comment: "")
        navigationController?.pushViewController(controller, animated: true)
    }
    
}
