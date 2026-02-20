//
//  PlaylistSubcategorySelectionViewController.swift
//  WeJ
//
//  Created by Ali Siddiqui on 8/11/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import UIKit
import RKNotificationHub
import NVActivityIndicatorView
import M13Checkbox
import MediaPlayer

class PlaylistSubcategorySelectionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, PlaylistSubcategoryTableViewCellDelegate, LibraryTracksViewControllerDelegate, SelectionCountBadgePresenting {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var doneButton: UIButton!
    var badge: RKNotificationHub!
    var totalTracksCount: Int {
        let controller = tabBarController! as! AddTracksTabBarController
        return controller.tracksSelected.count + controller.libraryTracksSelected.count
    }
    
    @IBOutlet weak var optionsTable: UITableView!
    
    var musicService: MusicService!
    
    var activityIndicator: NVActivityIndicatorView!
    var playlistType: PlaylistType!
    
    var fetcher: Fetcher!
    var optionsDict = [String: [Option]]()
    
    var orderedOptionsDictKeys: [String] {
        return optionsDict.keys.sorted()
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
            optionsTable.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSelectionCountBadge()
        initializeVariables()
        
        setDelegates()
        adjustViews()
        adjustFontSizes()
        customizeTableView()
        
        setOptions()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setBadge(to: totalTracksCount)
    }
    
    private func initializeVariables() {
        fetcher = (musicService == .spotify) ? SpotifyFetcher() : AppleMusicFetcher()
        
        let rect = CGRect(x: view.center.x - 20, y: view.center.x - 20, width: 40, height: 40)
        activityIndicator = NVActivityIndicatorView(frame: rect, type: .ballClipRotateMultiple, color: .white, padding: 0)
        activityIndicator.center = view.center
        view.addSubview(activityIndicator)
        
        activityIndicator.startAnimating()
    }
    
    private func setDelegates() {
        optionsTable.delegate = self
        optionsTable.dataSource = self
    }
    
    private func adjustViews() {
        switch playlistType {
        case .some(.albums): titleLabel.text = NSLocalizedString("Albums", comment: "")
        case .some(.artists): titleLabel.text = NSLocalizedString("Artists", comment: "")
        case .some(.playlists): titleLabel.text = NSLocalizedString("Playlists", comment: "")
        default: break
        }
    }
    
    private func adjustFontSizes() {
        if UIDevice.deviceType == .iPhone4_4s || UIDevice.deviceType == .iPhone5_5s_SE {
            titleLabel.changeToSmallerFont()
            doneButton.changeToSmallerFont()
        }
    }
    
    private func customizeTableView() {
        edgesForExtendedLayout = UIRectEdge.init(rawValue: 0)
        
        optionsTable.sectionIndexColor = .gray
        optionsTable.sectionIndexBackgroundColor = .clear
    }
    
    private func setOptions() {
        let completionHandler: ([String: [Option]]) -> (Void) = { [weak self] (optionsDict) in
            DispatchQueue.main.async {
                self?.optionsDict = optionsDict
                self?.activityIndicator.stopAnimating()
                self?.optionsTable.reloadData()
            }
        }
        
        switch playlistType {
        case .some(.albums): fetcher.getLibraryAlbums(atOffset: 0, withOptionsDict: [:], completionHandler: completionHandler)
        case .some(.artists): fetcher.getLibraryArtists(completionHandler: completionHandler)
        case .some(.playlists): fetcher.getLibraryPlaylists(completionHandler: completionHandler)
        default: break
        }
    }
    
    // MARK - Table
    
    func addWholePlaylist(withAddPlaylistButton addPlaylistButton: M13Checkbox, atCell cell: PlaylistSubcategoryTableViewCell) {
        let indexPath = IndexPath(row: optionsTable.indexPath(for: cell)!.row, section: optionsTable.indexPath(for: cell)!.section)
        playlistsSelected[musicService]![indexPath] = addPlaylistButton.checkState
        
        if addPlaylistButton.checkState == .checked {
            addTracks(atIndexPath: indexPath)
        } else {
            removeTracks(atIndexPath: indexPath)
        }
    }
    
