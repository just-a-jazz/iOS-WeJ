//
//  AppleMusicFetcher.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 7/31/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import Foundation
import MediaPlayer
import MusicKit
import SwiftyJSON

protocol Fetcher {
    var tracksList: [Track] { get set }
    func searchCatalog(forTerm term: String, completionHandler: @escaping () -> Void)
    
    func getLibraryAlbums(atOffset offset: Int, withOptionsDict optionsDict: [String: [Option]], completionHandler: @escaping ([String : [Option]]) -> Void)
    func getLibraryArtists(completionHandler: @escaping ([String: [Option]]) -> Void)
    func getLibraryPlaylists(completionHandler: @escaping ([String: [Option]]) -> Void)
    func getLibraryTracks(atOffset offset: Int, completionHandler: @escaping () -> Void)
    func convert(libraryTracks: [Track], trackHandler: @escaping (Track) -> Void, errorHandler: @escaping (Int) -> Void)
    
    func getMostPlayed(completionHandler: @escaping () -> Void)
}

class AppleMusicFetcher: Fetcher {
    
    var tracksList = [Track]()

    private static var templateWebRequest: (URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> Void = { (request, completionHandler) in
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode == 200 {
                completionHandler(data, response, error)
            } else if let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode == 401 {
                AppleMusicAuthorizationManager.developerToken = nil
            }
        }
        
        task.resume()
    }
    
    func searchCatalog(forTerm term: String, completionHandler: @escaping () -> Void) {
        Task { [weak self] in
            let developerToken = await AppleMusicAuthorizationManager.ensureDeveloperToken()
            
            if developerToken != nil {
                if let tracks = await self?.fetchCatalogTracksWithRestApi(forTerm: term) {
                    self?.tracksList.append(contentsOf: tracks)
                }
            } else {
                // Web server didn't respond with a token, so use the MusicKit API
                if let tracks = await self?.fetchCatalogTracksWithMusicKit(forTerm: term, limit: 25) {
                    self?.tracksList.append(contentsOf: tracks)
                }
            }
            completionHandler()
        }
    }
    
    private func fetchCatalogTracksWithRestApi(forTerm term: String, limit: Int = 25) async -> [Track] {
        guard let request = await AppleMusicURLFactory.createSearchRequest(forTerm: term) else {
            return []
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode == 200 {
                let tracksJSON = try JSON(data: data)["results"]["songs"]["data"].arrayValue
                return tracksJSON.prefix(limit).map { parse(json: $0) }
            }
        } catch {
            return []
        }
        
        return []
    }

    private func fetchCatalogTracksWithMusicKit(forTerm term: String, limit: Int) async -> [Track] {
        do {
            var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
            request.limit = limit
            let response = try await request.response()
            return response.songs.map { parse(song: $0) }
        } catch {
            return []
        }
    }
    
    static func getSearchHints(forTerm term: String, completionHandler: @escaping ([String]) -> Void) {
        Task {
            guard let request = await AppleMusicURLFactory.createSearchHintsRequest(forTerm: term) else {
                DispatchQueue.main.async {
                    completionHandler([])
                }
                return
            }

            templateWebRequest(request) { (data, response, error) in
                var hints = [String]()
                let hintsJSON = try! JSON(data: data!)["results"]["terms"].arrayValue
                for hintJSON in hintsJSON {
                    hints.append(hintJSON.stringValue)
                }
                DispatchQueue.main.async {
                    completionHandler(hints)
                }
            }
        }
    }
    
    func getLibraryAlbums(atOffset offset: Int, withOptionsDict optionsDict: [String: [Option]], completionHandler: @escaping ([String : [Option]]) -> Void) {
        AppleMusicAuthorizationManager.ensureMediaLibraryAccess { authorized in
            guard authorized else {
                completionHandler([:])
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
            let albums = MPMediaQuery.albums()
            albums.groupingType = .album
            let albumsList = albums.collections!
            
            var optionsDict = [String: [Option]]()
            
            for album in albumsList where !album.items.isEmpty {
                let albumName = album.items[0].albumTitle ?? "#"
                
                let key = String(albumName.first!).uppercased()
                let tracks = Track.convert(tracks: album.items)
                
                if optionsDict[key] != nil {
                    optionsDict[key]!.append(Option(name: albumName, tracks: tracks))
                } else {
                    optionsDict[key] = [Option(name: albumName, tracks: tracks)]
                }
            }
            
            completionHandler(optionsDict)
            }
        }
    }
    
    func getLibraryArtists(completionHandler: @escaping ([String: [Option]]) -> Void) {
        AppleMusicAuthorizationManager.ensureMediaLibraryAccess { authorized in
            guard authorized else {
                completionHandler([:])
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
            let artists = MPMediaQuery.artists()
            artists.groupingType = .artist
            let artistsList = artists.collections!
            
            var optionsDict = [String: [Option]]()
            
            for artist in artistsList where !artist.items.isEmpty {
                let artistName = artist.items[0].artist ?? "#"
                
                let key = String(artistName.first!).uppercased()
                let tracks = Track.convert(tracks: artist.items)
                
                if optionsDict[key] != nil {
                    optionsDict[key]!.append(Option(name: artistName, tracks: tracks))
                } else {
                    optionsDict[key] = [Option(name: artistName, tracks: tracks)]
                }
            }
            
            completionHandler(optionsDict)
            }
        }
    }
    
