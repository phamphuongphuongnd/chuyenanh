import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Kênh "Mở trong" (file từ app khác) — xem IncomingFilesBridge trong SceneDelegate.swift.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PdfOfficeIncomingFiles") {
      IncomingFilesBridge.shared.attach(messenger: registrar.messenger())
    }
  }
}
