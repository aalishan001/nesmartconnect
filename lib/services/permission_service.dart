import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static const platform = MethodChannel('com.naren.NESmartConnect/sms');

  static Future<void> requestAllPermissions() async {
    await [Permission.sms, Permission.phone].request();

    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await platform.invokeMethod('promptIgnoreBatteryOpt');
    }
  }
}
