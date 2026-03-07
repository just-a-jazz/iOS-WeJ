//
//  AppleMusicFetcher.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 7/31/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import Foundation
import MediaPlayer
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
            guard let request = await AppleMusicURLFactory.createSearchRequest(forTerm: term) else {
                completionHandler()
                return
            }

            AppleMusicFetcher.templateWebRequest(request) { [weak self] (data, response, _) in
                let tracksJSON = try! JSON(data: data!)["results"]["songs"]["data"].arrayValue
                for trackJSON in tracksJSON {
                    guard self != nil else { return }
                    self!.tracksList.append(self!.parse(json: trackJSON))
                }
                completionHandler()
            }
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
    
    func getLibraryArtists(completionHandler: @escaping ([String: [Option]]) -> Void) {
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
    
    func getLibraryPlaylists(completionHandler: @escaping ([String: [Option]]) -> Void) {
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
        let dispatchGroup = DispatchGroup()
        
        Task { [weak self] in
            var notFoundCount = 0
            
            for (i, libraryTrack) in libraryTracks.enumerated() {
                guard let request = await AppleMusicURLFactory.createSearchRequest(forTerm: libraryTrack.name + " " + libraryTrack.artist) else {
                    notFoundCount += 1
                    if i == libraryTracks.count - 1 {
                        DispatchQueue.main.async {
                            errorHandler(notFoundCount)
                        }
                    }
                    continue
                }
                
                dispatchGroup.enter()
                let task = URLSession.shared.dataTask(with: request) { (data, response, _) in
                    if let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode == 200 {
                        let tracksJSON = try! JSON(data: data!)["results"]["songs"]["data"].arrayValue
                        guard self != nil else { return }
                        
                        if !tracksJSON.isEmpty {
                            let track = self!.parse(json: tracksJSON[0])
                            if !Party.tracksQueue(hasTrack: track) {
                                DispatchQueue.main.async {
                                    trackHandler(track)
                                }
                            }
                        } else {
                            notFoundCount += 1
                        }
                    } else {
                        notFoundCount += 1
                    }
                    
                    if i == libraryTracks.count - 1 {
                        DispatchQueue.main.async {
                            errorHandler(notFoundCount)
                        }
                    }
                    dispatchGroup.leave()
                }
                
                task.resume()
                dispatchGroup.wait()
            }
        }
    }
    
    func getMostPlayed(completionHandler: @escaping () -> Void) {
        Task { [weak self] in
            guard let request = await AppleMusicURLFactory.createMostPlayedRequest() else {
                completionHandler()
                return
            }
            
            AppleMusicFetcher.templateWebRequest(request) { [weak self] (data, response, _) in
                let chartsJSON = try! JSON(data: data!)["results"]["songs"]
                if !chartsJSON.arrayValue.isEmpty {
                    let tracksJSON = chartsJSON.arrayValue[0]["data"].arrayValue
                    for trackJSON in tracksJSON {
                        guard self != nil else { return }
                        self!.tracksList.append(self!.parse(json: trackJSON))
                    }
                }
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
    
    private func getImageURL(fromURL url: String, withSize size: String) -> String {
        var url = url
        
        url = url.replacingOccurrences(of: "{w}", with: size)
        url = url.replacingOccurrences(of: "{h}", with: size)
        
        return url
    }
    
}
