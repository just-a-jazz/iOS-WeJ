# iOS-WeJ

An iOS app that allows users to share a music queue, and add Apple Music or Spotify tracks to it. The host can play the tracks as long as they have a valid subscription to either Apple Music or Spotify, and edit the queue as they wish.

WeJ Party Creation         |  WeJ Party Queue
:-------------------------:|:-------------------------:
![](https://github.com/alisidd/iOS-WeJ/blob/master/Images/party_creation.PNG)  |  ![](https://github.com/alisidd/iOS-WeJ/blob/master/Images/party_queue.PNG)

## Setup

This project expects a private config file that is not committed.

1. Copy `WeJ/Constants/PrivateConfig.template.swift` to `WeJ/Constants/PrivateConfig.swift`.
2. - Apple Music local library playback is possible as long as you have a valid Apple Music subscription without any API keys. If you want to browse though, then you'll need an Apple Developer account and then follow the steps here to enable MusicKit for your build: https://developer.apple.com/help/account/services/musickit/
   - Fill in your Spotify keys, server host, and any other values. Refer to https://developer.spotify.com/documentation/ios/getting-started for instructions on how to obtain Spotify keys. Use `wej://returnafterlogin` for the redirect URI though.

Notes:
- `PrivateConfig.swift` is gitignored on purpose.
- If you leave `appleMusicDeveloperToken` empty, the app will request a token from your auth server.
