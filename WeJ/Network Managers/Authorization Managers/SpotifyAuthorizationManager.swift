//
//  SpotifyAuthorizationManager.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 7/26/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import UIKit
import AuthenticationServices
import SpotifyiOS

class SpotifyAuthorizationManager: NSObject, AuthorizationManager, SPTSessionManagerDelegate {
    
    static weak var delegate: ViewControllerAccessDelegate?
    static var storyboardSegue: String!
    
    static let shared = SpotifyAuthorizationManager()
    
    private let configuration: SPTConfiguration
    private let sessionManager: SPTSessionManager
    private let webAuthScopes = ["user-library-read", "playlist-read-private", "streaming", "user-top-read", "app-remote-control"]
    private let spotifyAuthSession: URLSession
    lazy var appRemote: SPTAppRemote = {
        SPTAppRemote(configuration: configuration, logLevel: .none)
    }()
    
    private static let webAccessTokenDefaultsKey = "spotifyWebAccessToken"
    private static let webRefreshTokenDefaultsKey = "spotifyWebRefreshToken"
    private static let webTokenExpiryDefaultsKey = "spotifyWebTokenExpiry"
    
    private var webAuthenticationSession: ASWebAuthenticationSession?
    private var isWebAuthInProgress = false
    
    override init() {
        let configuration = SPTConfiguration(clientID: SpotifyConstants.clientID, redirectURL: SpotifyConstants.redirectURL)
        configuration.tokenSwapURL = SpotifyConstants.swapURL
        configuration.tokenRefreshURL = SpotifyConstants.refreshURL
        self.configuration = configuration
        self.sessionManager = SPTSessionManager(configuration: configuration, delegate: nil)
        
        let urlSessionConfiguration = URLSessionConfiguration.default
        urlSessionConfiguration.waitsForConnectivity = false
        urlSessionConfiguration.timeoutIntervalForRequest = 15
        urlSessionConfiguration.timeoutIntervalForResource = 30
        self.spotifyAuthSession = URLSession(configuration: urlSessionConfiguration)
        
        super.init()
        
        self.sessionManager.delegate = self
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        SpotifyAuthorizationManager.delegate?.processingLogin = true
        
        if let token = loadStoredValidWebAccessToken() {
            Party.spotifyAccessToken = token
            completeAuthorization()
            finishProcessingLogin()
            return
        }
        
        if let refreshToken = loadStoredWebRefreshToken() {
            refreshWebAccessToken(refreshToken)
            return
        }
        
        requestWebAuthorization()
    }
    
    // MARK: - App Delegate Callbacks
    
    static func handleAuthCallback(application: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
        let manager = shared
        if manager.handleWebAuthCallback(url) {
            return true
        }
        if manager.handleAppRemoteCallback(url) {
            return true
        }
        return manager.sessionManager.application(application, open: url, options: options)
    }
    
