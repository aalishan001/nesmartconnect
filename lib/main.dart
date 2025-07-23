import 'package:flutter/material.dart';
import 'package:NESmartConnect/add_dev.dart';
import 'package:NESmartConnect/splash.dart';
import 'package:NESmartConnect/login.dart'; // Import AuthWrapper

import 'home.dart';

void main() async {
  // The native side (MainActivity.kt) now handles all initial permission requests.
  // No need to request them here.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Naren IoT New Fresh',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Inter Display',
      ),
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
    // Navigate to AuthWrapper after splash delay (2 seconds)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SplashView();
  }
}