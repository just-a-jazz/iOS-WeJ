//
//  SpotifyFetcher.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 8/2/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import Foundation
import SwiftyJSON

class SpotifyFetcher: Fetcher {
    
    var tracksList = [Track]()
    private let maxLibraryItems = 200
    private let pageSize = 50
    
    private static var templateWebRequest: (URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> Void = { (request, completionHandler) in
        SpotifyAuthorizationManager.ensureValidWebAccessToken()
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode == 200, data != nil {
                completionHandler(data, response, error)
            }
        }
        
        task.resume()
    }
    
    func searchCatalog(forTerm term: String, completionHandler: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let request = SpotifyURLFactory.createSearchRequest(forTerm: term)
            
            SpotifyFetcher.templateWebRequest(request) { [weak self] (data, response, _) in
                let tracksJSON = try! JSON(data: data!)["tracks"]["items"].arrayValue
                for trackJSON in tracksJSON {
                    guard self != nil else { return }
                    self!.tracksList.append(self!.parse(json: trackJSON))
                }
                completionHandler()
            }
        }
    }
    
    func getLibraryAlbums(atOffset offset: Int, withOptionsDict optionsDict: [String: [Option]], completionHandler: @escaping ([String : [Option]]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if offset >= self.maxLibraryItems {
                completionHandler(optionsDict)
                return
            }
            let request = SpotifyURLFactory.createLibraryAlbumsRequest(atOffset: offset)
            
            SpotifyFetcher.templateWebRequest(request) { [weak self] (data, response, _) in
                var optionsDict = optionsDict
                
                let json = try! JSON(data: data!)
                
                let itemsJSON = json["items"].arrayValue
                for itemJSON in itemsJSON {
                    let albumJSON = itemJSON["album"]
                    let albumName = albumJSON["name"].stringValue
                    
                    let key = String(albumName.capitalized.first ?? "#")
                    
                    let dummyTrack = Track()
                    dummyTrack.id = albumJSON["id"].stringValue //album ID
                    
                    for images in albumJSON["images"].arrayValue {
                        if images["height"].stringValue == "64" {
                            dummyTrack.lowResArtworkURL = images["url"].stringValue
                            dummyTrack.fetchImage(fromURL: dummyTrack.lowResArtworkURL) { [weak dummyTrack] (image) in
                                dummyTrack?.lowResArtwork = image
                            }
                        }
                        
                        if images["height"].stringValue == "640" {
                            dummyTrack.highResArtworkURL = images["url"].stringValue
                        }
                    }
                    
                    if optionsDict[key] != nil {
                        optionsDict[key]!.append(Option(name: albumName, tracks: [dummyTrack]))
                    } else {
                        optionsDict[key] = [Option(name: albumName, tracks: [dummyTrack])]
                    }
                }
                
                let total = json["total"].intValue
                let maxTotal = min(total, self?.maxLibraryItems ?? total)
                if offset + self!.pageSize < maxTotal {
                    self?.getLibraryAlbums(atOffset: offset + self!.pageSize, withOptionsDict: optionsDict, completionHandler: completionHandler)
                } else {
                    completionHandler(optionsDict)
                }
            }
        }
    }
    
    func getLibraryAlbumTracks(atOffset offset: Int, forDummyTrack track: Track, completionHandler: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if offset >= self.maxLibraryItems {
                completionHandler()
                return
            }
            let request = SpotifyURLFactory.createLibraryAlbumsTracksRequest(atOffset: offset, forID: track.id)
            
            SpotifyFetcher.templateWebRequest(request) { [weak self] (data, response, _) in
                let json = try! JSON(data: data!)
                
                let tracksJSON = json["items"].arrayValue
                for trackJSON in tracksJSON {
                    guard self != nil else { return }
                    let trackMade = self!.parse(json: trackJSON)
                    trackMade.lowResArtworkURL = track.lowResArtworkURL
                    trackMade.lowResArtwork = track.lowResArtwork
                    trackMade.highResArtworkURL = track.highResArtworkURL
                    self!.tracksList.append(trackMade)
                }
                
                let total = json["total"].intValue
                let maxTotal = min(total, self?.maxLibraryItems ?? total)
                if offset + self!.pageSize < maxTotal {
                    self?.getLibraryAlbumTracks(atOffset: offset + self!.pageSize, forDummyTrack: track, completionHandler: completionHandler)
                } else {
                    completionHandler()
                }
            }
        }
    }
    
    func getLibraryArtists(completionHandler: @escaping ([String : [Option]]) -> Void) {
        
    }
    
    func getLibraryPlaylists(completionHandler: @escaping ([String : [Option]]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.getLibraryPlaylistsPage(atOffset: 0, withOptionsDict: [:], completionHandler: completionHandler)
        }
    }
    
    func getLibraryPlaylistTracks(atOffset offset: Int, forDummyTrack track: Track, completionHandler: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if offset >= self.maxLibraryItems {
                completionHandler()
                return
            }
            let request = SpotifyURLFactory.createLibraryPlaylistTracksRequest(atOffset: offset, forPlaylistID: track.name)
            SpotifyFetcher.templateWebRequest(request) { [weak self] (data, response, _) in
                let json = try! JSON(data: data!)
                let tracksJSON = json["items"].arrayValue
                for trackJSON in tracksJSON {
                    guard self != nil else { return }
                    self!.tracksList.append(self!.parse(json: trackJSON))
                }
                
                let total = json["total"].intValue
                let maxTotal = min(total, self?.maxLibraryItems ?? total)
                if offset + self!.pageSize < maxTotal {
                    self?.getLibraryPlaylistTracks(atOffset: offset + self!.pageSize, forDummyTrack: track, completionHandler: completionHandler)
                } else {
                    completionHandler()
                }
            }
        }
    }
    
    func getLibraryTracks(atOffset offset: Int, completionHandler: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let request = SpotifyURLFactory.createLibraryTracksRequest(atOffset: offset)
            
            SpotifyFetcher.templateWebRequest(request) { [weak self] (data, response, _) in
                let json = try! JSON(data: data!)
                let tracksJSON = json["items"].arrayValue
                for trackJSON in tracksJSON {
                    guard self != nil else { return }
                    self!.tracksList.append(self!.parse(json: trackJSON["track"]))
                }
                
                if json["total"].intValue > offset + 50 {
                    self?.getLibraryTracks(atOffset: offset + 50, completionHandler: completionHandler)
                } else {
                    completionHandler()
                }
            }
        }
    }

    private func getLibraryPlaylistsPage(atOffset offset: Int, withOptionsDict optionsDict: [String: [Option]], completionHandler: @escaping ([String : [Option]]) -> Void) {
        if offset >= maxLibraryItems {
            completionHandler(optionsDict)
            return
        }
        
        let request = SpotifyURLFactory.createLibraryPlaylistsRequest(atOffset: offset)
        
        SpotifyFetcher.templateWebRequest(request) { [weak self] (data, _, _) in
            guard let self = self else { return }
            var optionsDict = optionsDict
            
            let json = try! JSON(data: data!)
            let playlistsJSON = json["items"].arrayValue
            for playlistJSON in playlistsJSON {
                let playlistName = playlistJSON["name"].stringValue
                
                let key = String(playlistName.capitalized.first ?? "#")
                
                let dummyTrack = Track()
                dummyTrack.id = playlistJSON["owner"]["id"].stringValue
                dummyTrack.name = playlistJSON["id"].stringValue
                
                if optionsDict[key] != nil {
                    optionsDict[key]!.append(Option(name: playlistName, tracks: [dummyTrack]))
                } else {
                    optionsDict[key] = [Option(name: playlistName, tracks: [dummyTrack])]
                }
            }
            
            let total = json["total"].intValue
            let maxTotal = min(total, self.maxLibraryItems)
            if offset + self.pageSize < maxTotal {
                self.getLibraryPlaylistsPage(atOffset: offset + self.pageSize, withOptionsDict: optionsDict, completionHandler: completionHandler)
            } else {
                completionHandler(optionsDict)
            }
        }
    }
    
    func convert(libraryTracks: [Track], trackHandler: @escaping (Track) -> Void, errorHandler: @escaping (Int) -> Void) {
        let dispatchGroup = DispatchGroup()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var notFoundCount = 0
            
            for (i, libraryTrack) in libraryTracks.enumerated() {
                let request = SpotifyURLFactory.createSearchRequest(forTerm: libraryTrack.name + " " + libraryTrack.artist)
                
                dispatchGroup.enter()
                let task = URLSession.shared.dataTask(with: request) { (data, response, _) in
                    if let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode == 200 {
                        let tracksJSON = try! JSON(data: data!)["tracks"]["items"].arrayValue
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
    
    func getMostPlayed(atOffset offset: Int, limit: Int, completionHandler: @escaping (Int) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let request = SpotifyURLFactory.createTopPlayedTracksRequest(limit: limit, offset: offset)
            
            SpotifyFetcher.templateWebRequest(request) { (data, _, _) in
                let tracksJSON = try! JSON(data: data!)["items"].arrayValue
                var newCount = 0
                for trackJSON in tracksJSON {
                    guard self != nil else { return }
                    self!.tracksList.append(self!.parse(json: trackJSON))
                    newCount += 1
                }
                completionHandler(newCount)
            }
        }
    }
    
    func getMostPlayed(completionHandler: @escaping () -> Void) {
        getMostPlayed(atOffset: 0, limit: 20) { _ in
            completionHandler()
        }
    }
    
    private func parse(json: JSON) -> Track {
        let track = Track()
        let trackJSON = json["track"].exists() ? json["track"] : json
                
        track.id = trackJSON["id"].stringValue
        track.name = trackJSON["name"].stringValue
        
        track.artist = trackJSON["artists"].arrayValue.first?["name"].stringValue ?? ""
        
        let artworkURLs = extractArtworkURLs(from: trackJSON)
        track.lowResArtworkURL = artworkURLs.lowRes
        track.highResArtworkURL = artworkURLs.highRes
        
        if tracksList.count < SpotifyConstants.maxInitialLowRes, !track.lowResArtworkURL.isEmpty {
            track.fetchImage(fromURL: track.lowResArtworkURL) { [weak track] (image) in
                track?.lowResArtwork = image
            }
        }
        
        track.length = TimeInterval(trackJSON["duration_ms"].doubleValue / 1000)
        
        return track
    }
    
    private func extractArtworkURLs(from json: JSON) -> (lowRes: String, highRes: String) {
        let images = json["album"]["images"].arrayValue
        
        var highResImage: (height: Int, url: String)?
        var lowResImage: (height: Int, url: String)?
        var smallestImage: (height: Int, url: String)?
        
        for image in images {
            let height = image["height"].intValue
            let url = image["url"].stringValue
            
            if highResImage == nil || height > highResImage!.height {
                highResImage = (height, url)
            }
            
            if height >= 300 {
                if lowResImage == nil || height < lowResImage!.height {
                    lowResImage = (height, url)
                }
            }
            
            if smallestImage == nil || height < smallestImage!.height {
                smallestImage = (height, url)
            }
        }
        
        let lowResURL = (lowResImage ?? smallestImage)?.url ?? ""
        let highResURL = highResImage?.url ?? ""
        return (lowResURL, highResURL)
    }
    
}
