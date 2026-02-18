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
                
                if json["total"].intValue > offset + 50 {
                    self?.getLibraryAlbums(atOffset: offset + 50, withOptionsDict: optionsDict, completionHandler: completionHandler)
                } else {
                    completionHandler(optionsDict)
                }
            }
        }
    }
    
    func getLibraryAlbumTracks(atOffset offset: Int, forDummyTrack track: Track, completionHandler: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
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
                
                if json["total"].intValue > offset + 50 {
                    self?.getLibraryAlbumTracks(atOffset: offset + 50, forDummyTrack: track, completionHandler: completionHandler)
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
            let request = SpotifyURLFactory.createLibraryPlaylistsRequest()
            
            SpotifyFetcher.templateWebRequest(request) { (data, response, _) in
                var optionsDict = [String: [Option]]()
                
                let playlistsJSON = try! JSON(data: data!)["items"].arrayValue
                for playlistJSON in playlistsJSON {
                    let playlistName = playlistJSON["name"].stringValue
                    
                    let key = String(playlistName.capitalized.first ?? "#")
                    
                    let dummyTrack = Track()
                    dummyTrack.id = playlistJSON["owner"]["id"].stringValue //ownerID
                    dummyTrack.name = playlistJSON["id"].stringValue //playlistID
                    
                    if optionsDict[key] != nil {
                        optionsDict[key]!.append(Option(name: playlistName, tracks: [dummyTrack]))
                    } else {
                        optionsDict[key] = [Option(name: playlistName, tracks: [dummyTrack])]
                    }
                }
                completionHandler(optionsDict)
            }
        }
    }
    
    func getLibraryPlaylistTracks(atOffset offset: Int, forDummyTrack track: Track, completionHandler: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let request = SpotifyURLFactory.createLibraryPlaylistTracksRequest(atOffset: offset, forOwnerID: track.id, forPlaylistID: track.name)
            
            SpotifyFetcher.templateWebRequest(request) { [weak self] (data, response, _) in
                let json = try! JSON(data: data!)
                let tracksJSON = json["items"].arrayValue
                for trackJSON in tracksJSON {
                    guard self != nil else { return }
                    self!.tracksList.append(self!.parse(json: trackJSON["track"]))
                }
                
                if json["total"].intValue > offset + 50 {
                    self?.getLibraryPlaylistTracks(atOffset: offset + 50, forDummyTrack: track, completionHandler: completionHandler)
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
    
    func getMostPlayed(completionHandler: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.getID { (ownerID, playlistID) in
                let request = SpotifyURLFactory.createPlaylistsRequest(forOwnerID: ownerID, forPlaylistID: playlistID)
                
                SpotifyFetcher.templateWebRequest(request) {(data, response, _) in
                    let tracksJSON = try! JSON(data: data!)["tracks"]["items"].arrayValue
                    for (i, trackJSON) in tracksJSON.enumerated() where i < 20 {
                        guard self != nil else { return }
                        self!.tracksList.append(self!.parse(json: trackJSON["track"]))
                    }
                    completionHandler()
                }
            }
        }
    }
    
    private func getID(completionHandler: @escaping (String, String) -> Void) {
        let request = SpotifyURLFactory.createTopPlayedTracksRequest()
        
        SpotifyFetcher.templateWebRequest(request) { (data, response, _) in
            let trackItemsJSON = try! JSON(data: data!)["items"].arrayValue
            print(trackItemsJSON)
//            if let playlistJSON = playlistsJSON.first {
//                let ownerID = playlistJSON["owner"]["id"].stringValue
//                let playlistID = playlistJSON["id"].stringValue
//                completionHandler(ownerID, playlistID)
//            }
        }
    }
    
    private func parse(json: JSON) -> Track {
        let track = Track()
        
        track.id = json["id"].stringValue
        track.name = json["name"].stringValue
        
        track.artist = json["artists"].arrayValue[0]["name"].stringValue
        
        for images in json["album"]["images"].arrayValue {
            if images["height"].stringValue == "64" {
                track.lowResArtworkURL = images["url"].stringValue
                if tracksList.count < SpotifyConstants.maxInitialLowRes {
                    track.fetchImage(fromURL: track.lowResArtworkURL) { [weak track] (image) in
                        track?.lowResArtwork = image
                    }
                }
            }
            
            if images["height"].stringValue == "640" {
                track.highResArtworkURL = images["url"].stringValue
            }
        }
        
        track.length = TimeInterval(json["duration_ms"].doubleValue / 1000)
        
        return track
    }
    
}
