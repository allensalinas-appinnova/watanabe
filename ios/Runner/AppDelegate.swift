import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LumioSharedReceipts") {
      let channel = FlutterMethodChannel(name: "lumio/shared_receipts", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String,
              let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
          result(nil); return
        }
        if call.method == "groupPath" { result(root.path); return }
        if call.method == "purgeExpired" {
          let files = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey], options: [.skipsHiddenFiles])) ?? []
          for file in files {
            let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            if values?.isRegularFile == true, let date = values?.contentModificationDate,
               Date().timeIntervalSince(date) > 86400 { try? FileManager.default.removeItem(at: file) }
          }
          result(nil); return
        }
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
