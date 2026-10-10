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
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PillNoteDeviceMetadata") else { return }
    let channel = FlutterMethodChannel(name: "kr.kimrasng.pillnote/device_metadata", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "getMetadata" else { result(FlutterMethodNotImplemented); return }
      var system = utsname()
      uname(&system)
      let model = withUnsafePointer(to: &system.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
      }
      result([
        "model": model,
        "osVersion": UIDevice.current.systemVersion,
        "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
        "appBuild": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
      ])
    }
  }

}
