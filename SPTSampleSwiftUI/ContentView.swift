//
//  ContentView.swift
//  SPTSampleSwiftUI
//
//  Created by Ardian Pramudya Alphita on 22/03/23.
//

import SwiftUI

struct ContentView: View {
    
    @Environment(\.scenePhase) private var scenePhase
    
    private var service = SpotifyService.shared
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @State private var isConnected = false
    @State private var playerState: SPTAppRemotePlayerState? {
        didSet {
            trackDuration = Double(playerState!.track.duration / 1000)
            currentPosition = Double(playerState!.playbackPosition / 1000)
        }
    }
    @State private var currentPosition: Double = 0
    @State private var trackDuration: Double = 0
    @State private var isEditingSlider = false
    @State private var coverImage: UIImage?
    
    var body: some View {
        VStack {
            // MARK: - Current playerState View
            if let playerState, let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .frame(width: 150, height: 150)
                    .cornerRadius(10)
                
                Text(playerState.track.name)
                    .bold()
                    .font(.title)
                Text(playerState.track.album.name)
                Text(playerState.track.artist.name)
                Spacer()
                    .frame(height: 16)
                
                Slider(value: $currentPosition, in: 0...trackDuration) { isEditing in
                    isEditingSlider = isEditing
                    if !isEditing {
                        service.seek(to: currentPosition)
                    }
                }
                .onReceive(timer) { output in
                    if currentPosition <= trackDuration && isConnected {
                        currentPosition += 1
                    }
                }
                Text("\(DateComponentsFormatter.positional.string(from: currentPosition) ?? "0:00") : \(DateComponentsFormatter.positional.string(from: trackDuration) ?? "0:00")")
                
                if isConnected {
                    Button {
                        service.pause()
                    } label: {
                        Image(systemName: "pause.circle.fill")
                            .resizable()
                            .frame(width: 48, height: 48)
                            .tint(.green)
                    }
                }
            }
            
            // MARK: - Resume current playback
            if !isConnected, let _ = playerState {
                Button {
                    service.connect()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .frame(width: 48, height: 48)
                        .tint(.green)
                }
            }
            
            // MARK: - Connect to Spotify when not connected to app remote
            if !isConnected && playerState == nil {
                Button {
                    service.connect()
                } label: {
                    Text("Connect to Spotify")
                        .padding(4)
                }
                .buttonStyle(.borderedProminent)
                .cornerRadius(20)
                .tint(.green)
            }
        }
        
        // MARK: - Set the Spotify Service delegate
        .onAppear {
            service.delegate = self
        }
        
        // MARK: - Authorization
        // For spotify authorization and authentication flow
        .onOpenURL { url in
            // This will handle if spotify get authorized or not
            print("SPOTIFY-DEBUG: \(url)")
            let parameters = service.appRemote.authorizationParameters(from: url)
            print("SPOTIFY-DEBUG: \(parameters ?? [:])")
            if let code = parameters?["code"] {
                print("SPOTIFY-DEBUG code: \(code)")
                service.responseCode = code
            } else if let access_token = parameters?[SPTAppRemoteAccessTokenKey] {
                print("SPOTIFY-DEBUG access token from view: \(access_token)")
                service.accessToken = access_token
            } else if let error_description = parameters?[SPTAppRemoteErrorDescriptionKey] {
                print("SPOTIFY-DEBUG No access token error =", error_description)
            }
        }
        
        // MARK: - Lifecycle
        // Handle lifecycle for better API usage without any scene delegate
        .onChange(of: scenePhase) { newValue in
            switch newValue {
            case .active:
                print("App scene active")
                if let _ = service.appRemote.connectionParameters.accessToken {
                    service.appRemote.connect()
                }
            case .inactive:
                print("App scene inactive")
                if service.appRemote.isConnected {
                    service.appRemote.disconnect()
                }
            case .background:
                print("App scene in background")
                return
            @unknown default:
                fatalError("Cannot resolve scene changes")
            }
        }
    }
}

// MARK: - SpotifyServiceDelegate
extension ContentView: SpotifyServiceDelegate {
    func spotifyService(_ service: SpotifyService, didConected value: Bool, error: Error?) {
        print("SPOTIFY-DEBUG: didConnected called", value)
        if let error {
            print("SPOTIFY-DEBUG: error connected in view", error)
        }
        self.isConnected = value
    }
    
    func spotifyService(_ service: SpotifyService, didTrackChange playerState: SPTAppRemotePlayerState?) {
        print("SPOTIFY-DEBUG: didTrackChange called", playerState!)
        self.playerState = playerState
    }
    
    func spotifyService(_ service: SpotifyService, didGetTrackImage image: UIImage) {
        print("SPOTIFY-DEBUG: didGetTrackImage called", playerState!)
        self.coverImage = image
    }

}

extension DateComponentsFormatter {
    static let positional: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
