import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

class SignalingService {
  static final SignalingService instance = SignalingService._internal();
  SignalingService._internal();

  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messagesController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messagesController.stream;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  void connect() {
    final token = ApiService.instance.token;
    if (token == null) return;

    final uri = Uri.parse('${ApiService.wsUrl}?token=$token');
    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String) as Map<String, dynamic>;
            _messagesController.add(decoded);
          } catch (_) {}
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (err) {
          _isConnected = false;
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 4), () {
      if (!_isConnected && ApiService.instance.isAuthenticated) {
        connect();
      }
    });
  }

  void sendSignal(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  // 1:1 Calling Signals
  void sendCallOffer(String to, dynamic sdp, {String callType = 'audio'}) {
    sendSignal({
      'type': 'call_offer',
      'to': to,
      'call_type': callType,
      'payload': sdp,
    });
  }

  void sendCallAnswer(String to, dynamic sdp) {
    sendSignal({
      'type': 'call_answer',
      'to': to,
      'payload': sdp,
    });
  }

  void sendIceCandidate(String to, dynamic candidate) {
    sendSignal({
      'type': 'call_ice',
      'to': to,
      'payload': candidate,
    });
  }

  void sendHangup(String to) {
    sendSignal({
      'type': 'call_hangup',
      'to': to,
    });
  }

  // Hangout Hub Signals
  void joinHangoutHub(String hubId) {
    sendSignal({
      'type': 'hangout_join',
      'hangout_id': hubId,
    });
  }

  void leaveHangoutHub(String hubId) {
    sendSignal({
      'type': 'hangout_leave',
      'hangout_id': hubId,
    });
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }
}
