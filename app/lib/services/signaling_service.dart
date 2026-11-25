import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  final List<Map<String, dynamic>> _pendingSignals = [];

  // Authentic live presence tracker
  final ValueNotifier<Set<String>> onlineUsersNotifier = ValueNotifier<Set<String>>({});
  bool isOnline(String number) => onlineUsersNotifier.value.contains(number);

  Timer? _heartbeatTimer;

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_isConnected) {
        sendSignal({'type': 'ping', 'timestamp': DateTime.now().millisecondsSinceEpoch});
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void connect() {
    final token = ApiService.instance.token;
    if (token == null) return;

    // Fetch initial list of online users from REST API as well
    ApiService.instance.getOnlineUsers().then((list) {
      if (list.isNotEmpty) {
        onlineUsersNotifier.value = list.toSet();
      }
    });

    final uri = Uri.parse('${ApiService.wsUrl}?token=$token');
    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      _startHeartbeat();
      _flushPendingSignals();

      _channel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String) as Map<String, dynamic>;
            final type = decoded['type'];

            // Handle real-time presence events
            if (type == 'initial_presence') {
              final payload = decoded['payload'];
              if (payload is List) {
                onlineUsersNotifier.value = payload.map((e) => e.toString()).toSet();
              }
            } else if (type == 'presence_update') {
              final payload = decoded['payload'];
              final num = (payload?['number'] ?? decoded['from'])?.toString() ?? '';
              final status = payload?['status']?.toString();
              if (num.isNotEmpty) {
                final current = Set<String>.from(onlineUsersNotifier.value);
                if (status == 'online') {
                  current.add(num);
                } else {
                  current.remove(num);
                }
                onlineUsersNotifier.value = current;
              }
            }

            _messagesController.add(decoded);
          } catch (_) {}
        },
        onDone: () {
          _isConnected = false;
          _stopHeartbeat();
          _scheduleReconnect();
        },
        onError: (err) {
          _isConnected = false;
          _stopHeartbeat();
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _isConnected = false;
      _stopHeartbeat();
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

  void _flushPendingSignals() {
    if (_channel != null && _isConnected && _pendingSignals.isNotEmpty) {
      final list = List<Map<String, dynamic>>.from(_pendingSignals);
      _pendingSignals.clear();
      for (final msg in list) {
        try {
          _channel!.sink.add(jsonEncode(msg));
        } catch (_) {}
      }
    }
  }

  void sendSignal(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (_) {
        _pendingSignals.add(message);
      }
    } else {
      _pendingSignals.add(message);
      // Try reconnecting if not connected
      if (ApiService.instance.isAuthenticated) {
        connect();
      }
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
    _stopHeartbeat();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }
}
