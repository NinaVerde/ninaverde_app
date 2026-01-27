import FBSDKCoreKit
import FBSDKLoginKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    ApplicationDelegate.shared.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "native_facebook_auth",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "logIn":
          let manager = LoginManager()
          manager.logIn(permissions: ["public_profile", "email"], from: controller) {
            loginResult, error in
            if let error = error {
              result(
                FlutterError(
                  code: "error",
                  message: error.localizedDescription,
                  details: nil
                )
              )
              return
            }
            guard let loginResult = loginResult else {
              result(
                FlutterError(
                  code: "error",
                  message: "Facebook login returned no result.",
                  details: nil
                )
              )
              return
            }
            if loginResult.isCancelled {
              result(
                FlutterError(
                  code: "cancelled",
                  message: "Facebook login cancelled.",
                  details: nil
                )
              )
              return
            }
            if let token = AccessToken.current?.tokenString {
              result(token)
            } else {
              result(
                FlutterError(
                  code: "error",
                  message: "Missing Facebook access token.",
                  details: nil
                )
              )
            }
          }
        case "logOut":
          LoginManager().logOut()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    return ApplicationDelegate.shared.application(app, open: url, options: options)
  }
}
