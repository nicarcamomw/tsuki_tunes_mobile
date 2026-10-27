import Flutter
import UIKit
import UserNotifications
#if canImport(workmanager_apple)
import workmanager_apple
#else
import workmanager
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets release radar notifications show while the app is in foreground.
    UNUserNotificationCenter.current().delegate = self

    // The background isolate needs plugins (http, shared_preferences,
    // notifications) registered on its own engine.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    // Must match kReleaseRadarTask in release_radar_service.dart and
    // BGTaskSchedulerPermittedIdentifiers in Info.plist.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.tsuki.releaseRadar",
      frequency: NSNumber(value: 24 * 60 * 60)
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
