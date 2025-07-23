import 'package:NESmartConnect/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'add_dev.dart';
import 'dev_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
// import 'auth_wrapper.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  List<Map<String, String>> devices = []; // List to store devices added from add_sms_device.dart
  int _selectedIndex = 0; // Default to home screen

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add lifecycle observer
    _loadDevices(); // Load any saved devices on startup
  }

  @override
  void dispose() {
    _saveDevices(); // Save devices when the widget is disposed
    WidgetsBinding.instance.removeObserver(this); // Remove lifecycle observer
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _saveDevices(); // Save devices when app is paused or closed
    }
  }

  Future<void> _loadDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? devicesJson = prefs.getString('devices');
      print('Loaded devices JSON from SharedPreferences: $devicesJson');
      if (devicesJson != null && devicesJson.isNotEmpty) {
        final decoded = jsonDecode(devicesJson);
        print('Decoded devices: $decoded');
        setState(() {
          devices = List<Map<String, String>>.from(
            decoded.map((device) => Map<String, String>.from(device)),
          );
        });
        print('Devices after loading: $devices');
      } else {
        print('No devices found in SharedPreferences');
        setState(() {
          devices = [];
        });
      }
    } catch (e) {
      print('Error loading devices: $e');
      setState(() {
        devices = [];
      });
    }
  }

  Future<void> _saveDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      print('Saving devices: $devices');
      final devicesJson = jsonEncode(devices);
      print('Encoded devices JSON: $devicesJson');
      await prefs.setString('devices', devicesJson);
      print('Devices saved to SharedPreferences');
    } catch (e) {
      print('Error saving devices: $e');
    }
  }

Future<void> _handleLogout() async {
  final bool? confirmLogout = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 335,
        height: 220,
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
              Text(
                'Logout',
                style: TextStyle(
                  color: const Color(0xFF030100),
                  fontSize: 16,
                  fontFamily: 'Inter Display',
                  fontWeight: FontWeight.w600,
                  height: 1.50,
                ),
              ),
              Text(
                'Are you sure you want to logout?',
                style: TextStyle(
                  color: const Color(0xFF030100),
                  fontSize: 14,
                  fontFamily: 'Inter Display',
                  fontWeight: FontWeight.w400,
                  height: 1.57,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
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
                      onTap: () => Navigator.pop(context, true),
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
                            'Logout',
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
    ),
  );

  if (confirmLogout == true) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (route) => false,
      );
    }
  } else {
    // User cancelled logout, reset selected index to home
    setState(() {
      _selectedIndex = 0;
    });
  }
}

void _onItemTapped(int index) {
  if (index == 1) {
    showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddDev(
        onSave: (device) {
          setState(() {
            devices.add(device);
            _selectedIndex = 0; // Reset to Home
          });
          _saveDevices();
        },
        onCancel: () {
          setState(() {
            _selectedIndex = 0; // Reset to Home
          });
        },
      ),
    );
  } else if (index == 2) {
    _handleLogout();
  } else {
    setState(() {
      _selectedIndex = index;
    });
  }
}

