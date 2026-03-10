//
//  BackgroundTask.swift
//
//  Created by Yaro on 8/27/16.
//  Copyright © 2016 Yaro. All rights reserved.
//

import AVFoundation

class BackgroundTask {
    
    static var player = AVAudioPlayer()
    static var isPlaying = false
    
    static func startBackgroundTask() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !isPlaying {
                NotificationCenter.default.addObserver(self, selector: #selector(interuptedAudio), name: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
                playAudio()
                isPlaying = true
            }
        }
    }
    
    static func stopBackgroundTask() {
        DispatchQueue.global(qos: .userInitiated).async {
            if isPlaying {
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
                player.stop()
                isPlaying = false
            }
        }
    }
    
    @objc static func interuptedAudio(_ notification: Notification) {
        if notification.name == NSNotification.Name.AVAudioSessionInterruption && notification.userInfo != nil {
            let info = notification.userInfo!
            var intValue = 0
            (info[AVAudioSessionInterruptionTypeKey]! as AnyObject).getValue(&intValue)
            if intValue == 1 { playAudio() }
        }
    }
    
    private static func playAudio() {
        do {
            let bundle = Bundle.main.path(forResource: "BlankAudio", ofType: "wav")
            let alertSound = URL(fileURLWithPath: bundle!)
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            try player = AVAudioPlayer(contentsOf: alertSound)
            player.numberOfLoops = -1
            player.volume = 0.01
            player.prepareToPlay()
            player.play()
        } catch { print(error) }
    }
    
}
