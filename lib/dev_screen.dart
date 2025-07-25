import 'package:NESmartConnect/services/sms_parser_service.dart';
import 'package:NESmartConnect/services/sms_parser_service.dart' as smsService;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:NESmartConnect/adv_dev_setting.dart';
import 'package:NESmartConnect/settings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:segmented_button_slide/segmented_button_slide.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/api_service.dart';
import 'services/sms_parser_service.dart'; // Import the service at the top if not already there

class DevScreen extends StatefulWidget {
  final String deviceName;
  final String deviceNumber;
  final String deviceDesc;
  final String deviceCont;

  const DevScreen({
    super.key,
    required this.deviceName,
    required this.deviceNumber,
    required this.deviceDesc,
    required this.deviceCont,
  });

  @override
  State<DevScreen> createState() => _DevScreenState();
}

class _DevScreenState extends State<DevScreen>
    with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.naren.NESmartConnect/sms');

  // State variables for DevScreen components
  late String _deviceName;
  late String _deviceDesc;

  String _id = 'N/A';
  String _lastPingAction = 'N/A';
  String _lastPingInitiator = 'N/A';
  String _lastPingTimestamp = 'N/A';
  String _lastSync = 'N/A';
  int _n = 0;
  int _d = 0;
  String _responses = '0';
  String? _errorMessage;
  bool _motorState = false;
  int _selectedMode = 0;
  String _cyclicOnDigits = '000000';
  String _cyclicOffDigits = '000000';
  String _dailyAutoDigits = '000000';
  String _shiftTimerDigits = '000000';
  String _cyclicOnTime = '00:00:00';
  String _cyclicOffTime = '00:00:00';
  String _dailyAutoTime = '00:00:00';
  String _shiftTimerTime = '00:00:00';
  String _countdownMode = 'N/A';
  String _countdownStatus = 'N/A';
  String _countdownSince = '00:00:00';
  String _countdownTarget = '00:00:00';
  bool _countdownDismissed = false;
  final ValueNotifier<String> _countdownDisplayNotifier = ValueNotifier<String>(
    '00:00:00',
  );
  bool _isCountdownActive = false;
  String _dailyAutoCountdownDisplay = '00:00:00';
  String _cyclicCountdownDisplay = '00:00:00';
  String _shiftTimerCountdownDisplay = '00:00:00';
  Timer? _countdownTimer;
  String _voltageRY = 'N/A';
  String _voltageYB = 'N/A';
  String _voltageBR = 'N/A';
  String _currentR = 'N/A';
  String _currentY = 'N/A';
  String _currentB = 'N/A';
  bool _hasReceivedLtiUpdate = false;

  String _lastDailyAutoTime = '00:00:00';
  String _lastCyclicOnTime = '00:00:00';
  String _lastCyclicOffTime = '00:00:00';
  String _lastShiftTimerTime = '00:00:00';

  bool _isCountdownRestored = false;
  bool _isAwaitingResponse = false;

  final TextEditingController _cyclicOnController = TextEditingController();
  final TextEditingController _cyclicOffController = TextEditingController();
  final TextEditingController _dailyAutoController = TextEditingController();
  final TextEditingController _shiftTimerController = TextEditingController();
  bool _showAllTimers = false;
  int? _tempSelectedMode;

  int _consecutiveTimeouts = 0;
  static const int _maxConsecutiveTimeouts = 3;
  static const int _timeoutDurationSeconds = 45;

  // Scroll and animation controllers
  bool _isScrolledPastTop = false;
  late AnimationController _AnimationController;
  late Animation<Color?> _errorColorAnimation;
  late Animation<Color?> _ctddmColorAnimation;

  void _updateResponses() {
    final value = _n > 0 ? (100 / _n) - _d : 0;
    setState(() => _responses = value.toStringAsFixed(0));
  }

  @override
  void initState() {
    super.initState();
    platform.invokeMethod('startFg');
    _deviceName = widget.deviceName; // Initialize with widget value
    _deviceDesc = widget.deviceDesc;
    _loadSavedData().then((_) async {
      await _readInitialSms();
      await _setupChannel();
      _setActivePhoneNumber();
    });
    print(
      'InitState: Initializing DevScreen with deviceNumber: ${widget.deviceNumber}',
    );

    // Initialize animation for error strobing
    _AnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _errorColorAnimation = ColorTween(
      begin: Colors.white,
      end: Colors.red,
    ).animate(
      CurvedAnimation(parent: _AnimationController, curve: Curves.easeInOut),
    );
    _ctddmColorAnimation = ColorTween(
      begin: Colors.white,
      end: const Color.fromARGB(255, 23, 235, 16),
    ).animate(
      CurvedAnimation(parent: _AnimationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _setActivePhoneNumber() async {
    try {
      await platform.invokeMethod('setActivePhoneNumber', {
        'phoneNumber': widget.deviceNumber,
      });
      print('Set active phone number: ${widget.deviceNumber}');
    } catch (e) {
      print('Failed to set active phone number: $e');
    }
  }

  @override
  void didUpdateWidget(DevScreen oldWidget) {
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
      _lastPingAction =
          prefs.getString('lastPingAction_$deviceKey') ?? _lastPingAction;
      _id = prefs.getString('id_$deviceKey') ?? _id;
      _lastPingInitiator =
          prefs.getString('lastPingInitiator_$deviceKey') ?? _lastPingInitiator;
      _lastPingTimestamp =
          prefs.getString('lastPingTimestamp_$deviceKey') ?? _lastPingTimestamp;
      _lastSync = prefs.getString('lastSync_$deviceKey') ?? _lastSync;
      _n = prefs.getInt('n_$deviceKey') ?? _n;
      _d = prefs.getInt('d_$deviceKey') ?? _d;
      _motorState = prefs.getBool('motorState_$deviceKey') ?? _motorState;
      _selectedMode = prefs.getInt('selectedMode_$deviceKey') ?? _selectedMode;
      _cyclicOnTime =
          prefs.getString('cyclicOnTime_$deviceKey') ?? _cyclicOnTime;
      _cyclicOffTime =
          prefs.getString('cyclicOffTime_$deviceKey') ?? _cyclicOffTime;
      _dailyAutoTime =
          prefs.getString('dailyAutoTime_$deviceKey') ?? _dailyAutoTime;
      _shiftTimerTime =
          prefs.getString('shiftTimerTime_$deviceKey') ?? _shiftTimerTime;
      _cyclicOnDigits =
          prefs.getString('cyclicOnDigits_$deviceKey') ??
          _cyclicOnTime.replaceAll(':', '');
      _cyclicOffDigits =
          prefs.getString('cyclicOffDigits_$deviceKey') ??
          _cyclicOffTime.replaceAll(':', '');
      _dailyAutoDigits =
          prefs.getString('dailyAutoDigits_$deviceKey') ??
          _dailyAutoTime.replaceAll(':', '');
      _shiftTimerDigits =
          prefs.getString('shiftTimerDigits_$deviceKey') ??
          _shiftTimerTime.replaceAll(':', '');
      _countdownMode =
          prefs.getString('countdownMode_$deviceKey') ?? _countdownMode;
      _countdownStatus =
          prefs.getString('countdownStatus_$deviceKey') ?? _countdownStatus;
      _countdownSince =
          prefs.getString('countdownSince_$deviceKey') ?? _countdownSince;
      _countdownTarget =
          prefs.getString('countdownTarget_$deviceKey') ?? _countdownTarget;
      _countdownDismissed =
          prefs.getBool('countdownDismissed_$deviceKey') ?? _countdownDismissed;
      _countdownDisplayNotifier.value =
          prefs.getString('countdownDisplay_$deviceKey') ??
          _countdownDisplayNotifier.value;
      _voltageRY = prefs.getString('voltageRY_$deviceKey') ?? _voltageRY;
      _voltageYB = prefs.getString('voltageYB_$deviceKey') ?? _voltageYB;
      _voltageBR = prefs.getString('voltageBR_$deviceKey') ?? _voltageBR;
      _currentR = prefs.getString('currentR_$deviceKey') ?? _currentR;
      _currentY = prefs.getString('currentY_$deviceKey') ?? _currentY;
      _currentB = prefs.getString('currentB_$deviceKey') ?? _currentB;

      _cyclicOnController.text = _cyclicOnTime;
      _cyclicOffController.text = _cyclicOffTime;
      _dailyAutoController.text = _dailyAutoTime;
      _shiftTimerController.text = _shiftTimerTime;

      _updateCountdownDisplay();
      print(
        'LoadSavedData: Loaded data for device $deviceKey - Last Sync: $_lastSync, Last Ping: $_lastPingAction by $_lastPingInitiator',
      );
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceKey = widget.deviceNumber;
    await prefs.setString('id_$deviceKey', _id);
    await prefs.setString('lastPingAction_$deviceKey', _lastPingAction);
    await prefs.setString('lastPingInitiator_$deviceKey', _lastPingInitiator);
    await prefs.setString('lastPingTimestamp_$deviceKey', _lastPingTimestamp);
    await prefs.setString('lastSync_$deviceKey', _lastSync);
    await prefs.setInt('n_$deviceKey', _n);
    await prefs.setInt('d_$deviceKey', _d);
    await prefs.setBool('motorState_$deviceKey', _motorState);
    await prefs.setInt('selectedMode_$deviceKey', _selectedMode);
    await prefs.setString('cyclicOnTime_$deviceKey', _cyclicOnTime);
    await prefs.setString('cyclicOffTime_$deviceKey', _cyclicOffTime);
    await prefs.setString('dailyAutoTime_$deviceKey', _dailyAutoTime);
    await prefs.setString('shiftTimerTime_$deviceKey', _shiftTimerTime);
    await prefs.setString('countdownMode_$deviceKey', _countdownMode);
    await prefs.setString('countdownStatus_$deviceKey', _countdownStatus);
    await prefs.setString('countdownSince_$deviceKey', _countdownSince);
    await prefs.setString('countdownTarget_$deviceKey', _countdownTarget);
    await prefs.setBool('countdownDismissed_$deviceKey', _countdownDismissed);
    await prefs.setString(
      'countdownDisplay_$deviceKey',
      _countdownDisplayNotifier.value,
    );
    await prefs.setString('voltageRY_$deviceKey', _voltageRY);
    await prefs.setString('voltageYB_$deviceKey', _voltageYB);
    await prefs.setString('voltageBR_$deviceKey', _voltageBR);
    await prefs.setString('currentR_$deviceKey', _currentR);
    await prefs.setString('currentY_$deviceKey', _currentY);
    await prefs.setString('currentB_$deviceKey', _currentB);
    await prefs.setString('cyclicOnDigits_$deviceKey', _cyclicOnDigits);
    await prefs.setString('cyclicOffDigits_$deviceKey', _cyclicOffDigits);
    await prefs.setString('dailyAutoDigits_$deviceKey', _dailyAutoDigits);
    await prefs.setString('shiftTimerDigits_$deviceKey', _shiftTimerDigits);
    print(
      'SaveData: Saved data for device $deviceKey - Last Sync: $_lastSync, Last Ping: $_lastPingAction by $_lastPingInitiator',
    );
  }

  Future<void> _readInitialSms() async {
    try {
      print('ReadInitialSms: Starting for device ${widget.deviceNumber}');
      final smsService = SmsService();

      // Pass current UI values to preserve them
      final currentValues = smsService.createCurrentValuesMap(
        id: _id,
        lastPingAction: _lastPingAction,
        lastPingInitiator: _lastPingInitiator,
        lastPingTimestamp: _lastPingTimestamp,
        lastSync: _lastSync,
        n: _n,
        d: _d,
        motorState: _motorState,
        selectedMode: _selectedMode,
        cyclicOnTime: _cyclicOnTime,
        cyclicOffTime: _cyclicOffTime,
        dailyAutoTime: _dailyAutoTime,
        shiftTimerTime: _shiftTimerTime,
        countdownMode: _countdownMode,
        countdownStatus: _countdownStatus,
        countdownSince: _countdownSince,
        countdownTarget: _countdownTarget,
        countdownDismissed: _countdownDismissed,
        voltageRY: _voltageRY,
        voltageYB: _voltageYB,
        voltageBR: _voltageBR,
        currentR: _currentR,
        currentY: _currentY,
        currentB: _currentB,
        errorMessage: _errorMessage,
      );

      final smsData = await smsService.readInitialSms(
        widget.deviceNumber,
        currentValues,
      );

      if (smsData != null && smsData is Map) {
        setState(() {
          // Only update parameters that have new values (not N/A)
          // Only update parameters that have new values (not N/A)
          // Only update parameters that have new values (not N/A)
          if (smsData['lastPingAction'] != null &&
              smsData['lastPingAction'] != 'N/A') {
            _lastPingAction =
                smsData['lastPingAction']?.toString() ?? _lastPingAction;
          }
          if (smsData['id'] != null && smsData['id'] != 'N/A') {
            _id = smsData['id']?.toString() ?? _id;
          }
          if (smsData['lastPingInitiator'] != null &&
              smsData['lastPingInitiator'] != 'N/A') {
            _lastPingInitiator =
                smsData['lastPingInitiator']?.toString() ?? _lastPingInitiator;
          }
          if (smsData['lastPingTimestamp'] != null &&
              smsData['lastPingTimestamp'] != 'N/A') {
            _lastPingTimestamp =
                smsData['lastPingTimestamp']?.toString() ?? _lastPingTimestamp;
          }
          if (smsData['lastSync'] != null && smsData['lastSync'] != 'N/A') {
            _lastSync = smsData['lastSync']?.toString() ?? _lastSync;
          }
          if (smsData['n'] != null) {
            _n = smsData['n'] as int? ?? _n;
          }
          if (smsData['d'] != null) {
            _d = smsData['d'] as int? ?? _d;
          }
          if (smsData['motorState'] != null) {
            _motorState = smsData['motorState'] as bool? ?? _motorState;
          }
          if (smsData['mode'] != null) {
            _selectedMode = smsData['mode'] as int? ?? _selectedMode;
          }
          if (smsData['cyclicOnTime'] != null &&
              smsData['cyclicOnTime'] != 'N/A') {
            _cyclicOnTime =
                smsData['cyclicOnTime']?.toString() ?? _cyclicOnTime;
            _cyclicOnDigits = _cyclicOnTime.replaceAll(':', '');
            _cyclicOnController.text = _cyclicOnTime;
          }
          if (smsData['cyclicOffTime'] != null &&
              smsData['cyclicOffTime'] != 'N/A') {
            _cyclicOffTime =
                smsData['cyclicOffTime']?.toString() ?? _cyclicOffTime;
            _cyclicOffDigits = _cyclicOffTime.replaceAll(':', '');
            _cyclicOffController.text = _cyclicOffTime;
          }
          if (smsData['dailyAutoTime'] != null &&
              smsData['dailyAutoTime'] != 'N/A') {
            _dailyAutoTime =
                smsData['dailyAutoTime']?.toString() ?? _dailyAutoTime;
            _dailyAutoDigits = _dailyAutoTime.replaceAll(':', '');
            _dailyAutoController.text = _dailyAutoTime;
          }
          if (smsData['shiftTimerTime'] != null &&
              smsData['shiftTimerTime'] != 'N/A') {
            _shiftTimerTime =
                smsData['shiftTimerTime']?.toString() ?? _shiftTimerTime;
            _shiftTimerDigits = _shiftTimerTime.replaceAll(':', '');
            _shiftTimerController.text = _shiftTimerTime;
          }
          if (smsData['countdownMode'] != null &&
              smsData['countdownMode'] != 'N/A') {
            _countdownMode =
                smsData['countdownMode']?.toString() ?? _countdownMode;
          }
          if (smsData['countdownStatus'] != null &&
              smsData['countdownStatus'] != 'N/A') {
            _countdownStatus =
                smsData['countdownStatus']?.toString() ?? _countdownStatus;
          }
          if (smsData['countdownSince'] != null &&
              smsData['countdownSince'] != 'N/A') {
            _countdownSince =
                smsData['countdownSince']?.toString() ?? _countdownSince;
          }
          if (smsData['countdownTarget'] != null &&
              smsData['countdownTarget'] != 'N/A') {
            _countdownTarget =
                smsData['countdownTarget']?.toString() ?? _countdownTarget;
          }
          
          if (smsData['voltageRY'] != null && smsData['voltageRY'] != 'N/A') {
            _voltageRY = smsData['voltageRY']?.toString() ?? _voltageRY;
          }
          if (smsData['voltageYB'] != null && smsData['voltageYB'] != 'N/A') {
            _voltageYB = smsData['voltageYB']?.toString() ?? _voltageYB;
          }
          if (smsData['voltageBR'] != null && smsData['voltageBR'] != 'N/A') {
            _voltageBR = smsData['voltageBR']?.toString() ?? _voltageBR;
          }
          if (smsData['currentR'] != null && smsData['currentR'] != 'N/A') {
            _currentR = smsData['currentR']?.toString() ?? _currentR;
          }
          if (smsData['currentY'] != null && smsData['currentY'] != 'N/A') {
            _currentY = smsData['currentY']?.toString() ?? _currentY;
          }
          if (smsData['currentB'] != null && smsData['currentB'] != 'N/A') {
            _currentB = smsData['currentB']?.toString() ?? _currentB;
          }

          // Error always updates from latest message (even if null) - SPECIAL CASE
          _errorMessage = smsData['error'];
          print('ReadInitialSms: Error from latest SMS: $_errorMessage');

          // CountdownDismissed from latest message
          _countdownDismissed = smsData['countdownDismissed'] == true;
          print(
            'ReadInitialSms: CountdownDismissed from latest SMS: $_countdownDismissed',
          );

          // Update responses calculation
          _updateResponses();

          _updateCountdownDisplay();
          _saveData();
        });
      }
    } catch (e) {
      print('Error reading initial SMS: $e');
    }
  }

  Color _dynamicTextColor() =>
      _errorMessage != null ? Colors.red : const Color(0xFF030100);

  Future _setupChannel() async {
    print('SetupChannel: Setting up MethodChannel for ${widget.deviceNumber}');
    platform.setMethodCallHandler((call) async {
      // NEW: Handle raw SMS data and parse it
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
            _consecutiveTimeouts = 0;
            _hasReceivedLtiUpdate = true;

            // Error always updates from new message (special case) - HANDLE FIRST
            _errorMessage = params['error'];
            print('DevScreen: LTI Updated Error: $_errorMessage');

            // Other parameters only update if new value found
            if (params['lastPingAction'] != null &&
                params['lastPingAction'] != 'N/A') {
              _lastPingAction =
                  params['lastPingAction']?.toString() ?? _lastPingAction;
            }
            if (params['id'] != null && params['id'] != 'N/A') {
              _id = params['id']?.toString() ?? _id;
            }
            if (params['lastPingInitiator'] != null &&
                params['lastPingInitiator'] != 'N/A') {
              _lastPingInitiator =
                  params['lastPingInitiator']?.toString() ?? _lastPingInitiator;
            }
            if (params['lastPingTimestamp'] != null &&
                params['lastPingTimestamp'] != 'N/A') {
              _lastPingTimestamp =
                  params['lastPingTimestamp']?.toString() ?? _lastPingTimestamp;
            }
            if (params['lastSync'] != null && params['lastSync'] != 'N/A') {
              _lastSync = params['lastSync']?.toString() ?? _lastSync;
            }

            print('NNNNNNNNNNNNNNNDDDDDDDDDDDDDDDDDDDbefore: $_n, $_d');
            if (params['n'] != null) {
              _n = params['n'] as int? ?? _n;
            }
            if (params['d'] != null) {
              _d = params['d'] as int? ?? _d;
            }
            print('NNNNNNNNNNNNNNNDDDDDDDDDDDDDDDDDDDafter: $_n, $_d');

            _updateResponses(); // Call the responses update method

            if (params['motorState'] != null) {
              _motorState = params['motorState'] as bool? ?? _motorState;
            }

            print('Before mode update: _selectedMode=$_selectedMode');
            if (params['mode'] != null) {
              _selectedMode = params['mode'] as int? ?? _selectedMode;
            }
            print('After mode update: _selectedMode=$_selectedMode');

            if (params['cyclicOnTime'] != null &&
                params['cyclicOnTime'] != 'N/A') {
              _cyclicOnTime =
                  params['cyclicOnTime']?.toString() ?? _cyclicOnTime;
              _cyclicOnDigits = _cyclicOnTime.replaceAll(':', '');
              _cyclicOnController.text = _cyclicOnTime;
            }
            if (params['cyclicOffTime'] != null &&
                params['cyclicOffTime'] != 'N/A') {
              _cyclicOffTime =
                  params['cyclicOffTime']?.toString() ?? _cyclicOffTime;
              _cyclicOffDigits = _cyclicOffTime.replaceAll(':', '');
              _cyclicOffController.text = _cyclicOffTime;
            }
            if (params['dailyAutoTime'] != null &&
                params['dailyAutoTime'] != 'N/A') {
              _dailyAutoTime =
                  params['dailyAutoTime']?.toString() ?? _dailyAutoTime;
              _dailyAutoDigits = _dailyAutoTime.replaceAll(':', '');
              _dailyAutoController.text = _dailyAutoTime;
            }
            if (params['shiftTimerTime'] != null &&
                params['shiftTimerTime'] != 'N/A') {
              _shiftTimerTime =
                  params['shiftTimerTime']?.toString() ?? _shiftTimerTime;
              _shiftTimerDigits = _shiftTimerTime.replaceAll(':', '');
              _shiftTimerController.text = _shiftTimerTime;
            }

            if (params['countdownMode'] != null &&
                params['countdownMode'] != 'N/A') {
              _countdownMode =
                  params['countdownMode']?.toString() ?? _countdownMode;
            }
            if (params['countdownStatus'] != null &&
                params['countdownStatus'] != 'N/A') {
              _countdownStatus =
                  params['countdownStatus']?.toString() ?? _countdownStatus;
            }
            if (params['countdownSince'] != null &&
                params['countdownSince'] != 'N/A') {
              _countdownSince =
                  params['countdownSince']?.toString() ?? _countdownSince;
            }
            if (params['countdownTarget'] != null &&
                params['countdownTarget'] != 'N/A') {
              _countdownTarget =
                  params['countdownTarget']?.toString() ?? _countdownTarget;
            }
            _countdownDismissed = params['countdownDismissed'] == true;

            if (params['voltageRY'] != null && params['voltageRY'] != 'N/A') {
              _voltageRY = params['voltageRY']?.toString() ?? _voltageRY;
            }
            if (params['voltageYB'] != null && params['voltageYB'] != 'N/A') {
              _voltageYB = params['voltageYB']?.toString() ?? _voltageYB;
            }
            if (params['voltageBR'] != null && params['voltageBR'] != 'N/A') {
              _voltageBR = params['voltageBR']?.toString() ?? _voltageBR;
            }
            if (params['currentR'] != null && params['currentR'] != 'N/A') {
              _currentR = params['currentR']?.toString() ?? _currentR;
            }
            if (params['currentY'] != null && params['currentY'] != 'N/A') {
              _currentY = params['currentY']?.toString() ?? _currentY;
            }
            if (params['currentB'] != null && params['currentB'] != 'N/A') {
              _currentB = params['currentB']?.toString() ?? _currentB;
            }

            // Update saved timer values for comparison
            if (params['dailyAutoTime'] != null &&
                params['dailyAutoTime'] != 'N/A') {
              _lastDailyAutoTime =
                  params['dailyAutoTime']?.toString() ?? _lastDailyAutoTime;
            }
            if (params['cyclicOnTime'] != null &&
                params['cyclicOnTime'] != 'N/A') {
              _lastCyclicOnTime =
                  params['cyclicOnTime']?.toString() ?? _lastCyclicOnTime;
            }
            if (params['cyclicOffTime'] != null &&
                params['cyclicOffTime'] != 'N/A') {
              _lastCyclicOffTime =
                  params['cyclicOffTime']?.toString() ?? _lastCyclicOffTime;
            }
            if (params['shiftTimerTime'] != null &&
                params['shiftTimerTime'] != 'N/A') {
              _lastShiftTimerTime =
                  params['shiftTimerTime']?.toString() ?? _lastShiftTimerTime;
            }

            _updateCountdownDisplay();
            _saveData();

            // Debug logging (keep existing)
            print('LTI Updated Values for DevScreen:');
            print(
              'Last Ping: Action=$_lastPingAction, Initiator=$_lastPingInitiator, Timestamp=$_lastPingTimestamp',
            );
            print('Last Sync: $_lastSync');
            print('sssssssssssssssssssssssetup channel N: $_n');
            print('sssssssssssssssssssssssetup channelD: $_d');
            print('Motor State: $_motorState');
            print('Mode: $_selectedMode');
            print('Cyclic Timer: ON=$_cyclicOnTime, OFF=$_cyclicOffTime');
            print('Daily Auto Timer: $_dailyAutoTime');
            print('Shift Timer: $_shiftTimerTime');
            print(
              'Countdown: Mode=$_countdownMode, Status=$_countdownStatus, Since=$_countdownSince, Target=$_countdownTarget, Dismissed=$_countdownDismissed',
            );
            print('Voltages: RY=$_voltageRY, YB=$_voltageYB, BR=$_voltageBR');
            print('Currents: R=$_currentR, Y=$_currentY, B=$_currentB');
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
            print('responseReceived: Awaiting response cleared');
          });
        }
      } else if (call.method == 'responseTimeout') {
        if (mounted) {
          setState(() {
            _isAwaitingResponse = false;
            _consecutiveTimeouts++;
            print(
              'responseTimeout: Awaiting response cleared due to timeout, consecutiveTimeouts=$_consecutiveTimeouts',
            );
          });
          // ScaffoldMessenger.of(
          //   context,
          // ).showSnackBar(const SnackBar(content: Text('Response Timed Out')));
          await _readInitialSms();
          if (_consecutiveTimeouts >= _maxConsecutiveTimeouts) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder:
                  (context) => OfflinePopup(
                    onConfirm: () {
                      setState(() {
                        _consecutiveTimeouts =
                            0; // Reset timeouts after showing popup
                      });
                    },
                  ),
            );
          }
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
          const SnackBar(
            content: Text('User ID not found. Please log in again.'),
          ),
        );
      }
      return;
    }

    // Skip user status verification - remove the entire block that does:
    // final response = await http.get(...app-users/details/$uId...);

    setState(() {
      _isAwaitingResponse = true;

      print(
        'SendSms: Sending message "$message" to ${widget.deviceNumber} from ${widget.deviceCont}',
      );
    });

