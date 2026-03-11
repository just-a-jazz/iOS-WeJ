//
//  AppleMusicURLFactory.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 7/31/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import Foundation

struct AppleMusicURLFactory {
    private static let baseAppleMusicAPI = "api.music.apple.com"
    
    static func createDeveloperTokenRequest() -> URLRequest {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = PrivateConfig.webServerURL
        urlComponents.path = "/apple/token"
        
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.httpMethod = "GET"
                
        return urlRequest
    }
    
    static func createSearchRequest(forTerm term: String) async -> URLRequest? {
        guard let developerToken = await AppleMusicAuthorizationManager.ensureDeveloperToken(),
              let storefront = Party.appleMusicStorefront else {
            return nil
        }
        
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty else { return nil }
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = baseAppleMusicAPI
        urlComponents.path = "/v1/catalog/\(storefront)/search"
        
        urlComponents.queryItems = [
            URLQueryItem(name: "term", value: trimmedTerm),
            URLQueryItem(name: "types", value: "songs"),
            URLQueryItem(name: "limit", value: "25")
        ]
        
        guard let url = urlComponents.url else { return nil }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.addValue("Bearer \(developerToken)", forHTTPHeaderField: "Authorization")
        
        return urlRequest
    }
    
    static func createSearchHintsRequest(forTerm term: String) async -> URLRequest? {
        guard let developerToken = await AppleMusicAuthorizationManager.ensureDeveloperToken() else {
            return nil
        }
        
        let disallowedChars = CharacterSet(charactersIn: "()[],'.!?")
        let escapedTerm = term.components(separatedBy: disallowedChars).joined(separator: " ").replacedWhiteSpaceForURL
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = baseAppleMusicAPI
        urlComponents.path = "/v1/catalog/us/search/hints"
        
        let urlParameters = ["term": escapedTerm,
                             "types": "songs",
                             "limit": "7"]
        var queryItems = [URLQueryItem]()
        for (key, value) in urlParameters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else { return nil }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.addValue("Bearer \(developerToken)", forHTTPHeaderField: "Authorization")
        
        return urlRequest
    }
    
    static func createTrackRequest(forID id: String) async -> URLRequest? {
        guard let developerToken = await AppleMusicAuthorizationManager.ensureDeveloperToken(),
              let storefront = Party.appleMusicStorefront else {
            return nil
        }
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = baseAppleMusicAPI
        urlComponents.path = "/v1/catalog/\(storefront)/songs/\(id.components(separatedBy: ":")[1])"
        
        guard let url = urlComponents.url else { return nil }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.addValue("Bearer \(developerToken)", forHTTPHeaderField: "Authorization")
        
        return urlRequest
    }
}
