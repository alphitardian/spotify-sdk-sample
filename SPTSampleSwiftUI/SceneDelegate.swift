//
//  SceneDelegate.swift
//  SPTSampleSwiftUI
//
//  Created by Ardian Pramudya Alphita on 22/03/23.
//

import SwiftUI

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    
    private let service = SpotifyService.shared
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
        print("SceneDelegate is connected!")
    }
    
    // For spotify authorization and authentication flow
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // This will handle if spotify get authorized or not
        print("SPOTIFY-DEBUG: \(URLContexts)")
        guard let url = URLContexts.first?.url else { return }
        let parameters = service.appRemote.authorizationParameters(from: url)
        print("SPOTIFY-DEBUG: \(parameters ?? [:])")
        if let code = parameters?["code"] {
            print("SPOTIFY-DEBUG CODE: \(code)")
            service.responseCode = code
        } else if let access_token = parameters?[SPTAppRemoteAccessTokenKey] {
            print("SPOTIFY-DEBUG ACCESS TOKEN: \(access_token)")
            service.accessToken = access_token
        } else if let error_description = parameters?[SPTAppRemoteErrorDescriptionKey] {
            print("No access token error =", error_description)
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        if let _ = service.appRemote.connectionParameters.accessToken {
            service.appRemote.connect()
        }
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        if service.appRemote.isConnected {
            service.appRemote.disconnect()
        }
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        
    }
}
