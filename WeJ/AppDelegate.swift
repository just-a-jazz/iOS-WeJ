//
//  AppDelegate.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 11/9/16.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import UIKit
import Siren

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let currentCount = UserDefaults.standard.integer(forKey: "launchCount")
        UserDefaults.standard.set(currentCount + 1, forKey:"launchCount")
        UserDefaults.standard.set(false, forKey:"iOSErrorShown")
        UserDefaults.standard.synchronize()
        
        Siren.shared.alertType = .option
        Siren.shared.majorUpdateAlertType = .force
        Siren.shared.minorUpdateAlertType = .option
        Siren.shared.checkVersion(checkType: .daily)
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return SpotifyAuthorizationManager.handleAuthCallback(application: app, open: url, options: options)
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        return SpotifyAuthorizationManager.handleUserActivity(application: application, userActivity: userActivity, restorationHandler: restorationHandler)
    }
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        print("Resigning active")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        let bgTask: UIBackgroundTaskIdentifier = 0
        let app = UIApplication.shared
        app.beginBackgroundTask {
            app.endBackgroundTask(bgTask)
        }
        print("Entered background")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        print("App terminating")
    }

}
