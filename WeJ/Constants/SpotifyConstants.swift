//
//  SpotifyConstants.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 7/27/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import Foundation

struct SpotifyConstants {
    
    static let spotifyPlayerDidLoginNotification = Notification.Name("spotifyPlayerDidLoginNotification")
    
    static let clientID = PrivateConfig.spotifyClientID
    
    static let redirectURL = PrivateConfig.spotifyRedirectURL
    static let swapURL = URL(string: "https://\(PrivateConfig.webServerURL)/spotify/swap")
    static let refreshURL = URL(string: "https://\(PrivateConfig.webServerURL)/spotify/refresh")
    
    static let maxInitialLowRes = 5
    
}
