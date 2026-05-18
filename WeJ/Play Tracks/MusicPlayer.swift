//
//  MusicPlayer.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 1/20/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import Foundation
import StoreKit
import MediaPlayer
import SpotifyiOS

class MusicPlayer: NSObject, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    
    // MARK: - Music Player Variables
    
    var appleMusicPlayer = MPMusicPlayerController.applicationMusicPlayer
    private var spotifyAppRemote: SPTAppRemote {
        SpotifyAuthorizationManager.shared.appRemote
    }
    private var spotifyPlayerState: SPTAppRemotePlayerState?
    private var pendingPlayURI: String?
    
    let musicService = Party.musicService
    
    // MARK: - General Variables
    
    weak var delegate: MusicPlayerDelegate?
    
    var isScrubbing = false
    
    var currentPosition: TimeInterval? {
        get {
            if musicService == .spotify {
                guard let playbackPosition = spotifyPlayerState?.playbackPosition else { return nil }
                return TimeInterval(playbackPosition) / 1000
            }
            return appleMusicPlayer.currentPlaybackTime
        }
    }
    
    var currentTrackURI: String? {
        return spotifyPlayerState?.track.uri
    }
    
    var isSafeToPlayNextTrack: Bool {
        return !Party.tracksQueue.isEmpty && self.musicService == .spotify
    }
    
    var isPaused: Bool {
        return musicService == .spotify ? (spotifyPlayerState?.isPaused ?? true) : appleMusicPlayer.playbackState == .paused
    }
    
    // MARK: - Playback
    
    func preparePlayer() {
        if self.musicService == .spotify {
            prepareSpotifyAppRemote()
            connectSpotifyIfNeeded()
        } else {
            appleMusicPlayer.beginGeneratingPlaybackNotifications()
        }
    }
    
    func startPlayer() {
        DispatchQueue.main.async {
            if self.musicService == .spotify {
                self.startSpotifyPlayer(withTracks: Party.tracksQueue)
            } else {
                self.startAppleMusicPlayer(withTracks: Party.tracksQueue)
            }
        }
    }
    
    private func startSpotifyPlayer(withTracks tracks: [Track]) {
        guard !tracks.isEmpty else {
            spotifyAppRemote.playerAPI?.pause(nil)
            return
        }

        prepareSpotifyAppRemote()
        let uri = "spotify:track:" + tracks[0].id
        if spotifyAppRemote.isConnected {
            spotifyAppRemote.playerAPI?.play(uri, callback: nil)
        } else {
            connectOrAuthorizeAndPlay(uri: uri)
        }
    }
    
    private func startAppleMusicPlayer(withTracks tracks: [Track]) {
        if !tracks.isEmpty {
            if tracks.allSatisfy({ $0.isFromLibrary }) {
                let mediaItems = appleMusicLibraryItems(forTracks: tracks)
                if !mediaItems.isEmpty {
                    appleMusicPlayer.setQueue(with: MPMediaItemCollection(items: mediaItems))
                } else {
                    appleMusicPlayer.setQueue(with: [tracks[0].id])
                }
            } else {
                appleMusicPlayer.setQueue(with: [tracks[0].id])
            }
            playTrack()
        } else if BackgroundTask.isPlaying {
            BackgroundTask.stopBackgroundTask()
            appleMusicPlayer.setQueue(with: [])
            appleMusicPlayer.stop()
        }
    }

    private func appleMusicLibraryItems(forTracks tracks: [Track]) -> [MPMediaItem] {
        let ids = Set(tracks.compactMap { UInt64($0.id) })
        guard !ids.isEmpty else { return [] }
        let items = MPMediaQuery.songs().items ?? []
        return items.filter { ids.contains($0.persistentID) }
    }
    
    func playTrack() {
        if musicService == .spotify {
            if spotifyAppRemote.isConnected {
                spotifyAppRemote.playerAPI?.resume(nil)
            } else if let track = Party.tracksQueue.first {
                connectOrAuthorizeAndPlay(uri: "spotify:track:" + track.id)
            }
        } else {
            delegate?.alertPreviousiOSVersionUsers()
            if #available(iOS 10.1, *) {
                let capturedTrackID = Party.tracksQueue.first?.id
                appleMusicPlayer.prepareToPlay { (_) in
                    if capturedTrackID == Party.tracksQueue.first?.id {
                        self.appleMusicPlayer.play()
                    }
                }
            } else {
                appleMusicPlayer.prepareToPlay()
                appleMusicPlayer.play()
            }
        }
        
    }
    
    func pauseTrack() {
        if musicService == .spotify {
            spotifyAppRemote.playerAPI?.pause(nil)
        } else {
            BackgroundTask.stopBackgroundTask()
            appleMusicPlayer.pause()
        }
    }
    
    func scrubTrack(toPosition position: TimeInterval, callback: @escaping (Error?) -> Void) {
        if musicService == .spotify {
            let positionInMilliseconds = Int(position * 1000)
            spotifyAppRemote.playerAPI?.seek(toPosition: positionInMilliseconds) { _, error in
                callback(error)
            }
        }
    }
    
    func exitPlayer() {
        if musicService == .spotify, spotifyAppRemote.isConnected {
            spotifyAppRemote.playerAPI?.pause(nil)
            spotifyAppRemote.disconnect()
        }
        
        if musicService == .appleMusic && appleMusicPlayer.playbackState == .playing {
            BackgroundTask.stopBackgroundTask()
            appleMusicPlayer.stop()
        }
    }
    
    // MARK: - Spotify App Remote
    
    private func connectSpotifyIfNeeded() {
        guard musicService == .spotify else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            SpotifyAuthorizationManager.ensureValidWebAccessToken()
            DispatchQueue.main.async { [weak self] in
                self?.configureSpotifyAccessToken()
                if self?.spotifyAppRemote.isConnected == false {
                    self?.spotifyAppRemote.connect()
                }
            }
        }
    }
    
    private func prepareSpotifyAppRemote() {
        spotifyAppRemote.delegate = self
    }
    
    private func configureSpotifyAccessToken() {
        spotifyAppRemote.connectionParameters.accessToken = Party.spotifyAccessToken
    }
    
    private func connectOrAuthorizeAndPlay(uri: String) {
        pendingPlayURI = uri
        configureSpotifyAccessToken()
        spotifyAppRemote.connect()
    }
    
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { _, _ in })
        appRemote.playerAPI?.getPlayerState { [weak self] state, _ in
            self?.spotifyPlayerState = state as? SPTAppRemotePlayerState
        }
        if let uri = pendingPlayURI {
            pendingPlayURI = nil
            appRemote.playerAPI?.play(uri, callback: nil)
        }
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        if let uri = pendingPlayURI {
            pendingPlayURI = nil
            configureSpotifyAccessToken()
            appRemote.authorizeAndPlayURI(uri, completionHandler: nil)
        }
        spotifyPlayerState = nil
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        spotifyPlayerState = nil
    }
    
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        spotifyPlayerState = playerState
    }
    
}
