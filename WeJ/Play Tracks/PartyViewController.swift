//
//  PartyViewController.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 1/19/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import UIKit
import MediaPlayer
import MultipeerConnectivity

protocol MusicPlayerDelegate: class {
    func alertPreviousiOSVersionUsers()
}

protocol UpdatePartyDelegate: class {
    var hubAndQueueVC: HubAndQueuePageViewController? { get }
    func updateCache()
    func updateEveryonesTableView()
    func showCurrentlyPlayingArtwork()
}

protocol NetworkManagerDelegate: class {
    var connectionStatus: MCSessionState { get }
    func resetManager()
    func updateStatus(withState state: MCSessionState)
    func setup(withParty party: Party)
    func add(tracksReceived: [Track])
    func remove(track: Track)
    func update(usingPosition position: TimeInterval)
}

protocol PartyViewControllerInfoDelegate: class {
    var isHost: Bool { get }
    var connectedUsers: Int { get }
    var currentTrackPosition: TimeInterval? { get }
    var personalQueue: Set<Track> { get }
    func sendTracksToPeers(forTracks: [Track], toRemove: Bool)
    var tableHeight: CGFloat { get set }
    func layout()
}

class PartyViewController: UIViewController, MusicPlayerDelegate, UpdatePartyDelegate, NetworkManagerDelegate, PartyViewControllerInfoDelegate {
    
    // MARK: - Storyboard Variables
    
    // Currently Playing
    @IBOutlet weak var currentlyPlayingArtwork: UIImageView!
    @IBOutlet weak var currentlyPlayingTrackName: UILabel!
    @IBOutlet weak var currentlyPlayingArtistName: UILabel!
    @IBOutlet weak var currentlyPlayingStackViewConstraint: NSLayoutConstraint!

    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var skipTrackButton: UIButton!
    
    // Tracks Queue
    @IBOutlet weak var tableHeightConstraint: NSLayoutConstraint!
    var hubAndQueueVC: HubAndQueuePageViewController? {
        return childViewControllers.first{ $0 is HubAndQueuePageViewController } as? HubAndQueuePageViewController
    }
    
    // Connection Status
    @IBOutlet weak var alertLabelConstraint: NSLayoutConstraint!
    @IBOutlet weak var alertViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var statusIndicatorView: UIView!
    @IBOutlet weak var alertLabel: UILabel!
    @IBOutlet weak var reconnectButton: UIButton!
    @IBOutlet weak var resendButton: UIButton!
    
    var connectionStatus: MCSessionState = .notConnected {
        willSet {
            showConnectionRelatedViewsOnAlert()
            alertLabel.text = newValue.stringValue
            displayAlert()
            
            if newValue == .connected {
                changeStatusIndicatorView(toColor: AppConstants.green)
                hideAlert { [weak self] _ in self?.showFailedTracks() }
            } else if newValue == .connecting {
                changeStatusIndicatorView(toColor: AppConstants.orange)
            } else {
                changeStatusIndicatorView(toColor: AppConstants.red)
                hubAndQueueVC?.hideAddButton()
            }
        }
    }
    
    @IBAction func reconnectToParty() {
        resetManager()
    }
    
    // MARK: - General Variables
    
    lazy var networkManager: MultipeerManager? = { [unowned self] in
        let manager = MultipeerManager(isHost: self.isHost, partyName: self.isHost ? Party.name! : NSLocalizedString("Party", comment: ""))
        manager.delegate = self
        return manager
    }()
    var fetcher: Fetcher!
    
    private var musicPlayer = MusicPlayer()
    private var currentPositionFromHost: TimeInterval?
    var isHost = true
    var personalQueue = Set<Track>()
    var cache = [String: Track]()
    private var lastQueueAdvanceAt: Date?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        adjustViews()
        adjustFontSizes()
        
