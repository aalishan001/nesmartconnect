import 'package:NESmartConnect/services/rcs_service.dart';
import 'package:flutter/material.dart';
import 'package:NESmartConnect/add_dev.dart';
import 'package:NESmartConnect/splash.dart';
import 'package:NESmartConnect/login.dart'; // Import AuthWrapper

import 'home.dart';

import 'package:NESmartConnect/services/permission_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request all permissions
  await PermissionService.requestAllPermissions();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Naren IoT New Fresh',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Inter Display'),
      home: const SplashWrapper(),
      routes: {
        '/home': (context) => const HomeView(),
        '/adddevice': (context) => const AddDev(),
      },
    );
  }
}

class SplashWrapper extends StatefulWidget {
  const SplashWrapper({Key? key}) : super(key: key);

  @override
  _SplashWrapperState createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Check RCS configuration
    if (await RcsService.shouldShowRcsDialog()) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => RcsService.buildRcsDialog(context),
          ).then((_) {
            _navigateToAuth();
          });
        }
      });
    } else {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _navigateToAuth();
        }
      });
    }
  }

  void _navigateToAuth() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SplashView();
  }
}
