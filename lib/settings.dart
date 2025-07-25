import 'dart:async';
import 'dart:convert';

import 'package:NESmartConnect/dev_screen.dart';
import 'package:NESmartConnect/services/api_service.dart';
import 'package:NESmartConnect/services/sms_parser_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'adv_dev_setting.dart'; // Import the renamed AdvSettings screen

class Settings extends StatefulWidget {
  final String deviceName;
  final String deviceNumber;
  final String deviceCont;
  final String deviceDesc;
  const Settings({
    Key? key,
    required this.deviceName,
    required this.deviceNumber,
    required this.deviceCont,
    required this.deviceDesc,
  }) : super(key: key);

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  static const platform = MethodChannel('com.naren.NESmartConnect/sms');

  // Awaiting Response state
  bool _isAwaitingResponse = false;
  Timer? _awaitingResponseTimer;

  // Voltage and Current state variables
  String _lowVoltage = 'N/A';
  String _highVoltage = 'N/A';
  String _lowCurrent = 'N/A';
  String _highCurrent = 'N/A';
  bool _isEditingLowVoltage = false;
  bool _isEditingHighVoltage = false;
  bool _isEditingLowCurrent = false;
  bool _isEditingHighCurrent = false;
  final TextEditingController _lowVoltageController = TextEditingController();
  final TextEditingController _highVoltageController = TextEditingController();
  final TextEditingController _lowCurrentController = TextEditingController();
  final TextEditingController _highCurrentController = TextEditingController();

  // Device Details state variables
  String _deviceName = '';
  String _deviceDesc = '';
  bool _isEditingDeviceName = false;
  bool _isEditingDeviceDesc = false;
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _deviceDescController = TextEditingController();

  final Map<String, String> _originalValues = {
    'lowVoltage': 'N/A',
    'highVoltage': 'N/A',
    'lowCurrent': 'N/A',
    'highCurrent': 'N/A',
    'phone1': 'Not Set',
    'phone2': 'Not Set',
    'phone3': 'Not Set',
    'hostNumber': 'Not Set',
  };

  // Registered Numbers state variables
  String _phone1 = 'Not Set';
  String _phone2 = 'Not Set';
  String _phone3 = 'Not Set';
  String _hostNumber = 'Not Set';
  bool _isEditingPhone1 = false;
  bool _isEditingPhone2 = false;
  bool _isEditingPhone3 = false;
  final TextEditingController _phone1Controller = TextEditingController();
  final TextEditingController _phone2Controller = TextEditingController();
  final TextEditingController _phone3Controller = TextEditingController();

  // For RLO-specific logic
  bool _hasReceivedLtiUpdate = false; // Flag to prioritize LTI updates

  @override
  void initState() {
    super.initState();
    platform.invokeMethod('startFg');
    _hostNumber = widget.deviceCont; // Set host number initially
    _deviceName = widget.deviceName; // Initialize device name
    _deviceDesc = widget.deviceDesc ?? 'No description'; // Initialize device description
    _deviceNameController.text = _deviceName;
    _deviceDescController.text = _deviceDesc;
    _loadSavedData().then((_) async {
      await _readInitialSms();
      await _setupChannel();
    });
    print('Settings: InitState: Initializing with deviceNumber: ${widget.deviceNumber}');
  }

