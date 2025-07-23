import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
// Import API service
import 'services/api_service.dart';

class AddDev extends StatefulWidget {
  final VoidCallback? onCancel;
  final Function(Map<String, String>)? onSave;

  const AddDev({super.key, this.onCancel, this.onSave});

  @override
  State<AddDev> createState() => _AddDevState();
}

class _AddDevState extends State<AddDev> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _controlPhoneController = TextEditingController(); // New controller
  String _countryCode = '+91';
  String _controlCountryCode = '+91'; // New country code for controlling number
  String? _phoneError;
  String? _aliasError;
  String? _controlPhoneError; // New error for controlling number
  bool _isSubmitting = false;

// Initialize API service
final apiService = APIService();

@override
void dispose() {
  _phoneController.dispose();
  _aliasController.dispose();
  _descController.dispose();
  _controlPhoneController.dispose();
  super.dispose();
}

void _saveAndNavigate() {
  bool isControlPhoneValid = _controlPhoneController.text.isNotEmpty && _controlPhoneController.text.length >= 10;
  bool isPhoneValid = _phoneController.text.isNotEmpty && _phoneController.text.length >= 10;
  bool isAliasValid = _aliasController.text.isNotEmpty;

  setState(() {
    _controlPhoneError = isControlPhoneValid ? null : '${_controlPhoneController.text.length}/10';
    _phoneError = isPhoneValid ? null : '${_phoneController.text.length}/10';
    _aliasError = isAliasValid ? null : 'Alias cannot be empty';
  });

  if (!isControlPhoneValid || !isPhoneValid || !isAliasValid) {
    return;
  }

  String fullControlNumber = _controlCountryCode.startsWith('+')
      ? _controlCountryCode + _controlPhoneController.text
      : '$_controlCountryCode${_controlPhoneController.text}';
  String fullPhoneNumber = _countryCode.startsWith('+')
      ? _countryCode + _phoneController.text
      : '$_countryCode${_phoneController.text}';
  final newDevice = {
    'name': _aliasController.text,
    'number': fullPhoneNumber,
    'controlNumber': fullControlNumber,
    'desc': _descController.text.isEmpty ? 'No description' : _descController.text,
  };

  widget.onSave?.call(newDevice);
  Navigator.pop(context, newDevice);
}

Future<void> _registerDevice() async {
  if (_aliasController.text.trim().isEmpty || 
      _phoneController.text.trim().isEmpty) {
    _showSnackBar('Device alias and phone number are required');
    return;
  }

  if (!RegExp(r'^\d{10}$').hasMatch(_phoneController.text)) {
    _showSnackBar('Enter a valid 10-digit phone number');
    return;
  }

  setState(() {
    _isSubmitting = true;
  });

  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('u_id');
    String? userPhone = prefs.getString('acc_number');

    if (userId == null || userPhone == null) {
      _showSnackBar('User session invalid. Please log in again.');
      return;
    }

    // Using APIService to register device - returns a Map, not an HTTP response
    final result = await apiService.addDevice(
      userPhone, // control_phone
      _phoneController.text.trim(), // device_phone
      _aliasController.text.trim(), // device_name
    );

    print('Device registration response: $result');

    // Check the errFlag value directly from the Map
    if (result['errFlag'] == 0) {
      _showSnackBar('Device added successfully!');

      // Add the device to the local list as well
      if (widget.onSave != null) {
        widget.onSave!({
          'deviceName': _aliasController.text.trim(),
          'deviceNumber': _phoneController.text.trim(),
          'deviceCont': userPhone,
        });
      }

      Navigator.of(context).pop(); // Go back after successful registration
    } else {
      _showSnackBar('Failed to add device: ${result['message']}');
    }
  } catch (e) {
    print('Error registering device: $e');
    _showSnackBar('Error: $e');
  } finally {
    setState(() {
      _isSubmitting = false;
    });
  }
}

