import 'package:flutter/material.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, // 180deg starts from top
            end: Alignment.bottomCenter, // ends at bottom
            colors: [
              Color(0xFF7D030B), // #7D030B at 48.21%
              Color(0xFF030100), // #030100 at 100%
            ],
            stops: [0.4821, 1.0], // Matches 48.21% and 100%
          ),
        ),
        child: Center(
          child: Image.asset(
            'assets/images/Naren_Logo_02.png',
            width: 200.0,
          ),
        ),
      ),
    );
  }
}