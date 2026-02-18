//
//  AppleMusicAuthorizationManager.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 7/26/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import Foundation
import StoreKit

protocol AuthorizationManager {
    func requestAuthorization()
}

class AppleMusicAuthorizationManager: NSObject, AuthorizationManager, URLSessionDelegate {
    
    static weak var delegate: ViewControllerAccessDelegate?
    
    static let cloudServiceController = SKCloudServiceController()
    static var developerToken: String!
    static var storyboardSegue: String!
    
    static func requestDeveloperToken() {
        let request = AppleMusicURLFactory.createDeveloperTokenRequest()
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            let session = URLSession(configuration: URLSessionConfiguration.default)
            let task = session.dataTask(with: request) { (data, response, error) in
                if let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode == 200 {
                    developerToken = String(data: data!, encoding: .utf8)!
                }
                dispatchGroup.leave()
            }
            
            task.resume()
        }
        
        dispatchGroup.wait()
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
        if SKCloudServiceController.authorizationStatus() == .authorized {
            AppleMusicAuthorizationManager.handleCapabilities()
        } else {
            SKCloudServiceController.requestAuthorization { (status) in
                if status == .authorized {
                    AppleMusicAuthorizationManager.handleCapabilities()
                } else {
                    AppleMusicAuthorizationManager.postAlertForSettings()
                    AppleMusicAuthorizationManager.delegate?.processingLogin = false
                }
            }
        }
    }
    
    private static func handleCapabilities() {
        guard Party.cookie == nil else {
            DispatchQueue.main.async {
                delegate?.performSegue(withIdentifier: storyboardSegue, sender: nil)
            }
            delegate?.processingLogin = false
            return
        }
        
        AppleMusicAuthorizationManager.cloudServiceController.requestCapabilities { (capabilities, _) in
            if capabilities.contains(.musicCatalogPlayback) {
                AppleMusicAuthorizationManager.requestStorefrontIdentifier()
            } else {
                if capabilities.rawValue == 0 {
                    AppleMusicAuthorizationManager.postAlertForInternet()
                } else {
                    AppleMusicAuthorizationManager.postAlertForAppleMusicSubscription()
                }
                delegate?.processingLogin = false
            }
        }
    }
    
    static func requestStorefrontIdentifier() {
        let countryCodeHandler: (String?, Error?) -> Void = { (countryCode, error) in
            if let storefrontId = countryCode?.components(separatedBy: "-").first,
                let countryCode = AppleMusicConstants.countryCodes[storefrontId] ?? countryCode {
                Party.cookie = countryCode
                DispatchQueue.main.async {
                    delegate?.performSegue(withIdentifier: storyboardSegue, sender: nil)
                }
            } else {
                postAlertForInternet()
            }
            delegate?.processingLogin = false
        }
        
        if #available(iOS 11.0, *) {
            cloudServiceController.requestStorefrontCountryCode(completionHandler: countryCodeHandler)
        } else {
            cloudServiceController.requestStorefrontIdentifier(completionHandler: countryCodeHandler)
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
