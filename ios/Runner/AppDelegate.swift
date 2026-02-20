import Flutter
import UIKit
import UserNotifications
import Foundation
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("[APP-SWIFT] DidFinishLaunching başladı")
    
    // Plugin'ler Dart'tan önce kayıtlı olsun (Firebase Core kanalı hazır olur)
    GeneratedPluginRegistrant.register(with: self)
    
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    print("[APP-SWIFT] DidFinishLaunching tamamlandı (result: \(result))")
    return result
  }
  
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("[APP-SWIFT] FCM token alındı")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  override func application(_ application: UIApplication,
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("[APP-SWIFT] ERROR FCM token: \(error.localizedDescription)")
  }
  
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
}
