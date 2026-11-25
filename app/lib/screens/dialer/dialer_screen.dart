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

  static const Map<int, String> _districtNames = {
    1: 'Dhaka',
    2: 'Narsingdi',
    3: 'Brahmanbaria',
    4: 'Kishoreganj',
    5: 'Gazipur',
    6: 'Manikganj',
    7: 'Munshiganj',
    8: 'Narayanganj',
    9: 'Tangail',
    10: 'Faridpur',
    11: 'Gopalganj',
    12: 'Madaripur',
    13: 'Rajbari',
    14: 'Shariatpur',
    15: 'Chattogram',
    16: 'Cumilla',
    17: 'Chandpur',
    18: "Cox's Bazar",
    19: 'Feni',
    20: 'Lakshmipur',
    21: 'Noakhali',
    22: 'Rangamati',
    23: 'Khagrachhari',
    24: 'Bandarban',
    25: 'Rajshahi',
    26: 'Naogaon',
    27: 'Natore',
    28: 'Chapainawabganj',
    29: 'Pabna',
    30: 'Bogura',
    31: 'Joypurhat',
    32: 'Sirajganj',
    33: 'Khulna',
    34: 'Bagerhat',
    35: 'Satkhira',
    36: 'Jessore',
    37: 'Magura',
    38: 'Narail',
    39: 'Jhenaidah',
    40: 'Kushtia',
    41: 'Chuadanga',
    42: 'Meherpur',
    43: 'Barishal',
    44: 'Patuakhali',
    45: 'Bhola',
    46: 'Pirojpur',
    47: 'Jhalokati',
    48: 'Barguna',
    49: 'Sylhet',
    50: 'Moulvibazar',
    51: 'Habiganj',
    52: 'Sunamganj',
    53: 'Rangpur',
    54: 'Dinajpur',
    55: 'Thakurgaon',
    56: 'Panchagarh',
    57: 'Nilphamari',
    58: 'Lalmonirhat',
    59: 'Kurigram',
    60: 'Gaibandha',
    61: 'Mymensingh',
    62: 'Jamalpur',
    63: 'Sherpur',
    64: 'Netrokona',
  };

  /// Normalizes any raw input (with or without hyphen, with or without +) into standard call target
  String _normalizeCallNumber(String raw) {
    String s = raw.trim().replaceAll(' ', '');
    if (s.isEmpty) return s;

    // Mobile phones e.g. 017... or +88017...
    if (s.startsWith('01') || s.startsWith('+8801')) {
      return s;
    }

    // 1. If already formatted with hyphen: +X-XXXXXXX or +XX-XXXXXXX or X-XXXXXXX or XX-XXXXXXX
    final hyphenMatch = RegExp(r'^\+?([1-9][0-9]?)-(\d{7})$').firstMatch(s);
    if (hyphenMatch != null) {
      final code = hyphenMatch.group(1)!;
      final num = hyphenMatch.group(2)!;
      return '+$code-$num';
    }

    // 2. If starts with '+':
    if (s.startsWith('+')) {
      final digits = s.substring(1);
      // If 8 digits total after '+': 1-digit code (1-9) + 7-digit number
      if (digits.length == 8) {
        return '+${digits[0]}-${digits.substring(1)}';
      }
      // If 9 digits total after '+': 2-digit code (10-64) + 7-digit number (e.g. +161234567 -> +16-1234567)
      if (digits.length == 9) {
        return '+${digits.substring(0, 2)}-${digits.substring(2)}';
      }
      // If 7 digits after '+': default to Dhaka (+1)
      if (digits.length == 7) {
        return '+1-$digits';
      }
      return s;
    }

    // 3. If purely digits without '+':
    // 7 digits: e.g. 1111111 or 6860499 -> default to Dhaka (+1)
    if (s.length == 7 && RegExp(r'^\d{7}$').hasMatch(s)) {
      return '+1-$s';
    }
    // 8 digits: 1-digit code (1-9) + 7-digit number (e.g. 11111111 -> +1-1111111)
    if (s.length == 8 && RegExp(r'^[1-9]\d{7}$').hasMatch(s)) {
      return '+${s[0]}-${s.substring(1)}';
    }
    // 9 digits: 2-digit code (10-64) + 7-digit number (e.g. 161234567 -> +16-1234567, 257871466 -> +25-7871466)
    if (s.length == 9 && RegExp(r'^[1-6][0-9]\d{7}$').hasMatch(s)) {
      return '+${s.substring(0, 2)}-${s.substring(2)}';
    }

    // Fallback: prepend + if missing
    if (!s.startsWith('+') && !s.startsWith('0')) {
      return '+$s';
    }

    return s;
  }

  String _getFormattedDisplayHint(String text) {
    final s = text.trim().replaceAll(' ', '');
    if (s.isEmpty) {
      return 'Type number or use keypad (e.g. 1111111 or +16-1234567)';
    }

    final norm = _normalizeCallNumber(s);

    // If normalized into standard +Code-Number format
    final match = RegExp(r'^\+([1-9][0-9]?)-(\d{7})$').firstMatch(norm);
    if (match != null) {
      final code = int.tryParse(match.group(1)!) ?? 1;
      final district = _districtNames[code] ?? 'Region $code';
      return '$district Region ($norm)';
    }

    // Live hint while typing partial numbers
    if (s.startsWith('+')) {
      final codeStr = s.replaceAll('+', '').split('-').first;
      final code = int.tryParse(codeStr);
      if (code != null && _districtNames.containsKey(code)) {
        return '${_districtNames[code]} Region (+${code}...)';
      }
    } else if (s.length <= 2) {
      final code = int.tryParse(s);
      if (code != null && _districtNames.containsKey(code)) {
        return '${_districtNames[code]} Region (+${code}...)';
      }
    }

    return 'Target: $norm';
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
