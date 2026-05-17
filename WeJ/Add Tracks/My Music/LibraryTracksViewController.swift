//
//  LibraryTracksViewController.swift
//  WeJ
//
//  Created by Ali Siddiqui on 8/12/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import UIKit
import RKNotificationHub
import NVActivityIndicatorView
import M13Checkbox

protocol LibraryTracksViewControllerDelegate: class {
    func updateTable()
}

class LibraryTracksViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, SelectionCountBadgePresenting {
    
    weak var delegate: LibraryTracksViewControllerDelegate?
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var doneButton: UIButton!
    var badge: RKNotificationHub!
    var totalTracksCount: Int {
        let controller = tabBarController! as! AddTracksTabBarController
        return controller.tracksSelected.count + controller.libraryTracksSelected.count
    }
    
    @IBOutlet weak var tracksTableView: UITableView!
    @IBOutlet weak var activityIndicator: NVActivityIndicatorView!
    
    var fetcher: Fetcher!
    var musicService: MusicService!
    var playlistName: String!
    var playlistType: PlaylistType!
    var playlistIndexPath: IndexPath!
    
    var intermediateTracksList: [Track]!
    var libraryTracksList = [Track]() {
        didSet {
            DispatchQueue.main.async {
                self.populateUserTracksDict()
                self.tracksTableView.reloadData()
                self.activityIndicator.stopAnimating()
                self.fetchArtworkForRestOfTracks()
            }
        }
    }
    var libraryTracksDict = [String: [Track]]()
    var orderedLibraryTracksDictKeys: [String] {
        return libraryTracksDict.keys.sorted()
    }
    
