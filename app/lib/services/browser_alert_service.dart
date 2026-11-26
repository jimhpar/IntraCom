import 'browser_alert_stub.dart'
    if (dart.library.js_interop) 'browser_alert_web.dart' as impl;

class BrowserAlertService {
  static void playRingtone() => impl.playRingtone();
  static void stopRingtone() => impl.stopRingtone();
  static void playRingback() => impl.playRingback();
  static void stopRingback() => impl.stopRingback();
  static void playMessageSound() => impl.playMessageSound();
  static void startTabFlash(String text) => impl.startTabFlash(text);
  static void stopTabFlash() => impl.stopTabFlash();
}
