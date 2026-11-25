import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/ios_theme.dart';
import '../calling/in_call_screen.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<Map<String, dynamic>> _allCalls = [];
  bool _loading = true;
  int _selectedSegment = 0; // 0 = All, 1 = Missed

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final list = await ApiService.instance.getCallHistory();
    if (mounted) {
      setState(() {
        _allCalls = list;
        _loading = false;
      });
    }
  }

  Future<void> _clearAll() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear Call History?',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to remove all call records? This cannot be undone.',
          style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF3A3A3C)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ApiService.instance.clearCallHistory();
      if (success && mounted) {
        setState(() {
          _allCalls.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call history cleared'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _deleteCall(String id) async {
    final success = await ApiService.instance.deleteCallLog(id);
    if (success && mounted) {
      setState(() {
        _allCalls.removeWhere((c) => c['id'] == id);
      });
    }
  }

  String _formatCallTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp.toString()).toLocal();
      final now = DateTime.now();
      final diffDays = now.difference(dt).inDays;

      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      final timeStr = '$hour:$min $period';

      if (diffDays == 0 && dt.day == now.day) {
        return timeStr;
      } else if (diffDays <= 1) {
        return 'Yesterday';
      } else if (diffDays < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[dt.weekday - 1];
      } else {
        return '${dt.day}/${dt.month}';
      }
    } catch (_) {
      return '';
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return 'Missed';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) {
      return '${m}m ${s}s';
    }
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final dividerColor = isDark ? Colors.white10 : const Color(0xFFE5E5EA);

    final filteredCalls = _selectedSegment == 1
        ? _allCalls.where((c) => (c['status'] ?? '').toString().toLowerCase() == 'missed').toList()
        : _allCalls;

    return Scaffold(
      appBar: AppBar(
        title: CupertinoSlidingSegmentedControl<int>(
          backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          thumbColor: isDark ? const Color(0xFF636366) : Colors.white,
          groupValue: _selectedSegment,
          children: {
            0: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'All',
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            1: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Missed',
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          },
          onValueChanged: (val) {
            if (val != null) setState(() => _selectedSegment = val);
          },
        ),
        centerTitle: true,
        actions: [
          if (_allCalls.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: secondaryTextColor),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : filteredCalls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.phone_badge_plus,
                        size: 64,
                        color: secondaryTextColor.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedSegment == 1 ? 'No Missed Calls' : 'No Recent Calls',
                        style: TextStyle(fontSize: 18, color: secondaryTextColor, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your call history will appear here.',
                        style: TextStyle(fontSize: 14, color: secondaryTextColor.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.separated(
                    itemCount: filteredCalls.length,
                    separatorBuilder: (context, index) => Divider(height: 1, indent: 56, color: dividerColor),
                    itemBuilder: (ctx, idx) {
                      final call = filteredCalls[idx];
                      final isOutgoing = call['is_outgoing'] == true;
                      final isMissed = (call['status'] ?? '').toString().toLowerCase() == 'missed';
                      final isVideo = (call['call_type'] ?? '').toString().toLowerCase() == 'video';
                      final peerName = call['peer_name'] ?? call['peer_number'] ?? 'IntraCom User';
                      final peerNumber = call['peer_number'] ?? '';
                      final peerDistrict = call['peer_district'] ?? '';
                      final duration = call['duration_seconds'] is int ? call['duration_seconds'] as int : 0;
                      final timeStr = _formatCallTime(call['started_at']);

                      return Dismissible(
                        key: Key(call['id']?.toString() ?? '$idx'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(CupertinoIcons.trash, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          if (call['id'] != null) {
                            _deleteCall(call['id'].toString());
                          }
                        },
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Icon(
                              isOutgoing
                                  ? CupertinoIcons.arrow_up_right
                                  : (isMissed ? CupertinoIcons.arrow_down_left : CupertinoIcons.arrow_down_left),
                              color: isMissed
                                  ? Colors.redAccent
                                  : (isOutgoing ? IosTheme.accentBlue : IosTheme.primaryGreen),
                              size: 18,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  peerName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isMissed ? Colors.redAccent : primaryTextColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                timeStr,
                                style: TextStyle(fontSize: 13, color: secondaryTextColor),
                              ),
                            ],
                          ),
                          subtitle: Row(
                            children: [
                              if (isVideo)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(CupertinoIcons.video_camera, size: 14, color: secondaryTextColor),
                                ),
                              Text(
                                '$peerNumber ${peerDistrict.isNotEmpty ? "• $peerDistrict" : ""}',
                                style: TextStyle(fontSize: 13, color: secondaryTextColor),
                              ),
                              if (!isMissed && duration > 0) ...[
                                Text(' • ', style: TextStyle(color: secondaryTextColor)),
                                Text(_formatDuration(duration), style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                              ],
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(CupertinoIcons.phone_fill, color: IosTheme.primaryGreen, size: 20),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InCallScreen(
                                    targetNumber: peerNumber,
                                    targetName: peerName,
                                    isVideo: isVideo,
                                  ),
                                ),
                              );
                            },
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InCallScreen(
                                  targetNumber: peerNumber,
                                  targetName: peerName,
                                  isVideo: isVideo,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