void _showSnackBar(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: Duration(seconds: 2),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 20.0;

    return Container(
      width: double.infinity,
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, // Adjust for keyboard
        ),
        child: SizedBox(
          height: 600,
          child: Stack(
  children: [
    Positioned(
      left: horizontalPadding,
      right: horizontalPadding,
      top: 24,
      child: SizedBox(
        width: screenWidth - 2 * horizontalPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add new device',
                  style: TextStyle(
                    color: Color(0xFF030100),
                    fontSize: 24,
                    fontFamily: 'Inter Display',
                    fontWeight: FontWeight.w600,
                    height: 1.33,
                  ),
                ),

                GestureDetector(
  onTap: () {
    widget.onCancel?.call();
    Navigator.pop(context);
  },
  child: Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: Colors.white, // Add background to make shadow visible
      shape: BoxShape.circle, // Ensure circular shape
      boxShadow: [
        BoxShadow(
          color: Color(0x40000000), // Increase opacity (0x26 -> 0x40)
          blurRadius: 20,
          offset: Offset(0, 4),
          spreadRadius: 0,
        ),
      ],
    ),
    child: Icon(
      Icons.close,
      color: Color.fromARGB(255, 0, 0, 0),
      size: 20,
    ),
  ),
),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Enter details to add your device',
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
          ],
        ),
      ),
    ),
    Positioned(
      left: horizontalPadding,
      right: horizontalPadding,
      top: 108,
      child: SizedBox(
        width: screenWidth - 2 * horizontalPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Controlling Phone Number',
              style: TextStyle(
                color: Color(0xFF716D69),
                fontSize: 14,
                fontFamily: 'Inter Display',
                fontWeight: FontWeight.w400,
                height: 1.57,
              ),
            ),
            const SizedBox(height: 8),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: double.infinity,
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
                  child: IntlPhoneField(
                    controller: _controlPhoneController,
                    decoration: InputDecoration(
                      hintText: 'Enter controlling phone number',
                      hintStyle: TextStyle(
                        color: Color(0xFFC4C2C0),
                        fontSize: 16,
                        fontFamily: 'Inter Display',
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 18,
                      ),
                    ),
                    textAlignVertical: TextAlignVertical.center,
                    initialCountryCode: 'IN',
                    showCountryFlag: true,
                    disableLengthCheck: true,
                    showDropdownIcon: true,
                    onCountryChanged: (country) {
                      setState(() {
                        _controlCountryCode = country.dialCode;
                        _controlPhoneError = null;
                      });
                    },
                    flagsButtonPadding: EdgeInsets.only(left: 8),
                    onChanged: (phone) {
                      setState(() {
                        if (phone.number.isNotEmpty && phone.number.length < 10) {
                          _controlPhoneError = '${phone.number.length}/10';
                        } else {
                          _controlPhoneError = null;
                        }
                      });
                    },
                  ),
                ),
                if (_controlPhoneError != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 4),
                    child: Text(
                      _controlPhoneError!,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontFamily: 'Inter Display',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
    Positioned(
      left: horizontalPadding,
      right: horizontalPadding,
      top: 206,
      child: SizedBox(
        width: screenWidth - 2 * horizontalPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Phone Number',
              style: TextStyle(
                color: Color(0xFF716D69),
                fontSize: 14,
                fontFamily: 'Inter Display',
                fontWeight: FontWeight.w400,
                height: 1.57,
              ),
            ),
            const SizedBox(height: 8),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: double.infinity,
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
                  child: IntlPhoneField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      hintText: 'Enter device phone number',
                      hintStyle: TextStyle(
                        color: Color(0xFFC4C2C0),
                        fontSize: 16,
                        fontFamily: 'Inter Display',
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 18,
                      ),
                    ),
                    textAlignVertical: TextAlignVertical.center,
                    initialCountryCode: 'IN',
                    showCountryFlag: true,
                    showDropdownIcon: true,
                    disableLengthCheck: true,
                    onCountryChanged: (country) {
                      setState(() {
                        _countryCode = country.dialCode;
                        _phoneError = null;
                      });
                    },
                    flagsButtonPadding: EdgeInsets.only(left: 8),
                    onChanged: (phone) {
                      setState(() {
                        if (phone.number.isNotEmpty && phone.number.length < 10) {
                          _phoneError = '${phone.number.length}/10';
                        } else {
                          _phoneError = null;
                        }
                      });
                    },
                  ),
                ),
                if (_phoneError != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 4),
                    child: Text(
                      _phoneError!,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontFamily: 'Inter Display',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
    Positioned(
      left: horizontalPadding,
      right: horizontalPadding,
      top: 304,
      child: SizedBox(
        width: screenWidth - 2 * horizontalPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device alias',
              style: TextStyle(
                color: Color(0xFF716D69),
                fontSize: 14,
                fontFamily: 'Inter Display',
                fontWeight: FontWeight.w400,
                height: 1.57,
              ),
            ),
            const SizedBox(height: 8),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: double.infinity,
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
                    controller: _aliasController,
                    decoration: InputDecoration(
                      hintText: 'Enter device alias',
                      hintStyle: TextStyle(
                        color: Color(0xFFC4C2C0),
                        fontSize: 16,
                        fontFamily: 'Inter Display',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
                if (_aliasError != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 4),
                    child: Text(
                      _aliasError!,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontFamily: 'Inter Display',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
    Positioned(
      left: horizontalPadding,
      right: horizontalPadding,
      top: 402,
      child: SizedBox(
        width: screenWidth - 2 * horizontalPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device description',
              style: TextStyle(
                color: Color(0xFF716D69),
                fontSize: 14,
                fontFamily: 'Inter Display',
                fontWeight: FontWeight.w400,
                height: 1.57,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
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
                controller: _descController,
                decoration: InputDecoration(
                  hintText: 'Enter device description',
                  hintStyle: TextStyle(
                    color: Color(0xFFC4C2C0),
                    fontSize: 16,
                    fontFamily: 'Inter Display',
                    fontWeight: FontWeight.w400,
                    height: 1.50,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    Positioned(
      left: horizontalPadding,
      right: horizontalPadding,
      top: 518,
      child: GestureDetector(
        onTap: _saveAndNavigate,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: ShapeDecoration(
            color: const Color(0xFF800214),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(200),
            ),
          ),
          child: const Center(
            child: Text(
              'Add device',
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
        ),
      ),
    );
  }
}