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

  Widget _buildDialKey(String digit, String subtext, {VoidCallback? onTap, VoidCallback? onLongPress}) {
    return GestureDetector(
      onTap: onTap ?? () => _onDigitPressed(digit),
      onLongPress: onLongPress,
      child: Container(
        width: 78,
        height: 78,
        decoration: const BoxDecoration(
          color: IosTheme.dialerKeyDark,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              digit,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w400,
                color: IosTheme.dialerKeyTextDark,
                height: 1.1,
              ),
            ),
            if (subtext.isNotEmpty)
              Text(
                subtext,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: IosTheme.dialerKeySubtextDark,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Header display
            const Text(
              'INTRACOM DIALER',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: Colors.white38,
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
                        color: _enteredNumber.isEmpty ? Colors.white24 : Colors.white,
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
                style: const TextStyle(fontSize: 13, color: Colors.white54),
              )
            else
              const Text(
                'e.g. +1-6860499 (Dhaka) or +2-XXXXXXX',
                style: TextStyle(fontSize: 13, color: Colors.white38),
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
                      _buildDialKey('1', ''),
                      _buildDialKey('2', 'ABC'),
                      _buildDialKey('3', 'DEF'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDialKey('4', 'GHI'),
                      _buildDialKey('5', 'JKL'),
                      _buildDialKey('6', 'MNO'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDialKey('7', 'PQRS'),
                      _buildDialKey('8', 'TUV'),
                      _buildDialKey('9', 'WXYZ'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDialKey(
                        '+',
                        '*',
                        onTap: () => _onDigitPressed('+'),
                        onLongPress: () {
                          HapticFeedback.heavyImpact();
                          _onDigitPressed('*');
                        },
                      ),
                      _buildDialKey('0', ''),
                      _buildDialKey('#', ''),
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
                                icon: const Icon(Icons.videocam_rounded, color: Colors.white70, size: 30),
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
                                child: const Center(
                                  child: Icon(
                                    Icons.backspace_outlined,
                                    color: Colors.white70,
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
