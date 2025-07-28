import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

class SmsService {
  final SmsQuery _smsQuery = SmsQuery();
   static const _platform = MethodChannel('com.naren.NESmartConnect/sms');

  Future<int> _getDailyCount(String phone) async {
    try {
      final int? d = await _platform.invokeMethod<int>('getDailySmsCount', {
        'phoneNumber': phone,
      });
      return d ?? 0;
    } catch (_) {
      return 0;
    }
  }

// New method signature that accepts current values
Future<Map<String, dynamic>> readInitialSms(
  String phoneNumber, 
  [Map<String, dynamic>? currentValues]
) async {
  if (await _requestSmsPermission()) {
    List<SmsMessage> messages = await _queryLastFiveMessages(phoneNumber);
    return _parseAndAggregateMessages(messages, phoneNumber, currentValues);
  } else {
    return currentValues ?? {};
  }
}


  Future<bool> _requestSmsPermission() async {
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
    }
    return status.isGranted;
  }

Future<List<SmsMessage>> _queryLastFiveMessages(String phoneNumber) async {
    final String tenDigit = phoneNumber.replaceAll(RegExp(r'^\+91'), '');
    final List<SmsMessage> all = await _smsQuery.querySms(
      kinds: [SmsQueryKind.inbox],
      // No address filter → we get the newest messages first (sort:true)
      address: null,
      count: 40, // pull a small window (fast, < 1 ms)
      sort: true,
    );

    // Keep only messages whose address ends with the 10–digit MSISDN
    final List<SmsMessage> mine =
        all
            .where(
              (m) =>
                  m.address != null &&
                  m.address!
                      .replaceAll(RegExp(r'[^0-9]'), '')
                      .endsWith(tenDigit),
            )
            .take(10) // newest → oldest
            .toList();

    return mine;
  }

  Future<Map<String, dynamic>> _parseAndAggregateMessages(
    List<SmsMessage> messages,
    String phoneNumber, Map<String, dynamic>? currentValues,
  ) async {
    Map<String, dynamic> latestParams = currentValues ?? _initializeParams();
    Set<String> paramsToFind =
        Set<String>.from(latestParams.keys)
          ..remove('error')
          ..remove('countdownDismissed');

    DateTime? newestVoltageCurrentTimestamp;
    bool isFirstMessage = true;

if (messages.isNotEmpty) {
      var firstParams = await parseSms(
        messages[0].body ?? '',
        phoneNumber,
        messages[0].date?.millisecondsSinceEpoch ?? 0,
      );
      latestParams['error'] = firstParams['error'];
      latestParams['countdownDismissed'] = firstParams['countdownDismissed'];
        print('SMS_SERVICE_DEBUG: Latest message error: ${firstParams['error']}');
      print(
        'SMS_SERVICE_DEBUG: Latest message countdownDismissed: ${firstParams['countdownDismissed']}',
      );
    }

    // Now process all messages for other parameters
    for (var message in messages) {
      var params = await parseSms(
        message.body ?? '',
        phoneNumber,
        message.date?.millisecondsSinceEpoch ?? 0,
      );


      if (params.containsKey('voltageRY') && params['voltageRY'] != 'N/A') {
        if (newestVoltageCurrentTimestamp == null ||
            message.date!.isAfter(newestVoltageCurrentTimestamp)) {
          newestVoltageCurrentTimestamp = message.date;
        }
      }

      for (var entry in params.entries) {
        var key = entry.key;
        var value = entry.value;
        if (!paramsToFind.contains(key)) continue;
        if (key != 'error' &&
            key != 'countdownDismissed' &&
            value != 'N/A' &&
            value != null) {
          latestParams[key] = value;
          paramsToFind.remove(key);
        }
      }

      if (paramsToFind.isEmpty) {
        break;
      }
    }

    if (newestVoltageCurrentTimestamp != null) {
      latestParams['lastSync'] = _formatDate(newestVoltageCurrentTimestamp);
    }

    return latestParams;
  }

  Map<String, dynamic> _initializeParams() {
    return {
      'lowVoltage': 'N/A',
      'highVoltage': 'N/A',
      'lowCurrent': 'N/A',
      'highCurrent': 'N/A',
      'overloadTripTime': 'N/A',
      'voltageTripTime': 'N/A',
      'dryRunTripTime': 'N/A',
      'singlePhaseTripTime': 'N/A',
      'maxRunTime': 'N/A',
      'dryRunRestartTime': 'N/A',
      'feedbackDelayTime': 'N/A',
      'phoneNumber1': 'N/A',
      'phoneNumber2': 'N/A',
      'phoneNumber3': 'N/A',
      'hostNumber': 'N/A',
      'lastSync': 'N/A',
      'id': 'N/A',
      'lastPingAction': 'N/A',
      'lastPingInitiator': 'N/A',
      'lastPingTimestamp': 'N/A',
      'voltageRY': 'N/A',
      'voltageYB': 'N/A',
      'voltageBR': 'N/A',
      'currentR': 'N/A',
      'currentY': 'N/A',
      'currentB': 'N/A',
      'motorState': null,
      'error': null,
      'mode': null,
      'cyclicOnTime': 'N/A',
      'cyclicOffTime': 'N/A',
      'dailyAutoTime': 'N/A',
      'shiftTimerTime': 'N/A',
      'countdownMode': 'N/A',
      'countdownStatus': 'N/A',
      'countdownSince': 'N/A',
      'countdownTarget': 'N/A',
      'countdownDismissed': false,
      'n': 0,
      'd': 0,
    };
  }

  // Complete parseSms function - direct port from Kotlin
  Future<Map<String, dynamic>> parseSms(
    String message,
    String phoneNumber,
    int timestamp,
  ) async {

    Map<String, dynamic> params = {};

    try {
      print('SMS_PARSE: Raw SMS Body: \'$message\'');

      final lines = message.split('\n');
      final lastLine = lines.isNotEmpty ? lines.last.trim() : '';
      print('LAST_LINE_DEBUG: Last Line: \'$lastLine\'');

      // Regex patterns - exact port from Kotlin
      final timestampPattern = RegExp(
        r'[@¡](\d{2}/\d{2}-\d{2}:\d{2}(?::\d{2})?)',
      );
      final slideronPattern = RegExp(
        r'MOTOR:\s*ON|Motor\s+successfully\s+Turned\s+ON|Motor\s+Turned\s+ON',
        caseSensitive: false,
      );

      final slideroffPattern = RegExp(
        r'MOTOR:\s*OFF|Motor\s+successfully\s+Turned\s+OFF|Motor\s+Turned\s+OFF|MOTOR:\s*[^\n]*(?:error|fail|failed|failure)[^\n]*|Motor\s+Turned\s+Off\s+[^\n]*(?:error|fail|failed|failure)[^\n]*|[^\n]*(?:error|fail|failed|failure)[^\n]*|^Power\s+is\s+back',
        caseSensitive: false,
      );
      final idPattern = RegExp(
        r'(?:ID|Device ID):\s*([A-Z]{2}\d{4})',
        caseSensitive: false,
      );
      final idMatch = idPattern.firstMatch(message);
      if (idMatch != null) {
        params['id'] = idMatch.group(1) ?? 'N/A';
      }

      // Timestamp parsing
      int responsestamp = timestamp;
      try {
        if (lastLine.startsWith('@') || lastLine.startsWith('¡')) {
          final timeString = lastLine
              .replaceFirst('@', '')
              .replaceFirst('¡', '');
          final parts = timeString.split('-');
          if (parts.length == 2) {
            final dateParts = parts[0].split('/');
            final timeParts = parts[1].split(':');
            if (dateParts.length == 2 && timeParts.length >= 2) {
              final day = int.tryParse(dateParts[0]) ?? 1;
              final month = int.tryParse(dateParts[1]) ?? 1;
              final hour = int.tryParse(timeParts[0]) ?? 0;
              final minute = int.tryParse(timeParts[1]) ?? 0;
              final second =
                  timeParts.length > 2 ? int.tryParse(timeParts[2]) ?? 0 : 0;
              final now = DateTime.fromMillisecondsSinceEpoch(timestamp);
              responsestamp =
                  DateTime(
                    now.year,
                    month,
                    day,
                    hour,
                    minute,
                    second,
                  ).millisecondsSinceEpoch;
            }
          }
        }
      } catch (e) {
        responsestamp = timestamp;
      }

      // Initiator parsing - exact port from Kotlin
      final initiatorPattern = RegExp(
        r'(Initiated\s+by:|Init\s+by:|Motor Turned ON By)\s*(.+?)(?:\s*$|\s*\n)',
        caseSensitive: false,
      );
      final initiatorMatch = initiatorPattern.firstMatch(message);
      if (initiatorMatch != null) {
        final linesPing = lines.map((line) => line.trim()).toList();
        final initiator = initiatorMatch.group(2) ?? 'N/A';
        print(
          'LAST_PING_DEBUG: Initiator found: $initiator, Receipt Timestamp: $timestamp',
        );

        if (linesPing.length >= 2 && initiatorPattern.hasMatch(linesPing[1])) {
          params['lastPingAction'] = linesPing[0];
          params['lastPingInitiator'] = initiator;
          params['lastPingTimestamp'] = _formatDate(
            DateTime.fromMillisecondsSinceEpoch(responsestamp),
          );
          print(
            'LAST_PING_DEBUG: Second line match - Action: ${params["lastPingAction"]}',
          );
        } else {
          final firstLine = linesPing.isNotEmpty ? linesPing[0] : '';
          params['lastPingInitiator'] = initiator;
          params['lastPingTimestamp'] = _formatDate(
            DateTime.fromMillisecondsSinceEpoch(responsestamp),
          );

          if (firstLine.toLowerCase().startsWith('ol time')) {
            params['lastPingAction'] = 'Timings Check';
            print('LAST_PING_DEBUG: Timings Check');
          } else if (firstLine.toLowerCase().startsWith('ry:')) {
            params['lastPingAction'] = 'Status Check';
            print('LAST_PING_DEBUG: Status Check');
          } else if (firstLine.toLowerCase().startsWith('v=')) {
            params['lastPingAction'] = 'Status Check';
            print('LAST_PING_DEBUG: Status Check');
          } else if (firstLine.toLowerCase().startsWith('low voltage =')) {
            params['lastPingAction'] = 'Protection values check';
            print('LAST_PING_DEBUG: Protection values check');
          } else {
            params['lastPingAction'] = 'N/A';
            print('LAST_PING_DEBUG: No specific action matched');
          }
        }
      }

      // Voltage and Current parsing - exact port from Kotlin
      final format1Pattern = RegExp(
        r'RY:(\d+)\s*V/(\d+\.\d)\s*A\s*YB:(\d+)\s*V/(\d+\.\d)\s*A\s*BR:(\d+)\s*V/(\d+\.\d)\s*A',
        caseSensitive: false,
      );
      final format2Pattern = RegExp(
        r'V=(\d+),(\d+),(\d+)\s*A=(\d+\.\d),(\d+\.\d),(\d+\.\d)',
        caseSensitive: false,
      );
      final format3Pattern = RegExp(
        r'R Current:(\d+\.\d)\s*Y Current:(\d+\.\d)\s*B Current:(\d+\.\d)',
        caseSensitive: false,
      );
      final voltagePattern = RegExp(
        r'V=(\d+),(\d+),(\d+)',
        caseSensitive: false,
      );
      final currentPattern = RegExp(
        r'A=(\d+\.\d),(\d+\.\d),(\d+\.\d)',
        caseSensitive: false,
      );
      final singlePhasePattern = RegExp(
        r'V:(\d+)\s*V/(\d+\.\d)\s*A',
        caseSensitive: false,
      );

      final match1 = format1Pattern.firstMatch(message);
      final match2 = format2Pattern.firstMatch(message);
      final match3 = format3Pattern.firstMatch(message);
      final matchVoltage = voltagePattern.firstMatch(message);
      final matchCurrent = currentPattern.firstMatch(message);
      final singlePhaseMatch = singlePhasePattern.firstMatch(message);

      if (match1 != null) {
        params['voltageRY'] = '${match1.group(1)} V';
        params['voltageYB'] = '${match1.group(3)} V';
        params['voltageBR'] = '${match1.group(5)} V';
        params['currentR'] = '${match1.group(2)} A';
        params['currentY'] = '${match1.group(4)} A';
        params['currentB'] = '${match1.group(6)} A';
      } else if (match2 != null) {
        params['voltageRY'] = '${match2.group(1)} V';
        params['voltageYB'] = '${match2.group(2)} V';
        params['voltageBR'] = '${match2.group(3)} V';
        params['currentR'] = '${match2.group(4)} A';
        params['currentY'] = '${match2.group(5)} A';
        params['currentB'] = '${match2.group(6)} A';
      } else if (singlePhaseMatch != null) {
        params['voltageRY'] = '${singlePhaseMatch.group(1)} V';
        params['currentR'] = '${singlePhaseMatch.group(2)} A';
        params['voltageYB'] = 'N/A';
        params['voltageBR'] = 'N/A';
        params['currentY'] = 'N/A';
        params['currentB'] = 'N/A';
        print(
          'SMS_PARSE: Single phase values detected: Voltage=${params["voltageRY"]}, Current=${params["currentR"]}',
        );
      } else {
        if (matchVoltage != null) {
          params['voltageRY'] = '${matchVoltage.group(1)} V';
          params['voltageYB'] = '${matchVoltage.group(2)} V';
          params['voltageBR'] = '${matchVoltage.group(3)} V';
        }
        if (matchCurrent != null) {
          params['currentR'] = '${matchCurrent.group(1)} A';
          params['currentY'] = '${matchCurrent.group(2)} A';
          params['currentB'] = '${matchCurrent.group(3)} A';
        }
        if (match3 != null) {
          params['currentR'] = '${match3.group(1)} A';
          params['currentY'] = '${match3.group(2)} A';
          params['currentB'] = '${match3.group(3)} A';
        }
      }

      final hasVoltagesOrCurrents =
          (match1 != null || match2 != null || match3 != null);
      if (hasVoltagesOrCurrents) {
        params['lastSync'] = _formatDate(
          DateTime.fromMillisecondsSinceEpoch(responsestamp),
        );
        print(
          'LAST_SYNC_DEBUG: Last Sync updated to receipt timestamp due to voltages/currents: ${params["lastSync"]}',
        );
      } else {
        print(
          'LAST_SYNC_DEBUG: Last Sync set to current time (no voltages/currents): ${params["lastSync"]}',
        );
      }

      // Phone numbers parsing
      final phoneNumbersPattern = RegExp(
        r'Registered\s+Phone\s+Nos:\s*1\.(\d{10})\s*2\.(\d{10})\s*3\.(\d{10})',
        caseSensitive: false,
      );
      final phoneNumbersMatch = phoneNumbersPattern.firstMatch(message);
      if (phoneNumbersMatch != null) {
        final numbers =
            [
              phoneNumbersMatch.group(1),
              phoneNumbersMatch.group(2),
              phoneNumbersMatch.group(3),
            ].where((it) => it != '0000000000' && it != null).toList();
        final n = numbers.length;
        params['phoneNumber1'] = phoneNumbersMatch.group(1) ?? 'N/A';
        params['phoneNumber2'] = phoneNumbersMatch.group(2) ?? 'N/A';
        params['phoneNumber3'] = phoneNumbersMatch.group(3) ?? 'N/A';
        params['n'] = n;
        print('RESP: n=$n');
      }

      // Daily SMS count (simplified for Dart)
      params['d'] = await _getDailyCount(phoneNumber);
      
      bool sliderison = false;
      // Motor state
      if (slideronPattern.hasMatch(message)) {
        params['motorState'] = true;
        sliderison = true;
      } else if (slideroffPattern.hasMatch(message)) {
        params['motorState'] = false;
        params['countdownMode'] = 'N/A';
        params['countdownStatus'] = 'N/A';
        params['countdownSince'] = '00:00:00';
        params['countdownTarget'] = '00:00:00';
        params['countdownDismissed'] = false;
        sliderison = false;
      }

      // Error detection
final errorPatterns = {
        'Single Phase Error': RegExp(
          r'Single Phase Error',
          caseSensitive: false,
        ),
        'Feedback Failed Error': RegExp(
          r'Feedback Failed|Feedback not received',
          caseSensitive: false,
        ),
        'Dry Run Error': RegExp(r'Dry Run Error', caseSensitive: false),
        'High Voltage Error': RegExp(
          r'High Voltage Error',
          caseSensitive: false,
        ),
        'Unhealthy Voltage Error': RegExp(r'not healthy', caseSensitive: false),
        'Low Voltage Error': RegExp(r'Low Voltage', caseSensitive: false),
        'Overload Error': RegExp(r'over load Error', caseSensitive: false),
      };
      bool containsError = false;
      for (var entry in errorPatterns.entries) {
        if (entry.value.hasMatch(message)) {
          params['error'] = entry.key;
          containsError = true;
          break;
        }
      }
      if (!containsError) {
        params['error'] = null;
      }

      // Mode parsing
      final modePattern = RegExp(
        r'(MODE:|Mode Changed To:)\s*(Manual|Auto|Auto Start|Cyclic|Daily Auto|Shift Timer)',
        caseSensitive: false,
      );
      final modeMatch = modePattern.firstMatch(message);
      params['mode'] = _getModeValue(modeMatch?.group(2)?.toLowerCase());

      // Timer parsing
final cyclicOnPattern = RegExp(
        r'(Set\s+ON\s*:\s*(\d{2}:\d{2}:\d{2})|Cyclic time updated:\s*(\d{2}:\d{2}:\d{2}))',
        caseSensitive: false,
      );
      final cyclicOnMatch = cyclicOnPattern.firstMatch(message);
      if (cyclicOnMatch != null && message.toLowerCase().contains('cyclic')) {
        params['cyclicOnTime'] =
            cyclicOnMatch.group(2) ?? cyclicOnMatch.group(3) ?? '00:00:00';
      }

final cyclicOffPattern = RegExp(
        r'(Set\s+OFF\s*:\s*(\d{2}:\d{2}:\d{2})|Cyclic time updated:\s*(\d{2}:\d{2}:\d{2}))',
        caseSensitive: false,
      );
      final cyclicOffMatch = cyclicOffPattern.firstMatch(message);
      if (cyclicOffMatch != null && message.toLowerCase().contains('cyclic')) {
        params['cyclicOffTime'] =
            cyclicOffMatch.group(2) ?? cyclicOffMatch.group(3) ?? '00:00:00';
      }

final dailyAutoPattern = RegExp(
        r'(Set\s+ON\s*:\s*(\d{2}:\d{2}:\d{2})|Day Run time updated:\s*(\d{2}:\d{2}:\d{2}))',
        caseSensitive: false,
      );
      final dailyAutoMatch = dailyAutoPattern.firstMatch(message);
      if (dailyAutoMatch != null && message.toLowerCase().contains('daily')) {
        params['dailyAutoTime'] =
            dailyAutoMatch.group(2) ?? dailyAutoMatch.group(3) ?? '00:00:00';
      }

final shiftTimerPattern = RegExp(
        r'(Set\s+ON\s*:\s*(\d{2}:\d{2}:\d{2})|Shift Timer Time updated:\s*(\d{2}:\d{2}:\d{2}))',
        caseSensitive: false,
      );
      final shiftTimerMatch = shiftTimerPattern.firstMatch(message);
      if (shiftTimerMatch != null && message.toLowerCase().contains('shift')) {
        params['shiftTimerTime'] =
            shiftTimerMatch.group(2) ?? shiftTimerMatch.group(3) ?? '00:00:00';
      }

      // Countdown logic
final countdownModePattern = RegExp(
        r'MODE:\s*(Shift Timer|Cyclic|Daily Auto)',
        caseSensitive: false,
      );
      final countdownStatusPattern = RegExp(
        r'(?:STATUS:\s*)?(ON|OFF)\s*(Since|since)\s*[:]?\s*(\d{2}:\d{2}:\d{2}|\d{2}:\d{2}:)',
        caseSensitive: false,
      );
final setOnPattern = RegExp(
        r'Set\s+ON\s*:\s*(\d{2}:\d{2}:\d{2})',
        caseSensitive: false,
      );
      final setOffPattern = RegExp(
        r'Set\s+OFF\s*:\s*(\d{2}:\d{2}:\d{2})',
        caseSensitive: false,
      );
      final dismissPattern = RegExp(
        r'Time Completed',
        caseSensitive: false,
      );
      if (dismissPattern.hasMatch(message)) {
        params['countdownDismissed'] = true;
      } else if (countdownModePattern.hasMatch(message) &&
          countdownStatusPattern.hasMatch(message)) {
        final mode =
            countdownModePattern.firstMatch(message)?.group(1) ?? 'N/A';
        final statusMatch = countdownStatusPattern.firstMatch(message);
        final status = statusMatch?.group(1) ?? 'N/A';
        var sinceTime = statusMatch?.group(3) ?? '00:00:00';
        if (sinceTime.length < 8) sinceTime = '${sinceTime}00';

        String? targetTime;
        switch (mode.toLowerCase()) {
          case 'cyclic':
            targetTime =
                status == 'ON'
                    ? setOnPattern.firstMatch(message)?.group(1)
                    : setOffPattern.firstMatch(message)?.group(1);
            break;
          case 'shift timer':
            targetTime = shiftTimerMatch?.group(2) ?? shiftTimerMatch?.group(3);
            break;
          case 'daily auto':
            targetTime = dailyAutoMatch?.group(2) ?? dailyAutoMatch?.group(3);
            break;
          default:
            targetTime = '00:00:00';
        }
        targetTime ??= '00:00:00';

        if (sinceTime != '00:00:00' || targetTime != '00:00:00') {
          print(
            'COUNTDOWN_DEBUG: sinceTime: $sinceTime, targetTime: $targetTime',
          );
          if (!containsError) {
            if (mode.toLowerCase()=='cyclic'){
            params['countdownMode'] = mode;
            params['countdownStatus'] = status;
            params['countdownSince'] = sinceTime;
            final motorOnTill = _calculateMotorOnTill(
              DateTime.fromMillisecondsSinceEpoch(responsestamp),
              sinceTime,
              targetTime,
              mode,
            );
            params['countdownTarget'] = _formatDate(motorOnTill);
            params['countdownDismissed'] = false;
          } else if (mode.toLowerCase()=='shift timer' || mode.toLowerCase()=='daily auto'){
            if (sliderison == true) {
                params['countdownMode'] = mode;
                params['countdownStatus'] = status;
                params['countdownSince'] = sinceTime;
                final motorOnTill = _calculateMotorOnTill(
                  DateTime.fromMillisecondsSinceEpoch(responsestamp),
                  sinceTime,
                  targetTime,
                  mode,
                );
                params['countdownTarget'] = _formatDate(motorOnTill);
                params['countdownDismissed'] = false;
            }else {
              params['countdownMode'] = 'N/A';
              params['countdownStatus'] = 'N/A';
              params['countdownSince'] = '00:00:00';
              params['countdownTarget'] = '00:00:00';
              params['countdownDismissed'] = false;
            }
          } else {
            params['countdownMode'] = 'N/A';
            params['countdownStatus'] = 'N/A';
            params['countdownSince'] = '00:00:00';
            params['countdownTarget'] = '00:00:00';
            params['countdownDismissed'] = false;
          }
          } else {
            params['countdownMode'] = 'N/A';
            params['countdownStatus'] = 'N/A';
            params['countdownSince'] = '00:00:00';
            params['countdownTarget'] = '00:00:00';
            params['countdownDismissed'] = false;
          }
        } else {
          params['countdownMode'] = 'N/A';
          params['countdownStatus'] = 'N/A';
          params['countdownSince'] = '00:00:00';
          params['countdownTarget'] = '00:00:00';
          params['countdownDismissed'] = false;
        }
      }
      if (dismissPattern.hasMatch(message)) {
        params['countdownDismissed'] = true;
        print('SMS_PARSE: Set Run Time Completed detected');
      } else {
        print('SMS_PARSE: No Set Run Time Completed pattern found');
      }
      // Protection parameters parsing
final lowVoltagePattern = RegExp(
        r'Low\s*Voltage\s*=\s*(\d{1,3})\s*V',
        caseSensitive: false,
      );
      final lowVoltageMatch = lowVoltagePattern.firstMatch(message);
      if (lowVoltageMatch != null)
        params['lowVoltage'] = lowVoltageMatch.group(1) ?? 'N/A';

      final highVoltagePattern = RegExp(
        r'High\s*Voltage\s*=\s*(\d{1,3})\s*V',
        caseSensitive: false,
      );
      final highVoltageMatch = highVoltagePattern.firstMatch(message);
      if (highVoltageMatch != null)
        params['highVoltage'] = highVoltageMatch.group(1) ?? 'N/A';

      final highCurrentPattern = RegExp(
        r'(?:High\s*Current|Set High Current)\s*(?:Updated:|=)\s*(\d{1,2})\s*Amp[sS]',
        caseSensitive: false,
      );
      final setHcPattern = RegExp(
        r'Set HC:\s*(\d{1,2})\s*A',
        caseSensitive: false,
      );
      final highCurrentMatch = highCurrentPattern.firstMatch(message);
      final setHcMatch = setHcPattern.firstMatch(message);
      if (highCurrentMatch != null) {
        params['highCurrent'] = highCurrentMatch.group(1) ?? 'N/A';
      } else if (setHcMatch != null) {
        params['highCurrent'] = setHcMatch.group(1) ?? 'N/A';
      }

      final lowCurrentPattern = RegExp(
        r'(?:Low\s*Current|Set Low Current)\s*(?:Updated:|=)\s*(\d{1,2})\s*Amp[sS]',
        caseSensitive: false,
      );
      final setLcPattern = RegExp(
        r'Set LC:\s*(\d{1,2})\s*A',
        caseSensitive: false,
      );

      final lowCurrentMatch = lowCurrentPattern.firstMatch(message);
      final setLcMatch = setLcPattern.firstMatch(message);
      if (lowCurrentMatch != null) {
        params['lowCurrent'] = lowCurrentMatch.group(1) ?? 'N/A';
      } else if (setLcMatch != null) {
        params['lowCurrent'] = setLcMatch.group(1) ?? 'N/A';
      }

     final overloadTripPattern = RegExp(
        r'(?:OL\s*Time\s*=|Over load time updated:)\s*(\d{1,3})\s*Sec',
        caseSensitive: false,
      );
      final overloadTripMatch = overloadTripPattern.firstMatch(message);
      if (overloadTripMatch != null)
        params['overloadTripTime'] = overloadTripMatch.group(1) ?? 'N/A';

      final voltageTripPattern = RegExp(
        r'(?:Votlage\s*Trip\s*Time\s*|Voltage\s*Trip\s*Time\s*)(?:updated:|=)\s*(\d{1,3})\s*Sec',
        caseSensitive: false,
      );

      final voltageTripMatch = voltageTripPattern.firstMatch(message);
      if (voltageTripMatch != null)
        params['voltageTripTime'] = voltageTripMatch.group(1) ?? 'N/A';

      final dryRunTripPattern = RegExp(
        r'(?:DR\s*Time\s*=|Dry Run time updated:)\s*(\d{1,3})\s*Sec',
        caseSensitive: false,
      );

      final dryRunTripMatch = dryRunTripPattern.firstMatch(message);
      if (dryRunTripMatch != null)
        params['dryRunTripTime'] = dryRunTripMatch.group(1) ?? 'N/A';

      final singlePhaseTripPattern = RegExp(
        r'(?:SP\s*Time\s*=|Single phase time updated:)\s*(\d{1,3})\s*Sec',
        caseSensitive: false,
      );

      final singlePhaseTripMatch = singlePhaseTripPattern.firstMatch(message);
      if (singlePhaseTripMatch != null)
        params['singlePhaseTripTime'] = singlePhaseTripMatch.group(1) ?? 'N/A';

      final maxRunTimePattern = RegExp(
        r'Max\s+ON\s+time\s*(?:updated:|=)\s*(\d{2}:\d{2}:\d{2})',
        caseSensitive: false,
      );

      final maxRunTimeMatch = maxRunTimePattern.firstMatch(message);
      if (maxRunTimeMatch != null)
        params['maxRunTime'] = maxRunTimeMatch.group(1) ?? '00:00:00';

      final dryRunRestartPattern = RegExp(
        r'(?:Dry\s+Run\s+restart\s+time\s+updated:|RS Time =)\s*(\d{2}:\d{2})\s*(?:HR:MM)?',
        caseSensitive: false,
      );

      final dryRunRestartMatch = dryRunRestartPattern.firstMatch(message);
      if (dryRunRestartMatch != null)
        params['dryRunRestartTime'] = dryRunRestartMatch.group(1) ?? '00:00';

      final feedbackDelayPattern = RegExp(
        r'Feed\s*back\s*Delay\s*=\s*(\d{1,2})\s*Sec',
        caseSensitive: false,
      );

      final feedbackDelayMatch = feedbackDelayPattern.firstMatch(message);
      if (feedbackDelayMatch != null)
        params['feedbackDelayTime'] = feedbackDelayMatch.group(1) ?? 'N/A';

      if (message.contains(RegExp(r'Initiated by:(\d+)'))) {
        final hostMatch = RegExp(
          r'Initiated\s+by:\s*(\d+)',
          caseSensitive: false,
        ).firstMatch(message);
        params['hostNumber'] = hostMatch?.group(1) ?? 'N/A';
      }

      print('SMS_PARSE: Parsed Parameters: $params');
      return params;
    } catch (e) {
      print('SMS_PARSE: Error parsing SMS: $e');
      return params;
    }
  }

  int? _getModeValue(String? mode) {
    switch (mode) {
      case 'manual':
        return 0;
      case 'auto':
      case 'auto start':
        return 1;
      case 'cyclic':
        return 2;
      case 'daily auto':
        return 3;
      case 'shift timer':
        return 4;
      default:
        return null;
    }
  }

  int _parseDurationToMillis(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hours = int.tryParse(parts.length > 0 ? parts[0] : '0') ?? 0;
      final minutes = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      final seconds = int.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0;
      return (hours * 3600 + minutes * 60 + seconds) * 1000;
    } catch (e) {
      print('DURATION_ERROR: Failed to parse duration: $timeStr');
      return 0;
    }
  }

  DateTime _calculateMotorOnTill(
    DateTime ts,
    String sinceTime,
    String targetTime,
    String mode,
  ) {
    try {
      final sinceMillis = _parseDurationToMillis(sinceTime);
      final targetMillis = _parseDurationToMillis(targetTime);

      if (mode.toLowerCase() == 'daily auto') {
        final remainingMillis = targetMillis - sinceMillis;
        if (remainingMillis > 0) {
          return ts.add(Duration(milliseconds: remainingMillis));
        }
      } else {
        return ts
            .subtract(Duration(milliseconds: sinceMillis))
            .add(Duration(milliseconds: targetMillis));
      }
      return ts;
    } catch (e) {
      print('CALCULATE_MOTOR_ON_TILL: Error: $e');
      return ts;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yy HH:mm:ss').format(date);
  }

  Map<String, dynamic> createCurrentValuesMap({
    required String id,
    required String lastPingAction,
    required String lastPingInitiator,
    required String lastPingTimestamp,
    required String lastSync,
    required int n,
    required int d,
    required bool motorState,
    required int selectedMode,
    required String cyclicOnTime,
    required String cyclicOffTime,
    required String dailyAutoTime,
    required String shiftTimerTime,
    required String countdownMode,
    required String countdownStatus,
    required String countdownSince,
    required String countdownTarget,
    required bool countdownDismissed,
    required String voltageRY,
    required String voltageYB,
    required String voltageBR,
    required String currentR,
    required String currentY,
    required String currentB,
    String? errorMessage,
  }) {
    return {
      'id': id,
      'lastPingAction': lastPingAction,
      'lastPingInitiator': lastPingInitiator,
      'lastPingTimestamp': lastPingTimestamp,
      'lastSync': lastSync,
      'n': n,
      'd': d,
      'motorState': motorState,
      'mode': selectedMode,
      'cyclicOnTime': cyclicOnTime,
      'cyclicOffTime': cyclicOffTime,
      'dailyAutoTime': dailyAutoTime,
      'shiftTimerTime': shiftTimerTime,
      'countdownMode': countdownMode,
      'countdownStatus': countdownStatus,
      'countdownSince': countdownSince,
      'countdownTarget': countdownTarget,
      'countdownDismissed': countdownDismissed,
      'voltageRY': voltageRY,
      'voltageYB': voltageYB,
      'voltageBR': voltageBR,
      'currentR': currentR,
      'currentY': currentY,
      'currentB': currentB,
      'error': errorMessage,
      // Initialize additional parameters that might come from SMS
      'lowVoltage': 'N/A',
      'highVoltage': 'N/A',
      'lowCurrent': 'N/A',
      'highCurrent': 'N/A',
      'overloadTripTime': 'N/A',
      'voltageTripTime': 'N/A',
      'dryRunTripTime': 'N/A',
      'singlePhaseTripTime': 'N/A',
      'maxRunTime': 'N/A',
      'dryRunRestartTime': 'N/A',
      'feedbackDelayTime': 'N/A',
      'phoneNumber1': 'N/A',
      'phoneNumber2': 'N/A',
      'phoneNumber3': 'N/A',
      'hostNumber': 'N/A',
    };
  }

}
