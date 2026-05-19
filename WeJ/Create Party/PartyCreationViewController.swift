//
//  PartyCreationViewController.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 11/10/16.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import UIKit
import NVActivityIndicatorView

protocol ViewControllerAccessDelegate: class {
    var processingLogin: Bool { get set }
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?)
    func performSegue(withIdentifier identifier: String, sender: Any?)
    func completeAuthorization(withSegueIdentifier identifier: String)
    func tryAgain()
}

class PartyCreationViewController: UIViewController, UITextFieldDelegate, ViewControllerAccessDelegate {
    
    // MARK: - Storyboard Variables
    
    @IBOutlet weak var partyNameTextField: partyNameTextField!
    @IBOutlet weak var appleMusicButton: setupButton!
    @IBOutlet weak var spotifyButton: setupButton!
    
    @IBOutlet weak var createButton: UIButton!
    @IBOutlet weak var activityIndicator: NVActivityIndicatorView!
    
    // MARK: - General Variables
    
    private var authorizationManager: AuthorizationManager!
    var processingLogin = false {
        didSet {
            DispatchQueue.main.async {
                if self.processingLogin {
                    self.activityIndicator.startAnimating()
                } else {
                    self.activityIndicator.stopAnimating()
                }
                self.createButton.isHidden = self.processingLogin
            }
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeVariables()
        adjustFontSizes()
        
        setDelegates()
        
        setPartyName()
        disableSpotifyButton()
        setMusicService()
    }
    
    private func initializeVariables() {
        SpotifyAuthorizationManager.storyboardSegue = "Create Party"
        AppleMusicAuthorizationManager.storyboardSegue = "Create Party"
    }
    
    private func adjustFontSizes() {
        if UIDevice.deviceType == .iPhone4_4s || UIDevice.deviceType == .iPhone5_5s_SE {
            partyNameTextField.changeToSmallerFont()
            appleMusicButton.changeToSmallerFont()
            spotifyButton.changeToSmallerFont()
            createButton.changeToSmallerFont()
        }
    }
    
    private func setDelegates() {
        partyNameTextField.delegate = self
        SpotifyAuthorizationManager.delegate = self
        AppleMusicAuthorizationManager.delegate = self
    }
    
    private func setPartyName() {
        if let partyName = UserDefaults.standard.object(forKey: "partyName") as? String {
            partyNameTextField.text = partyName
            Party.name = partyName
        } else {
            setDefaultPartyName()
        }
    }
    
    private func setDefaultPartyName() {
        let partyName = String(describing: UIDevice().userName().prefix(14)) + " " + NSLocalizedString("Party", comment: "")
        partyNameTextField.text = partyName
        Party.name = partyName
    }
    
    private func setMusicService() {
        if let rawMusicService = UserDefaults.standard.object(forKey: "musicService") as? String,
            let musicService = MusicService(rawValue: rawMusicService) {
            if musicService == .spotify && !spotifyButton.isHidden {
                changeToSpotify()
            } else {
                changeToAppleMusic()
            }
        } else {
            changeToAppleMusic()
        }
    }
    
    private func disableSpotifyButton() {
        spotifyButton.isEnabled = false
        spotifyButton.isHidden = true
    }
    
    // MARK: - Text Field
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if !textField.text!.isEmpty {
            Party.name = textField.text!
        }
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentString = (textField.text ?? "") as NSString
        let newString = currentString.replacingCharacters(in: range, with: string)
        return  newString.count <= 20
    }
    
    // MARK: - Storyboard Functions
    
    @IBAction func changeToSpotify() {
        guard !processingLogin else { return }
        change(toButton: spotifyButton, fromButton: appleMusicButton)
        Party.musicService = .spotify
    }
    
    @IBAction func changeToAppleMusic() {
        guard !processingLogin else { return }
        change(toButton: appleMusicButton, fromButton: spotifyButton)
        Party.musicService = .appleMusic
    }
    
    private func change(toButton button: setupButton, fromButton otherButton: setupButton) {
        UIView.animate(withDuration: 0.2) {
            button.makeBorder()
            otherButton.removeBorder()
            
            button.alpha = 1
            otherButton.alpha = 0.6
        }
    }
    
    @IBAction func createParty() {
        if !processingLogin {
            authorizationManager = Party.musicService == .spotify ? SpotifyAuthorizationManager.shared : AppleMusicAuthorizationManager()
            authorizationManager.requestAuthorization()
        }
    }
    
    func tryAgain() {
        createParty()
    }
    
    func completeAuthorization(withSegueIdentifier identifier: String) {
        performSegue(withIdentifier: identifier, sender: nil)
    }
    
    // MARK: - Navigation

    @IBAction func goBack() {
        navigationController?.popViewController(animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let controller = segue.destination as? PartyViewController, segue.identifier == "Create Party" {
            controller.networkManager?.delegate = controller
            Party.delegate = controller
            saveCustomization()
        }
    }
    
    private func saveCustomization() {
        UserDefaults.standard.set(Party.name, forKey: "partyName")
        UserDefaults.standard.set(Party.musicService.rawValue, forKey: "musicService")
    }
    
}
