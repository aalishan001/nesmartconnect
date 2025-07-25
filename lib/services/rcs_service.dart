import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RcsService {
  static const String _rcsConfigKey = 'rcs_configured';

static Future<bool> shouldShowRcsDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final configured = prefs.getBool(_rcsConfigKey);
    return configured == null || configured == false;
  }

  static Future<void> markRcsConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rcsConfigKey, true);
  }

  static Widget buildRcsDialog(BuildContext context) {
    return AlertDialog(
      title: Text('SMS Reliability Setup Required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('For reliable SMS reception, please configure Google Messages:'),
          SizedBox(height: 16),
          Text('Option 1: Disable RCS'),
          Text('• Open Google Messages'),
          Text('• Go to Settings → RCS chats'),
          Text('• Turn OFF "RCS chats"'),
          SizedBox(height: 12),
          Text('Option 2: Enable SMS fallback'),
          Text('• Keep RCS ON'),
          Text('• Enable "Automatically resend as SMS/MMS"'),
          Text('• Enable "Use network provided SMS/MMS"'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            markRcsConfigured();
            Navigator.pop(context);
          },
          child: Text('Got it'),
        ),
      ],
    );
  }
}