    func getLibraryPlaylists(completionHandler: @escaping ([String: [Option]]) -> Void) {
        AppleMusicAuthorizationManager.ensureMediaLibraryAccess { authorized in
            guard authorized else {
                completionHandler([:])
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
            let playlists = MPMediaQuery.playlists()
            playlists.groupingType = .playlist
            let playlistsList = playlists.collections!
            
            var optionsDict = [String: [Option]]()
            
            for playlist in playlistsList where !playlist.items.isEmpty {
                let playlistName = playlist.value(forProperty: MPMediaPlaylistPropertyName) as? String ?? "#"
                
                let key = String(playlistName.first!)
                let tracks = Track.convert(tracks: playlist.items)
                
                if optionsDict[key] != nil {
                    optionsDict[key]!.append(Option(name: playlistName, tracks: tracks))
                } else {
                    optionsDict[key] = [Option(name: playlistName, tracks: tracks)]
                }
            }
            
            completionHandler(optionsDict)
            }
        }
    }
    
    func getLibraryTracks(atOffset offset: Int, completionHandler: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let userTracks = MPMediaQuery.songs()
            let userTracksList = userTracks.collections!
            
            for userTrackCollection in userTracksList where !userTrackCollection.items.isEmpty {
                guard self != nil else { return }
                self?.tracksList.append(Track.convert(tracks: userTrackCollection.items)[0])
            }
            
            completionHandler()
        }
    }
    
    func convert(libraryTracks: [Track], trackHandler: @escaping (Track) -> Void, errorHandler: @escaping (Int) -> Void) {
        Task { [weak self] in
            let developerToken = await AppleMusicAuthorizationManager.requestDeveloperToken()
            
            for (_, libraryTrack) in libraryTracks.enumerated() {
                let query = libraryTrack.name + " " + libraryTrack.artist
                var foundTrack: Track?

                if developerToken != nil {
                    foundTrack = await self?.fetchCatalogTracksWithRestApi(forTerm: query, limit: 1).first
                }

                if foundTrack == nil {
                    foundTrack = await self?.fetchCatalogTracksWithMusicKit(forTerm: query, limit: 1).first
                }

                if let track = foundTrack {
                    track.libraryID = libraryTrack.libraryID.isEmpty ? libraryTrack.id : libraryTrack.libraryID
                    if !Party.tracksQueue(hasTrack: track) {
                        await MainActor.run {
                            trackHandler(track)
                        }
                    }
                } else {
                    // Use the library track directly if a track from was not found through Apple Music's APIs
                    if !Party.tracksQueue(hasTrack: libraryTrack) {
                        await MainActor.run {
                            trackHandler(libraryTrack)
                        }
                    }
                }
            }
        }
    }
    
    func getMostPlayed(completionHandler: @escaping () -> Void) {
        AppleMusicAuthorizationManager.ensureMediaLibraryAccess { [weak self] authorized in
            guard authorized else {
                completionHandler()
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                let items = MPMediaQuery.songs().items ?? []
                let sortedItems = items.sorted { $0.playCount > $1.playCount }
                let topItems = Array(sortedItems.prefix(50))
                self?.tracksList = Track.convert(tracks: topItems)
                completionHandler()
            }
        }
    }
    
    private func parse(json: JSON) -> Track {
        let track = Track()
        let attributes = json["attributes"]
        
        track.id = json["id"].stringValue
        track.name = attributes["name"].stringValue
        track.artist = attributes["artistName"].stringValue
        
        track.lowResArtworkURL = getImageURL(fromURL: attributes["artwork"]["url"].stringValue, withSize: "60")
        
        if tracksList.count < AppleMusicConstants.maxInitialLowRes {
            track.fetchImage(fromURL: track.lowResArtworkURL) { [weak track] (image) in
                track?.lowResArtwork = image
            }
        }
        
        track.highResArtworkURL = getImageURL(fromURL: attributes["artwork"]["url"].stringValue, withSize: "400")
        track.length = TimeInterval(attributes["durationInMillis"].doubleValue / 1000)
        
        return track
    }
    
    private func parse(song: Song) -> Track {
        let track = Track()
        track.id = song.id.rawValue
        track.name = song.title
        track.artist = song.artistName

        if let artwork = song.artwork {
            if let lowResURL = artwork.url(width: 60, height: 60) {
                track.lowResArtworkURL = lowResURL.absoluteString
            }
            if let highResURL = artwork.url(width: 400, height: 400) {
                track.highResArtworkURL = highResURL.absoluteString
            }
        }

        if let duration = song.duration {
            track.length = TimeInterval(duration)
        }

        return track
    }
    
    private func getImageURL(fromURL url: String, withSize size: String) -> String {
        var url = url
        
        url = url.replacingOccurrences(of: "{w}", with: size)
        url = url.replacingOccurrences(of: "{h}", with: size)
        
        return url
    }
    
}