    func addTracks(atIndexPath indexPath: IndexPath) {
        getTracks(atIndexPath: indexPath) { [weak self] (tracks) in
            self?.libraryTracksSelected.append(contentsOf: tracks.filter { (trackToFind) in
                guard self != nil else { return false }
                return !self!.libraryTracksSelected.contains(where: {$0.id == trackToFind.id })})
        }
    }
    
    func removeTracks(atIndexPath indexPath: IndexPath) {
        getTracks(atIndexPath: indexPath) { [weak self] (tracksToRemove) in
            guard self != nil else { return }
            self?.libraryTracksSelected = self!.libraryTracksSelected.filter { (trackFound) in
                return !tracksToRemove.contains(where: {$0.id == trackFound.id })
            }
        }
    }
    
    private func getTracks(atIndexPath indexPath: IndexPath, completionHandler: @escaping ([Track]) -> Void) {
        let tracksSelected = optionsDict[orderedOptionsDictKeys[indexPath.section]]![indexPath.row].tracks
        
        if musicService == .spotify {
            switch playlistType {
            case .some(.albums): getSpotifyAlbumTracks(forPlaylist: tracksSelected, completionHandler: completionHandler)
            case .some(.playlists): getSpotifyPlaylistTracks(forPlaylist: tracksSelected, completionHandler: completionHandler)
            default: break
            }
        } else {
            completionHandler(tracksSelected)
            
        }
    }
    
    private func getSpotifyAlbumTracks(forPlaylist playlist: [Track], completionHandler: @escaping ([Track]) -> Void) {
        let spotifyPlaylistFetcher = SpotifyFetcher()
        spotifyPlaylistFetcher.getLibraryAlbumTracks(atOffset: 0, forDummyTrack: playlist[0]) {
            DispatchQueue.main.async {
                completionHandler(spotifyPlaylistFetcher.tracksList)
            }
        }
    }
    
    private func getSpotifyPlaylistTracks(forPlaylist playlist: [Track], completionHandler: @escaping ([Track]) -> Void) {
        let spotifyPlaylistFetcher = SpotifyFetcher()
        spotifyPlaylistFetcher.getLibraryPlaylistTracks(atOffset: 0, forDummyTrack: playlist[0]) {
            DispatchQueue.main.async {
                completionHandler(spotifyPlaylistFetcher.tracksList)
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return optionsDict.keys.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return optionsDict[orderedOptionsDictKeys[section]]!.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = orderedOptionsDictKeys[indexPath.section]
        performSegue(withIdentifier: "Show Tracks", sender: (optionsDict[section]![indexPath.row].tracks, optionsDict[section]![indexPath.row].name, indexPath))
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = AppConstants.darkerBlack
        
        let label = UILabel(frame: CGRect(x: 30, y: view.center.y + 13, width: 40, height: 15))
        label.text = orderedOptionsDictKeys[section]
        label.font = UIFont(name: "AvenirNext-Bold", size: 20)
        label.textColor = .white
        
        view.addSubview(label)
        
        return view
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return orderedOptionsDictKeys
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Option", for: indexPath) as! PlaylistSubcategoryTableViewCell
        
        let section = orderedOptionsDictKeys[indexPath.section]
        let row = optionsDict[section]![indexPath.row]
        
        cell.optionLabel.text = row.name
        cell.backgroundColor = .clear
        cell.addPlaylistButton?.setCheckState(playlistsSelected[musicService]![indexPath] ?? .unchecked, animated: true)
        cell.delegate = self
        
        return cell
    }

    // MARK: - Navigation

    @IBAction func goBack() {
        navigationController?.popViewController(animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let controller = segue.destination as? LibraryTracksViewController,
            let (tracks, playlistName, indexPath) = sender as? ([Track], String, IndexPath) {
            controller.delegate = self
            controller.musicService = musicService
            controller.playlistName = playlistName
            controller.playlistType = playlistType
            controller.playlistIndexPath = indexPath
            controller.intermediateTracksList = tracks
        }
    }
    
    func updateTable() {
        optionsTable.reloadData()
    }

}
