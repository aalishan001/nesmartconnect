import 'dart:convert';

import 'package:NESmartConnect/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:NESmartConnect/dev_screen.dart';
class AdvDevSettings extends StatefulWidget {
  final String deviceName;
  final String deviceNumber;
  final String deviceCont;

  const AdvDevSettings({
    super.key,
    required this.deviceName,
    required this.deviceNumber,
    required this.deviceCont,
  });

  @override
  State<AdvDevSettings> createState() => _AdvDevSettingsState();
}

class _AdvDevSettingsState extends State<AdvDevSettings> {
  static const platform = MethodChannel('com.naren.NESmartConnect/sms');

  // Awaiting Response state
  bool _isAwaitingResponse = false;
  Timer? _awaitingResponseTimer;

  // State variables for Timings
  String _overloadTrip = 'N/A';
  String _voltageTrip = 'N/A';
  String _dryRunTrip = 'N/A';
  String _singlePhaseTrip = 'N/A';
  String _maxRuntime = 'N/A';
  String _dryRunRestart = 'N/A';

  // State variable for Feedback Delay
  String _feedbackDelay = 'N/A';

  // State variable for Host Number
  String _hostNumber = 'N/A';

  // For RLO-specific logic
  String? _lastSentMotorCommand;
  bool _hasReceivedLtiUpdate = false;

  // Original values for change detection
  final Map<String, String> _originalValues = {};

  // Editing states
  bool _isEditingOverloadTrip = false;
  bool _isEditingVoltageTrip = false;
  bool _isEditingDryRunTrip = false;
  bool _isEditingSinglePhaseTrip = false;
  bool _isEditingMaxRuntime = false;
  bool _isEditingDryRunRestart = false;
  bool _isEditingFeedbackDelay = false;

  // Text controllers for editable fields
  final TextEditingController _overloadTripController = TextEditingController();
  final TextEditingController _voltageTripController = TextEditingController();
  final TextEditingController _dryRunTripController = TextEditingController();
  final TextEditingController _singlePhaseTripController = TextEditingController();
  final TextEditingController _maxRuntimeController = TextEditingController();
  final TextEditingController _dryRunRestartController = TextEditingController();
  final TextEditingController _feedbackDelayController = TextEditingController();

  // Digit strings for time inputs
  String _maxRuntimeDigits = '000000';
  String _dryRunRestartDigits = '0000';

  @override
  void initState() {
    super.initState();
    _hostNumber = widget.deviceNumber; // Set host number initially
    _loadSavedData().then((_) async {
      await _readInitialSms();
      await _setupChannel();
    });
    print('AdvDevSettings: InitState: Initializing with deviceNumber: ${widget.deviceNumber}');
  }