        if isHost {
            initializeMusicPlayer()
        } else {
            initializeStatusIndicatorView()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    deinit {
        Party.reset()
        
        if isHost {
            musicPlayer.exitPlayer()
        }
    }
    
    // MARK: - General Functions
    
    private func adjustViews() {
        hideCurrentlyPlayingArtwork()
        if !isHost {
            currentlyPlayingStackViewConstraint.constant -= 55
            playPauseButton.isHidden = true
            skipTrackButton.isHidden = true
            updateStatus(withState: .notConnected)
        }
    }
    
    private func adjustFontSizes() {
        if UIDevice.deviceType == .iPhone4_4s || UIDevice.deviceType == .iPhone5_5s_SE {
            currentlyPlayingTrackName.changeToSmallerFont()
            currentlyPlayingArtistName.changeToSmallerFont()
            alertLabel.changeToSmallerFont()
            reconnectButton.changeToSmallerFont()
            resendButton.changeToSmallerFont()
        }
    }
    
    private func initializeMusicPlayer() {
        musicPlayer.delegate = self
        setTimer()
        initializeCommandCenter()
        setupControlEvents()
        musicPlayer.preparePlayer()
    }
    
    private func initializeStatusIndicatorView() {
        statusIndicatorView.layer.cornerRadius = statusIndicatorView.frame.size.width / 2
        statusIndicatorView.clipsToBounds = true
    }
    
    private func setTimer() {
        let _ = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateProgress()
            self?.skipToNextSongIfRequired()
            
            if Party.musicService == .spotify {
                self?.updateControlCenter()
            }
        }
    }
    
    private func updateProgress() {
        if !Party.tracksQueue.isEmpty {
            if let position = musicPlayer.currentPosition {
                networkManager?.advertise(position: position)
            }
            if musicPlayer.isPaused && Party.musicService == .appleMusic {
                changeToPlayButton(animated: false)
                BackgroundTask.stopBackgroundTask()
            } else if Party.musicService == .appleMusic {
                changeToPauseButton(animated: false)
                BackgroundTask.startBackgroundTask()
            } else if Party.musicService == .spotify {
                if musicPlayer.isPaused {
                    changeToPlayButton(animated: false)
                } else {
                    changeToPauseButton(animated: false)
                }
                syncSpotifyQueueIfNeeded()
            }
        }
        networkManager?.advertise()
    }

    private func syncSpotifyQueueIfNeeded() {
        guard isHost,
              !Party.tracksQueue.isEmpty,
              let currentURI = musicPlayer.currentTrackURI else {
            return
        }
        
        // Prevent double-advance when a manual skip triggers a near-immediate sync.
        if let lastAdvance = lastQueueAdvanceAt,
           Date.now.timeIntervalSince(lastAdvance) < 1.0 {
            return
        }

        let expectedURI = "spotify:track:" + Party.tracksQueue[0].id
        if currentURI != expectedURI {
            playNextTrack(force: true)
        }
    }
    
    // This method is made to change Apple Music songs when it ends since playbackState (when the song ends) isn't consistent across iOS versions
    private func skipToNextSongIfRequired() {
        guard !Party.tracksQueue.isEmpty,
              Party.musicService == .appleMusic,
              let trackLength = Party.tracksQueue[0].length,
              let position = musicPlayer.currentPosition else {
            return
        }
        
        if trackLength - position <= 1 {
            playNextTrack(force: true)
        }
    }
    
    private func initializeCommandCenter() {
        MPRemoteCommandCenter.shared().pauseCommand.isEnabled = true
        MPRemoteCommandCenter.shared().playCommand.isEnabled = true
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled = true
        MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = true
    }
    
    private func setupControlEvents() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        MPRemoteCommandCenter.shared().pauseCommand.addTarget { [weak self]  _-> MPRemoteCommandHandlerStatus in
            self?.musicPlayer.pauseTrack()
            return .success
        }
        
