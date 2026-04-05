import Flutter
import UIKit
import UserNotifications
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var pushChannel: FlutterMethodChannel?
  private var pendingTokenHex: String?
  private var pendingPayloadJson: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      if let json = PushNotificationBridge.userInfoToJsonString(remote) {
        pendingPayloadJson = json
      }
    }

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    DispatchQueue.main.async { [weak self] in
      self?.attachPushChannelIfNeeded()
    }
    return result
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.attachPushChannelIfNeeded()
      if let json = self.pendingPayloadJson {
        self.pendingPayloadJson = nil
        self.pushChannel?.invokeMethod("onPushPayload", arguments: [json, false])
      }
    }
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }

  private func attachPushChannelIfNeeded() {
    guard pushChannel == nil,
          let controller = window?.rootViewController as? FlutterViewController else { return }
    let channel = FlutterMethodChannel(
      name: "periodically/push",
      binaryMessenger: controller.binaryMessenger
    )
    pushChannel = channel
    if let t = pendingTokenHex {
      pendingTokenHex = nil
      channel.invokeMethod("onApnsToken", arguments: t)
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    if let ch = pushChannel {
      ch.invokeMethod("onApnsToken", arguments: hex)
    } else {
      pendingTokenHex = hex
    }
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[APNS] register failed: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    PushPayloadSync.apply(userInfo: userInfo)
    if let json = PushNotificationBridge.userInfoToJsonString(userInfo) {
      if let ch = pushChannel {
        ch.invokeMethod("onPushPayload", arguments: [json, false])
      } else {
        pendingPayloadJson = json
      }
    }
    completionHandler(.newData)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    if let json = PushNotificationBridge.userInfoToJsonString(userInfo) {
      pushChannel?.invokeMethod("onPushPayload", arguments: [json, true])
    }
    completionHandler([])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    if let json = PushNotificationBridge.userInfoToJsonString(userInfo) {
      pushChannel?.invokeMethod("onPushPayload", arguments: [json, false])
    }
    completionHandler()
  }
}

// MARK: - JSON bridge (APNs userInfo → Flutter)

enum PushNotificationBridge {
  static func userInfoToJsonString(_ userInfo: [AnyHashable: Any]) -> String? {
    var dict: [String: Any] = [:]
    for (k, v) in userInfo {
      let key = k as? String ?? String(describing: k)
      dict[key] = unwrapPropertyList(v)
    }
    guard JSONSerialization.isValidJSONObject(dict),
          let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  private static func unwrapPropertyList(_ any: Any) -> Any {
    switch any {
    case let s as String:
      return s
    case let n as NSNumber:
      return n
    case let d as [String: Any]:
      return d.mapValues { unwrapPropertyList($0) }
    case let d as [AnyHashable: Any]:
      var out: [String: Any] = [:]
      for (k, v) in d {
        let key = k as? String ?? String(describing: k)
        out[key] = unwrapPropertyList(v)
      }
      return out
    case let a as [Any]:
      return a.map { unwrapPropertyList($0) }
    default:
      return String(describing: any)
    }
  }
}

// MARK: - App Group widget dosyası (sessiz push)

enum PushPayloadSync {
  private static let appGroupId = "group.com.siyazilim.periodicallynotification"

  static func apply(userInfo: Any) {
    guard let dict = userInfo as? [AnyHashable: Any] else { return }
    var type: String?
    for (k, v) in dict {
      let key = k as? String ?? String(describing: k)
      if key == "type", let s = v as? String { type = s }
    }
    guard type == "DAILY_WIDGET" || type == "DAILY_WIDGET_UPDATE" else { return }

    func str(_ key: String) -> String {
      for (k, v) in dict {
        let kk = k as? String ?? String(describing: k)
        if kk == key {
          return v as? String ?? String(describing: v)
        }
      }
      return ""
    }

    let title = str("title")
    let body = str("body")
    let itemId = str("itemId")
    let updatedAt = str("updatedAt")

    guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return }
    let cacheDir = dir.appendingPathComponent("widget_cache", isDirectory: true)
    try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    let file = cacheDir.appendingPathComponent("widget_data.json")
    let payload: [String: Any] = [
      "title": title,
      "body": body,
      "itemId": itemId,
      "updatedAt": updatedAt.isEmpty ? ISO8601DateFormatter().string(from: Date()) : updatedAt,
      "imagePath": ""
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else { return }
    try? data.write(to: file)
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
}