Timer(const Duration(seconds: 45), () {
      if (mounted && _isAwaitingResponse) {
        setState(() {
          _isAwaitingResponse = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Response Timed Out After 45 Seconds')),
        );
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
      if (mounted) {
        setState(() {
          _isAwaitingResponse = false;
          print('SendSms: Failed to send SMS: $e');
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send SMS: $e')));
      }
    }
  }

  Future<void> _toggleMotor(int selected) async {
    final message = selected == 1 ? '*MOTOR ON\$' : '*MOTOR OFF\$';
    print('ToggleMotor: Sending command $message');
    await _sendSms(message);
  }

  Future<void> _setMode() async {
    _tempSelectedMode = _selectedMode;
    final modeMessages = {
      0: '*MODE=0\$',
      1: '*MODE=1\$',
      2: '*MODE=2\$',
      3: '*MODE=3\$',
      4: '*MODE=4\$',
    };
    print('SetMode: Sending mode $_tempSelectedMode');
    await _sendSms(modeMessages[_tempSelectedMode]!);
    _tempSelectedMode = null;
  }

  Future<void> _sendCyclicCommand(
    String onCommand,
    String offCommand,
    bool onChanged,
    bool offChanged,
  ) async {
    if (onChanged) {
      _sendSms(onCommand);
      while (_isAwaitingResponse && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!_isAwaitingResponse) break;
      }
    }
    if (offChanged && mounted) {
      _sendSms(offCommand);
    }
  }

  Future<void> _setCyclicTimer() async {
    bool onChanged = _cyclicOnController.text != _lastCyclicOnTime;
    bool offChanged = _cyclicOffController.text != _lastCyclicOffTime;

    if (onChanged || offChanged) {
      print(
        'SetCyclicTimer: ON=${_cyclicOnController.text}, OFF=${_cyclicOffController.text}',
      );
      await _sendCyclicCommand(
        '*CYON-${_cyclicOnController.text}\$',
        '*CYOF-${_cyclicOffController.text}\$',
        onChanged,
        offChanged,
      );
      if (onChanged) _lastCyclicOnTime = _cyclicOnController.text;
      if (offChanged) _lastCyclicOffTime = _cyclicOffController.text;
    } else {
      print('SetCyclicTimer: No change, skipping command');
    }
  }

  Future<void> _resetCyclicTimer() async {
    print('ResetCyclicTimer: Resetting to ON=00:00:00, OFF=00:00:00');
    await _sendCyclicCommand(
      '*CYON-00:00:00\$',
      '*CYOF-00:00:00\$',
      true,
      true,
    );
    _lastCyclicOnTime = '00:00:00';
    _lastCyclicOffTime = '00:00:00';
    _cyclicOnController.text = '00:00:00';
    _cyclicOffController.text = '00:00:00';
  }

  Future<void> _setDailyAutoTimer() async {
    if (_dailyAutoController.text != _lastDailyAutoTime) {
      print('SetDailyAutoTimer: Time=${_dailyAutoController.text}');
      await _sendSms('*CHDL-${_dailyAutoController.text}\$');
      _lastDailyAutoTime = _dailyAutoController.text;
    } else {
      print('SetDailyAutoTimer: No change, skipping command');
    }
  }

  Future<void> _resetDailyAutoTimer() async {
    print('ResetDailyAutoTimer: Resetting to 00:00:00');
    await _sendSms('*RSTDT\$');
    _lastDailyAutoTime = '00:00:00';
    _dailyAutoController.text = '00:00:00';
  }

  Future<void> _setShiftTimer() async {
    if (_shiftTimerController.text != _lastShiftTimerTime) {
      print('SetShiftTimer: Time=${_shiftTimerController.text}');
      await _sendSms('*CHST-${_shiftTimerController.text}\$');
      _lastShiftTimerTime = _shiftTimerController.text;
    } else {
      print('SetShiftTimer: No change, skipping command');
    }
  }

  Future<void> _resetShiftTimer() async {
    print('ResetShiftTimer: Resetting to 00:00:00');
    await _sendSms('*RSTST\$');
    _lastShiftTimerTime = '00:00:00';
    _shiftTimerController.text = '00:00:00';
  }

  void _updateCyclicOnTime(String newValue) {
    setState(() {
      _cyclicOnTime = newValue;
      _cyclicOnDigits = newValue.replaceAll(':', '');
    });
    _saveData();
  }

  void _updateCyclicOffTime(String newValue) {
    setState(() {
      _cyclicOffTime = newValue;
      _cyclicOffDigits = newValue.replaceAll(':', '');
    });
    _saveData();
  }

  void _updateDailyAutoTime(String newValue) {
    setState(() {
      _dailyAutoTime = newValue;
      _dailyAutoDigits = newValue.replaceAll(':', '');
    });
    _saveData();
  }

  void _updateShiftTimerTime(String newValue) {
    setState(() {
      _shiftTimerTime = newValue;
      _shiftTimerDigits = newValue.replaceAll(':', '');
    });
    _saveData();
  }

  void _updateCountdownDisplay() {
    print(
      'UpdateCountdownDisplay: Called with countdownMode=$_countdownMode, countdownStatus=$_countdownStatus, since=$_countdownSince, target=$_countdownTarget, dismissed=$_countdownDismissed',
    );
    if (_countdownDismissed) {
      _countdownDisplayNotifier.value = '00:00:00';
      _isCountdownActive = false;
      _countdownTimer?.cancel();
      _saveData();
      print(
        'UpdateCountdownDisplay: Countdown dismissed, display set to 00:00:00',
      );
      return;
    }
    if (_countdownMode == 'N/A' ||
        _countdownStatus == 'N/A' ||
        _selectedMode == 0 ||
        _selectedMode == 1) {
      _countdownDisplayNotifier.value = '00:00:00';
      _isCountdownActive = false;
      _countdownTimer?.cancel();
      _saveData();
      print(
        'UpdateCountdownDisplay: Invalid mode/status or manual/auto mode, display set to 00:00:00',
      );
      return;
    }

    try {
      final dateFormat = DateFormat('dd/MM/yy HH:mm:ss');
      final motorontill = dateFormat.parse(_countdownTarget);
      final now = DateTime.now();
      final duration = motorontill.difference(now);
      print(
        "Times before failer if block: $_countdownTarget, $motorontill, $duration, $now",
      );
      final initialRemainingSeconds = duration.inSeconds;
      if (initialRemainingSeconds <= 0) {
        _countdownDisplayNotifier.value = '00:00:00';
        _isCountdownActive = false;
        _countdownTimer?.cancel();
        _saveData();
        print(
          'UpdateCountdownDisplay: motorontill is in the past or now ($initialRemainingSeconds s), display set to 00:00:00',
        );
        return;
      }

      _countdownDisplayNotifier.value = _secondsToTime(initialRemainingSeconds);
      _isCountdownActive = true;
      _startCountdown();
      print(
        'UpdateCountdownDisplay: Set display to ${_countdownDisplayNotifier.value}, starting countdown from $initialRemainingSeconds seconds',
      );
    } catch (e) {
      print(
        'UpdateCountdownDisplay: Failed to parse countdownTarget $_countdownTarget: $e',
      );
      _countdownDisplayNotifier.value = '00:00:00';
      _isCountdownActive = false;
      _countdownTimer?.cancel();
      _saveData();
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final timeFormat = DateFormat('h:mm a');
      final dateFormat = DateFormat('d MMM yyyy');
      return '${timeFormat.format(dateTime)} • ${dateFormat.format(dateTime)}';
    } catch (e) {
      return timestamp;
    }
  }

  void _startCountdown() {
    print(
      'StartCountdown: Called with isActive=$_isCountdownActive, selectedMode=$_selectedMode',
    );
    _countdownTimer?.cancel();
    if (!_isCountdownActive || _selectedMode == 0 || _selectedMode == 1) {
      print(
        'StartCountdown: Countdown not started (inactive or manual/auto mode)',
      );
      return;
    }
    int remainingSeconds = _timeToSeconds(_countdownDisplayNotifier.value);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds <= 0) {
        _countdownDisplayNotifier.value = '00:00:00';
        _isCountdownActive = false;
        _countdownMode = 'N/A';
        _countdownStatus = 'N/A';
        _countdownSince = '00:00:00';
        _countdownTarget = '00:00:00';
        timer.cancel();
        _saveData();
        print('StartCountdown: Countdown completed, reset to 00:00:00');
      } else {
        remainingSeconds--;
        _countdownDisplayNotifier.value = _secondsToTime(remainingSeconds);
        _saveData();
        print(
          'StartCountdown: Updated display for $_countdownMode to ${_countdownDisplayNotifier.value}',
        );
      }
    });
  }

  int _timeToSeconds(String time) {
    final parts = time.split(':').map(int.parse).toList();
    return parts[0] * 3600 + parts[1] * 60 + (parts.length > 2 ? parts[2] : 0);
  }

  String _secondsToTime(int seconds) {
    int hours = seconds ~/ 3600;
    seconds %= 3600;
    int minutes = seconds ~/ 60;
    seconds %= 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    platform.invokeMethod('stopFg');
    _countdownTimer?.cancel();
    _cyclicOnController.dispose();
    _cyclicOffController.dispose();
    _dailyAutoController.dispose();
    _shiftTimerController.dispose();
    _AnimationController.dispose();
    super.dispose();
    print('Dispose: Cleaning up DevScreen');
  }

  void _sendStatusCommand() {
    _sendSms('*STATUS\$');
    print('SendStatusCommand: Sent *STATUS\$');
  }

  void _sendGetRPNCommand() {
    _sendSms('*GETRPN\$');
    print('SendGetRPNCommand: Sent *GETRPN\$');
  }

  @override
  Widget build(BuildContext context) {
    String line1 = _lastPingAction;
    String line2 =
        _lastPingInitiator != 'N/A'
            ? "by $_lastPingInitiator @ $_lastPingTimestamp"
            : "@ $_lastPingTimestamp";
    // double calculationResult = (_n > 0) ? (100 / _n) - _d : 0;

    print('Build: Rendering DevScreen - Last Sync: $_lastSync, $line1 $line2');
    return WillPopScope(
      onWillPop: () async {
        print(
          'DevScreen: Back button pressed, passing updated details to HomeView',
        );
        Navigator.pop(context, {
          'name': _deviceName,
          'number': widget.deviceNumber,
          'controlNumber': widget.deviceCont,
          'desc': _deviceDesc,
        });
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            NotificationListener<ScrollUpdateNotification>(
              onNotification: (notification) {
                setState(() {
                  _isScrolledPastTop = notification.metrics.pixels > 50;
                });
                return false;
              },
              child: CustomScrollView(
                slivers: [
                  // Sticky Header
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyHeaderDelegate(
                      minHeight:
                          _isScrolledPastTop
                              ? (_errorMessage != null ? 170 : 160)
                              : 100, // Sticky: 180/160, Non-sticky: 100
                      maxHeight:
                          _isScrolledPastTop
                              ? (_errorMessage != null ? 170 : 160)
                              : 100,
                      child: Container(
                        color: Colors.white, // Opaque white background
                        padding: const EdgeInsets.symmetric(horizontal: 4),

                        child:
                            _isScrolledPastTop
                                ? _buildStickyHeaderContent()
                                : Padding(
                                  padding: const EdgeInsets.only(
                                    top: 52,
                                  ), // 52px from top
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.arrow_back,
                                          color: Colors.black,
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.settings_outlined,
                                          color: Colors.black,
                                        ),
                                        onPressed: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => Settings(
                                                    deviceName: _deviceName,
                                                    deviceNumber:
                                                        widget.deviceNumber,
                                                    deviceCont:
                                                        widget.deviceCont,
                                                    deviceDesc: _deviceDesc,
                                                  ),
                                            ),
                                          );
                                          print(
                                            'DevScreen: Received result from Settings: $result',
                                          );
                                          if (result != null && result is Map) {
                                            setState(() {
                                              _deviceName =
                                                  result['deviceName'];
                                              _deviceDesc =
                                                  result['deviceDesc'];
                                              print(
                                                'DevScreen: Updated state - _deviceName: $_deviceName, _deviceDesc: $_deviceDesc',
                                              );
                                            });
                                            // Do NOT pop here; stay on DevScreen
                                          } else if (result == true) {
                                            // Existing behavior for SMS reload
                                            print(
                                              'Settings popped: Reloading initial SMS',
                                            );
                                            await _readInitialSms();
                                            await _setupChannel();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                      ),
                    ),
                  ),
                  // Main Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_isScrolledPastTop) _buildMainHeaderContent(),

                          SizedBox(height: 8),
                          // Other Content
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
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 16,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'LAST PING: ${_lastPingAction.toUpperCase()}',
                                        style: TextStyle(
                                          color: const Color(0xFF716D69),
                                          fontSize: 13,
                                          fontFamily: 'Inter Display',
                                          fontWeight: FontWeight.w600,
                                          height: 1.67,
                                          letterSpacing: -0.24,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (line2.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: Row(
                                        children: [
                                          SvgPicture.asset(
                                            'assets/images/phone.svg',
                                            width: 16,
                                            height: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _lastPingInitiator.toUpperCase(),
                                            style: TextStyle(
                                              color: const Color.fromARGB(
                                                255,
                                                0,
                                                0,
                                                0,
                                              ),
                                              fontSize: 16,
                                              fontFamily: 'Inter Display',
                                              fontWeight: FontWeight.w400,
                                              height: 1.38,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Row(
                                      children: [
                                        SvgPicture.asset(
                                          'assets/images/timestamp.svg',
                                          width: 16,
                                          height: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTimestamp(
                                            _lastPingTimestamp,
                                          ).toUpperCase(),
                                          style: TextStyle(
                                            color: const Color.fromARGB(
                                              255,
                                              0,
                                              0,
                                              0,
                                            ),
                                            fontSize: 16,
                                            fontFamily: 'Inter Display',
                                            fontWeight: FontWeight.w400,
                                            height: 1.38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
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
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'LAST SYNCED:',
                                                style: TextStyle(
                                                  color: const Color(
                                                    0xFF716D69,
                                                  ),
                                                  fontSize: 13,
                                                  fontFamily: 'Inter Display',
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.67,
                                                  letterSpacing: -0.24,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 16,
                                            ),
                                            child: Row(
                                              children: [
                                                SvgPicture.asset(
                                                  'assets/images/timestamp.svg',
                                                  width: 16,
                                                  height: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _formatTimestamp(
                                                    _lastSync,
                                                  ).toUpperCase(),
                                                  style: TextStyle(
                                                    color: const Color.fromARGB(
                                                      255,
                                                      0,
                                                      0,
                                                      0,
                                                    ),
                                                    fontSize: 16,
                                                    fontFamily: 'Inter Display',
                                                    fontWeight: FontWeight.w400,
                                                    height: 1.38,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Center(
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.refresh,
                                            size: 20,
                                            color: Color(0xFF303849),
                                          ),
                                          onPressed: _sendStatusCommand,
                                          tooltip: 'Sync',
                                          padding: EdgeInsets.zero,
                                          constraints: BoxConstraints(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          // Check if we have a single-phase device
                          _isSinglePhase()
                              ? _buildSinglePhaseVoltageCurrentWidget()
                              : Container(
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
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'VOLTAGES',
                                              style: TextStyle(
                                                color: const Color(0xFF716D69),
                                                fontSize: 13,
                                                fontFamily: 'Inter Display',
                                                fontWeight: FontWeight.w600,
                                                height: 1.67,
                                                letterSpacing: -0.24,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            _buildPhaseBox(
                                              'RY',
                                              _voltageRY,
                                              'V',
                                            ),
                                            const SizedBox(height: 12),
                                            _buildPhaseBox(
                                              'YB',
                                              _voltageYB,
                                              'V',
                                            ),
                                            const SizedBox(height: 12),
                                            _buildPhaseBox(
                                              'BR',
                                              _voltageBR,
                                              'V',
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 120,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        color: const Color(0xFFE1E0DF),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'CURRENTS',
                                              style: TextStyle(
                                                color: const Color(0xFF716D69),
                                                fontSize: 13,
                                                fontFamily: 'Inter Display',
                                                fontWeight: FontWeight.w600,
                                                height: 1.67,
                                                letterSpacing: -0.24,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            _buildPhaseBox('R', _currentR, 'A'),
                                            const SizedBox(height: 12),
                                            _buildPhaseBox('Y', _currentY, 'A'),
                                            const SizedBox(height: 12),
                                            _buildPhaseBox('B', _currentB, 'A'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          SizedBox(height: 16),
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
                                ),
                              ],
                            ),
                            child: GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder:
                                      (context) => SelectModeModal(
                                        initialMode: _selectedMode,
                                        onSave: (newMode) {
                                          setState(() {
                                            _selectedMode = newMode;
                                          });
                                          _setMode();
                                        },
                                        onCancel: () {},
                                      ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'SELECT MODE',
                                          style: TextStyle(
                                            color: const Color(0xFF716D69),
                                            fontSize: 13,
                                            fontFamily: 'Inter Display',
                                            fontWeight: FontWeight.w600,
                                            height: 1.67,
                                            letterSpacing: -0.24,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedMode == 0
                                                  ? 'Manual'
                                                  : _selectedMode == 1
                                                  ? 'Auto Start'
                                                  : _selectedMode == 2
                                                  ? 'Cyclic Timer'
                                                  : _selectedMode == 3
                                                  ? 'Daily Auto'
                                                  : 'Shift Timer',
                                              style: TextStyle(
                                                color: const Color(0xFF030100),
                                                fontSize: 16,
                                                fontFamily: 'Inter Display',
                                                fontWeight: FontWeight.w400,
                                                height: 1.50,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Icon(Icons.keyboard_arrow_right_rounded),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TIMER SETTINGS',
                                style: TextStyle(
                                  color: const Color(0xFF716D69),
                                  fontSize: 13,
                                  fontFamily: 'Inter Display',
                                  fontWeight: FontWeight.w600,
                                  height: 1.67,
                                  letterSpacing: -0.24,
                                ),
                              ),
                              GestureDetector(
                                onTap:
                                    () => setState(
                                      () => _showAllTimers = !_showAllTimers,
                                    ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color:
                                        _showAllTimers
                                            ? Color(0xFFFFDAD4)
                                            : null,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.settings_outlined,
                                    size: 24.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!_showAllTimers) ...[
                            const SizedBox(height: 16),
                            if (_selectedMode == 2)
                              _buildTimerTile(
                                'Cyclic Timer',
                                _countdownMode == 'Cyclic'
                                    ? _countdownDisplayNotifier
                                    : ValueNotifier<String>('00:00:00'),
                                _cyclicOnController,
                                _cyclicOffController,
                                _updateCyclicOnTime, // Updated callback
                                _updateCyclicOffTime, // Updated callback
                                _setCyclicTimer,
                                _resetCyclicTimer,
                                _cyclicOnDigits,
                                _cyclicOffDigits,
                              ),
                            if (_selectedMode == 4)
                              _buildTimerTile(
                                'Shift Timer',
                                _countdownMode == 'Shift Timer'
                                    ? _countdownDisplayNotifier
                                    : ValueNotifier<String>('00:00:00'),
                                _shiftTimerController,
                                null,
                                _updateShiftTimerTime, // Updated callback
                                null,
                                _setShiftTimer,
                                _resetShiftTimer,
                                _shiftTimerDigits,
                              ),
                            if (_selectedMode == 3)
                              _buildTimerTile(
                                'Daily Auto',
                                _countdownMode == 'Daily Auto'
                                    ? _countdownDisplayNotifier
                                    : ValueNotifier<String>('00:00:00'),
                                _dailyAutoController,
                                null,
                                _updateDailyAutoTime, // Updated callback
                                null,
                                _setDailyAutoTimer,
                                _resetDailyAutoTimer,
                                _dailyAutoDigits,
                              ),
                            const SizedBox(height: 20),
                          ],
                          if (_showAllTimers) ...[
                            const SizedBox(height: 16),
                            _buildTimerTile(
                              'Cyclic Timer',
                              _countdownMode == 'Cyclic'
                                  ? _countdownDisplayNotifier
                                  : ValueNotifier<String>('00:00:00'),
                              _cyclicOnController,
                              _cyclicOffController,
                              _updateCyclicOnTime, // Updated callback
                              _updateCyclicOffTime, // Updated callback
                              _setCyclicTimer,
                              _resetCyclicTimer,
                              _cyclicOnDigits,
                              _cyclicOffDigits,
                            ),
                            const SizedBox(height: 16),
                            _buildTimerTile(
                              'Shift Timer',
                              _countdownMode == 'Shift Timer'
                                  ? _countdownDisplayNotifier
                                  : ValueNotifier<String>('00:00:00'),
                              _shiftTimerController,
                              null,
                              _updateShiftTimerTime, // Updated callback
                              null,
                              _setShiftTimer,
                              _resetShiftTimer,
                              _shiftTimerDigits,
                            ),
                            const SizedBox(height: 16),
                            _buildTimerTile(
                              'Daily Auto',
                              _countdownMode == 'Daily Auto'
                                  ? _countdownDisplayNotifier
                                  : ValueNotifier<String>('00:00:00'),
                              _dailyAutoController,
                              null,
                              _updateDailyAutoTime, // Updated callback
                              null,
                              _setDailyAutoTimer,
                              _resetDailyAutoTimer,
                              _dailyAutoDigits,
                            ),
                            const SizedBox(height: 16),
                          ],
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
                      Text(
                        'Awaiting Response...',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyHeaderContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
                Text(
                  _deviceName,
                  style: const TextStyle(
                    color: Color(0xFF030100),
                    fontSize: 24,
                    fontFamily: 'Inter Display',
                    fontWeight: FontWeight.w600,
                    height: 1.33,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFFEDEA),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        width: 1,
                        color: Color(0xFFFFDAD4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _id,
                    style: const TextStyle(
                      color: Color(0xFF800214),
                      fontSize: 14,
                      fontFamily: 'Inter Display',
                      fontWeight: FontWeight.w500,
                      height: 1.57,
                    ),
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.black),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => Settings(
                          deviceName: _deviceName,
                          deviceNumber: widget.deviceNumber,
                          deviceCont: widget.deviceCont,
                          deviceDesc: _deviceDesc,
                        ),
                  ),
                );
                print('DevScreen: Received result from Settings: $result');
                if (result != null && result is Map) {
                  setState(() {
                    _deviceName = result['deviceName'];
                    _deviceDesc = result['deviceDesc'];
                    print(
                      'DevScreen: Updated state - _deviceName: $_deviceName, _deviceDesc: $_deviceDesc',
                    );
                  });
                  // Do NOT pop here; stay on DevScreen
                } else if (result == true) {
                  // Existing behavior for SMS reload
                  print('Settings popped: Reloading initial SMS');
                  await _readInitialSms();
                  await _setupChannel();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: Container(
            width: 390,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(100)),
            child: SegmentedButtonSlide(
              selectedEntry: _motorState ? 1 : 0,
              onChange: _isAwaitingResponse ? (_) {} : _toggleMotor,
              entries: [
                SegmentedButtonSlideEntry(
                  label: _motorState ? "TURN OFF" : "MOTOR OFF",
                ),
                SegmentedButtonSlideEntry(
                  label: _motorState ? "MOTOR ON" : "TURN ON",
                ),
              ],
              colors: SegmentedButtonSlideColors(
                barColor: const Color(0xFFE1E0DF),
                backgroundSelectedColor: const Color.fromARGB(
                  255,
                  255,
                  255,
                  255,
                ),
              ),
              margin: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              height: 35,
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              borderRadius: BorderRadius.circular(100),
              selectedTextStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color:
                    _motorState
                        ? const Color.fromARGB(
                          255,
                          37,
                          211,
                          101,
                        ) // Red for MOTOR Color(0xFFF90D21)
                        : const Color(0xFFF90D21), // Green for MOTOR ON
                fontSize: 16,
              ),
              unselectedTextStyle: TextStyle(
                fontWeight: FontWeight.w400,
                color: const Color(0xFF030100), // Black for unselected
                fontSize: 16,
              ),
              hoverTextStyle: TextStyle(
                color: const Color(0xFF030100), // Black for hover
              ),
            ),
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Center(
              child: AnimatedBuilder(
                animation: _AnimationController,
                builder: (context, child) {
                  return Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontFamily: 'Inter Display',
                      color: _errorColorAnimation.value,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
          ),
        if (_countdownDismissed)
          Padding(
            padding: const EdgeInsets.only(top: 0),
            child: Center(
              child: AnimatedBuilder(
                animation: _AnimationController,
                builder: (context, child) {
                  return Text(
                    "Set Run Time Completed!!!",
                    style: TextStyle(
                      fontFamily: 'Inter Display',
                      color: _ctddmColorAnimation.value,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMainHeaderContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            SizedBox(width: 4),
            Text(
              " $_deviceName",
              style: const TextStyle(
                color: Color(0xFF030100),
                fontSize: 24,
                fontFamily: 'Inter Display',
                fontWeight: FontWeight.w600,
                height: 1.33,
              ),
            ),
            SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: ShapeDecoration(
                color: const Color(0xFFFFEDEA),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(width: 1, color: Color(0xFFFFDAD4)),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _id,
                style: const TextStyle(
                  color: Color(0xFF800214),
                  fontSize: 14,
                  fontFamily: 'Inter Display',
                  fontWeight: FontWeight.w500,
                  height: 1.57,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          ' ${widget.deviceNumber} • ${_d} SMS Received Today',
          style: const TextStyle(
            color: Color(0xFF8C8885),
            fontSize: 16,
            fontFamily: 'Inter Display',
            fontWeight: FontWeight.w400,
            height: 1.50,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(100)),
          child: SegmentedButtonSlide(
            selectedEntry: _motorState ? 1 : 0,
            onChange: _isAwaitingResponse ? (_) {} : _toggleMotor,
            entries: [
              SegmentedButtonSlideEntry(
                label: _motorState ? "TURN OFF" : "MOTOR OFF",
              ),
              SegmentedButtonSlideEntry(
                label: _motorState ? "MOTOR ON" : "TURN ON",
              ),
            ],
            colors: SegmentedButtonSlideColors(
              barColor: const Color(0xFFE1E0DF),
              backgroundSelectedColor: const Color.fromARGB(255, 255, 255, 255),
            ),
            margin: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            height: 35,
            padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            borderRadius: BorderRadius.circular(100),
            selectedTextStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color:
                  _motorState
                      ? const Color.fromARGB(
                        255,
                        37,
                        211,
                        101,
                      ) // Red for MOTOR Color(0xFFF90D21)
                      : const Color(0xFFF90D21), // Green for MOTOR ON
              fontSize: 16,
            ),
            unselectedTextStyle: TextStyle(
              fontWeight: FontWeight.w400,
              color: const Color(0xFF030100), // Black for unselected
              fontSize: 16,
            ),
            hoverTextStyle: TextStyle(
              color: const Color(0xFF030100), // Black for hover
            ),
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6.0),
            child: Center(
              child: AnimatedBuilder(
                animation: _AnimationController,
                builder: (context, child) {
                  return Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: _errorColorAnimation.value,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
          ),
        if (_countdownDismissed)
          Padding(
            padding: const EdgeInsets.only(top: 0),
            child: Center(
              child: AnimatedBuilder(
                animation: _AnimationController,
                builder: (context, child) {
                  return Text(
                    "Set Run Time Completed!!!",
                    style: TextStyle(
                      fontFamily: 'Inter Display',
                      color: _ctddmColorAnimation.value,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhaseBox(String label, String? value, String unit) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              color: const Color(0xFF8C8885),
              fontSize: 16,
              fontFamily: 'Inter Display',
              fontWeight: FontWeight.w400,
              height: 1.50,
            ),
          ),
          TextSpan(
            text: value != null ? '$value ' : 'N/A',
            style: TextStyle(
              color: _dynamicTextColor(),
              fontSize: 16,
              fontFamily: 'Inter Display',
              fontWeight: FontWeight.w400,
              height: 1.50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerTile(
    String title,
    ValueNotifier<String> countdownDisplayNotifier,
    TextEditingController controller1,
    TextEditingController? controller2,
    Function(String) onChanged1,
    Function(String)? onChanged2,
    VoidCallback onSet,
    VoidCallback onReset,
    String digits1, [
    String? digits2,
  ]) {
    bool isCyclicMode = title == 'Cyclic Timer';

    final modeMap = {'Cyclic Timer': 2, 'Daily Auto': 3, 'Shift Timer': 4};
    int requiredMode = modeMap[title] ?? 0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadows: [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 20,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Existing Row with title and countdown display...
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF030100),
                      fontSize: 12,
                      fontFamily: 'Inter Display',
                      fontWeight: FontWeight.w600,
                      height: 1.67,
                      letterSpacing: -0.24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<String>(
                  valueListenable: countdownDisplayNotifier,
                  builder: (context, countdownDisplay, child) {
                    // Existing countdown display logic...
                    Color backgroundColor = Colors.transparent;
                    Color borderColor = Color(0xFF8C8885);
                    Color textColor = Color(0xFF030100);
                    bool isThisTimerActive =
                        _isCountdownActive &&
                        (_countdownMode ==
                            (title == 'Cyclic Timer'
                                ? 'Cyclic'
                                : title == 'Daily Auto'
                                ? 'Daily Auto'
                                : 'Shift Timer'));
                    if (isThisTimerActive) {
                      if (isCyclicMode && _countdownStatus == 'ON') {
                        backgroundColor = Color(0xFFECFFF0);
                        borderColor = Color(0xFF007A1E);
                        textColor = Color(0xFF007A1E);
                      } else if (isCyclicMode) {
                        backgroundColor = Color(0xFFE1E0DF);
                      } else {
                        backgroundColor = Color(0xFFECFFF0);
                        borderColor = Color(0xFF007A1E);
                        textColor = Color(0xFF007A1E);
                      }
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: ShapeDecoration(
                        color: backgroundColor,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(width: 1, color: borderColor),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        countdownDisplay,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontFamily: 'Inter Display',
                          fontWeight: FontWeight.w500,
                          height: 1.57,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.refresh, size: 20, color: Color(0xFF303849)),
                  onPressed: () {
                    if (_selectedMode == requiredMode) {
                      _sendSms('*STATUS\$');
                      print('TimerTile Refresh: Sent *STATUS\$ for $title');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please switch to $title first.'),
                        ),
                      );
                    }
                  },
                  tooltip: 'Refresh $title Status',
                ),
              ],
            ),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (hasFocus && controller1.text == 'N/A') {
                          setState(() {
                            controller1.text = '00:00:00';
                            digits1 = '000000';
                            onChanged1('00:00:00');
                          });
                        }
                      },
                      child: TextField(
                        controller: controller1,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          TimerInputFormatter(digits1, (newDigits) {
                            setState(() {
                              digits1 = newDigits;
                              String formattedTime =
                                  '${newDigits.substring(0, 2)}:${newDigits.substring(2, 4)}:${newDigits.substring(4, 6)}';
                              controller1.text = formattedTime;
                              onChanged1(formattedTime);
                            });
                          }),
                        ],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                              width: 1,
                              color: const Color.fromARGB(255, 188, 188, 189),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              width: 1,
                              color: const Color.fromARGB(255, 204, 203, 203),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              width: 1,
                              color: const Color.fromARGB(255, 165, 214, 163),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          labelText: isCyclicMode ? 'Set On' : 'Set Time',
                          labelStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    if (isCyclicMode &&
                        controller2 != null &&
                        digits2 != null) ...[
                      const SizedBox(height: 16),
                      Focus(
                        onFocusChange: (hasFocus) {
                          if (hasFocus && controller2.text == 'N/A') {
                            setState(() {
                              controller2.text = '00:00:00';
                              digits2 = '000000';
                              onChanged2!('00:00:00');
                            });
                          }
                        },
                        child: TextField(
                          controller: controller2,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            TimerInputFormatter(digits2!, (newDigits) {
                              setState(() {
                                digits2 = newDigits;
                                String formattedTime =
                                    '${newDigits.substring(0, 2)}:${newDigits.substring(2, 4)}:${newDigits.substring(4, 6)}';
                                controller2.text = formattedTime;
                                onChanged2!(formattedTime);
                              });
                            }),
                          ],
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                width: 1,
                                color: const Color.fromARGB(255, 188, 188, 189),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                width: 1,
                                color: const Color.fromARGB(255, 204, 203, 203),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                width: 1,
                                color: const Color.fromARGB(255, 165, 214, 163),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            labelText: 'Set Off',
                            labelStyle: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      onReset();
                    },
                    child: Container(
                      height: 40,
                      clipBehavior: Clip.antiAlias,
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: 1,
                            color: const Color(0xFF800214),
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Reset',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF800214),
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
                      FocusScope.of(context).unfocus();
                      onSet();
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
                          'Set',
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
    );
  }

  bool _isSinglePhase() {
    return _voltageRY != 'N/A' &&
        _currentR != 'N/A' &&
        _voltageYB == 'N/A' &&
        _voltageBR == 'N/A' &&
        _currentY == 'N/A' &&
        _currentB == 'N/A';
  }

  // Add this function to the _DevScreenState class
  Widget _buildSinglePhaseVoltageCurrentWidget() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadows: [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 20,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VOLTAGE',
                    style: TextStyle(
                      color: const Color(0xFF716D69),
                      fontSize: 13,
                      fontFamily: 'Inter Display',
                      fontWeight: FontWeight.w600,
                      height: 1.67,
                      letterSpacing: -0.24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Single voltage value
                  Row(
                    children: [
                      Text(
                        _voltageRY,
                        style: TextStyle(
                          color: const Color(0xFF030100),
                          fontSize: 16,
                          fontFamily: 'Inter Display',
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 50, // Reduced height for single value
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: const Color(0xFFE1E0DF),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT',
                    style: TextStyle(
                      color: const Color(0xFF716D69),
                      fontSize: 13,
                      fontFamily: 'Inter Display',
                      fontWeight: FontWeight.w600,
                      height: 1.67,
                      letterSpacing: -0.24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Single current value
                  Row(
                    children: [
                      Text(
                        _currentR,
                        style: TextStyle(
                          color: const Color(0xFF030100),
                          fontSize: 16,
                          fontFamily: 'Inter Display',
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SelectModeModal extends StatefulWidget {
  final int initialMode;
  final Function(int) onSave;
  final VoidCallback onCancel;

  const SelectModeModal({
    super.key,
    required this.initialMode,
    required this.onSave,
    required this.onCancel,
  });

  @override
  _SelectModeModalState createState() => _SelectModeModalState();
}

class _SelectModeModalState extends State<SelectModeModal> {
  late int _tempSelectedMode;

  @override
  void initState() {
    super.initState();
    _tempSelectedMode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select mode',
                          style: TextStyle(
                            color: const Color(0xFF030100),
                            fontSize: 24,
                            fontFamily: 'Inter Display',
                            fontWeight: FontWeight.w600,
                            height: 1.33,
                          ),
                        ),

                        GestureDetector(
                          onTap: () {
                            widget.onCancel();
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color:
                                  Colors
                                      .white, // Add background to make shadow visible
                              shape: BoxShape.circle, // Ensure circular shape
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0x40000000,
                                  ), // Increase opacity (0x26 -> 0x40)
                                  blurRadius: 20,
                                  offset: Offset(0, 4),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Color.fromARGB(255, 0, 0, 0),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose your mode',
                      style: TextStyle(
                        color: const Color(0xFF8C8885),
                        fontSize: 16,
                        fontFamily: 'Inter Display',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildModeOption(context, 'Manual', 0),
                    const SizedBox(height: 10),
                    _buildModeOption(context, 'Auto Start', 1),
                    const SizedBox(height: 10),
                    _buildModeOption(context, 'Cyclic Timer', 2),
                    const SizedBox(height: 10),
                    _buildModeOption(context, 'Daily Auto', 3),
                    const SizedBox(height: 10),
                    _buildModeOption(context, 'Shift Timer', 4),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () {
                    widget.onSave(_tempSelectedMode);
                    Navigator.pop(context);
                  },
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    decoration: ShapeDecoration(
                      color:
                          _tempSelectedMode == widget.initialMode
                              ? Colors.grey
                              : const Color(0xFF800214),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(200),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Confirm',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption(BuildContext context, String label, int value) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _tempSelectedMode = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          shadows: [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 20,
              offset: Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF11141F),
                fontSize: 16,
                fontFamily: 'Inter Display',
                fontWeight: FontWeight.w400,
                height: 1.50,
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: 1,
                    color:
                        _tempSelectedMode == value
                            ? const Color(0xFF800214)
                            : const Color(0xFFE1E0DF),
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child:
                  _tempSelectedMode == value
                      ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF800214),
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}

class TimerInputWidget extends StatefulWidget {
  @override
  _TimerInputWidgetState createState() => _TimerInputWidgetState();
}

class _TimerInputWidgetState extends State<TimerInputWidget> {
  final TextEditingController _controller = TextEditingController();
  String _digits = "000000"; // Internal HHMMSS string

  @override
  void initState() {
    super.initState();
    _controller.text = _formatTime(_digits);
  }

  String _formatTime(String digits) {
    return '${digits.substring(0, 2)}:${digits.substring(2, 4)}:${digits.substring(4, 6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          TimerInputFormatter(_digits, (newDigits) {
            setState(() {
              _digits = newDigits;
            });
          }),
        ],
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Time (HH:MM:SS)',
        ),
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight ||
        child != oldDelegate.child;
  }
}

class OfflinePopup extends StatelessWidget {
  final VoidCallback onConfirm;

  const OfflinePopup({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      width: 400,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 50, vertical: 24),
            child: Text(
              'Sorry, You\'re Offline! \nHere\'s How to Reconnect',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF030100),
                fontSize: 24,
                fontFamily: 'Inter Display',
                fontWeight: FontWeight.w600,
                height: 1.33,
              ),
            ),
          ),
          Container(
            child: SizedBox(
              width: 400,
              child: Text(
                'Possible causes include power outages, expired SMS packs, or unregistered phone numbers. \nCheck and troubleshoot to reconnect.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF8C8885),
                  fontSize: 16,
                  fontFamily: 'Inter Display',
                  fontWeight: FontWeight.w400,
                  height: 1.50,
                ),
              ),
            ),
          ),
          SizedBox(height: 32),
          Container(
            child: GestureDetector(
              onTap: () {
                onConfirm();
                Navigator.pop(context);
              },
              child: Container(
                width: 335,
                height: 50,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: const Color(0xFF800214),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(200),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Okay',
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
    );
  }
}

class DisabledPopup extends StatelessWidget {
  final VoidCallback onConfirm;

  const DisabledPopup({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: 400,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 50, vertical: 24),
            child: Text(
              'Account Disabled',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF030100),
                fontSize: 24,
                fontFamily: 'Inter Display',
                fontWeight: FontWeight.w600,
                height: 1.33,
              ),
            ),
          ),
          Container(
            child: SizedBox(
              width: 400,
              child: Text(
                'You have been disabled by the admin. Please contact the admin to use the app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF8C8885),
                  fontSize: 16,
                  fontFamily: 'Inter Display',
                  fontWeight: FontWeight.w400,
                  height: 1.50,
                ),
              ),
            ),
          ),
          SizedBox(height: 32),
          Container(
            child: GestureDetector(
              onTap: () {
                onConfirm();
                Navigator.pop(context);
              },
              child: Container(
                width: 335,
                height: 50,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: const Color(0xFF800214),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(200),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Okay',
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
    );
  }
}

class TimerInputFormatter extends TextInputFormatter {
  String digits; // Internal "HHMMSS"
  final Function(String) onChanged;

  TimerInputFormatter(this.digits, this.onChanged);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Handle 'N/A' case
    if (oldValue.text == 'N/A') {
      digits = '000000';
      onChanged(digits);
      return TextEditingValue(
        text: '00:00:00',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    String newText = newValue.text;
    int newCursor = newValue.selection.baseOffset;
    int oldCursor = oldValue.selection.baseOffset;

    // Allow only digits and colons, reject other input
    String filtered = newText.replaceAll(RegExp(r'[^0-9:]'), '');
    if (filtered.length > 8) filtered = filtered.substring(0, 8);
    if (!filtered.contains(':')) return oldValue; // Basic validation

    // Handle insertion or deletion
    String newDigits = digits;
    if (newText.length < oldValue.text.length) {
      newDigits = _handleDeletion(oldValue, newValue, oldCursor);
    } else if (newText.length > oldValue.text.length) {
      newDigits = _handleInsertion(oldValue, newValue, newCursor);
    }

    // Apply rollovers immediately if values exceed limits
    newDigits = _applyRollovers(newDigits);

    // Update internal digits and format text
    digits = newDigits.padRight(6, '0');
    String formatted = _formatTime(digits);
    onChanged(digits);

    // Adjust cursor position
    int adjustedCursor = _adjustCursor(
      newCursor,
      newText,
      formatted,
      oldValue,
      newValue,
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: adjustedCursor),
    );
  }

  String _handleDeletion(
    TextEditingValue oldValue,
    TextEditingValue newValue,
    int cursorOffset,
  ) {
    int digitPos = _mapCursorToDigit(cursorOffset - 1, oldValue.text);
    if (digitPos < 0 || digitPos >= 6) return digits;
    return digits.substring(0, digitPos) + '0' + digits.substring(digitPos + 1);
  }

  String _handleInsertion(
    TextEditingValue oldValue,
    TextEditingValue newValue,
    int cursorOffset,
  ) {
    String newChar = newValue.text[cursorOffset - 1];
    if (!RegExp(r'[0-9]').hasMatch(newChar)) return digits;
    int digitPos = _mapCursorToDigit(cursorOffset - 1, oldValue.text);
    if (digitPos < 0 || digitPos >= 6) return digits;
    String newDigits = digits.substring(0, digitPos) + newChar;
    if (digitPos < 5) newDigits += digits.substring(digitPos, 5);
    return newDigits.length > 6 ? newDigits.substring(0, 6) : newDigits;
  }

  String _formatTime(String digits) {
    return '${digits.substring(0, 2)}:${digits.substring(2, 4)}:${digits.substring(4, 6)}';
  }

  String _applyRollovers(String digits) {
    int ss = int.parse(digits.substring(4, 6));
    int mm = int.parse(digits.substring(2, 4));
    int hh = int.parse(digits.substring(0, 2));

    // Roll over seconds
    if (ss >= 60) {
      mm += ss ~/ 60;
      ss %= 60;
    }
    // Roll over minutes
    if (mm >= 60) {
      hh += mm ~/ 60;
      mm %= 60;
    }
    // Cap hours at 24
    if (hh > 23) hh = 23;

    return '${hh.toString().padLeft(2, '0')}${mm.toString().padLeft(2, '0')}${ss.toString().padLeft(2, '0')}';
  }

  int _mapCursorToDigit(int cursorPos, String text) {
    if (cursorPos < 0 || cursorPos > text.length) return -1;
    if (cursorPos == 2 || cursorPos == 5) return -1; // Colons
    if (cursorPos < 2) return cursorPos; // HH
    if (cursorPos < 5) return cursorPos - 1; // MM
    if (cursorPos < 8) return cursorPos - 2; // SS
    return -1;
  }

  int _adjustCursor(
    int cursor,
    String newText,
    String formatted,
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newText.length > oldValue.text.length) {
      // Insertion
      int digitPos = _mapCursorToDigit(cursor - 1, oldValue.text);
      if (digitPos == 1) return 3; // After HH[1], skip colon to MM[0]
      if (digitPos == 3) return 6; // After MM[1], skip colon to SS[0]
      if (digitPos >= 0 && digitPos < 6)
        return cursor; // Normal digit positions
    }
    // Handle deletion or other cases
    if (cursor <= 2) return cursor; // HH
    if (cursor == 3) return 3; // Before MM
    if (cursor <= 5) return cursor; // MM
    if (cursor == 6) return 6; // Before SS
    if (cursor <= 8) return cursor; // SS
    return formatted.length;
  }
}
