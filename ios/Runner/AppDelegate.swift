import Flutter
import UIKit
import UserNotifications
import Foundation
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  var flutterEngine: FlutterEngine?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("[APP-SWIFT] DidFinishLaunching başladı")
    
    do {
      // Request notification permissions
      if #available(iOS 10.0, *) {
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
          options: authOptions,
          completionHandler: { granted, error in
            print("[APP-SWIFT] Notification permission: \(granted)")
          }
        )
      } else {
        let settings: UIUserNotificationSettings =
          UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
        application.registerUserNotificationSettings(settings)
      }
      
      application.registerForRemoteNotifications()

      // Start a dedicated FlutterEngine and register plugins with it so
      // the engine is available when SceneDelegate creates the FlutterViewController.
      self.flutterEngine = FlutterEngine(name: "my_engine")
      self.flutterEngine?.run()
      GeneratedPluginRegistrant.register(with: self.flutterEngine!)

      // Widget yenileme method channel
      let widgetChannel = FlutterMethodChannel(
        name: "com.siyazilim.periodicallynotification/widget",
        binaryMessenger: self.flutterEngine!.binaryMessenger
      )
      widgetChannel.setMethodCallHandler { call, result in
        guard call.method == "reloadWidget" else {
          result(FlutterMethodNotImplemented)
          return
        }
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
          print("[APP-SWIFT] reloadAllTimelines() çağrıldı")
          result(true)
        } else {
          result(false)
        }
      }

      let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
      
      print("[APP-SWIFT] DidFinishLaunching tamamlandı (result: \(result))")
      return result
    } catch {
      print("[APP-SWIFT] ERROR DidFinishLaunching: \(error)")
      return false
    }
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
  
  @available(iOS 13.0, *)
  override func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    print("[APP-SWIFT] Scene configuration talep edildi")
    let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    config.delegateClass = SceneDelegate.self
    print("[APP-SWIFT] SceneDelegate atandı")
    return config
  }
  
  @available(iOS 13.0, *)
  override func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    print("[APP-SWIFT] Scene sessions discard edildi")
  }
}

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  
  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    print("[APP-SWIFT] Scene willConnect başladı")
    
    guard let windowScene = scene as? UIWindowScene else {
      print("[APP-SWIFT] ERROR: Scene is not UIWindowScene")
      return
    }
    
    print("[APP-SWIFT] UIWindowScene oluşturuldu")
    
    let window = UIWindow(windowScene: windowScene)
    print("[APP-SWIFT] UIWindow oluşturuldu")
    
    // FlutterViewController'ı AppDelegate'de başlatılan FlutterEngine ile oluşturup set et
    if let appDelegate = UIApplication.shared.delegate as? AppDelegate, let engine = appDelegate.flutterEngine {
      let flutterViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
      window.rootViewController = flutterViewController
      print("[APP-SWIFT] FlutterViewController (engine ile) set edildi")
    } else {
      let flutterViewController = FlutterViewController()
      window.rootViewController = flutterViewController
      print("[APP-SWIFT] FlutterViewController (fallback) set edildi")
    }
    
    self.window = window
    window.makeKeyAndVisible()
    print("[APP-SWIFT] UIWindow visible yapıldı")
  }
  
  func sceneDidBecomeActive(_ scene: UIScene) {
    print("[APP-SWIFT] Scene did become active")
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
  
  func sceneWillResignActive(_ scene: UIScene) {
    print("[APP-SWIFT] Scene will resign active")
  }
  
  func sceneDidEnterBackground(_ scene: UIScene) {
    print("[APP-SWIFT] Scene did enter background")
  }
}
