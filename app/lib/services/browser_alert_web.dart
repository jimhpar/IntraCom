import 'dart:js_interop';

@JS('intracomAlerts.playRingtone')
external void _jsPlayRingtone();

@JS('intracomAlerts.stopRingtone')
external void _jsStopRingtone();

@JS('intracomAlerts.playRingback')
external void _jsPlayRingback();

@JS('intracomAlerts.stopRingback')
external void _jsStopRingback();

@JS('intracomAlerts.playMessageSound')
external void _jsPlayMessageSound();

@JS('intracomAlerts.startTabFlash')
external void _jsStartTabFlash(String text);

@JS('intracomAlerts.stopTabFlash')
external void _jsStopTabFlash();

void playRingtone() {
  try { _jsPlayRingtone(); } catch (_) {}
}

void stopRingtone() {
  try { _jsStopRingtone(); } catch (_) {}
}

void playRingback() {
  try { _jsPlayRingback(); } catch (_) {}
}

void stopRingback() {
  try { _jsStopRingback(); } catch (_) {}
}

void playMessageSound() {
  try { _jsPlayMessageSound(); } catch (_) {}
}

void startTabFlash(String text) {
  try { _jsStartTabFlash(text); } catch (_) {}
}

void stopTabFlash() {
  try { _jsStopTabFlash(); } catch (_) {}
}
