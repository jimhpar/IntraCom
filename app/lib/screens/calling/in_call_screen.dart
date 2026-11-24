import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/signaling_service.dart';
import '../../theme/ios_theme.dart';

class InCallScreen extends StatefulWidget {
  final String targetNumber;
  final String targetName;
  final bool isVideo;

  const InCallScreen({
    super.key,
    required this.targetNumber,
    this.targetName = 'IntraCom User',
    this.isVideo = false,
  });

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoCamOn = false;
  bool _isConnected = false;

  Timer? _callTimer;
  int _callSeconds = 0;

  @override
  void initState() {
    super.initState();
    _isVideoCamOn = widget.isVideo;

    // Simulate connection establishing via signaling
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isConnected = true;
        });
        _startTimer();
      }
    });

    // Send call offer via real signaling service
    SignalingService.instance.sendCallOffer(
      widget.targetNumber,
      {'type': 'offer', 'sdp': 'mock_webrtc_sdp'},
      callType: widget.isVideo ? 'video' : 'audio',
    );
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callSeconds++);
      }
    });
  }

  void _endCall() {
    _callTimer?.cancel();
    SignalingService.instance.sendHangup(widget.targetNumber);
    Navigator.pop(context);
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _callTimer?.cancel();
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
              _isConnected ? _formatDuration(_callSeconds) : 'Calling & Connecting...',
              style: TextStyle(
                fontSize: 15,
                color: _isConnected ? Colors.white70 : Colors.white38,
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
                        icon: Icons.volume_up,
                        label: 'Speaker',
                        isActive: _isSpeakerOn,
                        onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                      ),
                      _buildCallActionButton(
                        icon: _isVideoCamOn ? Icons.videocam : Icons.videocam_off,
                        label: 'Video',
                        isActive: _isVideoCamOn,
                        onTap: () => setState(() => _isVideoCamOn = !_isVideoCamOn),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // End Call Button (Big Red Button)
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: IosTheme.destructiveRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
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
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white12,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isActive ? Colors.black : Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }
}