  @override
  void didUpdateWidget(Settings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceNumber != widget.deviceNumber) {
      // If the device number changes, reload
      _loadSavedData().then((_) async {
        await _readInitialSms();
        await _setupChannel();
      });
    } else {
      // Reload SMS to catch updates
      _readInitialSms().then((_) async {
        await _setupChannel();
      });
    }
  }

 Future<void> _loadSavedData() async {
  final prefs = await SharedPreferences.getInstance();
  final deviceKey = widget.deviceNumber;
  setState(() {
    _lowVoltage = prefs.getString('lowVoltage_$deviceKey') ?? _lowVoltage;
    _highVoltage = prefs.getString('highVoltage_$deviceKey') ?? _highVoltage;
    _lowCurrent = prefs.getString('lowCurrent_$deviceKey') ?? _lowCurrent;
    _highCurrent = prefs.getString('highCurrent_$deviceKey') ?? _highCurrent;
    _phone1 = prefs.getString('phone1_$deviceKey') ?? _phone1;
    _phone2 = prefs.getString('phone2_$deviceKey') ?? _phone2;
    _phone3 = prefs.getString('phone3_$deviceKey') ?? _phone3;
    _hostNumber = widget.deviceCont; // Always use widget.deviceCont
    // Prioritize SharedPreferences over widget values
    _deviceName = prefs.getString('deviceName_$deviceKey') ?? widget.deviceName;
    _deviceDesc = prefs.getString('deviceDesc_$deviceKey') ?? (widget.deviceDesc.isEmpty ? 'No description' : widget.deviceDesc);

    _lowVoltageController.text = _lowVoltage.replaceAll(' V', '');
    _highVoltageController.text = _highVoltage.replaceAll(' V', '');
    _lowCurrentController.text = _lowCurrent.replaceAll(' Amps', '');
    _highCurrentController.text = _highCurrent.replaceAll(' Amps', '');
    _phone1Controller.text = _phone1;
    _phone2Controller.text = _phone2;
    _phone3Controller.text = _phone3;
    _deviceNameController.text = _deviceName;
    _deviceDescController.text = _deviceDesc;

    _originalValues['lowVoltage'] = _lowVoltage;
    _originalValues['highVoltage'] = _highVoltage;
    _originalValues['lowCurrent'] = _lowCurrent;
    _originalValues['highCurrent'] = _highCurrent;
    _originalValues['phone1'] = _phone1;
    _originalValues['phone2'] = _phone2;
    _originalValues['phone3'] = _phone3;
    _originalValues['hostNumber'] = _hostNumber;

    print('Settings: LoadSavedData: Loaded data for device $deviceKey');
  });
}

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceKey = widget.deviceNumber;
    await prefs.setString('lowVoltage_$deviceKey', _lowVoltage);
    await prefs.setString('highVoltage_$deviceKey', _highVoltage);
    await prefs.setString('lowCurrent_$deviceKey', _lowCurrent);
    await prefs.setString('highCurrent_$deviceKey', _highCurrent);
    await prefs.setString('phone1_$deviceKey', _phone1);
    await prefs.setString('phone2_$deviceKey', _phone2);
    await prefs.setString('phone3_$deviceKey', _phone3);
    await prefs.setString('hostNumber_$deviceKey', widget.deviceCont);
    await prefs.setString('deviceName_$deviceKey', _deviceName);
    await prefs.setString('deviceDesc_$deviceKey', _deviceDesc);

    _originalValues['lowVoltage'] = _lowVoltage;
    _originalValues['highVoltage'] = _highVoltage;
    _originalValues['lowCurrent'] = _lowCurrent;
    _originalValues['highCurrent'] = _highCurrent;
    _originalValues['phone1'] = _phone1;
    _originalValues['phone2'] = _phone2;
    _originalValues['phone3'] = _phone3;
    _originalValues['hostNumber'] = widget.deviceCont;

    print('Settings: SaveData: Saved data for device $deviceKey');
  }

  Future<void> _readInitialSms() async {
    try {
      print('Settings: ReadInitialSms: Starting for device ${widget.deviceNumber}');
      final smsData = await platform.invokeMethod('readInitialSms', {'phoneNumber': widget.deviceNumber});
      print('Settings: ReadInitialSms: Received data $smsData');
      if (smsData != null && smsData is Map) {
        setState(() {
          if (!_hasReceivedLtiUpdate) { // Only update if no LTI update has occurred
            // 1. Low Voltage
            _lowVoltage = '${smsData['lowVoltage']?.toString().replaceAll(' V', '') ?? _lowVoltage.replaceAll(' V', '')} V';
            _lowVoltageController.text = _lowVoltage.replaceAll(' V', '');

            // 2. High Voltage
            _highVoltage = '${smsData['highVoltage']?.toString().replaceAll(' V', '') ?? _highVoltage.replaceAll(' V', '')} V';
            _highVoltageController.text = _highVoltage.replaceAll(' V', '');

            // 3. High Current
            _highCurrent = '${smsData['highCurrent']?.toString().replaceAll(' Amps', '') ?? _highCurrent.replaceAll(' Amps', '')} Amps';
            _highCurrentController.text = _highCurrent.replaceAll(' Amps', '');

            // 4. Low Current
            _lowCurrent = '${smsData['lowCurrent']?.toString().replaceAll(' Amps', '') ?? _lowCurrent.replaceAll(' Amps', '')} Amps';
            _lowCurrentController.text = _lowCurrent.replaceAll(' Amps', '');

            // 12. Phone Numbers
            _phone1 = smsData['phoneNumber1']?.toString() ?? _phone1;
            _phone2 = smsData['phoneNumber2']?.toString() ?? _phone2;
            _phone3 = smsData['phoneNumber3']?.toString() ?? _phone3;
            _phone1Controller.text = _phone1;
            _phone2Controller.text = _phone2;
            _phone3Controller.text = _phone3;

            print('Settings: RLO Fetched Values:');
            print('Low Voltage: $_lowVoltage');
            print('High Voltage: $_highVoltage');
            print('Low Current: $_lowCurrent');
            print('High Current: $_highCurrent');
            print('Phone Numbers: 1=$_phone1, 2=$_phone2, 3=$_phone3');
          } else {
            print('Settings: RLO Skipped: LTI update already received');
          }
        });
      }
    } catch (e) {
      print('Settings: Error reading initial SMS: $e');
    }
  }

  Future<void> _setupChannel() async {
    print('Settings: SetupChannel: Setting up MethodChannel for ${widget.deviceNumber}');
platform.setMethodCallHandler((call) async {
      if (call.method == 'onRawSmsReceived') {
        final rawData = call.arguments as Map;
        final smsService = SmsService();
        final params = await smsService.parseSms(
          rawData['messageBody'] ?? '',
          rawData['phoneNumber'] ?? widget.deviceNumber,
          rawData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        );

        if (mounted) {
          setState(() {
            _hasReceivedLtiUpdate = true;
            // Update only if new values are found
            if (params['lowVoltage'] != null && params['lowVoltage'] != 'N/A') {
              _lowVoltage = '${params['lowVoltage']} V';
              _lowVoltageController.text = params['lowVoltage'].toString();
            }
            if (params['highVoltage'] != null &&
                params['highVoltage'] != 'N/A') {
              _highVoltage = '${params['highVoltage']} V';
              _highVoltageController.text = params['highVoltage'].toString();
            }
            if (params['highCurrent'] != null &&
                params['highCurrent'] != 'N/A') {
              _highCurrent = '${params['highCurrent']} Amps';
              _highCurrentController.text = params['highCurrent'].toString();
            }
            if (params['lowCurrent'] != null && params['lowCurrent'] != 'N/A') {
              _lowCurrent = '${params['lowCurrent']} Amps';
              _lowCurrentController.text = params['lowCurrent'].toString();
            }
            if (params['phoneNumber1'] != null &&
                params['phoneNumber1'] != 'N/A') {
              _phone1 = params['phoneNumber1'].toString();
              _phone1Controller.text = _phone1;
            }
            if (params['phoneNumber2'] != null &&
                params['phoneNumber2'] != 'N/A') {
              _phone2 = params['phoneNumber2'].toString();
              _phone2Controller.text = _phone2;
            }
            if (params['phoneNumber3'] != null &&
                params['phoneNumber3'] != 'N/A') {
              _phone3 = params['phoneNumber3'].toString();
              _phone3Controller.text = _phone3;
            }
            _saveData();
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Response Received: Updated')),
            );
          }
        }
      }
      // Keep other handlers unchanged
      else if (call.method == 'responseReceived') {
        // existing code
      } else if (call.method == 'responseTimeout') {
        // existing code
      }
    });

  }

