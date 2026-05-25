import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:async';

const String BASE_URL = 'http://178.104.196.214:5005';

const kGreen = Color(0xFF2E9E6B);
const kGreenLight = Color(0xFF4CAF80);
const kOrange = Color(0xFFF07C2A);
const kDark = Color(0xFF1A2B22);
const kBg = Color(0xFFF4F6F4);

void main() {
  runApp(const VelocarApp());
}

class VelocarApp extends StatelessWidget {
  const VelocarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Velocar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kGreen, primary: kGreen),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

Future<Map<String, String>> _authHeaders() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('session_token') ?? '';
  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };
}

// ==================== SPLASH ====================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token');
    // შევამოწმოთ აქტიური trip არის თუ არა
    final tripId = prefs.getInt('active_trip_id');
    final deviceId = prefs.getString('active_device_id');
    if (mounted) {
      if (tripId != null && deviceId != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ActiveRideScreen(tripId: tripId, deviceId: deviceId),
        ));
      } else if (token != null && token.isNotEmpty) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kGreen, kOrange], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.electric_scooter, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text('VELOCAR', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 4)),
            const SizedBox(height: 6),
            Text('Shared Electric Fleet', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, letterSpacing: 1)),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: kGreen),
          ],
        ),
      ),
    );
  }
}

// ==================== LOGIN ====================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';
  bool _obscure = true;

  Future<void> _login() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': _userCtrl.text.trim(), 'password': _passCtrl.text}),
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_token', data['token'] ?? '');
        await prefs.setString('username', data['user']?['username'] ?? _userCtrl.text);
        await prefs.setString('role', data['user']?['role'] ?? 'client');
        await prefs.setInt('user_id', data['user']?['id'] ?? 1);
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
      } else {
        setState(() { _error = data['error'] ?? 'შეცდომა'; });
      }
    } catch (e) {
      setState(() { _error = 'სერვერთან კავშირის შეცდომა'; });
    }
    setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kGreen, kOrange]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.electric_scooter, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text('VELOCAR', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 3)),
              const SizedBox(height: 4),
              Text('შედი შენს ანგარიშში', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
              const SizedBox(height: 40),
              _buildField(_userCtrl, 'მომხმარებელი', Icons.person_outline),
              const SizedBox(height: 16),
              _buildField(_passCtrl, 'პაროლი', Icons.lock_outline, obscure: _obscure, suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
                onPressed: () => setState(() => _obscure = !_obscure),
              )),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ]),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('შესვლა', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint, IconData icon, {bool obscure = false, Widget? suffix}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
        prefixIcon: Icon(icon, color: kGreen, size: 22),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: kGreen, width: 1.5)),
      ),
    );
  }
}

// ==================== MAIN SCREEN ====================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const MapHomeScreen(),
      const TripsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_tab],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          backgroundColor: Colors.white,
          selectedItemColor: kGreen,
          unselectedItemColor: Colors.grey[400],
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'რუკა'),
            BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'მოგზაურობები'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'პროფილი'),
          ],
        ),
      ),
    );
  }
}