        MPRemoteCommandCenter.shared().playCommand.addTarget { [weak self]  _ -> MPRemoteCommandHandlerStatus in
            self?.musicPlayer.playTrack()
            return .success
        }
        
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            self?.musicPlayer.isScrubbing = true
            self?.musicPlayer.scrubTrack(toPosition: (event as! MPChangePlaybackPositionCommandEvent).positionTime) { _ in
                self?.musicPlayer.isScrubbing = false
            }
            return .success
        }
        
        MPRemoteCommandCenter.shared().nextTrackCommand.addTarget { [weak self] _ -> MPRemoteCommandHandlerStatus in
            self?.skipTrack()
            return .success
        }
    }
    
    private func updateControlCenter() {
        guard !musicPlayer.isScrubbing else { return }
        DispatchQueue.main.async { [weak self] in
            guard !Party.tracksQueue.isEmpty else { return }
            guard let image = Party.tracksQueue[0].highResArtwork else { return }
            guard let length = Party.tracksQueue[0].length else { return }
            guard let currentPosition = self?.currentTrackPosition else { return }
            
            let artwork = MPMediaItemArtwork.init(boundsSize: image.size) { _ in return image }
            let trackInfo: [String: Any] = [MPMediaItemPropertyTitle: Party.tracksQueue[0].name,
                                            MPMediaItemPropertyArtist: Party.tracksQueue[0].artist,
                                            MPMediaItemPropertyPlaybackDuration : Double(length),
                                            MPNowPlayingInfoPropertyElapsedPlaybackTime: String(currentPosition),
                                            MPMediaItemPropertyArtwork: artwork]
            MPNowPlayingInfoCenter.default().nowPlayingInfo = trackInfo
        }
    }
    
    // MARK: - UpdatePartyDelegate
    
    func updateCache() {
        cache.removeAll()
        for track in Party.tracksQueue {
            cache[track.id] = track
        }
    }
    
    func updateEveryonesTableView() {
        // Update own table view
        hubAndQueueVC?.updateTable()
        fetchArtwork(forHighRes: false)
        fetchArtwork(forHighRes: true)
        updateCurrentlyPlayingTrack()
        
        // Update peers tableview
        if isHost {
            sendTracksToPeers(forTracks: Party.tracksQueue)
        } else {
            sendTracksToPeers(forTracks: Party.tracksFromMyself)
            Party.tracksFromMyself.removeAll()
            updatePersonalQueue()
        }
    }
    
    private func fetchArtwork(forHighRes: Bool) {
        let latestTracks = Party.tracksQueue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for (i, track) in Party.tracksQueue.enumerated() where latestTracks == Party.tracksQueue {
                if forHighRes && track.highResArtwork == nil && i < 15 {
                    self?.fetchHighResArtwork(forTrack: track)
                } else if !forHighRes && track.lowResArtwork == nil {
                    self?.fetchLowResArtwork(forTrack: track)
                }
            }
        }
    }
    
    private func fetchHighResArtwork(forTrack track: Track) {
        track.fetchImage(fromURL: track.highResArtworkURL) { [weak self, weak track] (image) in
            track?.highResArtwork = image
            if !Party.tracksQueue.isEmpty && track == Party.tracksQueue[0] {
                self?.currentlyPlayingArtwork.image = track?.highResArtwork?.addGradient()
            }
        }
    }

    private func fetchLowResArtwork(forTrack track: Track) {
        track.fetchImage(fromURL: track.lowResArtworkURL) { [weak self, weak track] (image) in
            track?.lowResArtwork = image
            self?.hubAndQueueVC?.updateTable()
        }
    }
    
    private func updateCurrentlyPlayingTrack() {
        DispatchQueue.main.async {
            if !Party.tracksQueue.isEmpty {
                self.currentlyPlayingArtwork.image = Party.tracksQueue[0].highResArtwork?.addGradient()
                self.currentlyPlayingTrackName.text = Party.tracksQueue[0].name
                self.currentlyPlayingArtistName.text = Party.tracksQueue[0].artist
            } else {
                self.hideCurrentlyPlayingArtwork()
            }
        }
    }
    
    func showCurrentlyPlayingArtwork() {
        DispatchQueue.main.async {
            self.currentlyPlayingArtwork.isHidden = false
            self.currentlyPlayingTrackName.isHidden = false
            self.currentlyPlayingArtistName.isHidden = false
            if self.isHost {
                self.playPauseButton.isHidden = false
                self.skipTrackButton.isHidden = false
            }
        }
    }
    
    private func hideCurrentlyPlayingArtwork() {
        DispatchQueue.main.async {
            self.currentlyPlayingArtwork.isHidden = true
            self.currentlyPlayingArtwork.image = nil
            self.currentlyPlayingTrackName.isHidden = true
            self.currentlyPlayingArtistName.isHidden = true
            self.playPauseButton.isHidden = true
            self.skipTrackButton.isHidden = true
            self.hubAndQueueVC?.expandTracksTable()
        }
    }
    
    // Handles addition and removal of tracks
    func sendTracksToPeers(forTracks tracks: [Track], toRemove isRemoval: Bool = false) {
        let tracks = removeImages(fromTracks: tracks)
        if isHost || (!isHost && !tracks.isEmpty) {
            if isRemoval {
                let tracks = modifyTracksToRemove(usingTracks: tracks)
                networkManager?.send(tracks: tracks, toRemove: isRemoval)
            } else {
                networkManager?.send(tracks: tracks, toRemove: isRemoval)
            }
        }
    }
    
    private func removeImages(fromTracks tracks: [Track]) -> [Track] {
        return tracks.map { track in
            let newTrack = track.copy() as! Track
            if !newTrack.isFromLibrary {
                newTrack.lowResArtwork = nil
                newTrack.highResArtwork = nil
            }
            return newTrack
        }
    }
    
    private func modifyTracksToRemove(usingTracks tracks: [Track]) -> [Track] {
        for track in tracks {
            track.id = "R:" + track.id
        }
        return tracks
    }
    
    private func updatePersonalQueue() {
        for track in personalQueue where !Party.tracksQueue.contains(where: { $0.id == track.id }) {
            personalQueue.remove(at: personalQueue.index(of: track)!)
        }
    }
    
    func add(tracksReceived: [Track]) {
        if isHost {
            let tracksReceived = tracksReceived.filter { !Party.tracksQueue(hasTrack: $0) }
            Party.tracksQueue.append(contentsOf: getCacheOptimizedTracks(fromTracks: tracksReceived))
            if Party.tracksQueue.count == tracksReceived.count {
                musicPlayer.startPlayer()
            }
        } else {
            Party.tracksQueue = getCacheOptimizedTracks(fromTracks: tracksReceived)
        }
    }
    
    private func getCacheOptimizedTracks(fromTracks tracks: [Track]) -> [Track] {
        var optimizedTracks = [Track]()
        for track in tracks {
            optimizedTracks.append(cache[track.id] ?? track)
        }
        return optimizedTracks
    }
    
    func remove(track: Track) {
        let id = track.id.components(separatedBy: ":")[1]
        
        if let i = Party.tracksQueue.index(where: { $0.id == id }) {
            Party.tracksQueue.remove(at: i)
        }
    }
    
    // MARK: - Storyboard Functions
    
    @IBAction func playPauseChange(_ sender: UIButton) {
        if musicPlayer.isPaused {
            changeToPauseButton(animated: true)
            musicPlayer.playTrack()
        } else {
            changeToPlayButton(animated: true)
            musicPlayer.pauseTrack()
        }
    }
    
    private func changeToPlayButton(animated: Bool) {
        let setImage: () -> Void = { [weak self] in
            self?.playPauseButton.setImage(#imageLiteral(resourceName: "playIcon"), for: .normal)
            self?.playPauseButton.setImage(#imageLiteral(resourceName: "playIconHighlighted"), for: .highlighted)
        }
        
        if animated {
            UIView.animate(withDuration: 0.1, animations: {
                self.playPauseButton.alpha = 0.0
            }, completion: { _ in
                setImage()
                UIView.animate(withDuration: 0.25) {
                    self.playPauseButton.alpha = 1
                }
            })
        } else {
            setImage()
        }
    }
    
    private func changeToPauseButton(animated: Bool) {
        let setImage: () -> Void = { [weak self] in
            self?.playPauseButton.setImage(#imageLiteral(resourceName: "pauseIcon"), for: .normal)
            self?.playPauseButton.setImage(#imageLiteral(resourceName: "pauseIconHighlighted"), for: .highlighted)
        }
        
        if animated {
            UIView.animate(withDuration: 0.1, animations: {
                self.playPauseButton.alpha = 0.0
            }, completion: { _ in
                setImage()
                UIView.animate(withDuration: 0.25) {
                    self.playPauseButton.alpha = 1
                }
            })
        } else {
            setImage()
        }
    }
    
    @IBAction func skipTrack() {
        if !Party.tracksQueue.isEmpty {
            sendTracksToPeers(forTracks: [Party.tracksQueue.removeFirst()], toRemove: true)
            musicPlayer.startPlayer()
            lastQueueAdvanceAt = Date.now
        }
    }
    
    // MARK: - Callbacks
    
    @objc private func playNextTrack(force: Bool = false) {
        if musicPlayer.isSafeToPlayNextTrack || force {
            sendTracksToPeers(forTracks: [Party.tracksQueue.removeFirst()], toRemove: true)
            musicPlayer.startPlayer()
            lastQueueAdvanceAt = Date.now
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Show Lyrics and Queue" {
            if let controller = segue.destination as? HubAndQueuePageViewController {
                controller.partyDelegate = self
            }
        }
    }
    
    @IBAction func unwindToPartyViewController(_ sender: UIStoryboardSegue) {
        if let controller = sender.source.tabBarController as? AddTracksTabBarController {
            fetcher = (Party.musicService == .spotify) ? SpotifyFetcher() : AppleMusicFetcher()
            fetcher.convert(libraryTracks: controller.libraryTracksSelected, trackHandler: { [weak self] (track) in
                self?.updateQueues(withTracks: [track])
            }, errorHandler: { [weak self] (tracksNotFoundCount) in
                self?.alertUser(forTracksCount: tracksNotFoundCount)
            })
            updateQueues(withTracks: controller.tracksSelected)
        }
    }
    
    private func updateQueues(withTracks tracks: [Track]) {
        Party.tracksFromMyself.append(contentsOf: tracks)
        personalQueue = personalQueue.union(Set(tracks))
        Party.tracksQueue.append(contentsOf: tracks)
        
        if Party.tracksQueue.count == tracks.count && isHost {
            musicPlayer.startPlayer()
        }
    }
    
    private func alertUser(forTracksCount count: Int) {
        guard count > 0 else { return }
        
        hideConnectionRelatedViewsOnAlert()
        resendButton.isHidden = true
        
        alertLabel.text = String(count) + " " + (count > 1 ? NSLocalizedString("library songs not found", comment: "") : NSLocalizedString("library song not found", comment: ""))
        displayAlert()
        let _ = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            self?.hideAlert()
        }
    }
    
    func showFailedTracks() {
        let count = MultipeerManager.tracksFailedToSend.count
        guard count > 0 else { return }
        
        hideConnectionRelatedViewsOnAlert()
        resendButton.isHidden = false
        alertLabel.text = String(count) + " " + (count > 1 ? NSLocalizedString("requests failed to send", comment: "") : NSLocalizedString("request failed to send", comment: ""))
        displayAlert()
        
        let _ = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self] _ in
            if self != nil && self!.connectionStatus == .connected {
                self?.hideAlert()
            }
        }
    }
    
    @IBAction func resendTracks() {
        hideAlert()
        networkManager?.send(tracks: MultipeerManager.tracksFailedToSend)
    }
    
    // MARK: MusicPlayerDelegate
    
    func alertPreviousiOSVersionUsers() {
        let errorShown = UserDefaults.standard.bool(forKey: "iOSErrorShown")
        guard errorShown == false else { return }
        
        let os = ProcessInfo().operatingSystemVersion
        switch (os.majorVersion, os.minorVersion, os.patchVersion) {
        case (11, 0, _):
            fallthrough
        case (11, 1, _):
            fallthrough
        case (11, 2, _):
            self.postAlertForiOSVersion()
        default:
            break
        }
    }
    
    private func postAlertForiOSVersion() {
        UserDefaults.standard.set(true, forKey:"iOSErrorShown")
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: NSLocalizedString("Incompatible iOS Version", comment: ""), message: NSLocalizedString("Your version of iOS may have problems with Apple Music playback. Please update to the newest version of iOS.", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
            
            self?.present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: NetworkManagerDelegate
    
    func resetManager() {
        networkManager = nil
        networkManager = MultipeerManager(isHost: self.isHost, partyName: isHost ? Party.name! : NSLocalizedString("Party", comment: ""))
        networkManager!.delegate = self
    }
    
    func updateStatus(withState state: MCSessionState) {
        if !isHost {
            DispatchQueue.main.async { [weak self] in
                self?.connectionStatus = state
            }
        }
    }
    
    func setup(withParty party: Party) {
        Party.name = type(of: party).name
        Party.musicService = type(of: party).musicService
        Party.spotifyAccessToken = type(of: party).spotifyAccessToken
        Party.appleMusicStorefront = type(of: party).appleMusicStorefront
    }
    
    func update(usingPosition position: TimeInterval) {
        currentPositionFromHost = position
    }
    
    // MARK: PartyViewControllerInfoDelegate
    
    var connectedUsers: Int {
        return networkManager!.sessions.count
    }
    
    var currentTrackPosition: TimeInterval? {
        return isHost ? musicPlayer.currentPosition : currentPositionFromHost
    }
    
    var tableHeight: CGFloat {
        get {
            return tableHeightConstraint.constant
        }
        set {
            tableHeightConstraint.constant = newValue
        }
    }
    
    func layout() {
        view.layoutIfNeeded()
    }
    
}