    static func handleUserActivity(application: UIApplication, userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return shared.sessionManager.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
    
    // MARK: - SPTSessionManagerDelegate
    
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        finishProcessingLogin()
    }
    
    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        handleAuthorizationFailure(error)
    }
    
    func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        finishProcessingLogin()
    }
    
    func sessionManager(manager: SPTSessionManager, shouldRequestAccessTokenWith authorizationCode: String) -> Bool {
        return true
    }
    
    // MARK: - Completion
    
    private func completeAuthorization() {
        DispatchQueue.main.async {
            SpotifyAuthorizationManager.delegate?.performSegue(withIdentifier: SpotifyAuthorizationManager.storyboardSegue, sender: nil)
        }
    }
    
    private func handleAuthorizationFailure(_ error: Error) {
        let nsError = error as NSError
        if nsError.code == NSURLErrorNotConnectedToInternet {
            SpotifyAuthorizationManager.postAlertForInternet()
        } else if nsError.code == 9 {
            SpotifyAuthorizationManager.postAlertForSpotifyPremium()
            sessionManager.session = nil
        }
        
        finishProcessingLogin()
    }
    
    private func finishProcessingLogin() {
        DispatchQueue.main.async {
            SpotifyAuthorizationManager.delegate?.processingLogin = false
        }
    }
    
    // MARK: - Web Authorization
    
    private func requestWebAuthorization() {
        isWebAuthInProgress = true
        
        let authURL = SpotifyURLFactory.createWebAuthorizationURL(withScopes: webAuthScopes)
        let callbackScheme = SpotifyConstants.redirectURL.scheme
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { [weak self] url, error in
            self?.handleWebAuthCallback(url, error: error)
        }
        session.presentationContextProvider = self
        self.webAuthenticationSession = session
        session.start()
    }
    
    private func handleWebAuthCallback(_ url: URL?, error: Error? = nil) {
        isWebAuthInProgress = false
        
        if let error = error as NSError? {
            if error.code == NSURLErrorNotConnectedToInternet {
                SpotifyAuthorizationManager.postAlertForInternet()
            } else {
                SpotifyAuthorizationManager.postAlertForAuthServer()
            }
            finishProcessingLogin()
            return
        }
        
        guard let url = url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            SpotifyAuthorizationManager.postAlertForAuthServer()
            finishProcessingLogin()
            return
        }
        
        let queryItems = components.queryItems ?? []
        if let _ = queryItems.first(where: { $0.name == "error" })?.value {
            SpotifyAuthorizationManager.postAlertForAuthServer()
            finishProcessingLogin()
            return
        }
        
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            SpotifyAuthorizationManager.postAlertForAuthServer()
            finishProcessingLogin()
            return
        }
        
        exchangeCodeForWebAccessToken(code)
    }
    
    private func handleWebAuthCallback(_ url: URL) -> Bool {
        guard isWebAuthInProgress, url.scheme == SpotifyConstants.redirectURL.scheme else { return false }
        handleWebAuthCallback(url, error: nil)
        return true
    }
    
    private func handleAppRemoteCallback(_ url: URL) -> Bool {
        guard let parameters = appRemote.authorizationParameters(from: url),
              let accessToken = parameters[SPTAppRemoteAccessTokenKey] else {
            return false
        }
        
        appRemote.connectionParameters.accessToken = accessToken
        appRemote.connect()
        return true
    }
    
    private func exchangeCodeForWebAccessToken(_ code: String) {
        let request = SpotifyURLFactory.createTokenSwapRequest(withCode: code)
        
        spotifyAuthSession.dataTask(with: request) { [weak self] data, response, error in
            self?.handleTokenResponse(data: data, response: response, error: error)
        }.resume()
    }
    
    private func refreshWebAccessToken(_ refreshToken: String) {
        let request = SpotifyURLFactory.createTokenRefreshRequest(withRefreshToken: refreshToken)
        
        spotifyAuthSession.dataTask(with: request) { [weak self] data, response, error in
            self?.handleTokenResponse(data: data, response: response, error: error, fallbackRefreshToken: refreshToken)
        }.resume()
    }
    
    private func handleTokenResponse(data: Data?, response: URLResponse?, error: Error?, fallbackRefreshToken: String? = nil) {
        guard let tokenResponse = processTokenResponse(data: data, response: response, error: error, fallbackRefreshToken: fallbackRefreshToken, notifyOnError: true) else {
            finishProcessingLogin()
            return
        }
        
        updateStoredTokens(with: tokenResponse)
        completeAuthorization()
        finishProcessingLogin()
    }
    
    static func ensureValidWebAccessToken() {
        let manager = shared
        if let token = manager.loadStoredValidWebAccessToken() {
            Party.spotifyAccessToken = token
            return
        }
        
        guard let refreshToken = manager.loadStoredWebRefreshToken() else { return }
        manager.refreshWebAccessTokenSync(refreshToken)
    }
    
    private func refreshWebAccessTokenSync(_ refreshToken: String) {
        let request = SpotifyURLFactory.createTokenRefreshRequest(withRefreshToken: refreshToken)
        
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        
        var tokenResponse: WebTokenResponse?
        spotifyAuthSession.dataTask(with: request) { [weak self] data, response, error in
            tokenResponse = self?.processTokenResponse(data: data, response: response, error: error, fallbackRefreshToken: refreshToken, notifyOnError: false)
            dispatchGroup.leave()
        }.resume()
        
        dispatchGroup.wait()
        
        guard let response = tokenResponse else { return }
        updateStoredTokens(with: response)
    }
    
    private struct WebTokenResponse {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Double
    }
    
    private func processTokenResponse(data: Data?, response: URLResponse?, error: Error?, fallbackRefreshToken: String?, notifyOnError: Bool) -> WebTokenResponse? {
        if let error = error as NSError? {
            if notifyOnError {
                if error.code == NSURLErrorNotConnectedToInternet {
                    SpotifyAuthorizationManager.postAlertForInternet()
                } else {
                    SpotifyAuthorizationManager.postAlertForAuthServer()
                }
            }
            return nil
        }
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if notifyOnError {
                SpotifyAuthorizationManager.postAlertForAuthServer()
            }
            return nil
        }
        
        guard let data = data else { return nil }
        guard let tokenResponse = parseWebTokenResponse(data: data, fallbackRefreshToken: fallbackRefreshToken) else {
            if notifyOnError {
                SpotifyAuthorizationManager.postAlertForAuthServer()
            }
            return nil
        }
        
        return tokenResponse
    }
    
    private func parseWebTokenResponse(data: Data, fallbackRefreshToken: String?) -> WebTokenResponse? {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? Double else {
            return nil
        }
        
        let refreshToken = (json["refresh_token"] as? String) ?? fallbackRefreshToken
        return WebTokenResponse(accessToken: accessToken, refreshToken: refreshToken, expiresIn: expiresIn)
    }
    
    // MARK: - Storage
    
    private func updateStoredTokens(with response: WebTokenResponse) {
        storeWebTokens(accessToken: response.accessToken, refreshToken: response.refreshToken, expiresIn: response.expiresIn)
        Party.spotifyAccessToken = response.accessToken
    }
    
    private func storeWebTokens(accessToken: String, refreshToken: String?, expiresIn: Double) {
        let expiryDate = Date.now.addingTimeInterval(expiresIn - 60)
        let defaults = UserDefaults.standard
        defaults.set(accessToken, forKey: SpotifyAuthorizationManager.webAccessTokenDefaultsKey)
        defaults.set(expiryDate, forKey: SpotifyAuthorizationManager.webTokenExpiryDefaultsKey)
        if let refreshToken = refreshToken {
            defaults.set(refreshToken, forKey: SpotifyAuthorizationManager.webRefreshTokenDefaultsKey)
        }
        defaults.synchronize()
    }
    
    private func loadStoredValidWebAccessToken() -> String? {
        let defaults = UserDefaults.standard
        guard let token = defaults.string(forKey: SpotifyAuthorizationManager.webAccessTokenDefaultsKey),
              let expiryDate = defaults.object(forKey: SpotifyAuthorizationManager.webTokenExpiryDefaultsKey) as? Date,
              expiryDate > Date.now else {
            return nil
        }
        
        return token
    }
    
    private func loadStoredWebRefreshToken() -> String? {
        return UserDefaults.standard.string(forKey: SpotifyAuthorizationManager.webRefreshTokenDefaultsKey)
    }

    static func clearStoredWebTokens() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: SpotifyAuthorizationManager.webAccessTokenDefaultsKey)
        defaults.removeObject(forKey: SpotifyAuthorizationManager.webRefreshTokenDefaultsKey)
        defaults.removeObject(forKey: SpotifyAuthorizationManager.webTokenExpiryDefaultsKey)
        defaults.synchronize()
        Party.spotifyAccessToken = nil
        shared.sessionManager.session = nil
    }
    
    // MARK: - Alerts
    
    private static func postAlertForInternet() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: NSLocalizedString("Error", comment: ""), message: NSLocalizedString("Please check your internet connection", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Try Again", comment: ""), style: .default) { _ in
                delegate?.tryAgain()
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
            
            delegate?.present(alert, animated: true, completion: nil)
        }
    }
    
    private static func postAlertForSpotifyPremium() {
        let alert = UIAlertController(title: NSLocalizedString("No Spotify Premium", comment: ""), message: NSLocalizedString("A Spotify Premium account is required to play music", comment: ""), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
        
        delegate?.present(alert, animated: true, completion: nil)
    }
    
    private static func postAlertForAuthServer() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: NSLocalizedString("Error", comment: ""), message: NSLocalizedString("Unable to reach the Authorization Server", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Try Again", comment: ""), style: .default) { _ in
                delegate?.tryAgain()
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
            
            delegate?.present(alert, animated: true, completion: nil)
        }
    }
    
}

extension SpotifyAuthorizationManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.windows.first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }
}