// ==================== MAP HOME ====================
class MapHomeScreen extends StatefulWidget {
  const MapHomeScreen({super.key});
  @override
  State<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends State<MapHomeScreen> {
  List _scooters = [];
  List _geofences = [];
  LatLng _center = const LatLng(41.6938, 44.8015);
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() => _center = LatLng(pos.latitude, pos.longitude));
      _mapController.move(_center, 15);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    try {
      final headers = await _authHeaders();
      // სქროლები
      final res1 = await http.get(Uri.parse('$BASE_URL/api/scooters'), headers: headers);
      final data1 = jsonDecode(res1.body);
      if (data1 is List) setState(() => _scooters = data1);

      // გეოზონები
      final res2 = await http.get(Uri.parse('$BASE_URL/api/geofences'), headers: headers);
      final data2 = jsonDecode(res2.body);
      if (data2 is List) setState(() => _geofences = data2);
    } catch (_) {}
  }

  // გეოზონის polygon წერტილები
  List<LatLng> _parseGeofence(dynamic geofence) {
    try {
      if (geofence['coordinates'] != null) {
        final coords = jsonDecode(geofence['coordinates'].toString());
        if (coords is List) {
          return coords.map<LatLng>((c) => LatLng(
            double.parse(c[1].toString()),
            double.parse(c[0].toString()),
          )).toList();
        }
      }
      // Default — თბილისის ზონა
      final lat = double.tryParse(geofence['latitude']?.toString() ?? '') ?? 41.6938;
      final lng = double.tryParse(geofence['longitude']?.toString() ?? '') ?? 44.8015;
      final r = 0.01;
      return [
        LatLng(lat + r, lng - r),
        LatLng(lat + r, lng + r),
        LatLng(lat - r, lng + r),
        LatLng(lat - r, lng - r),
      ];
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _center, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.velocar.app',
              ),
              // გეოზონები
              PolygonLayer(
                polygons: _geofences.map((g) {
                  final points = _parseGeofence(g);
                  if (points.isEmpty) return null;
                  return Polygon(
                    points: points,
                    color: kGreen.withOpacity(0.15),
                    borderColor: kGreen,
                    borderStrokeWidth: 2,
                  );
                }).whereType<Polygon>().toList(),
              ),
              // სქროლების მარკერები
              MarkerLayer(
                markers: _scooters
                    .where((s) => s['latitude'] != null && s['longitude'] != null)
                    .map((s) {
                  final available = s['status'] == 'available';
                  return Marker(
                    point: LatLng(
                      double.parse(s['latitude'].toString()),
                      double.parse(s['longitude'].toString()),
                    ),
                    width: 56, height: 56,
                    child: GestureDetector(
                      onTap: () => _showScooterInfo(context, s),
                      child: Column(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: available ? kGreen : Colors.grey,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
                            ),
                            child: const Icon(Icons.electric_scooter, color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Header
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kDark, kDark.withOpacity(0)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('VELOCAR', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                      onPressed: _loadData,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ქვედა ღილაკები
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.electric_scooter, color: kGreen, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${_scooters.where((s) => s['status'] == 'available').length} სქროლი ხელმისაწვდომია',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: kDark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 58,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
                    label: const Text('სქროლის სკანირება', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScanScreen())),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showScooterInfo(BuildContext context, Map s) {
    final available = s['status'] == 'available';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: available ? kGreen.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.electric_scooter, color: available ? kGreen : Colors.grey, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['device_id'] ?? '—', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kDark)),
                  Text(s['company_name'] ?? '—', style: TextStyle(color: Colors.grey[600])),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: available ? kGreen.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  available ? 'ხელმისაწვდომი' : 'დაკავებული',
                  style: TextStyle(color: available ? kGreen : Colors.red, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              _infoChip(Icons.battery_charging_full, '${s['battery'] ?? 0}%', kGreen),
              const SizedBox(width: 8),
              _infoChip(Icons.location_on, s['zone_name'] ?? 'ზონა', kOrange),
              const SizedBox(width: 8),
              _infoChip(Icons.attach_money, '₾0.15/წთ', kDark),
            ]),
            const SizedBox(height: 20),
            if (available)
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  label: const Text('QR სკანირება', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScanScreen()));
                  },
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.block, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('სქროლი ამჟამად დაკავებულია', style: TextStyle(color: Colors.red)),
                ]),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ==================== QR SCAN ====================
class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});
  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  bool _scanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final value = capture.barcodes.first.rawValue ?? '';
    if (value.contains('device_id=')) {
      setState(() => _scanned = true);
      final deviceId = value.split('device_id=').last;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ScooterDetailScreen(deviceId: deviceId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Container(color: Colors.black.withOpacity(0.5)),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('სქროლის QR კოდი', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('სქროლთან მიახლოვდი და დაასკანირე', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                const SizedBox(height: 32),
                Stack(
                  children: [
                    Container(
                      width: 240, height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(color: kGreen, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    Positioned(top: 3, left: 3, right: 3, bottom: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: MobileScanner(onDetect: _onDetect),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.qr_code, color: Colors.white54, size: 16),
                    const SizedBox(width: 6),
                    Text('QR კოდი მოათავსე ჩარჩოში', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                  ]),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8, left: 16,
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== SCOOTER DETAIL ====================
class ScooterDetailScreen extends StatefulWidget {
  final String deviceId;
  const ScooterDetailScreen({super.key, required this.deviceId});
  @override
  State<ScooterDetailScreen> createState() => _ScooterDetailScreenState();
}

class _ScooterDetailScreenState extends State<ScooterDetailScreen> {
  Map<String, dynamic>? _scooter;
  bool _loading = true;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(Uri.parse('$BASE_URL/api/scooters'), headers: headers);
      final data = jsonDecode(res.body);
      if (data is List) {
        final s = data.firstWhere((s) => s['device_id'] == widget.deviceId, orElse: () => null);
        setState(() { _scooter = s; _loading = false; });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _startRide() async {
    setState(() => _starting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 1;
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse('$BASE_URL/api/trips/start'),
        headers: headers,
        body: jsonEncode({'device_id': widget.deviceId, 'user_id': userId}),
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        await prefs.setInt('active_trip_id', data['trip_id']);
        await prefs.setString('active_device_id', widget.deviceId);
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => ActiveRideScreen(tripId: data['trip_id'], deviceId: widget.deviceId)),
            (_) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'შეცდომა')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('სერვერთან კავშირის შეცდომა')));
    }
    setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    final available = _scooter?['status'] == 'available';

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kDark,
        title: Text('სქროლი ${widget.deviceId}', style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : _scooter == null
          ? const Center(child: Text('სქროლი ვერ მოიძებნა'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)]),
              child: Column(
                children: [
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      color: available ? kGreen.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.electric_scooter, size: 52, color: available ? kGreen : Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Text(widget.deviceId, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kDark)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: available ? kGreen.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      available ? '✅ ხელმისაწვდომია' : '❌ დაკავებულია',
                      style: TextStyle(color: available ? kGreen : Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _infoRow(Icons.business, 'კომპანია', _scooter!['company_name'] ?? '—'),
                  _infoRow(Icons.battery_charging_full, 'ბატარეა', '${_scooter!['battery'] ?? 0}%'),
                  _infoRow(Icons.location_on, 'ზონა', _scooter!['zone_name'] ?? '—'),
                  _infoRow(Icons.attach_money, 'ტარიფი', '₾0.15 / წუთი'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (available)
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton.icon(
                  icon: _starting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.lock_open, color: Colors.white),
                  label: Text(_starting ? 'სქროლი იხსნება...' : 'გაქირავების დაწყება', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _starting ? null : _startRide,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block, color: Colors.red),
                    SizedBox(width: 8),
                    Text('სქროლი ხელმისაწვდომი არ არის', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: kGreen, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: kDark)),
        ],
      ),
    );
  }
}

// ==================== ACTIVE RIDE ====================
class ActiveRideScreen extends StatefulWidget {
  final int tripId;
  final String deviceId;
  const ActiveRideScreen({super.key, required this.tripId, required this.deviceId});
  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  int _seconds = 0;
  Timer? _timer;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeStr {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _cost => (_seconds / 60) * 0.15;

  Future<void> _endRide() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('გაქირავების დასრულება'),
        content: Text('დრო: $_timeStr\nღირებულება: ₾${_cost.toStringAsFixed(2)}\n\nდარწმუნებული ხარ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('გაგრძელება')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('დასრულება', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _ending = true);
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse('$BASE_URL/api/trips/end'),
        headers: headers,
        body: jsonEncode({'trip_id': widget.tripId, 'device_id': widget.deviceId}),
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('active_trip_id');
        await prefs.remove('active_device_id');
        _timer?.cancel();
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(children: [Icon(Icons.check_circle, color: kGreen), SizedBox(width: 8), Text('გაქირავება დასრულდა')]),
              content: Text('დრო: ${data['minutes']} წუთი\nგადახდილი: ₾${data['amount']}'),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainScreen()), (_) => false);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kGreen),
                  child: const Text('დახურვა', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('შეცდომა — სცადე ახლიდან')));
    }
    setState(() => _ending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // სქროლის ანიმაცია
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: kGreen.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: kGreen, width: 2),
                ),
                child: const Icon(Icons.electric_scooter, size: 64, color: kGreen),
              ),
              const SizedBox(height: 24),
              const Text('გაქირავება მიმდინარეობს', style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 8),
              Text(widget.deviceId, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),

              // ტაიმერი
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Text(_timeStr, style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold, letterSpacing: 4, fontFeatures: [FontFeature.tabularFigures()])),
                    const SizedBox(height: 8),
                    const Text('წუთი : წამი', style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ღირებულება
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kGreen.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('მიმდინარე ღირებულება', style: TextStyle(color: Colors.white70)),
                    Text('₾${_cost.toStringAsFixed(2)}', style: const TextStyle(color: kGreen, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ტარიფი
              Text('₾0.15 / წუთი', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),

              const Spacer(),

              // დასრულების ღილაკი
              SizedBox(
                width: double.infinity, height: 58,
                child: ElevatedButton.icon(
                  icon: _ending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.stop_circle, color: Colors.white, size: 24),
                  label: Text(_ending ? 'მუშავდება...' : 'გაქირავების დასრულება', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _ending ? null : _endRide,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== PAYMENT ====================
class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> scooter;
  const PaymentScreen({super.key, required this.scooter});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _loading = false;
  String _savedCardLast4 = '';
  int _minutes = 30;

  @override
  void initState() {
    super.initState();
    _loadCard();
  }

  Future<void> _loadCard() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _savedCardLast4 = prefs.getString('card_last4') ?? '');
  }

  double get _total => _minutes * 0.15;

  Future<void> _pay() async {
    if (_savedCardLast4.isEmpty) {
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('ბარათი არ არის'),
        content: const Text('გადახდისთვის საჭიროა ბარათის მიბმა'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('გაუქმება')),
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const CardScreen())); },
            child: const Text('ბარათის დამატება', style: TextStyle(color: kGreen)),
          ),
        ],
      ));
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _loading = false);
      showDialog(context: context, builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.check_circle, color: kGreen), SizedBox(width: 8), Text('გადახდა წარმატებული')]),
        content: Text('სქროლი ${widget.scooter['device_id']}\nდრო: $_minutes წუთი\nთანხა: ₾${_total.toStringAsFixed(2)}\nბარათი: •••• $_savedCardLast4'),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); Navigator.pop(context); },
            child: const Text('დახურვა', style: TextStyle(color: kGreen)),
          ),
        ],
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kDark,
        title: const Text('გადახდა', style: TextStyle(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('სქროლის ინფო', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kDark)),
                  const SizedBox(height: 12),
                  _row('სქროლი', widget.scooter['device_id'] ?? ''),
                  _row('კომპანია', widget.scooter['company_name'] ?? ''),
                  _row('ტარიფი', '₾0.15 / წუთი'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('გამოყენების დრო', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kDark)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _timeBtn(Icons.remove, () { if (_minutes > 5) setState(() => _minutes -= 5); }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text('$_minutes წთ', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kDark)),
                      ),
                      _timeBtn(Icons.add, () => setState(() => _minutes += 5)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: kGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('სულ:', style: TextStyle(fontWeight: FontWeight.w600, color: kDark)),
                        Text('₾${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kGreen)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_savedCardLast4.isEmpty)
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CardScreen())),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kOrange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kOrange.withOpacity(0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.add_card, color: kOrange),
                    SizedBox(width: 12),
                    Expanded(child: Text('ბარათი მიაბი გადახდისთვის', style: TextStyle(color: kOrange, fontWeight: FontWeight.w600))),
                    Icon(Icons.arrow_forward_ios, color: kOrange, size: 16),
                  ]),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                child: Row(children: [
                  const Icon(Icons.credit_card, color: kGreen),
                  const SizedBox(width: 12),
                  Text('•••• •••• •••• $_savedCardLast4', style: const TextStyle(fontWeight: FontWeight.w600, color: kDark)),
                  const Spacer(),
                  const Icon(Icons.check_circle, color: kGreen, size: 20),
                ]),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _pay,
                style: ElevatedButton.styleFrom(backgroundColor: kGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('გადახდა ₾${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Text(l, style: TextStyle(color: Colors.grey[600])),
      const Spacer(),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w600, color: kDark)),
    ]),
  );

  Widget _timeBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: kGreen.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: kGreen),
    ),
  );
}