    var libraryTracksSelected: [Track] {
        get {
            return (tabBarController as? AddTracksTabBarController)?.libraryTracksSelected ?? []
        }
        set {
            (tabBarController! as! AddTracksTabBarController).libraryTracksSelected = newValue
        }
    }
    var playlistsSelected: [MusicService: [IndexPath: M13Checkbox.CheckState]] {
        get {
            return (tabBarController as? AddTracksTabBarController)?.playlistsSelected ?? [:]
        }
        set {
            (tabBarController! as! AddTracksTabBarController).playlistsSelected = newValue
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSelectionCountBadge()
        initializeVariables()
        
        setDelegates()
        adjustViews()
        adjustTableView()
        adjustFontSizes()
        
        if case .some(.all) = playlistType {
            populateAllTracks()
        } else {
            populateSpecificTracks()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setBadge(to: totalTracksCount)
    }
    
    private func initializeVariables() {
        fetcher = (musicService == .spotify) ? SpotifyFetcher() : AppleMusicFetcher()
    }
    
    private func setDelegates() {
        tracksTableView.delegate = self
        tracksTableView.dataSource = self
    }
    
    private func adjustViews() {
        titleLabel.text = String(playlistName.prefix(20)) + (playlistName.count > 20 ? "..." : "")
    }
    
    private func adjustFontSizes() {
        if UIDevice.deviceType == .iPhone4_4s || UIDevice.deviceType == .iPhone5_5s_SE {
            titleLabel.changeToSmallerFont()
            doneButton.changeToSmallerFont()
        }
    }
    
    private func adjustTableView() {
        tracksTableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        
        tracksTableView.sectionIndexColor = .gray
        tracksTableView.sectionIndexBackgroundColor = .clear
    }
    
    private func populateSpecificTracks() {
        switch playlistType {
        case .some(.albums): populateAlbumTracks()
        case .some(.artists): populateArtistTracks()
        case .some(.playlists): populatePlaylistTracks()
        default: break
        }
    }
    
    private func populateAlbumTracks() {
        if musicService == .spotify {
            populateSpotifyAlbumTracks()
        } else {
            libraryTracksList = intermediateTracksList
        }
    }
    
    private func populateSpotifyAlbumTracks() {
        let spotifyAlbumFetcher = SpotifyFetcher()
        activityIndicator.startAnimating()
        
        if !intermediateTracksList.isEmpty {
            spotifyAlbumFetcher.getLibraryAlbumTracks(atOffset: 0, forDummyTrack: intermediateTracksList[0]) { [weak self] in
                guard self != nil else { return }
                self!.libraryTracksList = spotifyAlbumFetcher.tracksList
            }
        }
    }
    
    private func populateArtistTracks() {
        if musicService == .appleMusic {
            libraryTracksList = intermediateTracksList
        }
    }
    
    private func populatePlaylistTracks() {
        if musicService == .spotify {
            populateSpotifyPlaylistTracks()
        } else {
            libraryTracksList = intermediateTracksList
        }
    }
    
    private func populateSpotifyPlaylistTracks() {
        let spotifyPlaylistFetcher = SpotifyFetcher()
        activityIndicator.startAnimating()

        if !intermediateTracksList.isEmpty {
            spotifyPlaylistFetcher.getLibraryPlaylistTracks(atOffset: 0, forDummyTrack: intermediateTracksList[0]) { [weak self] in
                guard self != nil else { return }
                self!.libraryTracksList = spotifyPlaylistFetcher.tracksList
            }
        }
    }
    
    private func populateAllTracks() {
        activityIndicator.startAnimating()
        fetcher.getLibraryTracks(atOffset: 0) { [weak self] in
            guard self != nil else { return }
            self?.libraryTracksList = self!.fetcher.tracksList
        }
    }
    
    private func populateUserTracksDict() {
        for track in libraryTracksList {
            let key = String(track.name.uppercased().first ?? "#")
            
            if libraryTracksDict[key] != nil {
                libraryTracksDict[key]!.append(track)
            } else {
                libraryTracksDict[key] = [track]
            }
        }
    }
    
    private func fetchArtworkForRestOfTracks() {
        guard musicService == .spotify else { return }
        
        let tracksCaptured = libraryTracksList
        for (i, track) in libraryTracksList.enumerated() where libraryTracksList == tracksCaptured && track.lowResArtwork == nil {
            DispatchQueue.global(qos: .userInitiated).async {
                track.fetchImage(fromURL: track.lowResArtworkURL) { [weak self, weak track] (image) in
                    guard self != nil else { return }
                    track?.lowResArtwork = image
                    if (i % 20) == 0  || i == self!.libraryTracksList.count - 1 {
                        self?.tracksTableView.reloadData()
                    }
                }
            }
        }
    }
    
    // MARK: - Table
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return libraryTracksDict.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return libraryTracksDict[orderedLibraryTracksDictKeys[section]]!.count
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .clear
        
        let section = orderedLibraryTracksDictKeys[indexPath.section]
        let track = libraryTracksDict[section]![indexPath.row]
        if isSelectedOrQueued(track) {
            cell.accessoryType = .checkmark
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        } else {
            cell.accessoryType = .none
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Track", for: indexPath) as! TrackTableViewCell
        
        let section = orderedLibraryTracksDictKeys[indexPath.section]
        let track = libraryTracksDict[section]![indexPath.row]
        
        // Cell Properties
        cell.trackName.text = track.name
        cell.artistName.text = track.artist
        cell.artworkImageView.image = track.lowResArtwork
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)!
        let section = orderedLibraryTracksDictKeys[indexPath.section]
        let track = libraryTracksDict[section]![indexPath.row]
        
        addToQueue(track: track)
        modifyPlaylistCheckbox()
        UIView.animate(withDuration: 0.35) {
            cell.accessoryType = .checkmark
        }
    }
    
    private func addToQueue(track: Track) {
        if !Party.tracksQueue(hasTrack: track) && !libraryTracksSelected.contains(where: { $0.id == track.id }) {
            libraryTracksSelected.append(track)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = AppConstants.darkerBlack
        
        let label = UILabel(frame: CGRect(x: 30, y: view.center.y + 13, width: 40, height: 15))
        label.text = orderedLibraryTracksDictKeys[section]
        label.font = UIFont(name: "AvenirNext-Bold", size: 20)
        label.textColor = .white
        
        if UIDevice.deviceType == .iPhone4_4s || UIDevice.deviceType == .iPhone5_5s_SE {
            label.changeToSmallerFont()
        }
        
        view.addSubview(label)
        
        return view
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return orderedLibraryTracksDictKeys
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)!
        let section = orderedLibraryTracksDictKeys[indexPath.section]
        let track = libraryTracksDict[section]![indexPath.row]
        
        if Party.tracksQueue(hasTrack: track) {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            cell.accessoryType = .checkmark
            return
        }
        
        removeFromQueue(track: track)
        modifyPlaylistCheckbox()
        if !Party.tracksQueue(hasTrack: track) {
            UIView.animate(withDuration: 0.35) {
                cell.accessoryType = .none
            }
        }
    }
    
    func modifyPlaylistCheckbox() {
        guard playlistType != .all else { return }
        
        if let list = tracksTableView.indexPathsForSelectedRows {
            if list.count < libraryTracksList.count {
                playlistsSelected[musicService]![playlistIndexPath] = .mixed
            } else {
                playlistsSelected[musicService]![playlistIndexPath] = .checked
            }
        } else {
            playlistsSelected[musicService]![playlistIndexPath] = .unchecked
        }
        delegate?.updateTable()
    }
    
    private func removeFromQueue(track: Track) {
        if let index = libraryTracksSelected.index(where: {$0.id == track.id}) {
            libraryTracksSelected.remove(at: index)
        }
    }
    
    private func isSelectedOrQueued(_ track: Track) -> Bool {
        return Party.tracksQueue(hasTrack: track) || libraryTracksSelected.contains(where: { $0.id == track.id })
    }
    
    // MARK: - Navigation
    
    @IBAction func goBack() {
        navigationController?.popViewController(animated: true)
    }

}
