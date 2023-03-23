//
//  SpotifyService.swift
//  SPTSampleSwiftUI
//
//  Created by Ardian Pramudya Alphita on 22/03/23.
//

import SwiftUI

public protocol SpotifyServiceDelegate {
    func spotifyService(_ service: SpotifyService, didConected value: Bool, error: Error?)
    func spotifyService(_ service: SpotifyService, didTrackChange playerState: SPTAppRemotePlayerState?)
    func spotifyService(_ service: SpotifyService, didGetTrackImage image: UIImage)
}

public class SpotifyService: NSObject {
    
    public static let shared = SpotifyService()
    
    var delegate: SpotifyServiceDelegate?
    
    // MARK: - Public property
    var responseCode: String? {
        didSet {
            fetchAccessToken { dictionary, error in
                if let error = error {
                    print("SPOTIFY-DEBUG: Fetching token request error \(error)")
                    return
                }
                let accessToken = dictionary!["access_token"] as! String
                print("SPOTIFY-DEBUG ACCESS TOKEN: \(accessToken)")
                DispatchQueue.main.async { [weak self] in
                    self?.accessToken = accessToken
                    self?.appRemote.connectionParameters.accessToken = accessToken
                    self?.appRemote.connect()
                    print("SPOTIFY-DEBUG: App remote connect after get access token")
                }
            }
        }
    }
    
    lazy var appRemote: SPTAppRemote = {
        let appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        appRemote.connectionParameters.accessToken = self.accessToken
        appRemote.delegate = self
        return appRemote
    }()
    
    lazy var configuration: SPTConfiguration = {
        let configuration = SPTConfiguration(clientID: spotifyClientId, redirectURL: redirectUri)
        // Set the playURI to a non-nil value so that Spotify plays music after authenticating
        // otherwise another app switch will be required
        configuration.playURI = ""
        // Set these url's to your backend which contains the secret to exchange for an access token
        // You can use the provided ruby script spotify_token_swap.rb for testing purposes
        configuration.tokenSwapURL = URL(string: "http://localhost:1234/swap")
        configuration.tokenRefreshURL = URL(string: "http://localhost:1234/refresh")
        return configuration
    }()
    
    var accessToken = UserDefaults.standard.string(forKey: accessTokenKey) {
        didSet {
            let defaults = UserDefaults.standard
            defaults.set(accessToken, forKey: accessTokenKey)
        }
    }
    
    lazy var sessionManager: SPTSessionManager? = {
        let manager = SPTSessionManager(configuration: configuration, delegate: self)
        return manager
    }()
    
    // MARK: - Private property
    private var lastPlayerState: SPTAppRemotePlayerState?
}

// MARK: - SPTAppRemoteDelegate
extension SpotifyService: SPTAppRemoteDelegate {
    public func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("SPOTIFY-DEBUG: Spotify have connected")
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe { [weak self] result, error in
            if let error {
                print("SPOTIFY-DEBUG: cannot subscribe player API", error.localizedDescription)
                self?.delegate?.spotifyService(self!, didConected: false, error: error)
            }
            print("SPOTIFY-DEBUG: App remote player API subscribed")
            self?.delegate?.spotifyService(self!, didConected: true, error: nil)
        }
    }
    
    public func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("SPOTIFY-DEBUG: Spotify have disconnected", error?.localizedDescription ?? "")
        delegate?.spotifyService(self, didConected: false, error: error)
    }
    
    public func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("SPOTIFY-DEBUG: Spotify failed to connect", error?.localizedDescription ?? "")
        delegate?.spotifyService(self, didConected: false, error: error)
    }
}

// MARK: - SPTAppRemotePlaterStateDelegate
extension SpotifyService: SPTAppRemotePlayerStateDelegate {
    // Get the track info
    public func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        print("SPOTIFY-DEBUG: player state changed")
        print("SPOTIFY-DEBUG: isPaused", playerState.isPaused)
        print("SPOTIFY-DEBUG: track.uri", playerState.track.uri)
        print("SPOTIFY-DEBUG: track.name", playerState.track.name)
        print("SPOTIFY-DEBUG: track.imageIdentifier", playerState.track.imageIdentifier)
        print("SPOTIFY-DEBUG: track.artist.name", playerState.track.artist.name)
        print("SPOTIFY-DEBUG: track.album.name", playerState.track.album.name)
        print("SPOTIFY-DEBUG: track.isSaved", playerState.track.isSaved)
        print("SPOTIFY-DEBUG: playbackSpeed", playerState.playbackSpeed)
        print("SPOTIFY-DEBUG: playbackOptions.isShuffling", playerState.playbackOptions.isShuffling)
        print("SPOTIFY-DEBUG: playbackOptions.repeatMode", playerState.playbackOptions.repeatMode.hashValue)
        print("SPOTIFY-DEBUG: playbackPosition", playerState.playbackPosition)
        print("SPOTIFY-DEBUG: playbackRestrictions.canSeek", playerState.playbackRestrictions.canSeek)
        print("SPOTIFY-DEBUG: player state object", playerState)
        delegate?.spotifyService(self, didTrackChange: playerState)
        lastPlayerState = playerState
        fetchArtwork(for: playerState.track)
    }
}