// ==================== CARD SCREEN ====================
class CardScreen extends StatefulWidget {
  const CardScreen({super.key});
  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  final _numberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _hasSaved = false;
  String _last4 = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final l = prefs.getString('card_last4') ?? '';
    final n = prefs.getString('card_name') ?? '';
    setState(() { _hasSaved = l.isNotEmpty; _last4 = l; });
    if (n.isNotEmpty) _nameCtrl.text = n;
  }

  Future<void> _save() async {
    final num = _numberCtrl.text.replaceAll(' ', '');
    if (num.length < 16) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ბარათის ნომერი არასწორია')));
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    final l = num.substring(num.length - 4);
    await prefs.setString('card_last4', l);
    await prefs.setString('card_name', _nameCtrl.text);
    setState(() { _hasSaved = true; _last4 = l; _loading = false; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ ბარათი დაემატა'), backgroundColor: kGreen),
    );
  }

  Future<void> _remove() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('card_last4');
    await prefs.remove('card_name');
    setState(() { _hasSaved = false; _last4 = ''; });
    _numberCtrl.clear(); _expiryCtrl.clear(); _cvvCtrl.clear(); _nameCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kDark,
        title: const Text('ბარათის მართვა', style: TextStyle(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _hasSaved ? Column(children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kDark, Color(0xFF2D4A38)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Velocar Card', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const Icon(Icons.credit_card, color: kGreen, size: 32),
              ]),
              const Spacer(),
              Text('•••• •••• •••• $_last4', style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 3, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_nameCtrl.text.isEmpty ? 'ბარათის მფლობელი' : _nameCtrl.text.toUpperCase(),
                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('ბარათის წაშლა', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _remove,
            ),
          ),
        ]) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ახალი ბარათის დამატება', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kDark)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Column(children: [
              _cField(_nameCtrl, 'სახელი გვარი', 'GIORGI BERIDZE', Icons.person_outline),
              const SizedBox(height: 14),
              _cField(_numberCtrl, 'ბარათის ნომერი', '0000 0000 0000 0000', Icons.credit_card, type: TextInputType.number, max: 19),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _cField(_expiryCtrl, 'ვადა', 'MM/YY', Icons.calendar_today, max: 5)),
                const SizedBox(width: 14),
                Expanded(child: _cField(_cvvCtrl, 'CVV', '•••', Icons.lock_outline, type: TextInputType.number, max: 3, obscure: true)),
              ]),
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: kGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('ბარათის შენახვა', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock, size: 13, color: Colors.grey[400]),
            const SizedBox(width: 4),
            Text('დაცული გადახდა', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ]),
        ]),
      ),
    );
  }

  Widget _cField(TextEditingController ctrl, String label, String hint, IconData icon,
      {TextInputType? type, int? max, bool obscure = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kDark)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl, keyboardType: type, maxLength: max, obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: kGreen, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen)),
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    ]);
  }
}

