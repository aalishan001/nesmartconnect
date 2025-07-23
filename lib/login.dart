import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:NESmartConnect/splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'home.dart'; // Assuming HomeView is in home.dart
import 'services/api_service.dart'; // Import the API service

// Initialize the API service
final apiService = APIService();

class LoginScreen extends StatefulWidget {
  final VoidCallback onSwitchToSignup;
  const LoginScreen({Key? key, required this.onSwitchToSignup}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

Future<void> _login() async {
  final phone = _phoneController.text.trim();
  final password = _passwordController.text.trim();
  
  if (phone.isEmpty || password.isEmpty) {
    _showSnackBar('All fields are required');
    return;
  }
  if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
    _showSnackBar('Enter a valid 10-digit phone number');
    return;
  }
  
  setState(() {
    _isLoading = true;
  });
  
  try {
    // First check if server is reachable
    final isServerUp = await apiService.isServerReachable();
    if (!isServerUp) {
      _showSnackBar('Server is unreachable. Please check your internet connection or try again later.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Dummy login
    if (phone == '1234567890' && password == 'dummycredential') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('u_id', 'dummy_001');
      await prefs.setString('username', 'Dummy User');
      await prefs.setString('acc_number', phone);
      print('Login: Dummy credentials used. User logged in as Dummy User.');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeView()),
      );
      return;
    }
    
    // API login for other credentials - replace with API service
    final data = await apiService.login(phone, password);
    
    print('Login response status: ${data['errFlag']}');
    print('Login response body: ${data['message']}');
    print('Login response user: ${data['user']}');
    print('Login response token: ${data['token']}'); // Assuming token is part of the response

    if (data['errFlag'] == 0) {
      final user = data['user'];
      if (user['u_id'] == null) {
        print('Login error: u_id missing in response');
        _showSnackBar('Login failed: Invalid user data from server');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('u_id', user['u_id']);
      await prefs.setString('username', user['username']);
      await prefs.setString('acc_number', user['acc_number']);
      
      // Store controlling_numbers if available
      if (user['controlling_numbers'] != null) {
        await prefs.setStringList('controlling_numbers', 
          List<String>.from(user['controlling_numbers']));
      }
      
      print('Login: Saved u_id=${user['u_id']}, username=${user['username']}, acc_number=${user['acc_number']}');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeView()),
      );
    } else {
      _showSnackBar('Login failed: ${data['message']}');
    }
  } catch (e) {
    print('Login error: $e');
    _showSnackBar('Error during login: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 454,
      clipBehavior: Clip.antiAlias,
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            top: 206,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Password',
                  style: TextStyle(
                    color: Color(0xFF716D69),
                    fontSize: 14,
                    fontFamily: 'Inter Display',
                    fontWeight: FontWeight.w400,
                    height: 1.57,
                  ),
                ),
                Container(
                  height: 52,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        width: 1,
                        color: Color(0xFFE1E0DF),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(12, 14, 12, 14),
                      hintText: 'Enter your password',
                      hintStyle: TextStyle(
                        color: Color(0xFFC4C2C0),
                        fontSize: 16,
                        fontFamily: 'Inter Display',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 108,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mobile Number',
                  style: TextStyle(
                    color: Color(0xFF716D69),
                    fontSize: 14,
                    fontFamily: 'Inter Display',
                    fontWeight: FontWeight.w400,
                    height: 1.57,
                  ),
                ),
                Container(
                  height: 52,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        width: 1,
                        color: Color(0xFFE1E0DF),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        padding: const EdgeInsets.all(10),
                        decoration: const ShapeDecoration(
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              width: 1,
                              color: Color(0xFFE1E0DF),
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            '+91',
                            style: TextStyle(
                              color: Color(0xFF030100),
                              fontSize: 16,
                              fontFamily: 'Inter Display',
                              fontWeight: FontWeight.w400,
                              height: 1.50,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.fromLTRB(12, 14, 12, 14),
                            hintText: 'Enter your mobile number',
                            hintStyle: TextStyle(
                              color: Color(0xFFC4C2C0),
                              fontSize: 16,
                              fontFamily: 'Inter Display',
                              fontWeight: FontWeight.w400,
                              height: 1.50,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Log In',
                  style: TextStyle(
                    color: Color(0xFF030100),
                    fontSize: 24,
                    fontFamily: 'Inter Display',
                    fontWeight: FontWeight.w600,
                    height: 1.33,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Access your account to manage your devices',
                  style: TextStyle(
                    color: Color(0xFF8C8885),
                    fontSize: 16,
                    fontFamily: 'Inter Display',
                    fontWeight: FontWeight.w400,
                    height: 1.50,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 322,
            child: GestureDetector(
              onTap: _isLoading ? null : _login,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: ShapeDecoration(
                  color: const Color(0xFF800214),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(200),
                  ),
                ),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF716D69)),
                          ),
                        )
                      : const Text(
                          'Login',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontSize: 16,
                            fontFamily: 'Inter Display',
                            fontWeight: FontWeight.w600,
                            height: 1.50,
                          ),
                        ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 398,
            child: Center(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Don’t have an account? ',
                      style: TextStyle(
                        color: Color(0xFF8C8885),
                        fontSize: 14,
                        fontFamily: 'Inter Display',
                        fontWeight: FontWeight.w400,
                        height: 1.57,
                      ),
                    ),
                    TextSpan(
                      text: 'Sign Up',
                      style: const TextStyle(
                        color: Color(0xFF800214),
                        fontSize: 14,
                        fontFamily: 'Inter Display',
                        fontWeight: FontWeight.w600,
                        height: 1.57,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = widget.onSwitchToSignup,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  final VoidCallback onSwitchToLogin;
  const SignupScreen({Key? key, required this.onSwitchToLogin}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

Future<void> _signup() async {
  final name = _nameController.text.trim();
  final phone = _phoneController.text.trim();
  final password = _passwordController.text.trim();

  if (name.isEmpty || phone.isEmpty || password.isEmpty) {
    _showSnackBar('All fields are required');
    return;
  }

  if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
    _showSnackBar('Enter a valid 10-digit phone number');
    return;
  }

  if (password.length < 6) {
    _showSnackBar('Password must be at least 6 characters');
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    // Backend signup - using API service
    final data = await apiService.signup(name, phone, password);
    
    print('Signup response: $data');

    if (data['errFlag'] == 0) {
      // Automatically log in the user after signup
      final loginData = await apiService.login(phone, password);
      
      // Rest of the code stays the same
      if (loginData['errFlag'] == 0) {
        final user = loginData['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('u_id', user['u_id']);
        await prefs.setString('username', user['username']);
        await prefs.setString('acc_number', user['acc_number']);
        
        // Store controlling_numbers if available
        if (user['controlling_numbers'] != null) {
          await prefs.setStringList('controlling_numbers', 
            List<String>.from(user['controlling_numbers']));
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeView()),
        );
      } else {
        _showSnackBar('Signup successful, but login failed: ${loginData['message']}');
      }
    } else {
      _showSnackBar('Signup failed: ${data['message']}');
    }
  } catch (e) {
    print('Signup error: $e');
    _showSnackBar('Error during signup: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 552,
      clipBehavior: Clip.antiAlias,
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            top: 304,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Password',
                  style: TextStyle(
                    color: Color(0xFF716D69),
                    fontSize: 14,
                    fontFamily: 'Inter Display',
                    fontWeight: FontWeight.w400,
                    height: 1.57,
                  ),
                ),
                Container(
                  height: 52,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        width: 1,
                        color: Color(0xFFE1E0DF),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(12, 14, 12, 14),
                      hintText: 'Enter your password',
                      hintStyle: TextStyle(
                        color: Color(0xFFC4C2C0),
                        fontSize: 16,
                        fontFamily: 'Inter Display',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 108,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Name',
                  style: TextStyle(
                    color: Color(0xFF716D69),
                    fontSize: 14,
                    fontFamily: 'Inter Display',
                    fontWeight: FontWeight.w400,
                    height: 1.57,
                  ),
                ),
                Container(
                  height: 52,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        width: 1,
                        color: Color(0xFFE1E0DF),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(12, 14, 12, 14),
                      hintText: 'Enter your name',
                      hintStyle: TextStyle(
                        color: Color(0xFFC4C2C0),
                        fontSize: 16,
                        fontFamily: 'Inter Display',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 206,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mobile Number',
                  style: TextStyle(
                    color: Color(0xFF716D69),
                    fontSize: 14,
                    fontFamily: 'Inter Display',
                    fontWeight: FontWeight.w400,
                    height: 1.57,
                  ),
                ),
                Container(
                  height: 52,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        width: 1,
                        color: Color(0xFFE1E0DF),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 50,
                        padding: const EdgeInsets.all(10),
                        decoration: const ShapeDecoration(
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              width: 1,
                              color: Color(0xFFE1E0DF),
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            '+91',
                            style: TextStyle(
                              color: Color(0xFF030100),
                              fontSize: 16,
                              fontFamily: 'Inter Display',
                              fontWeight: FontWeight.w400,
                              height: 1.50,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.fromLTRB(12, 14, 12, 14),
                            hintText: 'Enter your mobile number',
                            hintStyle: TextStyle(
                              color: Color(0xFFC4C2C0),
                              fontSize: 16,
                              fontFamily: 'Inter Display',
                              fontWeight: FontWeight.w400,
                              height: 1.50,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sign Up',
                  style: TextStyle(
                    color: Color(0xFF030100),
                    fontSize: 24,
                    fontFamily: 'Inter Display',
                    fontWeight: FontWeight.w600,
                    height: 1.33,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your account to get started',
                  style: TextStyle(
                    color: Color(0xFF8C8885),
                    fontSize: 16,
                    fontFamily: 'Inter Display',
                    fontWeight: FontWeight.w400,
                    height: 1.50,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 420,
            child: GestureDetector(
              onTap: _isLoading ? null : _signup,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: ShapeDecoration(
                  color: const Color(0xFF800214),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(200),
                  ),
                ),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF800214)),
                          ),
                        )
                      : const Text(
                          'Sign Up',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontSize: 16,
                            fontFamily: 'Inter Display',
                            fontWeight: FontWeight.w600,
                            height: 1.50,
                          ),
                        ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 496,
            child: Center(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(
                        color: Color(0xFF8C8885),
                        fontSize: 14,
                        fontFamily: 'Inter Display',
                        fontWeight: FontWeight.w400,
                        height: 1.57,
                      ),
                    ),
                    TextSpan(
                      text: 'Log In',
                      style: const TextStyle(
                        color: Color(0xFF800214),
                        fontSize: 14,
                        fontFamily: 'Inter Display',
                        fontWeight: FontWeight.w600,
                        height: 1.57,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = widget.onSwitchToLogin,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _showLogin = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    setState(() {
      _isLoggedIn = isLoggedIn;
    });
  }

  void _toggleAuthScreen() {
    setState(() {
      _showLogin = !_showLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return const HomeView();
    }

    return Scaffold(
      body: Stack(
        children: [
          const SplashView(),
          Align(
            alignment: Alignment.bottomCenter,
            child: _showLogin
                ? LoginScreen(onSwitchToSignup: _toggleAuthScreen)
                : SignupScreen(onSwitchToLogin: _toggleAuthScreen),
          ),
        ],
      ),
    );
  }
}