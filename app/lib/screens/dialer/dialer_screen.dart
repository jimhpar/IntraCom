import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/ios_theme.dart';
import '../calling/in_call_screen.dart';

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  final TextEditingController _numberCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _numberCtrl.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Normalizes any raw input (with or without hyphen, with or without +) into standard call target
  String _normalizeCallNumber(String raw) {
    String s = raw.trim().replaceAll(' ', '');
    if (s.isEmpty) return s;

    // If it's a mobile phone e.g. 017... or +88017...
    if (s.startsWith('01') || s.startsWith('+8801')) {
      return s;
    }

    // If already in +X-XXXXXXX format
    if (RegExp(r'^\+[1-9]-\d{7}$').hasMatch(s)) {
      return s;
    }

    // If in X-XXXXXXX format
    if (RegExp(r'^[1-9]-\d{7}$').hasMatch(s)) {
      return '+$s';
    }

    // If in +XXXXXXXX format (8 digits after +)
    if (RegExp(r'^\+[1-9]\d{7}$').hasMatch(s)) {
      return '${s.substring(0, 2)}-${s.substring(2)}';
    }

    // If 8 digits e.g. 11111111 or 16860499
    if (RegExp(r'^[1-9]\d{7}$').hasMatch(s)) {
      return '+${s[0]}-${s.substring(1)}';
    }

    // If 7 digits e.g. 1111111 or 6860499 -> default to Area +1 (Dhaka)
    if (RegExp(r'^\d{7}$').hasMatch(s)) {
      return '+1-$s';
    }

    // If starts with +1... etc.
    if (!s.startsWith('+') && !s.startsWith('0')) {
      return '+$s';
    }

    return s;
  }

  String _getFormattedDisplayHint(String text) {
    final norm = _normalizeCallNumber(text);
    if (norm.isEmpty) {
      return 'Type number or use keypad (e.g. 1111111 or 16860499)';
    }

    if (norm.startsWith('+1-')) {
      return 'Dhaka Region ($norm)';
    } else if (norm.startsWith('+2-')) {
      return 'Narsingdi Region ($norm)';
    } else if (norm.startsWith('+3-')) {
      return 'Brahmanbaria Region ($norm)';
    } else if (norm.startsWith('+')) {
      return 'Target: $norm';
    }
    return 'Calling: $norm';
  }

  void _insertDigit(String digit) {
    HapticFeedback.lightImpact();
    final text = _numberCtrl.text;
    final selection = _numberCtrl.selection;

    if (selection.isValid && selection.start >= 0 && selection.end >= 0) {
      final start = selection.start;
      final end = selection.end;
      final newText = text.replaceRange(start, end, digit);
      _numberCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + digit.length),
      );
    } else {
      final newText = text + digit;
      _numberCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  void _onBackspace() {
    HapticFeedback.selectionClick();
    final text = _numberCtrl.text;
    final selection = _numberCtrl.selection;

    if (text.isEmpty) return;

    if (selection.isValid && selection.start >= 0 && selection.end >= 0) {
      if (selection.start != selection.end) {
        final start = selection.start;
        final end = selection.end;
        final newText = text.replaceRange(start, end, '');
        _numberCtrl.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start),
        );
        return;
      }
      final cursor = selection.start;
      if (cursor > 0) {
        final newText = text.replaceRange(cursor - 1, cursor, '');
        _numberCtrl.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursor - 1),
        );
      }
    } else {
      final newText = text.substring(0, text.length - 1);
      _numberCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  void _onClear() {
    HapticFeedback.mediumImpact();
    _numberCtrl.clear();
  }

  void _makeCall({bool isVideo = false}) {
    final rawNumber = _numberCtrl.text.trim();
    if (rawNumber.isEmpty) return;
    HapticFeedback.heavyImpact();

    final target = _normalizeCallNumber(rawNumber);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InCallScreen(
          targetNumber: target,
          targetName: 'Calling $target',
          isVideo: isVideo,
        ),
      ),
    );
  }

  Widget _buildDialKey(
    BuildContext context,
    String digit,
    String subtext, {
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final keyText = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final keySubtext = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

    return GestureDetector(
      onTap: onTap ?? () => _insertDigit(digit),
      onLongPress: onLongPress,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: keyBg,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              digit,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w400,
                color: keyText,
                height: 1.1,
              ),
            ),
            if (subtext.isNotEmpty)
              Text(
                subtext,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: keySubtext,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white38 : const Color(0xFF8E8E93);
    final enteredColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final hintColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF3A3A3C);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              'INTRACOM DIALER',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: titleColor,
              ),
            ),
            const Spacer(flex: 1),

            // Number input field with keyboard, paste, and selection support
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                height: 64,
                child: Center(
                  child: TextField(
                    controller: _numberCtrl,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.phone,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w300,
                      color: enteredColor,
                      letterSpacing: 2.0,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter Number',
                      hintStyle: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w300,
                        color: isDark ? Colors.white24 : Colors.black26,
                        letterSpacing: 1.5,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),
            // Intelligent formatted preview helper
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _getFormattedDisplayHint(_numberCtrl.text),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _numberCtrl.text.isNotEmpty ? IosTheme.primaryGreen : hintColor,
                ),
              ),
            ),
            const Spacer(flex: 1),

            // Dial pad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDialKey(context, '1', ''),
                      _buildDialKey(context, '2', 'ABC'),
                      _buildDialKey(context, '3', 'DEF'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDialKey(context, '4', 'GHI'),
                      _buildDialKey(context, '5', 'JKL'),
                      _buildDialKey(context, '6', 'MNO'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDialKey(context, '7', 'PQRS'),
                      _buildDialKey(context, '8', 'TUV'),
                      _buildDialKey(context, '9', 'WXYZ'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDialKey(
                        context,
                        '+',
                        '*',
                        onTap: () => _insertDigit('+'),
                        onLongPress: () {
                          HapticFeedback.heavyImpact();
                          _insertDigit('*');
                        },
                      ),
                      _buildDialKey(context, '0', '+', onLongPress: () {
                        HapticFeedback.heavyImpact();
                        _insertDigit('+');
                      }),
                      _buildDialKey(context, '#', ''),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Bottom actions (Video Call, Call, Backspace)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Video call button
                      SizedBox(
                        width: 76,
                        height: 76,
                        child: _numberCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.videocam_rounded, color: iconColor, size: 30),
                                onPressed: () => _makeCall(isVideo: true),
                              )
                            : const SizedBox.shrink(),
                      ),

                      // Green circular Call button
                      GestureDetector(
                        onTap: () => _makeCall(isVideo: false),
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: const BoxDecoration(
                            color: IosTheme.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.phone,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),

                      // Backspace / Clear button
                      SizedBox(
                        width: 76,
                        height: 76,
                        child: _numberCtrl.text.isNotEmpty
                            ? GestureDetector(
                                onTap: _onBackspace,
                                onLongPress: _onClear,
                                child: Center(
                                  child: Icon(
                                    Icons.backspace_outlined,
                                    color: iconColor,
                                    size: 28,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
