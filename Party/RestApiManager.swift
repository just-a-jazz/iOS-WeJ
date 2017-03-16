//
//  RestApiManager.swift
//  Party
//
//  Created by Ali Siddiqui on 1/19/17.
//  Copyright © 2017 Ali Siddiqui and Matthew Paletta. All rights reserved.
//

import Foundation
import StoreKit
import SwiftyJSON
import MultipeerConnectivity

class RestApiManager {
    
    // Apple Music Variables
    private var appleTracksUrl = "https://itunes.apple.com/search?media=music&term="
    private let genresUrl = "https://itunes.apple.com/WebObjects/MZStoreServices.woa/ws/genres?id=34"
    private let serviceController = SKCloudServiceController()
    private var storefrontIdentifierFound = String()
    
    // Spotify Variables
    private var spotifyTracksUrl = "https://api.spotify.com/v1/"
    
    // General Variables
    var tracksList = [Track]()
    var genresList = [String]()
    
    let dispatchGroup = DispatchGroup()
    let dispatchGroupForStorefrontFetch = DispatchGroup()
    let dispatchGroupForGenreFetch = DispatchGroup()
    var latestRequest = [MCPeerID: [String]]()
    
    // MARK: - Apple Music
    
    func makeHTTPRequestToApple(withString string: String) {
        dispatchGroup.enter()
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            // Get storefront identifer to ensure tracks returned are playable by the user
            if self.storefrontIdentifierFound.isEmpty {
                self.dispatchGroupForStorefrontFetch.enter()
                self.fetchStorefrontIdentifier()
                self.dispatchGroupForStorefrontFetch.wait()
            }
            
            let requestURL = URL(string: self.appleTracksUrl + string.replacingOccurrences(of: " ", with: "+") + "&s=" + self.storefrontIdentifierFound)
            
            let task = URLSession.shared.dataTask(with: requestURL!) { (data, response, error) in
                if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                    if statusCode == 200 {
                        let json = JSON(data: data!)
                        self.parseAppleTrackJSON(forJSON: json)
                    }
                }
                
                self.dispatchGroup.leave()
            }
            
