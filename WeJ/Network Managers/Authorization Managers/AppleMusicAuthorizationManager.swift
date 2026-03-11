//
//  AppleMusicAuthorizationManager.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 7/26/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import Foundation
import MusicKit
import StoreKit
import UIKit
import MediaPlayer

protocol AuthorizationManager {
    func requestAuthorization()
}

class AppleMusicAuthorizationManager: NSObject, AuthorizationManager {
    
    static weak var delegate: ViewControllerAccessDelegate?
    
    static var developerToken: String!
    static var storyboardSegue: String!
    
    static func requestDeveloperToken() async -> String? {
        if !PrivateConfig.appleMusicDeveloperToken.isEmpty {
            developerToken = PrivateConfig.appleMusicDeveloperToken
            return developerToken
        }

        let request = AppleMusicURLFactory.createDeveloperTokenRequest()
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let statusCode = (response as? HTTPURLResponse)?.statusCode,
               statusCode == 200 {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let token = json?["token"] as? String else {
                    throw NSError(domain: "AppleMusicAuthorizationManager", code: 1)
                }
                developerToken = token
            }
        } catch {
            developerToken = nil
        }

        return developerToken
    }

    static func ensureDeveloperToken() async -> String? {
        if let token = developerToken, !token.isEmpty {
            return token
        }
        return await requestDeveloperToken()
    }

    static func ensureMediaLibraryAccess(completionHandler: @escaping (Bool) -> Void) {
        let status = MPMediaLibrary.authorizationStatus()
        if status == .authorized {
            completionHandler(true)
            return
        }

        MPMediaLibrary.requestAuthorization { newStatus in
            completionHandler(newStatus == .authorized)
        }
    }
    
//    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
//        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
//            if let serverTrust = challenge.protectionSpace.serverTrust {
//                var secresult = SecTrustResultType.invalid
//                let status = SecTrustEvaluate(serverTrust, &secresult)
//                
//                if errSecSuccess == status {
//                    if let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) {
//                        let serverCertificateData = SecCertificateCopyData(serverCertificate)
//                        let data = CFDataGetBytePtr(serverCertificateData);
//                        let size = CFDataGetLength(serverCertificateData);
//                        let cert1 = NSData(bytes: data, length: size)
//                        let file_der = Bundle.main.path(forResource: "certificate", ofType: "cer")
//                        
//                        if let file = file_der {
//                            if let cert2 = NSData(contentsOfFile: file) {
//                                if cert1.isEqual(to: cert2 as Data) {
//                                    completionHandler(.useCredential, URLCredential(trust:serverTrust))
//                                    return
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//        }
//        
//        completionHandler(.cancelAuthenticationChallenge, nil)
//    }
    
    func requestAuthorization() {
        AppleMusicAuthorizationManager.delegate?.processingLogin = true
        Task {
            let status = await MusicAuthorization.request()
            if status == .authorized {
                await AppleMusicAuthorizationManager.handleAuthorization()
            } else {
                AppleMusicAuthorizationManager.postAlertForSettings()
                await MainActor.run {
                    AppleMusicAuthorizationManager.delegate?.processingLogin = false
                }
            }
        }
    }
    
    private static func handleAuthorization() async {
        guard Party.appleMusicStorefront == nil else {
            await MainActor.run {
                delegate?.performSegue(withIdentifier: storyboardSegue, sender: nil)
                delegate?.processingLogin = false
            }
            return
        }
        
        do {
            let subscription = try await MusicSubscription.current
            guard subscription.canPlayCatalogContent else {
                AppleMusicAuthorizationManager.postAlertForAppleMusicSubscription()
                await MainActor.run {
                    delegate?.processingLogin = false
                }
                return
            }
        } catch {
            AppleMusicAuthorizationManager.postAlertForInternet()
            await MainActor.run {
                delegate?.processingLogin = false
            }
            return
        }
        
        await AppleMusicAuthorizationManager.requestStorefrontCountryCode()
    }
    
    private static func requestStorefrontCountryCode() async {
        let controller = SKCloudServiceController()
        let countryCode: String? = await withCheckedContinuation { continuation in
            controller.requestStorefrontCountryCode { code, _ in
                continuation.resume(returning: code)
            }
        }
        
        guard let storefrontID = countryCode?.lowercased(),
              !storefrontID.isEmpty else {
            postAlertForInternet()
            await MainActor.run {
                delegate?.processingLogin = false
            }
            return
        }

        Party.appleMusicStorefront = storefrontID
        await MainActor.run {
            delegate?.performSegue(withIdentifier: storyboardSegue, sender: nil)
            delegate?.processingLogin = false
        }
    }
    
    private static func postAlertForSettings() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: NSLocalizedString("Apple Music Access Denied", comment: ""), message: NSLocalizedString("Go to Settings to enable Apple Music", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
                alert.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: ""), style: .default) { _ in
                UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
            })
            
            delegate?.present(alert, animated: true, completion: nil)
        }
    }
    
    private static func postAlertForAppleMusicSubscription() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: NSLocalizedString("No Apple Music Subscription", comment: ""), message: NSLocalizedString("An Apple Music Subscription is required to play music", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
            
            delegate?.present(alert, animated: true, completion: nil)
        }
    }
    
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
    
}
