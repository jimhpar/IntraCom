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
  String _enteredNumber = '';

  void _onDigitPressed(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      _enteredNumber += digit;
    });
  }

  void _onBackspace() {
    HapticFeedback.selectionClick();
    if (_enteredNumber.isNotEmpty) {
      setState(() {
        _enteredNumber = _enteredNumber.substring(0, _enteredNumber.length - 1);
      });
    }
  }

  void _onClear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _enteredNumber = '';
    });
  }

  void _makeCall({bool isVideo = false}) {
    if (_enteredNumber.isEmpty) return;
    HapticFeedback.heavyImpact();

    // Immediately open the In-Call interface!
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InCallScreen(
          targetNumber: _enteredNumber,
          targetName: 'Calling...',
          isVideo: isVideo,
        ),
      ),
    );
  }

  Widget _buildDialKey(BuildContext context, String digit, String subtext, {VoidCallback? onTap, VoidCallback? onLongPress}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final keyText = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final keySubtext = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

    return GestureDetector(
      onTap: onTap ?? () => _onDigitPressed(digit),
      onLongPress: onLongPress,
      child: Container(
        width: 78,
        height: 78,
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
                fontSize: 34,
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
    final placeholderColor = isDark ? Colors.white24 : Colors.black26;
    final hintColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final subHintColor = isDark ? Colors.white38 : const Color(0xFFAEB0B5);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF3A3A3C);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Header display
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
            // Number display with format hint
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                height: 60,
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      _enteredNumber.isEmpty ? 'Enter Number' : _enteredNumber,
                      style: TextStyle(
                        fontSize: _enteredNumber.isEmpty ? 26 : 38,
                        fontWeight: FontWeight.w300,
                        color: _enteredNumber.isEmpty ? placeholderColor : enteredColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_enteredNumber.isNotEmpty)
              Text(
                _enteredNumber.startsWith('+') 
                  ? 'Area Code: ${_enteredNumber.split("-").first}' 
                  : 'Format: +AreaCode-XXXXXXX',
                style: TextStyle(fontSize: 13, color: hintColor),
              )
            else
              Text(
                'e.g. +1-6860499 (Dhaka) or +2-XXXXXXX',
                style: TextStyle(fontSize: 13, color: subHintColor),
              ),
            const Spacer(flex: 1),
            // Dial pad (iOS Style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDialKey(context, '4', 'GHI'),
                      _buildDialKey(context, '5', 'JKL'),
                      _buildDialKey(context, '6', 'MNO'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDialKey(context, '7', 'PQRS'),
                      _buildDialKey(context, '8', 'TUV'),
                      _buildDialKey(context, '9', 'WXYZ'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDialKey(
                        context,
                        '+',
                        '*',
                        onTap: () => _onDigitPressed('+'),
                        onLongPress: () {
                          HapticFeedback.heavyImpact();
                          _onDigitPressed('*');
                        },
                      ),
                      _buildDialKey(context, '0', '+'),
                      _buildDialKey(context, '#', ''),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Bottom actions (Video Call, Call, Backspace)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Video call button
                      SizedBox(
                        width: 78,
                        height: 78,
                        child: _enteredNumber.isNotEmpty
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
                          width: 78,
                          height: 78,
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
                      // Backspace button
                      SizedBox(
                        width: 78,
                        height: 78,
                        child: _enteredNumber.isNotEmpty
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
