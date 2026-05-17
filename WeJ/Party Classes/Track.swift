//
//  Track.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 1/19/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import Foundation
import MediaPlayer

class Track: NSObject, NSCoding, NSCopying {
    
    var id = String()
    var libraryID = String()
    var name = String()
    var artist = String()
    
    var lowResArtworkURL = String()
    var lowResArtwork: UIImage?
    
    var highResArtworkURL = String()
    var highResArtwork: UIImage?
    
    var length: TimeInterval?
    var isFromLibrary = false
    
    func fetchImage(fromURL urlString: String, completionHandler: @escaping (UIImage?) -> Void) {
        let errorHandler: () -> Void = {
            DispatchQueue.main.async {
                completionHandler(#imageLiteral(resourceName: "stockArtwork"))
            }
        }
        
        guard let url = URL(string: urlString) else {
            errorHandler()
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] (data, _, error) in
            guard self != nil else { return }
            
            guard error == nil, let data = data else {
                errorHandler()
                return
            }
            DispatchQueue.main.async {
                completionHandler(UIImage(data: data))
            }
        }
        
        task.resume()
    }
    
    static func typeOf(track: Track) -> RequestType {
        return track.id.hasPrefix("R:") ? .removal : .addition
    }
    
    static func convert(tracks: [MPMediaItem]) -> [Track] {
        var newTracks = [Track]()
        
        for track in tracks {
            let newTrack = Track()
            
            newTrack.id = String(track.persistentID)
            newTrack.libraryID = newTrack.id
            newTrack.name = track.title ?? ""
            newTrack.artist = track.artist ?? ""
            newTrack.lowResArtwork = track.artwork?.image(at: CGSize(width: 60, height: 60)) ?? #imageLiteral(resourceName: "stockArtwork")
            newTrack.highResArtwork = track.artwork?.image(at: CGSize(width: 400, height: 400))
            newTrack.length = track.playbackDuration
            newTrack.isFromLibrary = true
            
            newTracks.append(newTrack)
        }
        
        return newTracks
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(id, forKey: "id")
        aCoder.encode(libraryID, forKey: "libraryID")
        aCoder.encode(name, forKey: "name")
        aCoder.encode(artist, forKey: "artist")
        aCoder.encode(lowResArtworkURL, forKey: "lowResArtworkURL")
        aCoder.encode(lowResArtwork, forKey: "lowResArtwork")
        aCoder.encode(highResArtworkURL, forKey: "highResArtworkURL")
        aCoder.encode(highResArtwork, forKey: "highResArtwork")
        aCoder.encode(length, forKey: "length")
        aCoder.encode(isFromLibrary, forKey: "isFromLibrary")
    }
    
    convenience required init?(coder aDecoder: NSCoder) {
        let id = aDecoder.decodeObject(forKey: "id") as! String
        let libraryID = aDecoder.decodeObject(forKey: "libraryID") as? String
        let name = aDecoder.decodeObject(forKey: "name") as! String
        let artist = aDecoder.decodeObject(forKey: "artist") as! String
        let lowResArtworkURL = aDecoder.decodeObject(forKey: "lowResArtworkURL") as! String
        let lowResArtwork = aDecoder.decodeObject(forKey: "lowResArtwork") as? UIImage
        let highResArtworkURL = aDecoder.decodeObject(forKey: "highResArtworkURL") as! String
        let highResArtwork = aDecoder.decodeObject(forKey: "highResArtwork") as? UIImage
        let length = aDecoder.decodeObject(forKey: "length") as? TimeInterval
        let isFromLibrary = aDecoder.decodeBool(forKey: "isFromLibrary")
        
        self.init()
        
        self.id = id
        self.libraryID = libraryID ?? ""
        self.name = name
        self.artist = artist
        self.lowResArtworkURL = lowResArtworkURL
        self.lowResArtwork = lowResArtwork
        self.highResArtworkURL = highResArtworkURL
        self.highResArtwork = highResArtwork
        self.length = length
        self.isFromLibrary = isFromLibrary
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        let copy = Track()
        copy.id = id
        copy.libraryID = libraryID
        copy.name = name
        copy.artist = artist
        
        copy.lowResArtworkURL = lowResArtworkURL
        copy.lowResArtwork = lowResArtwork
        copy.highResArtworkURL = highResArtworkURL
        copy.highResArtwork = highResArtwork
        
        copy.length = length
        copy.isFromLibrary = isFromLibrary
        return copy
    }
    
    func hasSameIdentity(as track: Track) -> Bool {
        if !id.isEmpty && id == track.id {
            return true
        }
        
        if !libraryID.isEmpty && libraryID == track.libraryID {
            return true
        }
        
        if !libraryID.isEmpty && libraryID == track.id {
            return true
        }
        
        if !track.libraryID.isEmpty && id == track.libraryID {
            return true
        }
        
        return false
    }
}