            task.resume()
        }
        
    }
    
    func fetchStorefrontIdentifier() {
        serviceController.requestStorefrontIdentifier { (storefrontIdentifier, error) in
            if let storefrontId = storefrontIdentifier, storefrontId.characters.count >= 6 {
                let range = storefrontId.startIndex...storefrontId.index(storefrontId.startIndex, offsetBy: 5)
                self.storefrontIdentifierFound = storefrontId[range]
            }
            
            self.dispatchGroupForStorefrontFetch.leave()
        }
    }
    
    func parseAppleTrackJSON(forJSON json: JSON) {
        tracksList.removeAll()
        for track in json["results"].arrayValue {
            let newTrack = Track()
            newTrack.id = track["trackId"].stringValue
            newTrack.name = track["trackName"].stringValue
            newTrack.artist = track["artistName"].stringValue
            newTrack.album = track["collectionName"].stringValue
            
            newTrack.lowResArtworkURL = track["artworkUrl100"].stringValue
            newTrack.artwork = fetchImage(fromURL: newTrack.lowResArtworkURL)
            newTrack.highResArtworkURL = newTrack.lowResArtworkURL.replacingOccurrences(of: "100x100", with: "600x600")
            newTrack.highResArtwork = fetchImage(fromURL: newTrack.highResArtworkURL)
            
            newTrack.length = TimeInterval(track["trackTimeMillis"].doubleValue / 1000)
            
            tracksList.append(newTrack)
        }
    }
    
    func makeHTTPRequestToAppleForSingleTrack(forID id: String) {
        dispatchGroup.enter()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let requestURL = URL(string: self.spotifyTracksUrl + "tracks/" + id)
            
            let task = URLSession.shared.dataTask(with: requestURL!) { (data, response, error) in
                if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                    if statusCode == 200 {
                        let json = JSON(data: data!)
                        self.parseSingleSpotifyTrackJSON(forTrack: json)
                    }
                }
                self.dispatchGroup.leave()
            }
            
            task.resume()
        }
    }
    
    func getAuthentication() -> SPTAuth? {
        let auth = SPTAuth.defaultInstance()
        auth?.clientID = "308657d9662146ecae57855ac2a01045"
        auth?.redirectURL = URL(string: "partyapp://returnafterlogin")
        auth?.requestedScopes = [SPTAuthStreamingScope]
        
        return auth
        
    }
    
    // MARK: - Spotify
    
    func makeHTTPRequestToSpotify(withString string: String) {
        dispatchGroup.enter()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let requestURL = URL(string: self.spotifyTracksUrl + "search?q=" + string.replacingOccurrences(of: " ", with: "+") + "&type=track")
            
            let task = URLSession.shared.dataTask(with: requestURL!) { (data, response, error) in
                if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                    if statusCode == 200 {
                        let json = JSON(data: data!)
                        self.parseMultipleSpotifyTracksJSON(forJSON: json)
                    }
                }
                self.dispatchGroup.leave()
            }
                
            task.resume()
        }
    }
    
    func parseMultipleSpotifyTracksJSON(forJSON json: JSON) {
        tracksList.removeAll()
        for (type,subJson):(String, JSON) in json["tracks"] {
            if type == "items" {
                for track in subJson.arrayValue {
                    let newTrack = Track()
                    
                    newTrack.id = track["id"].stringValue
                    newTrack.name = track["name"].stringValue
                    
                    for artists in track["artists"].arrayValue { //get other artists too
                        newTrack.artist = artists["name"].stringValue
                        break
                    }
                    
                    for images in track["album"]["images"].arrayValue {
                        if images["height"].stringValue == "640" {
                            newTrack.highResArtworkURL = images["url"].stringValue
                        }
                        if images["height"].stringValue == "64" {
                            newTrack.lowResArtworkURL = images["url"].stringValue
                            newTrack.artwork = fetchImage(fromURL: newTrack.lowResArtworkURL)
                        }
                    }
                    
                    newTrack.length = TimeInterval(track["duration_ms"].doubleValue / 1000)
                    
                    tracksList.append(newTrack)
                }
            }
        }
    }
    
    func fetchImage(fromURL urlString: String) -> UIImage? {
        if let url = URL(string: urlString) {
            do {
                let data = try Data(contentsOf: url)
                return UIImage(data: data)
            } catch {
                print("Error trying to get data from Artwork URL")
            }
        }
        return nil
    }
    
    func makeHTTPRequestToSpotifyForSingleTrack(forID id: String) {
        dispatchGroup.enter()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let requestURL = URL(string: self.spotifyTracksUrl + "tracks/" + id)
            
            let task = URLSession.shared.dataTask(with: requestURL!) { (data, response, error) in
                if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                    if statusCode == 200 {
                        let json = JSON(data: data!)
                        self.parseSingleSpotifyTrackJSON(forTrack: json)
                    }
                }
                self.dispatchGroup.leave()
            }
                
            task.resume()
        }
    }
    
    func parseSingleSpotifyTrackJSON(forTrack track: JSON) {
        let newTrack = Track()
        
        newTrack.id = track["id"].stringValue
        newTrack.name = track["name"].stringValue
        
        for artists in track["artists"].arrayValue { //get other artists too
            newTrack.artist = artists["name"].stringValue
            break
        }
        
        for images in track["album"]["images"].arrayValue {
            if images["height"].stringValue == "640" {
                newTrack.highResArtworkURL = images["url"].stringValue
            }
            if images["height"].stringValue == "64" {
                newTrack.lowResArtworkURL = images["url"].stringValue
                newTrack.artwork = fetchImage(fromURL: newTrack.lowResArtworkURL)
            }
            
        }
        
        newTrack.length = TimeInterval(track["duration_ms"].doubleValue / 1000)
        
        tracksList.append(newTrack)
    }
}
