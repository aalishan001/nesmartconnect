import 'dart:convert';
import 'dart:io'; // For SocketException
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math'; // For min() function

class APIService {
  // Base URL - Change this to your actual backend URL
  static const String baseUrl = "https://nesmartconnect-uzggi.ondigitalocean.app";
  
  // Singleton pattern
  static final APIService _instance = APIService._internal();
  factory APIService() => _instance;
  APIService._internal();

  // Login user
  Future<Map<String, dynamic>> login(String accNumber, String password) async {
    try {
      if (kDebugMode) {
        print('Attempting to login with account: $accNumber');
        print('Login URL: $baseUrl/appuser/login');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/appuser/login'),
        body: {
          'acc_number': accNumber,
          'password': password
        }
      );

      // Log response information for debugging
      if (kDebugMode) {
        print('Login response status code: ${response.statusCode}');
        print('Login response headers: ${response.headers}');
        print('Login response body: ${response.body.substring(0, min(100, response.body.length))}...');
      }

      // Check for non-200 status codes
      if (response.statusCode != 200) {
        return {
          'errFlag': 1,
          'message': 'Server error: HTTP ${response.statusCode}',
          'statusCode': response.statusCode
        };
      }

      // Check if response is HTML instead of JSON
      if (response.body.trim().startsWith('<!')) {
        return {
          'errFlag': 1,
          'message': 'Server returned HTML instead of JSON. The server might be down or redirecting.',
          'html': true
        };
      }

      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['errFlag'] == 0) {
        // Store user data locally
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('u_id', data['user']['u_id']);
        prefs.setString('username', data['user']['username']);
        prefs.setString('acc_number', data['user']['acc_number']);
      }
      return data;
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
        // Add more detailed error information
        if (e is FormatException) {
          print('JSON parsing error. Raw response might not be valid JSON.');
        } else if (e is http.ClientException) {
          print('HTTP client error: ${e.message}');
        } else if (e is SocketException) {
          print('Network error: ${e.message}');
        }
      }
      
      return {
        'errFlag': 1,
        'message': 'Connection error. Please check your internet connection.',
        'error': e.toString()
      };
    }
  }

  // User signup
  Future<Map<String, dynamic>> signup(String username, String userMobile, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/appuser/signup'),
        body: {
          'username': username,
          'userMobile': userMobile,
          'password': password,
        }
      );
      return json.decode(response.body);
    } catch (e) {
      if (kDebugMode) {
        print('Signup error: $e');
      }
      return {'errFlag': 1, 'message': 'Network error: $e'};
    }
  }

  // Add device
  Future<Map<String, dynamic>> addDevice(String controlPhone, String devicePhone, String deviceName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/appuser/add-device'),
        body: {
          'control_phone': controlPhone,
          'device_phone': devicePhone,
          'device_name': deviceName,
        }
      );
      return json.decode(response.body);
    } catch (e) {
      if (kDebugMode) {
        print('Add device error: $e');
      }
      return {'errFlag': 1, 'message': 'Network error: $e'};
    }
  }

  // Add device ID
  Future<Map<String, dynamic>> addDeviceId(String devicePhone, String deviceId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/appuser/add-devid'),
        body: {
          'device_phone': devicePhone,
          'device_id': deviceId,
        }
      );
      return json.decode(response.body);
    } catch (e) {
      if (kDebugMode) {
        print('Add device ID error: $e');
      }
      return {'errFlag': 1, 'message': 'Network error: $e'};
    }
  }

  // Log SMS
  Future<Map<String, dynamic>> logSms(String smsText, String senderPhone, String receiverPhone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/appuser/log-sms'),
        body: {
          'sms_text': smsText,
          'sender_phone': senderPhone,
          'receiver_phone': receiverPhone,
        }
      );
      return json.decode(response.body);
    } catch (e) {
      if (kDebugMode) {
        print('Log SMS error: $e');
      }
      return {'errFlag': 1, 'message': 'Network error: $e'};
    }
  }

  // Check user status method if needed
  Future<Map<String, dynamic>> getUserStatus(String userId) async {
    try {
      // Use shared preferences first
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_data');
      if (userJson != null) {
        final userData = json.decode(userJson);
        if (userData.containsKey('status')) {
          return {'errFlag': 0, 'status': userData['status']};
        }
      }
      
      // If needed, add a proper endpoint check for user status
      return {'errFlag': 0, 'status': 'enabled'};
    } catch (e) {
      if (kDebugMode) {
        print('Get user status error: $e');
      }
      return {'errFlag': 1, 'message': 'Error checking user status: $e'};
    }
  }

  // Check if server is reachable
  Future<bool> isServerReachable() async {
    try {
      final response = await http.get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 5));
      
      if (kDebugMode) {
        print('Server connectivity check: ${response.statusCode}');
      }
      return response.statusCode < 500; // Any response under 500 means server is up
    } catch (e) {
      if (kDebugMode) {
        print('Server unreachable: $e');
      }
      return false;
    }
  }
}