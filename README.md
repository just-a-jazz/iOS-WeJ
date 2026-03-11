# iOS-WeJ

An iOS app that allows users to share a music queue, and add Apple Music or Spotify tracks to it. The host can play the tracks as long as they have a valid subscription to either Apple Music or Spotify, and edit the queue as they wish.

WeJ Party Creation         |  WeJ Party Queue
:-------------------------:|:-------------------------:
![](https://github.com/alisidd/iOS-WeJ/blob/master/Images/party_creation.PNG)  |  ![](https://github.com/alisidd/iOS-WeJ/blob/master/Images/party_queue.PNG)

# Getting Started

The following guide shows you how to download the project from GitHub and run it on your own iPhone using Xcode.

## Requirements

- A Mac running at least macOS Monterey
- Xcode 14 and above
- An iPhone or iPad with at least iOS 15.6 (simulator won't be able to play back music)
- A free Apple ID is enough for local library Apple Music playback. Browsing Apple Music requires a paid developer account.

## 1. Get the Code

### Option A — Clone with Git

```bash
git clone https://github.com/just-a-jazz/iOS-WeJ.git
cd iOS-WeJ
```

### Option B — Download ZIP
Go to the repository on GitHub.
Click Code → Download ZIP.
Unzip the file and open the extracted folder.

## 2. Open the Project in Xcode
Open Finder and navigate to the project folder.
Double-click the ```.xcodeproj``` file.
If you see a ```.xcworkspace``` file, open that instead.
Xcode will index the project and prepare it for building.

## 3. Setup Config file
This project expects a private config file that is not committed.

1. Copy `WeJ/Constants/PrivateConfig.template.swift` to `WeJ/Constants/PrivateConfig.swift`.
2. * Apple Music *local library* playback is possible without any API keys as long as you have a valid Apple Music subscription. If you want to browse though, then you'll need an Apple Developer account and then follow the steps here to enable MusicKit for your build: https://developer.apple.com/help/account/services/musickit/
   * Spotify playback *requires* API keys. Fill in your Spotify keys, server host, and any other values. Refer to [Spotify's iOS Documentation](https://developer.spotify.com/documentation/ios/getting-started) for instructions on how to obtain your own Spotify keys. Use `wej://returnafterlogin` for the redirect URI. Set up your server using [a service I created that you can deploy on your own server](https://github.com/just-a-jazz/App-Services/tree/main/iOS-WeJ).

## 4. Run the App on a Physical Device
### 4.1 Add your Apple ID to Xcode
1. Connect your iPhone/iPad to your Mac.
2. Open Xcode → Settings… → Accounts.
3. Click the + button and select Add Apple ID….
4. Sign in using your Apple ID.
### 4.2 Enable Signing
1. In the Project Navigator, select the top-level project (blue icon).
2. Under **TARGETS**, select the app.
3. Open the Signing & Capabilities tab.
4. Enable Automatically manage signing.
5. Choose your Team (your Apple ID / Personal Team).
6. Choose a unique bundle identifier.
### 4.3 Run on Your Device
1. In the device menu at the top of Xcode, select your connected iPhone/iPad.
2. Press Run ▶ (Cmd + R).
3. Xcode will build and install the app on your device.
### 4.4 Trust the Developer (first time only)
1. On your device, open Settings → General → VPN & Device Management.
2. Tap your Developer App profile.
3. Tap Trust.
4. Run the app again from Xcode.


