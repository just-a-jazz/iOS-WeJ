//
//  SpotifyURLFactory.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 7/27/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import Foundation

struct SpotifyURLFactory {

    private static let baseSpotifyWebAPI = "api.spotify.com"
    private static let baseSpotifyAccountsAPI = "accounts.spotify.com"
    
    static func createSearchRequest(forTerm term: String) -> URLRequest {
        let disallowedChars = CharacterSet(charactersIn: "()[],.!?")
        let escapedTerm = term.components(separatedBy: disallowedChars).joined(separator: " ").replacedWhiteSpaceForURL
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = baseSpotifyWebAPI
        urlComponents.path = "/v1/search"
        
        let urlParameters = ["q": escapedTerm,
                             "type": "track"]
        var queryItems = [URLQueryItem]()
        for (key, value) in urlParameters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        urlComponents.queryItems = queryItems
        
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.addValue("Bearer \(Party.spotifyAccessToken!)", forHTTPHeaderField: "Authorization")
        
        return urlRequest
    }
    
    static func createTrackRequest(forID id: String) -> URLRequest {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = baseSpotifyWebAPI
        urlComponents.path = "/v1/tracks/\(id.components(separatedBy: ":")[1])"
        
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.addValue("Bearer \(Party.spotifyAccessToken!)", forHTTPHeaderField: "Authorization")
        
        return urlRequest
    }
    
    static func createLibraryAlbumsRequest(atOffset offset: Int) -> URLRequest {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = baseSpotifyWebAPI
        urlComponents.path = "/v1/me/albums"
        
        let urlParameters = ["limit": "50",
                             "offset": String(offset)]
        var queryItems = [URLQueryItem]()
        for (key, value) in urlParameters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        urlComponents.queryItems = queryItems
        
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.addValue("Bearer \(Party.spotifyAccessToken!)", forHTTPHeaderField: "Authorization")
        
        return urlRequest
    }
    
    static func createLibraryAlbumsTracksRequest(atOffset offset: Int, forID id: String) -> URLRequest {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = baseSpotifyWebAPI
        urlComponents.path = "/v1/albums/\(id)/tracks"
        
        let urlParameters = ["limit": "50",
                             "offset": String(offset)]
        var queryItems = [URLQueryItem]()
        for (key, value) in urlParameters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        urlComponents.queryItems = queryItems
        
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.addValue("Bearer \(Party.spotifyAccessToken!)", forHTTPHeaderField: "Authorization")
        
        return urlRequest
    }
    
    static func createLibraryPlaylistsRequest(atOffset offset: Int) -> URLRequest {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = baseSpotifyWebAPI
        urlComponents.path = "/v1/me/playlists"
        
        let urlParameters = ["limit": "50",
                             "offset": String(offset)]
        var queryItems = [URLQueryItem]()
        for (key, value) in urlParameters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        urlComponents.queryItems = queryItems
        
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.addValue("Bearer \(Party.spotifyAccessToken!)", forHTTPHeaderField: "Authorization")
        
        return urlRequest
    }
    
    static func createLibraryPlaylistTracksRequest(atOffset offset: Int, forPlaylistID playlistID: String) -> URLRequest {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = baseSpotifyWebAPI
        urlComponents.path = "/v1/playlists/\(playlistID)/items"
        
        let urlParameters = ["limit": "50",
                             "offset": String(offset)]
        var queryItems = [URLQueryItem]()
        for (key, value) in urlParameters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        urlComponents.queryItems = queryItems
        
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.addValue("Bearer \(Party.spotifyAccessToken!)", forHTTPHeaderField: "Authorization")
        
        return urlRequest
    }
    
    static func createLibraryTracksRequest(atOffset offset: Int) -> URLRequest {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = baseSpotifyWebAPI
        urlComponents.path = "/v1/me/tracks"
        
        let urlParameters = ["limit": "50",
                             "offset": String(offset)]
        var queryItems = [URLQueryItem]()
        for (key, value) in urlParameters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        urlComponents.queryItems = queryItems
        
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.addValue("Bearer \(Party.spotifyAccessToken!)", forHTTPHeaderField: "Authorization")
        
        return urlRequest
    }
    
    static func createPlaylistsRequest(forOwnerID ownerID: String, forPlaylistID playlistID: String) -> URLRequest {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = baseSpotifyWebAPI
        urlComponents.path = "/v1/users/\(ownerID)/playlists/\(playlistID)"
        
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.addValue("Bearer \(Party.spotifyAccessToken!)", forHTTPHeaderField: "Authorization")
        
        return urlRequest
    }
    
    static func createTopPlayedTracksRequest(limit: Int, offset: Int) -> URLRequest {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = baseSpotifyWebAPI
        urlComponents.path = "/v1/me/top/tracks"
        
        let urlParameters = ["limit": String(limit),
                             "offset": String(offset)]
        var queryItems = [URLQueryItem]()
        for (key, value) in urlParameters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        urlComponents.queryItems = queryItems
        
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.addValue("Bearer \(Party.spotifyAccessToken!)", forHTTPHeaderField: "Authorization")
        
        return urlRequest
    }
    
    static func createWebAuthorizationURL(withScopes scopes: [String]) -> URL {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = baseSpotifyAccountsAPI
        urlComponents.path = "/authorize"
        urlComponents.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: SpotifyConstants.clientID),
            URLQueryItem(name: "redirect_uri", value: SpotifyConstants.redirectURL.absoluteString),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " "))
        ]
        
        return urlComponents.url!
    }
    
    static func createTokenSwapRequest(withCode code: String) -> URLRequest {
        var request = URLRequest(url: SpotifyConstants.swapURL!)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let redirectValue = SpotifyConstants.redirectURL.absoluteString
        let body = "code=\(code)&redirect_uri=\(redirectValue)"
        request.httpBody = body.data(using: .utf8)
        
        return request
    }
    
    static func createTokenRefreshRequest(withRefreshToken refreshToken: String) -> URLRequest {
        var request = URLRequest(url: SpotifyConstants.refreshURL!)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "refresh_token=\(refreshToken)".data(using: .utf8)
        
        return request
    }
    
}