// MARK: - SPTSessionManagerDelegate
extension SpotifyService: SPTSessionManagerDelegate {
    public func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        DispatchQueue.main.async { [weak self] in
            self?.appRemote.connectionParameters.accessToken = session.accessToken
            self?.appRemote.connect()
            print("SPOTIFY-DEBUG: App remote connect on initiate session manager")
        }
    }
    
    public func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        print("SPOTIFY-DEBUG: session manager fail", error.localizedDescription)
    }
    
    public func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        print("SPOTIFY-DEBUG: session manager renew")
    }
}

// MARK: - Networking
extension SpotifyService {
    func fetchAccessToken(completion: @escaping ([String: Any]?, Error?) -> Void) {
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let spotifyAuthKey = "Basic \((spotifyClientId + ":" + spotifyClientSecretKey).data(using: .utf8)!.base64EncodedString())"
        request.allHTTPHeaderFields = ["Authorization": spotifyAuthKey, "Content-Type": "application/x-www-form-urlencoded"]
        
        var requestBodyComponents = URLComponents()
        let scopeAsString = stringScopes.joined(separator: " ")
        
        requestBodyComponents.queryItems = [
            URLQueryItem(name: "client_id", value: spotifyClientId),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: responseCode!),
            URLQueryItem(name: "redirect_uri", value: redirectUri.absoluteString),
            URLQueryItem(name: "code_verifier", value: ""), // not currently used
            URLQueryItem(name: "scope", value: scopeAsString),
        ]
        
        request.httpBody = requestBodyComponents.query?.data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,                              // is there data
                  let response = response as? HTTPURLResponse,  // is there HTTP response
                  (200 ..< 300) ~= response.statusCode,         // is statusCode 2XX
                  error == nil else {                           // was there no error, otherwise ...
                print("Error fetching token \(error?.localizedDescription ?? "")")
                return completion(nil, error)
            }
            let responseObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            print("Access Token Dictionary:", responseObject ?? "")
            completion(responseObject, nil)
        }
        task.resume()
    }
    
    func fetchArtwork(for track: SPTAppRemoteTrack) {
        appRemote.imageAPI?.fetchImage(forItem: track, with: CGSize.zero) { [weak self] image, error in
            if let error = error {
                print("SPOTIFY-DEBUG: Error fetching track image:", error.localizedDescription)
            } else if let image = image as? UIImage {
                self?.delegate?.spotifyService(self!, didGetTrackImage: image)
            }
        }
    }
    
}

// MARK: - Action
extension SpotifyService {
    func connect() {
        // appRemote.authorizeAndPlayURI(playUri)
        
        // This will open Spotify to get authorized in the app
        guard let sessionManager = sessionManager else { return }
        sessionManager.initiateSession(with: scopes, options: .clientOnly)
    }
    
    func pause() {
        appRemote.playerAPI?.pause { result, error in
            if let error {
                print("SPOTIFY-DEBUG: pause request error", error.localizedDescription)
            }
            print("SPOTIFY-DEBUG: pause request success", result!)
        }
    }
    
    func getPlayerState() {
        appRemote.playerAPI?.getPlayerState { result, error in
            if let error {
                print("SPOTIFY-DEBUG: cannot get player state", error.localizedDescription)
            }
            print("SPOTIFY-DEBUG: current player state", result!)
        }
    }
    
    func play(withUri uri: String) {
        appRemote.playerAPI?.play(uri, asRadio: false) { result, error in
            if let error {
                print("SPOTIFY-DEBUG: cannot play track", error)
            }
            print("SPOTIFY-DEBUG: play track", result!)
        }
    }
    
    func resume(withUri uri: String) {
        appRemote.playerAPI?.play("", asRadio: false) { result, error in
            if let error {
                print("SPOTIFY-DEBUG: cannot resume track", error)
            }
            print("SPOTIFY-DEBUG: resume track", result!)
        }
    }
    
    func seek(to value: Double) {
        appRemote.playerAPI?.seek(toPosition: Int(value * 1000)) { result, error in
            if let error {
                print("SPOTIFY-DEBUG: cannot seek track", error)
            }
            print("SPOTIFY-DEBUG: seek track", result!)
        }
    }
}