// ==================== TRIPS ====================
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(Uri.parse('$BASE_URL/api/trips'), headers: headers);
      final data = jsonDecode(res.body);
      setState(() { _trips = data is List ? data : (data['trips'] ?? []); _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kDark,
        title: const Text('ჩემი მოგზაურობები', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : _trips.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.history, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('მოგზაურობები ჯერ არ გაქვს', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        const SizedBox(height: 8),
        Text('QR სკანირებით დაიწყე!', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
      ]))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trips.length,
        itemBuilder: (_, i) {
          final t = _trips[i];
          final completed = t['status'] == 'completed';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: kGreen.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.electric_scooter, color: kGreen),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t['device_id'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, color: kDark)),
                if (t['duration_minutes'] != null)
                  Text('${t['duration_minutes']} წუთი', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                Text('₾${t['amount_paid'] ?? 0}', style: const TextStyle(color: kGreen, fontWeight: FontWeight.w600)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: completed ? kGreen.withOpacity(0.1) : kOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  completed ? 'დასრულდა' : (t['status'] ?? '—'),
                  style: TextStyle(color: completed ? kGreen : kOrange, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ==================== PROFILE ====================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _username = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? '—';
      _role = prefs.getString('role') ?? 'client';
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kDark,
        title: const Text('პროფილი', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Column(children: [
              Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [kGreen, kOrange]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(_username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kDark)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(_role, style: const TextStyle(color: kGreen, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
            child: Column(children: [
              _tile(Icons.credit_card, 'ბარათის მართვა', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CardScreen()))),
              const Divider(height: 1, indent: 56),
              _tile(Icons.qr_code_scanner, 'QR სკანირება', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScanScreen()))),
              const Divider(height: 1, indent: 56),
              _tile(Icons.logout, 'გამოსვლა', color: Colors.red, onTap: _logout),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _tile(IconData icon, String title, {VoidCallback? onTap, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? kGreen),
      title: Text(title, style: TextStyle(color: color ?? kDark, fontWeight: FontWeight.w500)),
      trailing: color == null ? const Icon(Icons.arrow_forward_ios, size: 15, color: Colors.grey) : null,
      onTap: onTap,
    );
  }
}