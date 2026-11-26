import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../services/api_service.dart';
import '../../services/browser_alert_service.dart';
import '../../services/signaling_service.dart';
import '../../theme/ios_theme.dart';

class InCallScreen extends StatefulWidget {
  final String targetNumber;
  final String targetName;
  final bool isVideo;
  final bool isIncoming;
  final bool initialConnected;
  final dynamic remoteOffer;

  const InCallScreen({
    super.key,
    required this.targetNumber,
    this.targetName = 'IntraCom User',
    this.isVideo = false,
    this.isIncoming = false,
    this.initialConnected = false,
    this.remoteOffer,
  });

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoCamOn = false;
  late bool _isConnected;
  String? _mediaWarning;
  String _iceStatus = '';

  Timer? _callTimer;
  Timer? _ringTimeoutTimer;
  int _callSeconds = 0;
  StreamSubscription? _signalingSub;

  // WebRTC state
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _renderersInitialized = false;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  bool _remoteDescSet = false;

  @override
  void initState() {
    super.initState();
    _isVideoCamOn = widget.isVideo;
    _isConnected = widget.initialConnected;

    // 1. Listen for peer signaling responses BEFORE starting WebRTC
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
        BrowserAlertService.stopRingback();
        if (!_isConnected) {
          setState(() {
            _isConnected = true;
          });
          _startTimer();
        }
        _handleRemoteAnswer(msg['payload']);
      } else if (type == 'call_ice' && isMatch) {
        _handleRemoteIce(msg['payload']);
      } else if ((type == 'call_hangup' || type == 'call_reject') && isMatch) {
        _ringTimeoutTimer?.cancel();
        BrowserAlertService.stopRingback();
        _onPeerHangup();
      } else if (type == 'call_unavailable') {
        _ringTimeoutTimer?.cancel();
        _callTimer?.cancel();
        BrowserAlertService.stopRingback();
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
      BrowserAlertService.playRingback();
      // 2. Start a 30-second Ringing Timeout
      _ringTimeoutTimer = Timer(const Duration(seconds: 30), () {
        if (!_isConnected && mounted) {
          _callTimer?.cancel();
          BrowserAlertService.stopRingback();
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
    }

    // 3. Initialize WebRTC media permissions, TURN/STUN ICE, and SDP exchange
    _initWebRTC();
  }

  Future<void> _initWebRTC() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      if (mounted) {
        setState(() => _renderersInitialized = true);
      }

      // Fetch authenticated STUN + TURN servers in parallel with media permission
      final iceFuture = ApiService.instance.getIceServers();

      // Request browser/device microphone (and HD low-data video if video call) permission
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          },
          'video': widget.isVideo
              ? {
                  'facingMode': 'user',
                  'width': {'ideal': 960, 'max': 1280},
                  'height': {'ideal': 540, 'max': 720},
                  'frameRate': {'ideal': 24, 'max': 30},
                }
              : false,
        });
      } catch (e) {
        if (widget.isVideo) {
          try {
            _localStream = await navigator.mediaDevices.getUserMedia({
              'audio': {
                'echoCancellation': true,
                'noiseSuppression': true,
                'autoGainControl': true,
              },
              'video': false,
            });
            if (mounted) {
              setState(() {
                _isVideoCamOn = false;
                _mediaWarning = 'Camera unavailable — using Audio only';
              });
            }
          } catch (_) {
            if (mounted) {
              setState(() => _mediaWarning = 'Microphone permission denied or unavailable');
            }
          }
        } else {
          if (mounted) {
            setState(() => _mediaWarning = 'Microphone permission denied or unavailable');
          }
        }
      }

      if (_localStream != null && mounted) {
        _localRenderer.srcObject = _localStream;
      }

      final iceServers = await iceFuture;
      _peerConnection = await createPeerConnection({
        'iceServers': iceServers,
        'sdpSemantics': 'unified-plan',
        'iceCandidatePoolSize': 4,
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
      });

      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          final sender = await _peerConnection!.addTrack(track, _localStream!);
          await _tuneSenderBitrate(sender, track.kind);
        }
      } else {
        // Ensure we still receive remote audio/video even if local mic/cam was denied
        await _peerConnection!.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
          init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
        );
        if (widget.isVideo) {
          await _peerConnection!.addTransceiver(
            kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
            init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
          );
        }
      }

      _peerConnection!.onTrack = (RTCTrackEvent event) async {
        if (!mounted) return;
        if (event.streams.isNotEmpty) {
          setState(() {
            _remoteStream = event.streams[0];
            _remoteRenderer.srcObject = _remoteStream;
          });
        } else {
          _remoteStream ??= await createLocalMediaStream('remote_stream');
          await _remoteStream!.addTrack(event.track);
          if (mounted) {
            setState(() {
              _remoteRenderer.srcObject = _remoteStream;
            });
          }
        }
      };

      _peerConnection!.onAddStream = (MediaStream stream) {
        if (mounted) {
          setState(() {
            _remoteStream = stream;
            _remoteRenderer.srcObject = stream;
          });
        }
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        if (!mounted) return;
        setState(() {
          if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
              state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
            _iceStatus = widget.isVideo ? 'FaceTime HD Connected' : 'HD Voice Connected';
          } else if (state == RTCIceConnectionState.RTCIceConnectionStateChecking) {
            _iceStatus = 'Connecting Media...';
          } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
            _iceStatus = 'Media Reconnecting...';
          }
        });
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          SignalingService.instance.sendIceCandidate(widget.targetNumber, {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          });
        }
      };

      if (widget.isIncoming) {
        final offerMap = widget.remoteOffer is Map ? widget.remoteOffer as Map : null;
        final offerSdp = offerMap?['sdp']?.toString();
        final offerType = offerMap?['type']?.toString() ?? 'offer';

        if (offerSdp != null && offerSdp.contains('v=')) {
          await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(offerSdp, offerType),
          );
          _remoteDescSet = true;

          // Consume any early ICE candidates buffered by SignalingService before Accept was clicked
          final buffered = SignalingService.instance.consumeBufferedIce(widget.targetNumber);
          for (final item in buffered) {
            await _handleRemoteIce(item);
          }
          await _flushPendingIce();

          final answer = await _peerConnection!.createAnswer();
          await _peerConnection!.setLocalDescription(answer);
          SignalingService.instance.sendCallAnswer(widget.targetNumber, {
            'type': answer.type,
            'sdp': answer.sdp,
          });
        } else {
          SignalingService.instance.sendCallAnswer(widget.targetNumber, {'type': 'answer'});
        }
      } else {
        // Clear any stale ICE buffer for this peer before new offer
        SignalingService.instance.consumeBufferedIce(widget.targetNumber);

        final offer = await _peerConnection!.createOffer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': widget.isVideo,
        });
        await _peerConnection!.setLocalDescription(offer);
        SignalingService.instance.sendCallOffer(
          widget.targetNumber,
          {'type': offer.type, 'sdp': offer.sdp},
          callType: widget.isVideo ? 'video' : 'audio',
        );
      }
    } catch (e) {
      if (!widget.isIncoming) {
        SignalingService.instance.sendCallOffer(
          widget.targetNumber,
          {'type': 'offer', 'sdp': 'fallback_signaling'},
          callType: widget.isVideo ? 'video' : 'audio',
        );
      } else {
        SignalingService.instance.sendCallAnswer(widget.targetNumber, {'type': 'answer'});
      }
    }
  }

  /// Caps bitrate for crisp FaceTime-like quality with minimal data usage (~4.8 MB/min video, ~240 KB/min audio)
  Future<void> _tuneSenderBitrate(RTCRtpSender sender, String? kind) async {
    try {
      final params = sender.parameters;
      if (params.encodings != null && params.encodings!.isNotEmpty) {
        for (final enc in params.encodings!) {
          if (kind == 'video') {
            enc.maxBitrate = 650000; // 650 kbps crisp HD
            enc.maxFramerate = 24;
          } else if (kind == 'audio') {
            enc.maxBitrate = 32000; // 32 kbps HD Opus
          }
        }
        await sender.setParameters(params);
      }
    } catch (_) {}
  }

  Future<void> _handleRemoteAnswer(dynamic payload) async {
    if (_peerConnection == null || payload is! Map) return;
    final sdp = payload['sdp']?.toString();
    final type = payload['type']?.toString() ?? 'answer';
    if (sdp != null && sdp.contains('v=')) {
      try {
        await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, type));
        _remoteDescSet = true;
        final buffered = SignalingService.instance.consumeBufferedIce(widget.targetNumber);
        for (final item in buffered) {
          await _handleRemoteIce(item);
        }
        await _flushPendingIce();
      } catch (_) {}
    }
  }

  Future<void> _handleRemoteIce(dynamic payload) async {
    if (payload is! Map || payload['candidate'] == null) return;
    final candidate = RTCIceCandidate(
      payload['candidate'].toString(),
      payload['sdpMid']?.toString(),
      payload['sdpMLineIndex'] is int ? payload['sdpMLineIndex'] as int : 0,
    );
    if (_peerConnection != null && _remoteDescSet) {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (_) {}
    } else {
      _pendingRemoteCandidates.add(candidate);
    }
  }

  Future<void> _flushPendingIce() async {
    if (_peerConnection == null) return;
    for (final c in _pendingRemoteCandidates) {
      try {
        await _peerConnection!.addCandidate(c);
      } catch (_) {}
    }
    _pendingRemoteCandidates.clear();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }
    }
  }

  void _toggleVideo() {
    setState(() => _isVideoCamOn = !_isVideoCamOn);
    if (_localStream != null) {
      for (final track in _localStream!.getVideoTracks()) {
        track.enabled = _isVideoCamOn;
      }
    }
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    if (!kIsWeb) {
      try {
        Helper.setSpeakerphoneOn(_isSpeakerOn);
      } catch (_) {}
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
    BrowserAlertService.stopRingback();
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
    BrowserAlertService.stopRingback();
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
    BrowserAlertService.stopRingback();
    SignalingService.instance.consumeBufferedIce(widget.targetNumber);
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _remoteStream?.dispose();
    _peerConnection?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    Future.delayed(const Duration(milliseconds: 500), () {
      ApiService.instance.callHistoryRefreshNotifier.value++;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showRemoteVideo = widget.isVideo && _remoteStream != null && _renderersInitialized;
    final showLocalVideo = _isVideoCamOn && _localStream != null && _renderersInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Active full-screen remote video OR 1x1 WebRTC audio playback element
          if (_renderersInitialized)
            showRemoteVideo
                ? Positioned.fill(
                    child: RTCVideoView(
                      _remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  )
                : Positioned(
                    left: 0,
                    top: 0,
                    width: 1,
                    height: 1,
                    child: Opacity(
                      opacity: 0.01,
                      child: RTCVideoView(_remoteRenderer),
                    ),
                  ),

          // Local PiP Video Preview (muted by default in RTCVideoView? We keep mirror: true)
          if (showLocalVideo)
            Positioned(
              top: 56,
              right: 20,
              width: 110,
              height: 155,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 30),
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
                if (_iceStatus.isNotEmpty && _isConnected) ...[
                  const SizedBox(height: 4),
                  Text(
                    _iceStatus,
                    style: const TextStyle(fontSize: 12, color: IosTheme.primaryGreen, fontWeight: FontWeight.w500),
                  ),
                ],
                if (_mediaWarning != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _mediaWarning!,
                      style: const TextStyle(fontSize: 12, color: Colors.orangeAccent),
                    ),
                  ),
                ],

                const Spacer(),

                if (!showRemoteVideo)
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
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
                            onTap: _toggleMute,
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
                            onTap: _toggleSpeaker,
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
                            onTap: _toggleVideo,
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
        ],
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