  @override
  void didUpdateWidget(AdvDevSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceNumber != widget.deviceNumber) {
      _loadSavedData().then((_) async {
        await _readInitialSms();
        await _setupChannel();
      });
    } else {
      _readInitialSms().then((_) async {
        await _setupChannel();
      });
    }
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceKey = widget.deviceNumber;
    setState(() {
      _overloadTrip = prefs.getString('overloadTrip_$deviceKey') ?? _overloadTrip;
      _voltageTrip = prefs.getString('voltageTrip_$deviceKey') ?? _voltageTrip;
      _dryRunTrip = prefs.getString('dryRunTrip_$deviceKey') ?? _dryRunTrip;
      _singlePhaseTrip = prefs.getString('singlePhaseTrip_$deviceKey') ?? _singlePhaseTrip;
      _maxRuntime = prefs.getString('maxRuntime_$deviceKey') ?? _maxRuntime;
      _dryRunRestart = prefs.getString('dryRunRestart_$deviceKey') ?? _dryRunRestart;
      _feedbackDelay = prefs.getString('feedbackDelay_$deviceKey') ?? _feedbackDelay;
      _hostNumber = widget.deviceNumber;

      _overloadTripController.text = _overloadTrip.replaceAll(' Sec', '');
      _voltageTripController.text = _voltageTrip.replaceAll(' Sec', '');
      _dryRunTripController.text = _dryRunTrip.replaceAll(' Sec', '');
      _singlePhaseTripController.text = _singlePhaseTrip.replaceAll(' Sec', '');
      _maxRuntimeController.text = _maxRuntime;
      _dryRunRestartController.text = _dryRunRestart;
      _feedbackDelayController.text = _feedbackDelay.replaceAll(' Sec', '');

      _maxRuntimeDigits = _timeToDigitsHHMMSS(_maxRuntime);
      _dryRunRestartDigits = _timeToDigitsHHMM(_dryRunRestart);

      _originalValues['overloadTrip'] = _overloadTrip;
      _originalValues['voltageTrip'] = _voltageTrip;
      _originalValues['dryRunTrip'] = _dryRunTrip;
      _originalValues['singlePhaseTrip'] = _singlePhaseTrip;
      _originalValues['maxRuntime'] = _maxRuntime;
      _originalValues['dryRunRestart'] = _dryRunRestart;
      _originalValues['feedbackDelay'] = _feedbackDelay;
      _originalValues['hostNumber'] = _hostNumber;

      print('AdvDevSettings: LoadSavedData: Loaded data for device $deviceKey');
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceKey = widget.deviceNumber;
    await prefs.setString('overloadTrip_$deviceKey', _overloadTrip);
    await prefs.setString('voltageTrip_$deviceKey', _voltageTrip);
    await prefs.setString('dryRunTrip_$deviceKey', _dryRunTrip);
    await prefs.setString('singlePhaseTrip_$deviceKey', _singlePhaseTrip);
    await prefs.setString('maxRuntime_$deviceKey', _maxRuntime);
    await prefs.setString('dryRunRestart_$deviceKey', _dryRunRestart);
    await prefs.setString('feedbackDelay_$deviceKey', _feedbackDelay);
    await prefs.setString('hostNumber_$deviceKey', widget.deviceNumber);

    _originalValues['overloadTrip'] = _overloadTrip;
    _originalValues['voltageTrip'] = _voltageTrip;
    _originalValues['dryRunTrip'] = _dryRunTrip;
    _originalValues['singlePhaseTrip'] = _singlePhaseTrip;
    _originalValues['maxRuntime'] = _maxRuntime;
    _originalValues['dryRunRestart'] = _dryRunRestart;
    _originalValues['feedbackDelay'] = _feedbackDelay;
    _originalValues['hostNumber'] = widget.deviceNumber;

    print('AdvDevSettings: SaveData: Saved data for device $deviceKey');
  }

  Future<void> _readInitialSms() async {
    try {
      print('AdvDevSettings: ReadInitialSms: Starting for device ${widget.deviceNumber}');
      final smsData = await platform.invokeMethod('readInitialSms', {'phoneNumber': widget.deviceNumber});
      print('AdvDevSettings: ReadInitialSms: Received data $smsData');
      if (smsData != null && smsData is Map) {
        setState(() {
          if (!_hasReceivedLtiUpdate) {
            _overloadTrip = '${smsData['overloadTripTime']?.toString().replaceAll(' Sec', '') ?? _overloadTrip.replaceAll(' Sec', '')} Sec';
            _overloadTripController.text = _overloadTrip.replaceAll(' Sec', '');
            _voltageTrip = '${smsData['voltageTripTime']?.toString().replaceAll(' Sec', '') ?? _voltageTrip.replaceAll(' Sec', '')} Sec';
            _voltageTripController.text = _voltageTrip.replaceAll(' Sec', '');
            _dryRunTrip = '${smsData['dryRunTripTime']?.toString().replaceAll(' Sec', '') ?? _dryRunTrip.replaceAll(' Sec', '')} Sec';
            _dryRunTripController.text = _dryRunTrip.replaceAll(' Sec', '');
            _singlePhaseTrip = '${smsData['singlePhaseTripTime']?.toString().replaceAll(' Sec', '') ?? _singlePhaseTrip.replaceAll(' Sec', '')} Sec';
            _singlePhaseTripController.text = _singlePhaseTrip.replaceAll(' Sec', '');
            _maxRuntime = smsData['maxRunTime']?.toString() ?? _maxRuntime;
            _maxRuntimeController.text = _maxRuntime;
            _maxRuntimeDigits = _timeToDigitsHHMMSS(_maxRuntime);
            _dryRunRestart = smsData['dryRunRestartTime']?.toString() ?? _dryRunRestart;
            _dryRunRestartController.text = _dryRunRestart;
            _dryRunRestartDigits = _timeToDigitsHHMM(_dryRunRestart);
            _feedbackDelay = '${smsData['feedbackDelayTime']?.toString().replaceAll(' Sec', '') ?? _feedbackDelay.replaceAll(' Sec', '')} Sec';
            _feedbackDelayController.text = _feedbackDelay.replaceAll(' Sec', '');
            _hostNumber = widget.deviceNumber;
            _saveData();
            print('AdvDevSettings: RLO Fetched Values:');
            print('Overload Trip: $_overloadTrip');
            print('Voltage Trip: $_voltageTrip');
            print('Dry Run Trip: $_dryRunTrip');
            print('Single Phase Trip: $_singlePhaseTrip');
            print('Max Runtime: $_maxRuntime');
            print('Dry Run Restart: $_dryRunRestart');
            print('Feedback Delay: $_feedbackDelay');
            print('Host Number: $_hostNumber');
          } else {
            print('AdvDevSettings: RLO Skipped: LTI update already received');
          }
        });
      }
    } catch (e) {
      print('AdvDevSettings: Error reading initial SMS: $e');
    }
  }

  Future<void> _setupChannel() async {
    print('AdvDevSettings: SetupChannel: Setting up MethodChannel for ${widget.deviceNumber}');
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final params = call.arguments as Map;
        print('AdvDevSettings: onSmsReceived: Received params $params');
        if (mounted) {
          setState(() {
            _hasReceivedLtiUpdate = true;
            _overloadTrip = '${params['overloadTripTime']?.toString().replaceAll(' Sec', '') ?? _overloadTrip.replaceAll(' Sec', '')} Sec';
            _overloadTripController.text = _overloadTrip.replaceAll(' Sec', '');
            _voltageTrip = '${params['voltageTripTime']?.toString().replaceAll(' Sec', '') ?? _voltageTrip.replaceAll(' Sec', '')} Sec';
            _voltageTripController.text = _voltageTrip.replaceAll(' Sec', '');
            _dryRunTrip = '${params['dryRunTripTime']?.toString().replaceAll(' Sec', '') ?? _dryRunTrip.replaceAll(' Sec', '')} Sec';
            _dryRunTripController.text = _dryRunTrip.replaceAll(' Sec', '');
            _singlePhaseTrip = '${params['singlePhaseTripTime']?.toString().replaceAll(' Sec', '') ?? _singlePhaseTrip.replaceAll(' Sec', '')} Sec';
            _singlePhaseTripController.text = _singlePhaseTrip.replaceAll(' Sec', '');
            _maxRuntime = params['maxRunTime']?.toString() ?? _maxRuntime;
            _maxRuntimeController.text = _maxRuntime;
            _maxRuntimeDigits = _timeToDigitsHHMMSS(_maxRuntime);
            _dryRunRestart = params['dryRunRestartTime']?.toString() ?? _dryRunRestart;
            _dryRunRestartController.text = _dryRunRestart;
            _dryRunRestartDigits = _timeToDigitsHHMM(_dryRunRestart);
            _feedbackDelay = '${params['feedbackDelayTime']?.toString().replaceAll(' Sec', '') ?? _feedbackDelay.replaceAll(' Sec', '')} Sec';
            _feedbackDelayController.text = _feedbackDelay.replaceAll(' Sec', '');
            _hostNumber = widget.deviceNumber;
            _saveData();
            print('AdvDevSettings: LTI Updated Values:');
            print('Overload Trip: $_overloadTrip');
            print('Voltage Trip: $_voltageTrip');
            print('Dry Run Trip: $_dryRunTrip');
            print('Single Phase Trip: $_singlePhaseTrip');
            print('Max Runtime: $_maxRuntime');
            print('Dry Run Restart: $_dryRunRestart');
            print('Feedback Delay: $_feedbackDelay');
            print('Host Number: $_hostNumber');
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Response Received: Updated')),
            );
          }
        }
      } else if (call.method == 'responseReceived') {
        if (mounted) {
          setState(() {
            _isAwaitingResponse = false;
            _awaitingResponseTimer?.cancel();
            print('AdvDevSettings: responseReceived: Awaiting response cleared');
          });
        }
      } else if (call.method == 'responseTimeout') {
        if (mounted) {
          setState(() {
            _isAwaitingResponse = false;
            _awaitingResponseTimer?.cancel();
            print('AdvDevSettings: responseTimeout: Awaiting response cleared due to timeout');
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Response Timed Out')),
          );
          await _readInitialSms();
        }
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

  // Remove the user status check block
  // final prefs = await SharedPreferences.getInstance();
  // final userJson = prefs.getString('user_data');
  // final Map<String, dynamic> userData = userJson != null ? jsonDecode(userJson) : {'status': 'enabled'};
  
  setState(() {
    _isAwaitingResponse = true;
    print('SendSms: Sending message "$message" to ${widget.deviceNumber} from ${widget.deviceCont}');
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
    
    // Remove the manual API call to log SMS
    // await _addSMSLog(message, widget.deviceCont, widget.deviceNumber, uId!);
  } catch (e) {
    // Rest of the function
  }
}

  Future<void> _addSMSLog(String command, String sender, String receiver, String uId) async {
  try {
    final response = await http.post(
    Uri.parse('https://nesmartconnect-uzggi.ondigitalocean.app/sms-logs/add'),
    body: {
      'command': command,
      'sender': sender,
      'receiver': receiver,
      'u_id': uId,
    },
    );

    print('addSMSLog: Response status: ${response.statusCode}');
    print('addSMSLog: Response body: ${response.body}');

    if (response.statusCode == 200) {
    print('addSMSLog: SMS log added successfully');
    } else {
    print('addSMSLog: Failed to add SMS log');
    }
  } catch (e) {
    print('addSMSLog: Error adding SMS log: $e');
  }
  }

  String _timeToDigitsHHMMSS(String time) {
  return time.replaceAll(':', '');
  }

  String _timeToDigitsHHMM(String time) {
  return time.replaceAll(':', '');
  }

  String _formatDigitsToTimeHHMMSS(String digits) {
  if (digits.length != 6) {
    digits = digits.padLeft(6, '0');
  }
  int seconds = int.parse(digits.substring(4, 6));
  int minutes = int.parse(digits.substring(2, 4));
  int hours = int.parse(digits.substring(0, 2));
  if (seconds > 59) {
    minutes += seconds ~/ 60;
    seconds = seconds % 60;
  }
  if (minutes > 59) {
    hours += minutes ~/ 60;
    minutes = minutes % 60;
  }
  if (hours > 99) {
    hours = 99;
  }
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDigitsToTimeHHMM(String digits) {
  if (digits.length != 4) {
    digits = digits.padLeft(4, '0');
  }
  int minutes = int.parse(digits.substring(2, 4));
  int hours = int.parse(digits.substring(0, 2));
  if (minutes > 59) {
    hours += minutes ~/ 60;
    minutes = minutes % 60;
  }
  if (hours > 99) {
    hours = 99;
  }
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  bool _isValidInteger(String value) {
  if (value == 'N/A' || value.isEmpty) return false;
  return int.tryParse(value) != null;
  }

  bool _isValidTimeHHMMSS(String value) {
  if (value == 'N/A' || value.isEmpty) return false;
  final parts = value.split(':');
  if (parts.length != 3) return false;
  return int.tryParse(parts[0]) != null &&
       int.tryParse(parts[1]) != null &&
       int.tryParse(parts[2]) != null;
  }

  bool _isValidTimeHHMM(String value) {
  if (value == 'N/A' || value.isEmpty) return false;
  final parts = value.split(':');
  if (parts.length != 2) return false;
  return int.tryParse(parts[0]) != null &&
       int.tryParse(parts[1]) != null;
  }

  @override
  void dispose() {
  _awaitingResponseTimer?.cancel();
  _overloadTripController.dispose();
  _voltageTripController.dispose();
  _dryRunTripController.dispose();
  _singlePhaseTripController.dispose();
  _maxRuntimeController.dispose();
  _dryRunRestartController.dispose();
  _feedbackDelayController.dispose();
  super.dispose();
  print('AdvDevSettings: Dispose: Cleaning up');
  }

  @override
  Widget build(BuildContext context) {
  return WillPopScope(
    onWillPop: () async {
    print('AdvDevSettings: Back button pressed, returning true');
    Navigator.pop(context, true);
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
                                      Navigator.pop(context, true);
                                    },
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Advanced Settings',
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
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timings Box
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
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'TIMINGS',
                                        style: TextStyle(
                                          color: const Color(0xFF716D69),
                                          fontSize: 13,
                                          fontFamily: 'Inter Display',
                                          fontWeight: FontWeight.w600,
                                          height: 1.67,
                                          letterSpacing: -0.24,
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: GestureDetector(
                                          onTap: () => _sendSms(r'*GETAT$'),
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
                                                  'Get current times',
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
                                    label: 'Overload Trip',
                                    value: _overloadTrip,
                                    controller: _overloadTripController,
                                    isEditing: _isEditingOverloadTrip,
                                    toggleEdit: () => setState(() => _isEditingOverloadTrip = !_isEditingOverloadTrip),
                                    save: () {
                                      final newValue = _overloadTripController.text.padLeft(3, '0');
                                      final originalValue = _originalValues['overloadTrip']?.replaceAll(' Sec', '') ?? '';
                                      if (_isValidInteger(newValue) && newValue != originalValue) {
                                        setState(() {
                                          _overloadTrip = '$newValue Sec';
                                          _isEditingOverloadTrip = false;
                                          _sendSms('*SETOL-$newValue\$');
                                          _saveData();
                                          _originalValues['overloadTrip'] = _overloadTrip;
                                        });
                                      } else {
                                        setState(() {
                                          _isEditingOverloadTrip = false;
                                          _overloadTripController.text = _originalValues['overloadTrip']?.replaceAll(' Sec', '') ?? _overloadTrip.replaceAll(' Sec', '');
                                        });
                                      }
                                    },
                                    maxLength: 3,
                                  ),
                                  SizedBox(height: 16),
                                  _buildTextField(
                                    label: 'Voltage Trip',
                                    value: _voltageTrip,
                                    controller: _voltageTripController,
                                    isEditing: _isEditingVoltageTrip,
                                    toggleEdit: () => setState(() => _isEditingVoltageTrip = !_isEditingVoltageTrip),
                                    save: () {
                                      final newValue = _voltageTripController.text.padLeft(3, '0');
                                      final originalValue = _originalValues['voltageTrip']?.replaceAll(' Sec', '') ?? '';
                                      if (_isValidInteger(newValue) && newValue != originalValue) {
                                        setState(() {
                                          _voltageTrip = '$newValue Sec';
                                          _isEditingVoltageTrip = false;
                                          _sendSms('*SETVT-$newValue\$');
                                          _saveData();
                                          _originalValues['voltageTrip'] = _voltageTrip;
                                        });
                                      } else {
                                        setState(() {
                                          _isEditingVoltageTrip = false;
                                          _voltageTripController.text = _originalValues['voltageTrip']?.replaceAll(' Sec', '') ?? _voltageTrip.replaceAll(' Sec', '');
                                        });
                                      }
                                    },
                                    maxLength: 3,
                                  ),
                                  SizedBox(height:16),
                                  _buildTextField(
                                    label: 'Dry Run Trip',
                                    value: _dryRunTrip,
                                    controller: _dryRunTripController,
                                    isEditing: _isEditingDryRunTrip,
                                    toggleEdit: () => setState(() => _isEditingDryRunTrip = !_isEditingDryRunTrip),
                                    save: () {
                                      final newValue = _dryRunTripController.text.padLeft(3, '0');
                                      final originalValue = _originalValues['dryRunTrip']?.replaceAll(' Sec', '') ?? '';
                                      if (_isValidInteger(newValue) && newValue != originalValue) {
                                        setState(() {
                                          _dryRunTrip = '$newValue Sec';
                                          _isEditingDryRunTrip = false;
                                          _sendSms('*SETDR-$newValue\$');
                                          _saveData();
                                          _originalValues['dryRunTrip'] = _dryRunTrip;
                                        });
                                      } else {
                                        setState(() {
                                          _isEditingDryRunTrip = false;
                                          _dryRunTripController.text = _originalValues['dryRunTrip']?.replaceAll(' Sec', '') ?? _dryRunTrip.replaceAll(' Sec', '');
                                        });
                                      }
                                    },
                                    maxLength: 3,
                                  ),
                                  SizedBox(height:16),
                                  _buildTextField(
                                    label: 'Single Phase Trip',
                                    value: _singlePhaseTrip,
                                    controller: _singlePhaseTripController,
                                    isEditing: _isEditingSinglePhaseTrip,
                                    toggleEdit: () => setState(() => _isEditingSinglePhaseTrip = !_isEditingSinglePhaseTrip),
                                    save: () {
                                      final newValue = _singlePhaseTripController.text.padLeft(3, '0');
                                      final originalValue = _originalValues['singlePhaseTrip']?.replaceAll(' Sec', '') ?? '';
                                      if (_isValidInteger(newValue) && newValue != originalValue) {
                                        setState(() {
                                          _singlePhaseTrip = '$newValue Sec';
                                          _isEditingSinglePhaseTrip = false;
                                          _sendSms('*SETSP-$newValue\$');
                                          _saveData();
                                          _originalValues['singlePhaseTrip'] = _singlePhaseTrip;
                                        });
                                      } else {
                                        setState(() {
                                          _isEditingSinglePhaseTrip = false;
                                          _singlePhaseTripController.text = _originalValues['singlePhaseTrip']?.replaceAll(' Sec', '') ?? _singlePhaseTrip.replaceAll(' Sec', '');
                                        });
                                      }
                                    },
                                    maxLength: 3,
                                  ),
                                  SizedBox(height: 16),
                                  _buildTextField(
                                    label: 'Max Runtime',
                                    value: _maxRuntime,
                                    controller: _maxRuntimeController,
                                    isEditing: _isEditingMaxRuntime,
                                    toggleEdit: () => setState(() => _isEditingMaxRuntime = !_isEditingMaxRuntime),
                                    save: () {
                                      final newValue = _maxRuntimeController.text;
                                      final originalValue = _originalValues['maxRuntime'] ?? '';
                                      if (_isValidTimeHHMMSS(newValue) && newValue != originalValue) {
                                        setState(() {
                                          _maxRuntime = newValue;
                                          _isEditingMaxRuntime = false;
                                          _sendSms('*CHMN-$newValue\$');
                                          _saveData();
                                          _originalValues['maxRuntime'] = _maxRuntime;
                                        });
                                      } else {
                                        setState(() {
                                          _isEditingMaxRuntime = false;
                                          _maxRuntimeController.text = _originalValues['maxRuntime'] ?? _maxRuntime;
                                        });
                                      }
                                    },
                                    maxLength: 8,
                                    inputFormatter: TimerInputFormatter(_maxRuntimeDigits, 6, (newValue) {
                                      _maxRuntime = newValue;
                                      _maxRuntimeController.text = newValue;
                                    }),
                                  ),
                                  SizedBox(height: 16),
                                  _buildTextField(
                                    label: 'Dry Run Restart',
                                    value: _dryRunRestart,
                                    controller: _dryRunRestartController,
                                    isEditing: _isEditingDryRunRestart,
                                    toggleEdit: () => setState(() => _isEditingDryRunRestart = !_isEditingDryRunRestart),
                                    save: () {
                                      final newValue = _dryRunRestartController.text;
                                      final originalValue = _originalValues['dryRunRestart'] ?? '';
                                      if (_isValidTimeHHMM(newValue) && newValue != originalValue) {
                                        setState(() {
                                          _dryRunRestart = newValue;
                                          _isEditingDryRunRestart = false;
                                          _sendSms('*SETRS-$newValue\$');
                                          _saveData();
                                          _originalValues['dryRunRestart'] = _dryRunRestart;
                                        });
                                      } else {
                                        setState(() {
                                          _isEditingDryRunRestart = false;
                                          _dryRunRestartController.text = _originalValues['dryRunRestart'] ?? _dryRunRestart;
                                        });
                                      }
                                    },
                                    maxLength: 5,
                                    inputFormatter: TimerInputFormatter(_dryRunRestartDigits, 4, (newValue) {
                                      _dryRunRestart = newValue;
                                      _dryRunRestartController.text = newValue;
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          // Feedback Delay Box
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
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'FEEDBACK DELAY',
                                        style: TextStyle(
                                          color: const Color(0xFF716D69),
                                          fontSize: 13,
                                          fontFamily: 'Inter Display',
                                          fontWeight: FontWeight.w600,
                                          height: 1.67,
                                          letterSpacing: -0.24,
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: GestureDetector(
                                          onTap: () => _sendSms(r'*GETFD$'),
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
                                                  'Get current time',
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
                                    label: 'Feedback Delay',
                                    value: _feedbackDelay,
                                    controller: _feedbackDelayController,
                                    isEditing: _isEditingFeedbackDelay,
                                    toggleEdit: () => setState(() => _isEditingFeedbackDelay = !_isEditingFeedbackDelay),
                                    save: () {
                                      final newValue = _feedbackDelayController.text.padLeft(2, '0');
                                      final originalValue = _originalValues['feedbackDelay']?.replaceAll(' Sec', '') ?? '';
                                      if (_isValidInteger(newValue) && newValue != originalValue) {
                                        setState(() {
                                          _feedbackDelay = '$newValue Sec';
                                          _isEditingFeedbackDelay = false;
                                          _sendSms('*SETFD-$newValue\$');
                                          _saveData();
                                          _originalValues['feedbackDelay'] = _feedbackDelay;
                                        });
                                      } else {
                                        setState(() {
                                          _isEditingFeedbackDelay = false;
                                          _feedbackDelayController.text = _originalValues['feedbackDelay']?.replaceAll(' Sec', '') ?? _feedbackDelay.replaceAll(' Sec', '');
                                        });
                                      }
                                    },
                                    maxLength: 2,
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
    TextInputFormatter? inputFormatter,
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
                  padding: EdgeInsets.only(left: 20, top: 16, bottom: 16),
                  child: isEditing
                      ? TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          inputFormatters: inputFormatter != null
                              ? [inputFormatter]
                              : [
                                  FilteringTextInputFormatter.digitsOnly,
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

// Helper class for HH:MM:SS time input formatting
class TimerInputFormatter extends TextInputFormatter {
  String digits;
  final int maxLength;
  final Function(String) onChanged;

  TimerInputFormatter(this.digits, this.maxLength, this.onChanged);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.replaceAll(':', '');
    if (newText.length < oldValue.text.replaceAll(':', '').length) {
      if (digits.isNotEmpty) digits = digits.substring(0, digits.length - 1).padLeft(maxLength, '0');
    } else {
      String newDigit = newText.substring(oldValue.text.replaceAll(':', '').length);
      if (RegExp(r'[0-9]').hasMatch(newDigit)) digits = (digits.substring(1) + newDigit).padLeft(maxLength, '0');
    }
    String formattedTime = formatTime(digits);
    onChanged(formattedTime);
    return TextEditingValue(text: formattedTime, selection: TextSelection.collapsed(offset: formattedTime.length));
  }

  String formatTime(String digits) {
    if (digits.length > maxLength) digits = digits.substring(0, maxLength);
    if (maxLength == 6) {
      int seconds = int.parse(digits.substring(4).padLeft(2, '0'));
      int minutes = int.parse(digits.substring(2, 4).padLeft(2, '0'));
      int hours = int.parse(digits.substring(0, 2).padLeft(2, '0'));
      if (seconds > 59) {
        minutes += seconds ~/ 60;
        seconds %= 60;
      }
      if (minutes > 59) {
        hours += minutes ~/ 60;
        minutes %= 60;
      }
      if (hours > 99) hours = 99;
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      int minutes = int.parse(digits.substring(2).padLeft(2, '0'));
      int hours = int.parse(digits.substring(0, 2).padLeft(2, '0'));
      if (minutes > 59) {
        hours += minutes ~/ 60;
        minutes %= 60;
      }
      if (hours > 99) hours = 99;
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    }
  }
}