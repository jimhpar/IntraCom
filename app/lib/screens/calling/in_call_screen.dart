import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/signaling_service.dart';
import '../../theme/ios_theme.dart';

class InCallScreen extends StatefulWidget {
  final String targetNumber;
  final String targetName;
  final bool isVideo;
  final bool isIncoming;
  final bool initialConnected;

  const InCallScreen({
    super.key,
    required this.targetNumber,
    this.targetName = 'IntraCom User',
    this.isVideo = false,
    this.isIncoming = false,
    this.initialConnected = false,
  });

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoCamOn = false;
  late bool _isConnected;

  Timer? _callTimer;
  Timer? _ringTimeoutTimer;
  int _callSeconds = 0;
  StreamSubscription? _signalingSub;

  @override
  void initState() {
    super.initState();
    _isVideoCamOn = widget.isVideo;
    _isConnected = widget.initialConnected;

    // 1. Listen for peer responses BEFORE sending call offer so no packet is dropped
    _signalingSub = SignalingService.instance.messageStream.listen((msg) {
      if (!mounted) return;

      final type = msg['type'];
      final from = (msg['from'] ?? '').toString();
      final cleanFrom = from.replaceAll('-', '').replaceAll('+', '');
      final cleanTarget = widget.targetNumber.replaceAll('-', '').replaceAll('+', '');

      final isMatch = from.isEmpty ||
          from == widget.targetNumber ||
          cleanFrom == cleanTarget ||
          (cleanTarget.length == 7 && cleanFrom.endsWith(cleanTarget)) ||
          (cleanFrom.length == 7 && cleanTarget.endsWith(cleanFrom));

      if (type == 'call_answer' && isMatch) {
        _ringTimeoutTimer?.cancel();
        if (!_isConnected) {
          setState(() {
            _isConnected = true;
          });
          _startTimer();
        }
      } else if ((type == 'call_hangup' || type == 'call_reject') && isMatch) {
        _ringTimeoutTimer?.cancel();
        _onPeerHangup();
      } else if (type == 'call_unavailable') {
        _ringTimeoutTimer?.cancel();
        _callTimer?.cancel();
        if (mounted) {
          final reason = msg['payload']?['reason'] ?? 'User is currently offline or unreachable';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(reason), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 4)),
          );
          Navigator.pop(context);
        }
      }
    });

    if (_isConnected) {
      _startTimer();
    } else {
      // 2. Start a 30-second Ringing Timeout
      _ringTimeoutTimer = Timer(const Duration(seconds: 30), () {
        if (!_isConnected && mounted) {
          _callTimer?.cancel();
          SignalingService.instance.sendHangup(widget.targetNumber);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No Answer (Call timed out after 30s)'),
              backgroundColor: Colors.orangeAccent,
              duration: Duration(seconds: 4),
            ),
          );
          Navigator.pop(context);
        }
      });

      // 3. Send real call offer via signaling service
      SignalingService.instance.sendCallOffer(
        widget.targetNumber,
        {'type': 'offer', 'sdp': 'webrtc_pion_sdp'},
        callType: widget.isVideo ? 'video' : 'audio',
      );
    }
  }

  void _startTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callSeconds++);
      }
    });
  }

  void _onPeerHangup() {
    _ringTimeoutTimer?.cancel();
    _callTimer?.cancel();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call ended'), duration: Duration(seconds: 2)),
      );
      Navigator.pop(context);
    }
  }

  void _endCall() {
    _ringTimeoutTimer?.cancel();
    _callTimer?.cancel();
    SignalingService.instance.sendHangup(widget.targetNumber);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _ringTimeoutTimer?.cancel();
    _callTimer?.cancel();
    _signalingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            // Header: Target Info
            Text(
              widget.targetName,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.targetNumber,
                style: const TextStyle(fontSize: 16, color: IosTheme.primaryGreen, fontWeight: FontWeight.w600, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isConnected ? _formatDuration(_callSeconds) : 'Ringing & Waiting for Answer...',
              style: TextStyle(
                fontSize: 15,
                color: _isConnected ? Colors.white70 : Colors.amberAccent,
                fontWeight: _isConnected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),

            const Spacer(),

            // Visualizer or Video view
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated breathing ripple rings
                  if (_isConnected)
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: IosTheme.primaryGreen.withValues(alpha: 0.3), width: 2),
                      ),
                    ),
                  CircleAvatar(
                    radius: 65,
                    backgroundColor: const Color(0xFF2C2C2E),
                    child: Icon(
                      widget.isVideo ? Icons.videocam : Icons.person,
                      size: 60,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Bottom In-Call Action Grid (iOS phone call style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCallActionButton(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        label: 'Mute',
                        isActive: _isMuted,
                        onTap: () => setState(() => _isMuted = !_isMuted),
                      ),
                      _buildCallActionButton(
                        icon: Icons.dialpad,
                        label: 'Keypad',
                        isActive: false,
                        onTap: () {},
                      ),
                      _buildCallActionButton(
                        icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                        label: 'Speaker',
                        isActive: _isSpeakerOn,
                        onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCallActionButton(
                        icon: _isVideoCamOn ? Icons.videocam : Icons.videocam_off,
                        label: 'Video',
                        isActive: _isVideoCamOn,
                        onTap: () => setState(() => _isVideoCamOn = !_isVideoCamOn),
                      ),
                      _buildCallActionButton(
                        icon: Icons.bluetooth,
                        label: 'Audio',
                        isActive: false,
                        onTap: () {},
                      ),
                      _buildCallActionButton(
                        icon: Icons.chat_bubble_outline,
                        label: 'Chat',
                        isActive: false,
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // End Call Button (Big Red Circle)
            GestureDetector(
              onTap: _endCall,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.call_end,
                  size: 36,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCallActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : const Color(0xFF2C2C2E),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 28,
              color: isActive ? Colors.black : Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