Future<void> _sendSms(String message) async {
  if (_isAwaitingResponse) return;

  // Check user session is valid
  final prefs = await SharedPreferences.getInstance();
  final uId = prefs.getString('u_id');
  if (uId == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID not found. Please log in again.')),
      );
    }
    return;
  }

  // Remove user status verification block
  // final prefs = await SharedPreferences.getInstance();
  // final userJson = prefs.getString('user_data');
  // final Map<String, dynamic> userData = userJson != null ? jsonDecode(userJson) : {};
  
  setState(() {
    _isAwaitingResponse = true;
    print('SendSms: Sending message "$message" to ${widget.deviceNumber} from ${widget.deviceCont}');
  });
  Timer(const Duration(seconds: 45), () {
      if (mounted && _isAwaitingResponse) {
        setState(() {
          _isAwaitingResponse = false;
        });
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Response Timed Out After 45 Seconds')),
        // );
      }
    });
  
  try {
    await platform.invokeMethod('sendSmsAndWaitForResponse', {
      'phoneNumber': widget.deviceNumber,
      'message': message,
      'senderNumber': widget.deviceCont,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Command Sent, Waiting for Response')),
      );
    }
    
    // Log SMS using APIService
    final apiService = APIService();
    await apiService.logSms(message, widget.deviceCont, widget.deviceNumber);
  } catch (e) {
    // Rest of the function
  }
}

  bool _isValidInteger(String value) {
    return int.tryParse(value) != null;
  }

  void _navigateToAdvSettings() async {
    // Show password dialog
    String? enteredPassword;
    final bool? dialogResult = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: 335,
          height: 200,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17.40),
            ),
            shadows: [
              BoxShadow(
                color: Color(0x19000000),
                blurRadius: 20,
                offset: Offset(0, 2),
                spreadRadius: 0,
              )
            ],
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Container(
                      child: Text(
                        'Enter Password',
                        style: TextStyle(
                          color: const Color(0xFF030100),
                          fontSize: 16,
                          fontFamily: 'Inter Display',
                          fontWeight: FontWeight.w600,
                          height: 1.50,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                TextField(
                  onChanged: (value) {
                    enteredPassword = value;
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                        width: 1,
                        strokeAlign: BorderSide.strokeAlignCenter,
                        color: const Color.fromARGB(255, 188, 188, 189),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        width: 1,
                        strokeAlign: BorderSide.strokeAlignCenter,
                        color: const Color.fromARGB(255, 204, 203, 203),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        width: 1,
                        strokeAlign: BorderSide.strokeAlignCenter,
                        color: const Color.fromARGB(255, 165, 214, 163),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    labelText: 'Password',
                    labelStyle: TextStyle(fontSize: 12),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context, false); // Cancel returns false
                        },
                        child: Container(
                          height: 40,
                          clipBehavior: Clip.antiAlias,
                          decoration: ShapeDecoration(
                            color: const Color(0xFFE1E0DF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Cancel',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFF716D69),
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (enteredPassword == widget.deviceName) {
                            Navigator.pop(context, true); // Submit with true
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Incorrect Password')),
                            );
                          }
                        },
                        child: Container(
                          height: 40,
                          clipBehavior: Clip.antiAlias,
                          decoration: ShapeDecoration(
                            color: const Color(0xFF800214),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Submit',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ));

    if (dialogResult == true) {
      print('Settings: Navigating to AdvSettings');
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdvDevSettings(
            deviceName: widget.deviceName,
            deviceNumber: widget.deviceNumber,
            deviceCont: widget.deviceCont,
          ),
        ),
      );
      print('Settings: Received result from AdvSettings: $result');
      if (result == true) {
        print('Settings: AdvSettings popped: Reloading initial SMS');
        await _readInitialSms();
        await _setupChannel();
      }
    }
  }

  @override
  void dispose() {
    platform.invokeMethod('stopFg');
    _awaitingResponseTimer?.cancel();
    _lowVoltageController.dispose();
    _highVoltageController.dispose();
    _lowCurrentController.dispose();
    _highCurrentController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _phone3Controller.dispose();
    _deviceNameController.dispose();
    _deviceDescController.dispose();
    super.dispose();
    print('Settings: Dispose: Cleaning up');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        print('Settings: Back button pressed, returning device details');
        Navigator.pop(context, {
          'deviceName': _deviceName,
          'deviceDesc': _deviceDesc,
        });
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x19000000),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 52), // 52px from top
                        child: Container(
                          width: MediaQuery.of(context).size.width - 40,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.arrow_back, color: Color(0xFF030100)),
                                    onPressed: () {
                                      Navigator.pop(context, {
                                        'deviceName': _deviceName,
                                        'deviceDesc': _deviceDesc,
                                      });
                                    },
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Device Settings',
                                    style: TextStyle(
                                      color: Color(0xFF030100),
                                      fontSize: 16,
                                      fontFamily: 'Inter Display',
                                      fontWeight: FontWeight.w600,
                                      height: 1.50,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: _navigateToAdvSettings,
                                child: SvgPicture.asset(
                                  'assets/images/adv_setting.svg',
                                  width: 24,
                                  height: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Device Details
                          Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: ShapeDecoration(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              shadows: [
                                BoxShadow(
                                  color: Color(0x19000000),
                                  blurRadius: 20,
                                  offset: Offset(0, 2),
                                  spreadRadius: 0,
                                )
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DEVICE DETAILS',
                                    style: TextStyle(
                                      color: const Color(0xFF716D69),
                                      fontSize: 13,
                                      fontFamily: 'Inter Display',
                                      fontWeight: FontWeight.w600,
                                      height: 1.67,
                                      letterSpacing: -0.24,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  _buildTextField(
                                    label: 'Name',
                                    value: _deviceName,
                                    controller: _deviceNameController,
                                    isEditing: _isEditingDeviceName,
                                    toggleEdit: () => setState(() => _isEditingDeviceName = !_isEditingDeviceName),
                                    save: () {
                                      final newValue = _deviceNameController.text.trim();
                                      if (newValue.isNotEmpty && newValue != _deviceName) {
                                        setState(() {
                                          _deviceName = newValue;
                                          _isEditingDeviceName = false;
                                          _saveData();
                                        });
                                      } else {
                                        setState(() {
                                          _isEditingDeviceName = false;
                                          _deviceNameController.text = _deviceName;
                                        });
                                      }
                                    },
                                    maxLength: 50,
                                    suffix: '',
                                  ),
                                  SizedBox(height: 16),
                                  _buildTextField(
                                    label: 'Description',
                                    value: _deviceDesc,
                                    controller: _deviceDescController,
                                    isEditing: _isEditingDeviceDesc,
                                    toggleEdit: () => setState(() => _isEditingDeviceDesc = !_isEditingDeviceDesc),
                                    save: () {
                                      final newValue = _deviceDescController.text.trim();
                                      setState(() {
                                        _deviceDesc = newValue.isEmpty ? 'No description' : newValue;
                                        _isEditingDeviceDesc = false;
                                        _saveData();
                                      });
                                    },
                                    maxLength: 200,
                                    suffix: '',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          // Voltage and Current Box
                          Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: ShapeDecoration(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              shadows: [
                                BoxShadow(
                                  color: Color(0x19000000),
                                  blurRadius: 20,
                                  offset: Offset(0, 2),
                                  spreadRadius: 0,
                                )
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'VOLTAGE AND CURRENT',
                                        style: TextStyle(
                                          color: const Color(0xFF716D69),
                                          fontSize: 13,
                                          fontFamily: 'Inter Display',
                                          fontWeight: FontWeight.w600,
                                          height: 1.67,
                                          letterSpacing: -0.24,
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: GestureDetector(
                                          onTap: () => _sendSms(r'*GETAP$'),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                            decoration: ShapeDecoration(
                                              color: Color(0xFFFFEDEA),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(24),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Get values',
                                                  style: TextStyle(
                                                    color: Color(0xFF800214),
                                                    fontSize: 14,
                                                    fontFamily: 'Inter Display',
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.57,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Icon(
                                                  Icons.refresh,
                                                  color: Color(0xFF800214),
                                                  size: 16,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  _buildTextField(
                                    label: 'Low Current Value',
                                    value: _lowCurrent,
                                    controller: _lowCurrentController,
                                    isEditing: _isEditingLowCurrent,
                                    toggleEdit: () => setState(() => _isEditingLowCurrent = !_isEditingLowCurrent),
                                    save: () {
                                      final newValue = _lowCurrentController.text.padLeft(2, '0');
                                      final originalValue = _originalValues['lowCurrent']?.replaceAll(' Amps', '') ?? '';
                                      if (_isValidInteger(newValue) && newValue != originalValue) {
                                        setState(() {
                                          _lowCurrent = '$newValue Amps';
                                          _isEditingLowCurrent = false;
                                          _sendSms('*SETLC-$newValue\$');
                                          _saveData();
                                          _originalValues['lowCurrent'] = _lowCurrent;
                                        });
                                      } else {
                                        setState(() {
                                          _isEditingLowCurrent = false;
                                          _lowCurrentController.text = _originalValues['lowCurrent']?.replaceAll(' Amps', '') ?? _lowCurrent.replaceAll(' Amps', '');
                                        });
                                      }
                                    },
                                    maxLength: 2,
                                    suffix: 'Amps',
                                  ),
                                  SizedBox(height: 16),
                                  _buildTextField(
                                    label: 'High Current Value',
                                    value: _highCurrent,
                                    controller: _highCurrentController,
                                    isEditing: _isEditingHighCurrent,
                                    toggleEdit: () => setState(() => _isEditingHighCurrent = !_isEditingHighCurrent),
                                    save: () {
                                      final newValue = _highCurrentController.text.padLeft(2, '0');
                                      final originalValue = _originalValues['highCurrent']?.replaceAll(' Amps', '') ?? '';
                                      if (_isValidInteger(newValue) && newValue != originalValue) {
                                        setState(() {
                                          _highCurrent = '$newValue Amps';
                                          _isEditingHighCurrent = false;
                                          _sendSms('*SETHC-$newValue\$');
                                          _saveData();
                                          _originalValues['highCurrent'] = _highCurrent;
                                        });
                                      } else {
                                        setState(() {
                                          _isEditingHighCurrent = false;
                                          _highCurrentController.text = _originalValues['highCurrent']?.replaceAll(' Amps', '') ?? _highCurrent.replaceAll(' Amps', '');
                                        });
                                      }
                                    },
                                    maxLength: 2,
                                    suffix: 'Amps',
                                  ),
                                  SizedBox(height: 16),
                                  _buildTextField(
                                    label: 'Low Voltage Value',
                                    value: _lowVoltage,
                                    controller: _lowVoltageController,
                                    isEditing: _isEditingLowVoltage,
                                    toggleEdit: () => setState(() => _isEditingLowVoltage = !_isEditingLowVoltage),
                                    save: () {
                                      final newValue = _lowVoltageController.text.padLeft(3, '0');
                                      final originalValue = _originalValues['lowVoltage']?.replaceAll(' V', '') ?? '';
                                      if (_isValidInteger(newValue) && newValue != originalValue) {
                                        setState(() {
                                          _lowVoltage = '$newValue V';
                                          _isEditingLowVoltage = false;
                                          _sendSms('*SETLV-$newValue\$');
                                          _saveData();
                                          _originalValues['lowVoltage'] = _lowVoltage;
                                        });
                                      } else {
                                        setState(() {
                                          _isEditingLowVoltage = false;
                                          _lowVoltageController.text = _originalValues['lowVoltage']?.replaceAll(' V', '') ?? _lowVoltage.replaceAll(' V', '');
                                        });
                                      }
                                    },
                                    maxLength: 3,
                                    suffix: 'V',
                                  ),
                                  SizedBox(height: 16),
                                  _buildTextField(
                                    label: 'High Voltage Value',
                                    value: _highVoltage,
                                    controller: _highVoltageController,
                                    isEditing: _isEditingHighVoltage,
                                    toggleEdit: () => setState(() => _isEditingHighVoltage = !_isEditingHighVoltage),
                                    save: () {
                                      final newValue = _highVoltageController.text.padLeft(3, '0');
                                      final originalValue = _originalValues['highVoltage']?.replaceAll(' V', '') ?? '';
                                      if (_isValidInteger(newValue) && newValue != originalValue) {
                                        setState(() {
                                          _highVoltage = '$newValue V';
                                          _isEditingHighVoltage = false;
                                          _sendSms('*SETHV-$newValue\$');
                                          _saveData();
                                          _originalValues['highVoltage'] = _highVoltage;
                                        });
                                      } else {
                                        setState(() {
                                          _isEditingHighVoltage = false;
                                          _highVoltageController.text = _originalValues['highVoltage']?.replaceAll(' V', '') ?? _highVoltage.replaceAll(' V', '');
                                        });
                                      }
                                    },
                                    maxLength: 3,
                                    suffix: 'V',
                                  ),
                                  
                                  
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          // Registered Numbers Box
                          Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: ShapeDecoration(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              shadows: [
                                BoxShadow(
                                  color: Color(0x19000000),
                                  blurRadius: 20,
                                  offset: Offset(0, 2),
                                  spreadRadius: 0,
                                )
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'REGISTERED NOS.',
                                        style: TextStyle(
                                          color: const Color(0xFF716D69),
                                          fontSize: 13,
                                          fontFamily: 'Inter Display',
                                          fontWeight: FontWeight.w600,
                                          height: 1.67,
                                          letterSpacing: -0.24,
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: GestureDetector(
                                          onTap: () => _sendSms(r'*GETRPN$'),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                            decoration: ShapeDecoration(
                                              color: Color(0xFFFFEDEA),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(24),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Get reg numbers',
                                                  style: TextStyle(
                                                    color: const Color(0xFF800214),
                                                    fontSize: 14,
                                                    fontFamily: 'Inter Display',
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.57,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Icon(
                                                  Icons.refresh,
                                                  color: Color(0xFF800214),
                                                  size: 16,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  _buildTextField(
                                    label: 'Phone 1',
                                    value: _phone1,
                                    controller: _phone1Controller,
                                    isEditing: _isEditingPhone1,
                                    toggleEdit: _phone1 != widget.deviceCont.replaceFirst('+91', '')
                                        ? () => setState(() => _isEditingPhone1 = !_isEditingPhone1)
                                        : null,
                                    save: () {
                                      final newValue = _phone1Controller.text;
                                      final originalValue = _originalValues['phone1'] ?? '';
                                      if (newValue.length == 10 && newValue != originalValue) {
                                        setState(() {
                                          _phone1 = newValue;
                                          _isEditingPhone1 = false;
                                          _sendSms('*CHP1-$newValue\$');
                                          _saveData();
                                          _originalValues['phone1'] = _phone1;
                                        });
                                      } else {
                                        setState(() {
                                          _isEditingPhone1 = false;
                                          _phone1Controller.text = _originalValues['phone1'] ?? _phone1;
                                        });
                                      }
                                    },
                                    maxLength: 10,
                                    enabled: _phone1 != widget.deviceCont.replaceFirst('+91', ''),
                                  ),
                                  SizedBox(height: 16),
                                  _buildTextField(
                                    label: 'Phone 2',
                                    value: _phone2,
                                    controller: _phone2Controller,
                                    isEditing: _isEditingPhone2,
                                    toggleEdit: _phone2 != widget.deviceCont.replaceFirst('+91', '')
                                        ? () => setState(() => _isEditingPhone2 = !_isEditingPhone2)
                                        : null,
                                    save: () {
                                      final newValue = _phone2Controller.text;
                                      final originalValue = _originalValues['phone2'] ?? '';
                                      if (newValue.length == 10 && newValue != originalValue) {
                                        setState(() {
                                          _phone2 = newValue;
                                          _isEditingPhone2 = false;
                                          _sendSms('*CHP2-$newValue\$');
                                          _saveData();
                                          _originalValues['phone2'] = _phone2;
                                        });
                                      } else {
                                        setState(() {
                                          _isEditingPhone2 = false;
                                          _phone2Controller.text = _originalValues['phone2'] ?? _phone2;
                                        });
                                      }
                                    },
                                    maxLength: 10,
                                    enabled: _phone2 != widget.deviceCont.replaceFirst('+91', ''),
                                  ),
                                  SizedBox(height: 16),
                                  _buildTextField(
                                    label: 'Phone 3',
                                    value: _phone3,
                                    controller: _phone3Controller,
                                    isEditing: _isEditingPhone3,
                                    toggleEdit: _phone3 != widget.deviceCont.replaceFirst('+91', '')
                                        ? () => setState(() => _isEditingPhone3 = !_isEditingPhone3)
                                        : null,
                                    save: () {
                                      final newValue = _phone3Controller.text;
                                      final originalValue = _originalValues['phone3'] ?? '';
                                      if (newValue.length == 10 && newValue != originalValue) {
                                        setState(() {
                                          _phone3 = newValue;
                                          _isEditingPhone3 = false;
                                          _sendSms('*CHP3-$newValue\$');
                                          _saveData();
                                          _originalValues['phone3'] = _phone3;
                                        });
                                      } else {
                                        setState(() {
                                          _isEditingPhone3 = false;
                                          _phone3Controller.text = _originalValues['phone3'] ?? _phone3;
                                        });
                                      }
                                    },
                                    maxLength: 10,
                                    enabled: _phone3 != widget.deviceCont.replaceFirst('+91', ''),
                                  ),
                                  SizedBox(height: 16),
                                  Text('  Host Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  SizedBox(height: 8),
                                  Container(
                                    height: 56,
                                    width: 500,
                                    decoration: ShapeDecoration(
                                      shape: RoundedRectangleBorder(
                                        side: BorderSide(
                                          width: 1,
                                          color: Color(0xFFE1E0DF),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      child: Text(
                                        _hostNumber,
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
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_isAwaitingResponse)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Awaiting Response...', style: TextStyle(color: Colors.white, fontSize: 20)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback? toggleEdit,
    required VoidCallback save,
    required int maxLength,
    String? suffix,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '  $label',
          style: TextStyle(fontSize: 14),
        ),
        SizedBox(height: 4),
        Container(
          height: 56,
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: 1,
                color: Color(0xFFE1E0DF),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 16, top: 16, bottom: 16),
                  child: isEditing
                      ? TextField(
                          controller: controller,
                          keyboardType: TextInputType.text,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(maxLength),
                          ],
                          enabled: enabled,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(bottom: 13),
                            suffixStyle: TextStyle(
                              color: Color(0xFF030100),
                              fontSize: 16,
                              fontFamily: 'Inter Display',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          style: TextStyle(
                            color: Color(0xFF030100),
                            fontSize: 16,
                            fontFamily: 'Inter Display',
                            fontWeight: FontWeight.w400,
                            height: 1.50,
                          ),
                        )
                      : Text(
                          value,
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
              if (enabled)
                Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: isEditing ? save : toggleEdit,
                    child: Text(
                      isEditing ? 'SAVE' : 'EDIT',
                      style: TextStyle(
                        color: Color(0xFF800214),
                        fontSize: 12,
                        fontFamily: 'Inter Display',
                        fontWeight: FontWeight.w600,
                        height: 1.67,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}