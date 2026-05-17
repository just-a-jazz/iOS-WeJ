//
//  SceneDelegate.swift
//  WeJ
//

import UIKit

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let urlContext = connectionOptions.urlContexts.first {
            handle(url: urlContext.url)
        }

        if let userActivity = connectionOptions.userActivities.first {
            handle(userActivity: userActivity)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handle(url: url)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        handle(userActivity: userActivity)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        print("Resigning active")
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        let bgTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
        let app = UIApplication.shared
        app.beginBackgroundTask {
            app.endBackgroundTask(bgTask)
        }
        print("Entered background")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    private func handle(url: URL) {
        _ = SpotifyAuthorizationManager.handleAuthCallback(application: UIApplication.shared, open: url, options: [:])
    }

    private func handle(userActivity: NSUserActivity) {
        _ = SpotifyAuthorizationManager.handleUserActivity(application: UIApplication.shared, userActivity: userActivity, restorationHandler: { _ in })
    }
}
