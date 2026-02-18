//
//  Party.swift
//  WeJ
//
//  Created by Matthew Paletta on 2016-11-14.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import Foundation

class Party: NSObject, NSCoding {
    
    static weak var delegate: UpdatePartyDelegate?
    
    static var name: String? {
        didSet {
            delegate?.hubAndQueueVC?.updateHubTitle()
        }
    }
    static var musicService = MusicService.spotify
    
    static var tracksQueue = [Track]() {
        didSet {
            delegate?.updateCache()
            delegate?.updateEveryonesTableView()
            if !tracksQueue.isEmpty {
                delegate?.showCurrentlyPlayingArtwork()
            }
            if oldValue.isEmpty && !tracksQueue.isEmpty || tracksQueue.count == 1 {
                delegate?.hubAndQueueVC?.minimizeTracksTable()
            }
        }
    }
    static var tracksFromMyself = [Track]()
    static var cookie: String? { // Represents Spotify access token or Apple Music country code
        didSet {
            DispatchQueue.main.async {
                delegate?.hubAndQueueVC?.showAddButton()
            }
        }
    }
    
    static func reset() {
        name = nil
        musicService = .spotify
        tracksQueue.removeAll()
        tracksFromMyself.removeAll()
        cookie = nil
    }
    
    static func tracksQueue(hasTrack track: Track) -> Bool {
        return Party.tracksQueue.contains(where: { $0.id == track.id })
    }
    
    // MARK: - NSCoding
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(Party.name, forKey: "name")
        aCoder.encode(Party.musicService.rawValue, forKey: "musicService")
        aCoder.encode(Party.cookie, forKey: "cookie")
    }
    
    convenience required init?(coder aDecoder: NSCoder) {
        let name = aDecoder.decodeObject(forKey: "name") as? String
        let musicService = aDecoder.decodeObject(forKey: "musicService") as! String
        let cookie = aDecoder.decodeObject(forKey: "cookie") as? String
        
        self.init()
        
        Party.name = name
        Party.musicService = MusicService(rawValue: musicService)!
        Party.cookie = cookie
    }
    
}