Future<void> _confirmDeleteDevice(int index, Map<String, String> device) async {
  final bool? confirm = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 335,
        height: 220,
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
                      'Delete Device',
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
              Text(
                'Are you sure you want to delete "${device['name']}" (${device['number']})? This action cannot be undone.',
                style: TextStyle(
                  color: const Color(0xFF030100),
                  fontSize: 14,
                  fontFamily: 'Inter Display',
                  fontWeight: FontWeight.w400,
                  height: 1.57,
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
                        Navigator.pop(context, true); // Delete returns true
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
                            'Delete',
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
    ),
  );

  if (confirm == true) {
    // Remove the device from the list
    setState(() {
      devices.removeAt(index);
    });

    // Save the updated devices list to SharedPreferences
    await _saveDevices();

    // Delete device-specific data from SharedPreferences
    await _deleteDeviceData(device['number']!);

    // Show a confirmation message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Device "${device['name']}" deleted')),
      );
    }
  }
}

  Future<void> _deleteDeviceData(String deviceNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Get all keys in SharedPreferences
      final allKeys = prefs.getKeys();

      // Find keys that start with "device_${deviceNumber}_"
      final deviceKeys = allKeys.where((key) => key.startsWith('device_${deviceNumber}_')).toList();

      // Remove each key associated with this device
      for (final key in deviceKeys) {
        await prefs.remove(key);
        print('Deleted key: $key');
      }

      print('Deleted device-specific data for device number: $deviceNumber');
    } catch (e) {
      print('Error deleting device data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white, // Background for the whole screen
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Header (Replaces AppBar)
            Container(
              height: 100,
              padding: const EdgeInsets.only(left: 16, right: 8, top: 60),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Devices',
                    style: TextStyle(
                      color: Color(0xFF030100),
                      fontSize: 24,
                      fontFamily: 'Inter Display',
                      fontWeight: FontWeight.w600,
                      height: 1.33,
                    ),
                  ),
                  if (!devices.isEmpty)
                    Opacity(
                      opacity: 0.80,
                      child: GestureDetector(
                        onTap: () {
                          showModalBottomSheet<Map<String, String>>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => AddDev(
                              onSave: (device) {
                                setState(() {
                                  devices.add(device);
                                });
                                _saveDevices();
                              },
                              onCancel: () {},
                            ),
                          );
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          padding: const EdgeInsets.all(10),
                          decoration: ShapeDecoration(
                            color: const Color(0xFF800214),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          child: SvgPicture.asset(
                            'assets/images/add_new.svg',
                            width: 20,
                            height: 20,
                            colorFilter: const ColorFilter.mode(Color.fromARGB(255, 255, 255, 255), BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: devices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                  'assets/images/home_empty.svg',
                  width: 100,
                ),
                            const SizedBox(height: 8),
                            const SizedBox(
                              width: 215,
                              child: Text(
                                'Add Your First Device',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF030100),
                                  fontSize: 16,
                                  fontFamily: 'Inter Display',
                                  fontWeight: FontWeight.w600,
                                  height: 1.50,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const SizedBox(
                              width: 260,
                              child: Text(
                                'Get started by setting up\nyour device now!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF090A0A),
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                  height: 1.43,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () {
                                showModalBottomSheet<Map<String, String>>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => AddDev(
                                    onSave: (device) {
                                      setState(() {
                                        devices.add(device);
                                      });
                                      _saveDevices();
                                    },
                                    onCancel: () {},
                                  ),
                                );
                              },
                              child: Container(
                                width: 170,
                                height: 48,
                                decoration: ShapeDecoration(
                                  color: const Color(0xFF800214),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(48),
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Add new device',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: 'Inter Display',
                                      fontWeight: FontWeight.w500,
                                      height: 1.50,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
  itemCount: devices.length,
  itemBuilder: (context, index) {
    final device = devices[index];
    return Dismissible(
      key: Key(device['number']!), // Unique key for each device
      direction: DismissDirection.endToStart, // Swipe left only
      confirmDismiss: (direction) async {
        // Trigger the delete confirmation dialog
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              width: 335,
              height: 220,
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
                            'Delete Device',
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
                    Text(
                      'Are you sure you want to delete "${device['name']}" (${device['number']})? This action cannot be undone.',
                      style: TextStyle(
                        color: const Color(0xFF030100),
                        fontSize: 14,
                        fontFamily: 'Inter Display',
                        fontWeight: FontWeight.w400,
                        height: 1.57,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context, false); // Cancel
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
                              Navigator.pop(context, true); // Confirm delete
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
                                  'Delete',
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
          ),
        );

        if (confirm == true) {
          setState(() {
            devices.removeAt(index);
          });
          await _saveDevices();
          await _deleteDeviceData(device['number']!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Device "${device['name']}" deleted')),
            );
          }
          return true; // Allow dismissal
        }
        return false; // Cancel dismissal
      },
      background: Container(), // Empty primary background
      secondaryBackground: Container(
        height: 100,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: ShapeDecoration(
          color: const Color.fromARGB(255, 189, 19, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 16),
        child: Icon(
          Icons.delete_outline, // Outlined delete icon
          color: Colors.white,
          size: 32,
        ),
      ),
child: GestureDetector(
  onTap: () async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DevScreen(
          deviceName: device['name']!,
          deviceNumber: device['number']!,
          deviceDesc: device['desc'] ?? 'No description',
          deviceCont: device['controlNumber']!,
        ),
      ),
    );
    print('HomeView: Received result from DevScreen: $result');
    if (result != null && result is Map) {
      setState(() {
        // Update the device in the devices list
        final index = devices.indexWhere((d) => d['number'] == device['number']);
        if (index != -1) {
          devices[index] = {
            'name': result['name']!,
            'number': result['number']!,
            'controlNumber': result['controlNumber']!,
            'desc': result['desc']!,
          };
          print('HomeView: Updated devices[$index]: ${devices[index]}');
        }
      });
      // Save the updated devices list
      await _saveDevices();
      // Sync individual SharedPreferences keys for Settings
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('deviceName_${device['number']}', result['name']!);
      await prefs.setString('deviceDesc_${device['number']}', result['desc']!);
      print('HomeView: Updated device ${result['name']} and saved to SharedPreferences');
    }
  },
  child: Container(
    height: 100,
    margin: const EdgeInsets.symmetric(vertical: 8.0),
    decoration: ShapeDecoration(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      shadows: const [
        BoxShadow(
          color: Color(0x19000000),
          blurRadius: 20,
          offset: Offset(0, 2),
          spreadRadius: 0,
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 12,
            child: Text(
              device['name']!,
              style: const TextStyle(
                color: Color(0xFF2E2E2E),
                fontSize: 16,
                fontFamily: 'Inter Display',
                fontWeight: FontWeight.w600,
                height: 1.50,
                letterSpacing: -0.32,
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 40,
            child: Text(
              device['desc'] ?? 'No description',
              style: const TextStyle(
                color: Color(0xFF8C8885),
                fontSize: 14,
                fontFamily: 'Inter Display',
                fontWeight: FontWeight.w400,
                height: 1.57,
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 66,
            child: Text(
              device['number']!,
              style: const TextStyle(
                color: Color(0xFF8C8885),
                fontSize: 14,
                fontFamily: 'Inter Display',
                fontWeight: FontWeight.w400,
                height: 1.57,
              ),
            ),
          ),
          Positioned(
            right: -5,
            bottom: -5,
            child: SvgPicture.asset(
              'assets/images/home_empty.svg',
              width: 60,
              height: 60,
            ),
          ),
        ],
      ),
    ),
  ),
),
    );
  },
),
              ),
            ),
          ],
        ),
      ),
bottomNavigationBar: Theme(
  data: Theme.of(context).copyWith(
    splashFactory: InkRipple.splashFactory, // Rectangular ripple effect
    splashColor: Colors.grey.withOpacity(0.3), // Subtle grey highlight
    highlightColor: Colors.transparent, // Prevents full-bar highlight
  ),
  child:BottomNavigationBar(
  items: [
    BottomNavigationBarItem(
      icon: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: _selectedIndex == 0
              ? const Border(top: BorderSide(color: Colors.black, width: 2))
              : null,
        ),
        padding: const EdgeInsets.only(top: 4),
        child: SvgPicture.asset(
          'assets/images/home.svg',
          colorFilter: ColorFilter.mode(
            _selectedIndex == 0 ? Colors.black : Colors.grey,
            BlendMode.srcIn,
          ),
          width: 24,
          height: 24,
        ),
      ),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(),
        padding: const EdgeInsets.only(top: 4),
        child: SvgPicture.asset(
          'assets/images/add_new.svg',
          colorFilter: ColorFilter.mode(
            _selectedIndex == 1 ? Colors.black : Colors.grey,
            BlendMode.srcIn,
          ),
          width: 24,
          height: 24,
        ),
      ),
      label: 'Add New Device',
    ),
    BottomNavigationBarItem(
      icon: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: _selectedIndex == 2
              ? const Border(top: BorderSide(color: Colors.black, width: 2))
              : null,
        ),
        padding: const EdgeInsets.only(top: 4),
        child: Icon(
          Icons.logout,
          color: _selectedIndex == 2 ? Colors.black : Colors.grey,
        ),
      ),
      label: 'Logout',
    ),
  ],
  currentIndex: _selectedIndex,
  selectedItemColor: const Color.fromARGB(255, 0, 0, 0),
  unselectedItemColor: Colors.grey,
  selectedLabelStyle: const TextStyle(
    fontWeight: FontWeight.bold,
  ),
  unselectedLabelStyle: const TextStyle(
    fontWeight: FontWeight.normal,
  ),
  onTap: _onItemTapped,
  backgroundColor: Colors.white,
),)
    );
  }
}