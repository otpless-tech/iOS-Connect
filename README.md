# OtplessSwiftConnect

This guide will walk you through integrating the `OtplessSwiftConnect` SDK in your iOS project using CocoaPods.


## 📌 Requirements

Before you start, make sure your setup meets the following requirements:

### 1. You must have a login website  
This website should:
- Support loading in a SafariViewController
- Have login functionality implemented using Otpless

### 2. Your website must integrate our **Web SDK**
- The Web SDK communicates with our iOS SDK via a socket connection
- This enables **inter-process communication (IPC)** between the native iOS layer and your web layer

### 3. SafariViewController must load your own website
- **You should load your login page** with additional params that the iOS SDK will be providing to you and these params should be passed to the Otpless Web SDK during web sdk initialization.
- The Web SDK will then handle the login flow and communicate with the iOS SDK
- **You cannot use our Pre-Built UI** in this case, as it is designed to be used for websites using our Headless SDK and want to utilize the iOS SDK capabilities in SafariViewController.

### 4. iOS SDK must be initialized before opening SafariViewController
- You must initialize our SDK by calling a function with the `appId` and `secret`
- Once initialization is complete (socket connection ready to be established), you can begin the login flow

---

## 🔧 Integration Steps

### Step 1: Add SDK Dependency

SDK can be installed via both Cocoapods and Swift Package Manager. 
#### Cocoapods
- Open your app's project file `.xcodeproj`.
- Add the following line into the dependencies section of your project's `Podfile`:

```ruby
pod 'OtplessSwiftConnect', '1.0.1'
```


  **Make sure to run the following commands in your root folder to fetch the
  dependency.**

```bash
pod repo update
pod install
```

#### Swift Package Manager
1. In Xcode, click File > Swift Packages > Add Package Dependency.
2. In the dialog that appears, enter the repository URL: https://github.com/otpless-tech/iOS-Connect.git.
3. Select the dependency rule as `exact version` and use the version `1.0.1`.

---

### Step 2: Initialize the SDK

In your app code, initialize the SDK before opening SafariViewController:

```swift
OtplessSwiftConnect.shared.initialize(appId: "YOUR_APP_ID", secret: "YOUR_SECRET") { success in
    if success {
        // Initialization successful
    } else {
        // Initialization failed, however you can still open SafariViewController and use Otpless' login features without
        // the iOS SDK native capabilities like SNA.
    }
}
```

---

### Step 3: Open SafariViewController with Parameters

After initialization, get the required query parameters from the SDK and append them to the login URL that loads in SafariViewController:

```swift
func start() {
    let params = OtplessSwiftConnect.shared.getStartParams()
    openSafariVC(urlString: "https://yourwebsite.com/login", params: params)
}

func openSafariVC(urlString: String, params: [String: Any]) {
    guard var components = URLComponents(string: urlString) else {
        return
    }

    // Add SDK parameters to URL
    components.queryItems = params.map {
        URLQueryItem(name: $0.key, value: "\($0.value)")
    }

    guard let finalURL = components.url else { return }

    let safariVC = SFSafariViewController(url: finalURL)
    present(safariVC, animated: true)
}
```

---

### Step 4: Integrate Web SDK in Your Website

We'll provide you a JavaScript snippet to add in your login page. This SDK:
- Connects to the native iOS SDK using a socket
- Handles real-time communication between native and web layers
- Allows Otpless functionality (like login/passkey) to work from your webview
- The success response of user authentication is received in the web SDK and you'll have to manage sending it back to your iOS yourself. The only role of this SDK is to create a socket connection between the Otpless iOS SDK and Otpless web SDK for achieving native capabilities.
