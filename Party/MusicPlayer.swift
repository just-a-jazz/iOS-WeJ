//
//  MusicPlayer.swift
//  Party
//
//  Created by Ali Siddiqui on 1/20/17.
//  Copyright © 2017 Ali Siddiqui and Matthew Paletta. All rights reserved.
//

import Foundation
import StoreKit
import MediaPlayer

class MusicPlayer: NSObject {
    
    // MARK: - Apple Music Variables
    
    private let serviceController = SKCloudServiceController()
    let appleMusicPlayer = MPMusicPlayerController.applicationMusicPlayer()
    
    // MARK: - Spotify Variables
    
    var spotifyPlayer = SPTAudioStreamingController.sharedInstance() {
        didSet {
            initializeCommandCenter()
        }
    }
    
    // MARK: - General Variables
    
    let commandCenter = MPRemoteCommandCenter.shared()
    var party = Party()
    
    // MARK: - Apple Music Functions
    
    func hasCapabilities() {
        serviceController.requestCapabilities{ (capability, error) in
            if capability.contains(.musicCatalogPlayback) || capability.contains(.addToCloudMusicLibrary) {
                print("Has Apple Music capabilities")
            } else {
                print("Doesn't have Apple Music capabilities")
            }
        }
    }
    
    func haveAuthorization() {
        // If user has pressed Don't allow, move them to the settings
        SKCloudServiceController.requestAuthorization { (status) in
            switch status {
            case .authorized:
                print("Apple Music authorized")
                self.appleMusicPlayer.beginGeneratingPlaybackNotifications()
                self.initializeCommandCenter()
            default:
                print("Apple Music failed to authorize")
            }
            
        }
    }
    
    func safeToPlayNextTrack() -> Bool {
        return appleMusicPlayer.playbackState == .stopped && appleMusicPlayer.nowPlayingItem == nil
    }
    
    // MARK: - General Functions
    
    func initializeCommandCenter() {
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.playCommand.isEnabled = true
        
        setupControlEvents()
    }
    
    func setupControlEvents() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        commandCenter.pauseCommand.addTarget { (commandEvent) -> MPRemoteCommandHandlerStatus in
            self.pauseTrack()
            return .success
        }
        
        commandCenter.playCommand.addTarget { (commandEvent) -> MPRemoteCommandHandlerStatus in
            self.playTrack()
            return .success
        }
    }
    
    // Improve - hard fails here randomly
    func isPaused() -> Bool {
        return party.musicService == .appleMusic ? appleMusicPlayer.playbackState == .paused : spotifyPlayer?.playbackState.isPlaying == false
    }
    
    // MARK: - Playback
    
    func modifyQueue(withTracks tracks: [Track]) {
        if self.party.musicService == .appleMusic {
            self.modifyAppleMusicQueue(withTrack: tracks)
        } else {
            self.modifySpotifyQueue(withTrack: tracks)
        }
    }
    
    func modifyAppleMusicQueue(withTrack tracks: [Track]) {
        if !tracks.isEmpty {
            let id = [tracks[0].id]
            appleMusicPlayer.setQueueWithStoreIDs(id)
            playTrack()
        } else {
            appleMusicPlayer.setQueueWithStoreIDs([])
            appleMusicPlayer.stop()
        }
    }
    
    func modifySpotifyQueue(withTrack tracks: [Track]) {
        if !tracks.isEmpty {
            try? AVAudioSession.sharedInstance().setActive(true)
            spotifyPlayer?.playSpotifyURI("spotify:track:" + tracks[0].id, startingWith: 0, startingWithPosition: 0, callback: nil)
        } else {
            spotifyPlayer?.skipNext(nil)
        }
    }
    
    @objc func playTrack() {
        if party.musicService == .appleMusic {
            appleMusicPlayer.prepareToPlay()
            appleMusicPlayer.play()
        } else {
            spotifyPlayer?.setIsPlaying(true, callback: nil)
        }
        
    }
    
    @objc func pauseTrack() {
        if party.musicService == .appleMusic {
            appleMusicPlayer.pause()
        } else {
            spotifyPlayer?.setIsPlaying(false, callback: nil)
        }
    }
    
}
