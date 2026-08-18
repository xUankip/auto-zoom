import Flutter
import UIKit
import AVFoundation

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AlarmPlugin") {
      AlarmPlugin.register(with: registrar)
    }
  }
}

public class AlarmPlugin: NSObject, FlutterPlugin {
  private static var audioPlayer: AVAudioPlayer?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.autozoom/alarm", binaryMessenger: registrar.messenger())
    let instance = AlarmPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "playAlarm" {
      AlarmPlugin.playAlarmSound()
      result(true)
    } else if call.method == "stopAlarm" {
      AlarmPlugin.stopAlarmSound()
      result(true)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  public static func playAlarmSound() {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
      try AVAudioSession.sharedInstance().setActive(true)

      let soundURL = Bundle.main.url(forResource: "alarm", withExtension: "caf") ??
                     Bundle.main.url(forResource: "alarm", withExtension: "wav")

      if let url = soundURL {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.numberOfLoops = 3 // Repeats for ~36 seconds
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
      } else {
        print("[AlarmPlugin] Alarm sound file not found in bundle.")
      }
    } catch {
      print("[AlarmPlugin] Failed to play alarm: \(error)")
    }
  }

  public static func stopAlarmSound() {
    audioPlayer?.stop()
    audioPlayer = nil
  }
}


