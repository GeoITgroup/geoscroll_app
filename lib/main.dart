import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'dart:async';

const String BASE_URL    = 'https://velocar.ge';
const String APP_VERSION = '1.0.3';

const kGreen      = Color(0xFF2E9E6B);
const kGreenLight = Color(0xFF4CAF80);
const kOrange     = Color(0xFFF07C2A);
const kDark       = Color(0xFF1A2B22);
const kBg         = Color(0xFFF4F6F4);

// ─── Vehicle type metadata (used across screens) ───
const Map<String, String> kTypeIcons = {
  'scooter': '🛴', 'bike': '🚲', 'ebike': '⚡', 'moped': '🛵', 'car': '🚗',
};
const Map<String, String> kTypeNames = {
  'scooter': 'სქროლი', 'bike': 'ველო', 'ebike': 'ელ. ველო', 'moped': 'მოპედი', 'car': 'მანქანა',
};

final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile'], serverClientId: '76613972502-652obdjh6ipvsi4ftp0cms8nn2fuaamv.apps.googleusercontent.com');

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    final token = await _messaging.getToken();
    if (token != null) await _saveTokenToServer(token);
    _messaging.onTokenRefresh.listen(_saveTokenToServer);
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showInAppNotification(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  static Future<void> _saveTokenToServer(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionToken = prefs.getString('session_token') ?? '';
      if (sessionToken.isEmpty) return;
      await http.post(
        Uri.parse('$BASE_URL/api/user/fcm-token'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $sessionToken'},
        body: jsonEncode({'fcm_token': token}),
      );
      await prefs.setString('fcm_token', token);
    } catch (_) {}
  }

  static void _showInAppNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _notificationKey.currentState?.showNotification(
      title: notification.title ?? 'Velocar',
      body: notification.body ?? '',
    );
  }

  static void _handleNotificationTap(RemoteMessage message) {}

  static Future<void> resendToken() async {
    final token = await _messaging.getToken();
    if (token != null) await _saveTokenToServer(token);
  }
}

final GlobalKey<_InAppNotificationState> _notificationKey = GlobalKey();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await PushNotificationService.init();
  runApp(const VelocarApp());
}

class VelocarApp extends StatelessWidget {
  const VelocarApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'Velocar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: kGreen, primary: kGreen),
          useMaterial3: true,
          fontFamily: 'Roboto'),
      home: InAppNotificationWrapper(key: _notificationKey, child: const SplashScreen()));
}

class InAppNotificationWrapper extends StatefulWidget {
  final Widget child;
  const InAppNotificationWrapper({super.key, required this.child});
  @override
  State<InAppNotificationWrapper> createState() => _InAppNotificationState();
}

class _InAppNotificationState extends State<InAppNotificationWrapper>
    with SingleTickerProviderStateMixin {
  String _title = '', _body = '';
  bool _visible = false;
  Timer? _timer;
  late AnimationController _anim;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void showNotification({required String title, required String body}) {
    setState(() { _title = title; _body = body; _visible = true; });
    _anim.forward(from: 0);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), () {
      _anim.reverse().then((_) => setState(() => _visible = false));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_visible)
        Positioned(top: 0, left: 0, right: 0,
            child: SlideTransition(position: _slide,
                child: SafeArea(child: Padding(padding: const EdgeInsets.all(12),
                    child: Material(elevation: 8, borderRadius: BorderRadius.circular(14),
                        child: Container(padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(14)),
                            child: Row(children: [
                              Container(width: 40, height: 40,
                                  decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle),
                                  child: const Icon(Icons.notifications, color: Colors.white, size: 20)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(_title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(_body, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                              ])),
                              IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                                  onPressed: () => _anim.reverse().then((_) => setState(() => _visible = false))),
                            ])))))))
    ]);
  }
}

Future<Map<String,String>> _authHeaders() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('session_token') ?? '';
  return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
}

MaterialPageRoute _route(Widget w) => MaterialPageRoute(builder: (_) => w);

Widget _logo(double size, double iconSize) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kGreen, kOrange], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.255)),
    child: Icon(Icons.electric_scooter, size: iconSize, color: Colors.white));

// ═══════════════════════════════════════════════════════════
// WebView SCREEN — აპშიდე იხსნება BOG გვერდი
// ═══════════════════════════════════════════════════════════
class BogWebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final VoidCallback? onSuccess;

  const BogWebViewScreen({
    super.key,
    required this.url,
    required this.title,
    this.onSuccess,
  });

  @override
  State<BogWebViewScreen> createState() => _BogWebViewScreenState();
}

class _BogWebViewScreenState extends State<BogWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (url) {
          setState(() => _loading = false);
          if (url.contains('velocar.ge/api/bog/callback') ||
              url.contains('velocar.ge/payment/success') ||
              url.contains('card-success')) {
            widget.onSuccess?.call();
            Navigator.pop(context, true);
          }
          if (url.contains('payment/fail')) {
            Navigator.pop(context, false);
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
          backgroundColor: kDark,
          title: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 15)),
          leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context, false)),
          actions: [
            if (_loading)
              const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))))
          ]),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: kGreen)),
      ]));
}

// ═══════════════════════════════════════════════════════════
// SPLASH SCREEN
// ═══════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override void initState() { super.initState(); _check(); }
  Future<void> _check() async {
    await Future.delayed(const Duration(seconds: 2));
    final prefs    = await SharedPreferences.getInstance();
    final token    = prefs.getString('session_token');
    final tripId   = prefs.getInt('active_trip_id');
    final deviceId = prefs.getString('active_device_id');
    if (!mounted) return;
    if (tripId != null && deviceId != null) {
      // active trip-ის გაგრძელება — pricing fetch-დება ActiveRideScreen-ში
      Navigator.pushReplacement(context, _route(ActiveRideScreen(tripId: tripId, deviceId: deviceId)));
    } else if (token != null && token.isNotEmpty) {
      await PushNotificationService.resendToken();
      Navigator.pushReplacement(context, _route(const MainScreen()));
    } else {
      Navigator.pushReplacement(context, _route(const LoginScreen()));
    }
  }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: kDark,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _logo(110, 64), const SizedBox(height: 24),
        const Text('VELOCAR', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 4)),
        const SizedBox(height: 6),
        Text('Shared Electric Fleet', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, letterSpacing: 1)),
        const SizedBox(height: 48), const CircularProgressIndicator(color: kGreen)])));
}

// ═══════════════════════════════════════════════════════════
// LOGIN SCREEN
// ═══════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false, _gLoading = false, _obscure = true;
  String _error = '';

  Future<void> _login() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await http.post(Uri.parse('$BASE_URL/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': _userCtrl.text.trim(), 'password': _passCtrl.text}));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        await _saveSession(data);
        await PushNotificationService.resendToken();
        if (mounted) Navigator.pushReplacement(context, _route(const MainScreen()));
      } else { setState(() => _error = data['error'] ?? 'შეცდომა'); }
    } catch (_) { setState(() => _error = 'სერვერთან კავშირის შეცდომა'); }
    setState(() => _loading = false);
  }

  Future<void> _googleLogin() async {
    setState(() { _gLoading = true; _error = ''; });
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) { setState(() => _gLoading = false); return; }
      final auth = await account.authentication;
      final res  = await http.post(Uri.parse('$BASE_URL/api/auth/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id_token': auth.idToken, 'email': account.email,
            'display_name': account.displayName, 'photo_url': account.photoUrl}));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        await _saveSession(data, ga: account);
        await PushNotificationService.resendToken();
        if (mounted) Navigator.pushReplacement(context, _route(const MainScreen()));
      } else { setState(() => _error = data['error'] ?? 'Google-ით შესვლა ვერ მოხერხდა'); }
    } catch (_) { setState(() => _error = 'Google-ით შესვლა ვერ მოხერხდა'); }
    setState(() => _gLoading = false);
  }

  Future<void> _saveSession(Map data, {GoogleSignInAccount? ga}) async {
    final prefs = await SharedPreferences.getInstance();
    final u = data['user'] ?? {};
    await prefs.setString('session_token', data['token'] ?? '');
    await prefs.setString('username',  u['username']  ?? u['display_name'] ?? ga?.displayName ?? '');
    await prefs.setString('email',     u['email']     ?? ga?.email ?? '');
    await prefs.setString('photo_url', u['photo_url'] ?? ga?.photoUrl ?? '');
    await prefs.setString('role',      u['role']      ?? 'client');
    await prefs.setInt   ('user_id',   u['id'] is int ? u['id'] : int.tryParse(u['id']?.toString() ?? '1') ?? 1);
    await prefs.setBool  ('verified',  u['verified']  == true);
  }

  @override Widget build(BuildContext context) => Scaffold(backgroundColor: kDark,
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 40), _logo(72, 40), const SizedBox(height: 24),
            const Text('VELOCAR', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 3)),
            const SizedBox(height: 4),
            Text('შედი შენს ანგარიშში', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
            const SizedBox(height: 40),
            SizedBox(width: double.infinity, height: 52,
                child: OutlinedButton(onPressed: _gLoading ? null : _googleLogin,
                    style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        backgroundColor: Colors.white.withOpacity(0.07)),
                    child: _gLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: kGreen, strokeWidth: 2))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Image.network('https://www.google.com/favicon.ico', width: 20, height: 20,
                          errorBuilder: (_,__,___) => const Icon(Icons.g_mobiledata, color: Colors.white, size: 22)),
                      const SizedBox(width: 10),
                      const Text('Google-ით შესვლა', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500))]))),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Divider(color: Colors.white.withOpacity(0.15))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('ან', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13))),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.15)))]),
            const SizedBox(height: 20),
            _field(_userCtrl, 'მომხმარებელი', Icons.person_outline),
            const SizedBox(height: 16),
            _field(_passCtrl, 'პაროლი', Icons.lock_outline, obscure: _obscure,
                suffix: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
                    onPressed: () => setState(() => _obscure = !_obscure))),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8), Expanded(child: Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 13)))]))],
            const SizedBox(height: 28),
            SizedBox(width: double.infinity, height: 54,
                child: ElevatedButton(onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(backgroundColor: kGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: _loading ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('შესვლა', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)))),
          ]))));

  Widget _field(TextEditingController ctrl, String hint, IconData icon, {bool obscure=false, Widget? suffix}) =>
      TextField(controller: ctrl, obscureText: obscure, style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
              prefixIcon: Icon(icon, color: kGreen, size: 22), suffixIcon: suffix,
              filled: true, fillColor: Colors.white.withOpacity(0.07),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: kGreen, width: 1.5))));
}

// ═══════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override State<MainScreen> createState() => _MainScreenState();
}
class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  @override Widget build(BuildContext context) {
    final screens = [const MapHomeScreen(), const TripsScreen(), const MenuScreen()];
    return Scaffold(
        body: screens[_tab],
        bottomNavigationBar: Container(
            decoration: BoxDecoration(color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0,-4))]),
            child: BottomNavigationBar(currentIndex: _tab, onTap: (i) => setState(() => _tab = i),
                backgroundColor: Colors.white, selectedItemColor: kGreen, unselectedItemColor: Colors.grey[400],
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'რუკა'),
                  BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'ისტორია'),
                  BottomNavigationBarItem(icon: Icon(Icons.menu), activeIcon: Icon(Icons.menu_open), label: 'მენიუ'),
                ])));
  }
}

// ═══════════════════════════════════════════════════════════
// MAP HOME SCREEN — GPS default + Vehicle filter + Dynamic pricing
// ═══════════════════════════════════════════════════════════
class MapHomeScreen extends StatefulWidget {
  const MapHomeScreen({super.key});
  @override State<MapHomeScreen> createState() => _MapHomeScreenState();
}
class _MapHomeScreenState extends State<MapHomeScreen> {
  List _scooters = [], _geofences = [];
  double _walletBalance = 0;
  LatLng _center = const LatLng(41.6938, 44.8015); // ფოლბექი — თბილისი
  GoogleMapController? _mapCtrl;
  final Set<Marker> _markers = {};
  final Set<Polygon> _polygons = {};
  String _filterType = 'all'; // 'all' | 'scooter' | 'bike' | 'ebike' | 'moped' | 'car'
  bool _gpsLoaded = false;
  bool _gpsApplied = false;

  @override void initState() { super.initState(); _getLocation(); _loadData(); _loadBalance(); }

  Future<void> _loadBalance() async {
    try {
      final h = await _authHeaders();
      final r = await http.get(Uri.parse('$BASE_URL/api/wallet/balance'), headers: h);
      final d = jsonDecode(r.body);
      if (d['success'] == true && mounted) {
        setState(() => _walletBalance = (d['balance'] as num?)?.toDouble() ?? 0);
      }
    } catch (_) {}
  }

  Future<void> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _fallbackLocation();
        return;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        _fallbackLocation();
        return;
      }
      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 8), onTimeout: () {
        throw TimeoutException('GPS timeout');
      });
      if (!mounted) return;
      setState(() {
        _center = LatLng(pos.latitude, pos.longitude);
        _gpsLoaded = true;
      });
      _applyInitialCamera();
    } catch (_) {
      _fallbackLocation();
    }
  }

  // თუ GPS-ი ვერ მიიღო — overlay გადადის, fallback ცენტრით
  void _fallbackLocation() {
    if (!mounted) return;
    setState(() => _gpsLoaded = true);  // overlay-ის გადაცემა — fallback _center-ით
    _applyInitialCamera();
  }

  // GPS-ი და map controller-ი ერთმანეთს ელოდებიან — ვინც ბოლოს მოვა, ის გადააფარებს კამერას
  void _applyInitialCamera() {
    if (_mapCtrl != null && _gpsLoaded && !_gpsApplied) {
      _gpsApplied = true;
      _mapCtrl!.animateCamera(CameraUpdate.newLatLngZoom(_center, 15));
    }
  }

  Future<void> _loadData() async {
    try {
      final h = await _authHeaders();
      final r1 = await http.get(Uri.parse('$BASE_URL/api/scooters'), headers: h);
      final d1 = jsonDecode(r1.body);
      if (d1 is List) setState(() => _scooters = d1);
      final r2 = await http.get(Uri.parse('$BASE_URL/api/geofences'), headers: h);
      final d2 = jsonDecode(r2.body);
      if (d2 is List) setState(() => _geofences = d2);
      _rebuildOverlays();
    } catch (_) {}
  }

  void _rebuildOverlays() async {
    final markers = <Marker>{};
    final filtered = _filterType == 'all'
        ? _scooters
        : _scooters.where((s) => (s['vehicle_type']?.toString() ?? 'scooter') == _filterType).toList();
    for (final s in filtered) {
      if (s['latitude'] == null || s['longitude'] == null) continue;
      final ok = s['status'] == 'available';
      markers.add(Marker(
        markerId: MarkerId(s['device_id']?.toString() ?? s['id'].toString()),
        position: LatLng(double.parse(s['latitude'].toString()), double.parse(s['longitude'].toString())),
        icon: BitmapDescriptor.defaultMarkerWithHue(ok ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange),
        onTap: () => _showInfo(context, s),
      ));
    }
    final polygons = <Polygon>{};
    int gi = 0;
    // ─── მხოლოდ ის გეოფენსები, რომელიც სქროლს მინიჭებული აქვს ───
    final assignedIds = <int>{};
    for (final s in _scooters) {
      final gid = s['geofence_id'];
      if (gid != null) {
        final id = int.tryParse(gid.toString());
        if (id != null) assignedIds.add(id);
      }
    }
    for (final g in _geofences) {
      final gid = int.tryParse(g['id']?.toString() ?? '');
      if (gid == null || !assignedIds.contains(gid)) continue; // არ ჩვენდება არამინიჭებული
      final pts = _parseGeofence(g);
      if (pts.isEmpty) continue;
      polygons.add(Polygon(
        polygonId: PolygonId('geo_${gi++}'),
        points: pts,
        fillColor: kGreen.withOpacity(0.15),
        strokeColor: kGreen,
        strokeWidth: 2,
      ));
    }
    if (mounted) setState(() {
      _markers..clear()..addAll(markers);
      _polygons..clear()..addAll(polygons);
    });
  }

  List<LatLng> _parseGeofence(dynamic g) {
    try {
      // Server აბრუნებს polygon_coords (უკვე parsed array of [lat, lng])
      final pc = g['polygon_coords'];
      if (pc is List && pc.isNotEmpty) {
        return pc
            .where((p) => p is List && p.length >= 2)
            .map<LatLng>((p) => LatLng(
                double.parse(p[0].toString()),
                double.parse(p[1].toString())))
            .toList();
      }
      // legacy ფორმატი — coordinates string-ად
      if (g['coordinates'] != null) {
        final c = jsonDecode(g['coordinates'].toString());
        if (c is List) {
          return c
              .where((p) => p is List && p.length >= 2)
              .map<LatLng>((p) => LatLng(
                  double.parse(p[1].toString()),
                  double.parse(p[0].toString())))
              .toList();
        }
      }
      // არ ვხატავთ ცრუ ოთხკუთხედს — თუ პოლიგონი არ მოვიდა, ცარიელი დააბრუნე
      return [];
    } catch (_) { return []; }
  }

  void _setFilter(String type) {
    setState(() => _filterType = type);
    _rebuildOverlays();
  }

  Future<void> _centerOnMe() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16));
    } catch (_) {}
  }

  @override Widget build(BuildContext context) {
    final filteredScooters = _filterType == 'all'
        ? _scooters
        : _scooters.where((s) => (s['vehicle_type']?.toString() ?? 'scooter') == _filterType).toList();
    final availableCount = filteredScooters.where((s) => s['status'] == 'available').length;
    final filterLabel = _filterType == 'all' ? 'მოწყობილობა' : (kTypeNames[_filterType] ?? '');

    return Scaffold(body: Stack(children: [
      GoogleMap(
        initialCameraPosition: CameraPosition(target: _center, zoom: 14),
        onMapCreated: (c) { _mapCtrl = c; _applyInitialCamera(); },
        myLocationEnabled: true, myLocationButtonEnabled: false, zoomControlsEnabled: false,
        markers: _markers, polygons: _polygons,
      ),
      // ── Loading overlay — GPS resolution-მდე Tbilisi flash-ი არ ჩანდეს ──
      if (!_gpsApplied)
        Container(
          color: kDark.withOpacity(0.85),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _logo(80, 44),
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: kGreen, strokeWidth: 2),
              const SizedBox(height: 16),
              Text('მდებარეობის მოძებნა...',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
            ]),
          ),
        ),
      // ── ზედა bar ──
      Positioned(top: 0, left: 0, right: 0,
          child: Container(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [kDark, kDark.withOpacity(0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top+12, 16, 20),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('VELOCAR', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  Row(children: [
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(context, _route(const WalletScreen()));
                        _loadBalance();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: kGreen.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kGreen.withOpacity(0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.account_balance_wallet, color: kGreen, size: 16),
                          const SizedBox(width: 6),
                          Text('₾${_walletBalance.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                        child: IconButton(icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                            onPressed: () { _loadData(); _loadBalance(); })),
                  ]),
                ]),
                const SizedBox(height: 10),
                // ── Vehicle type filter chips ──
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _filterChip('all', '🌟', 'ყველა'),
                      const SizedBox(width: 8),
                      _filterChip('scooter', kTypeIcons['scooter']!, kTypeNames['scooter']!),
                      const SizedBox(width: 8),
                      _filterChip('bike', kTypeIcons['bike']!, kTypeNames['bike']!),
                      const SizedBox(width: 8),
                      _filterChip('ebike', kTypeIcons['ebike']!, kTypeNames['ebike']!),
                      const SizedBox(width: 8),
                      _filterChip('moped', kTypeIcons['moped']!, kTypeNames['moped']!),
                      const SizedBox(width: 8),
                      _filterChip('car', kTypeIcons['car']!, kTypeNames['car']!),
                    ],
                  ),
                ),
              ]))),
      // ── My location button ──
      Positioned(bottom: 180, right: 16,
          child: FloatingActionButton(
            heroTag: 'fab_my_loc',
            mini: true,
            backgroundColor: Colors.white,
            onPressed: _centerOnMe,
            child: const Icon(Icons.my_location, color: kGreen),
          )),
      // ── ქვედა: ხელმისაწვდომი + სკან ღილაკი ──
      Positioned(bottom: 20, left: 20, right: 20, child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)]),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_filterType == 'all' ? '🛴' : (kTypeIcons[_filterType] ?? '🛴'),
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('$availableCount $filterLabel ხელმისაწვდომი',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: kDark))])),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 58,
            child: ElevatedButton.icon(icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
                label: const Text('QR სკანირება', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: kGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4),
                onPressed: () => Navigator.push(context, _route(const QRScanScreen())))),
      ])),
    ]));
  }

  Widget _filterChip(String type, String icon, String label) {
    final selected = _filterType == type;
    return GestureDetector(
      onTap: () => _setFilter(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kGreen : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? kGreen : Colors.white.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: Colors.white, fontWeight: selected ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
        ]),
      ),
    );
  }

  void _showInfo(BuildContext context, Map s) {
    final ok = s['status'] == 'available';
    final vType = s['vehicle_type']?.toString() ?? 'scooter';
    final perMin = double.tryParse(s['per_minute_rate']?.toString() ?? '0.15') ?? 0.15;
    final unlock = double.tryParse(s['unlock_fee']?.toString() ?? '0') ?? 0;
    final perKm = double.tryParse(s['per_km_rate']?.toString() ?? '0') ?? 0;
    final battery = int.tryParse(s['battery']?.toString() ?? '0') ?? 0;
    showModalBottomSheet(context: context, backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            Container(width: 56, height: 56,
                decoration: BoxDecoration(color: ok ? kGreen.withOpacity(0.1) : Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
                child: Center(child: Text(kTypeIcons[vType] ?? '🛴', style: const TextStyle(fontSize: 28)))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s['device_id']??'—', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kDark)),
              Text('${kTypeNames[vType] ?? vType} · ${s['company_name']??'—'}', style: TextStyle(color: Colors.grey[600], fontSize: 13))])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: ok ? kGreen.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(ok ? 'ხელმისაწვდომი' : 'დაკავებული',
                    style: TextStyle(color: ok ? kGreen : Colors.red, fontWeight: FontWeight.w600, fontSize: 12))),
          ]),
          const SizedBox(height: 16),
          // ── დინამიური ფასები ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              _priceCol('₾${perMin.toStringAsFixed(2)}', 'წუთი'),
              _priceCol(unlock > 0 ? '₾${unlock.toStringAsFixed(2)}' : 'უფასო', 'გახსნა'),
              if (perKm > 0) _priceCol('₾${perKm.toStringAsFixed(2)}', 'კმ'),
              _priceCol('$battery%', 'ბატარეა'),
            ]),
          ),
          const SizedBox(height: 16),
          if (ok) SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton.icon(icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  label: const Text('QR სკანირება', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: kGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () { Navigator.pop(context); Navigator.push(context, _route(const QRScanScreen())); }))
          else Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.block, color: Colors.red, size: 18), SizedBox(width: 8),
                Text('მოწყობილობა დაკავებულია', style: TextStyle(color: Colors.red))])),
          const SizedBox(height: 8),
        ])));
  }

  Widget _priceCol(String value, String label) => Expanded(child: Column(children: [
    Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: kDark, fontSize: 14)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
  ]));
}

// ═══════════════════════════════════════════════════════════
// QR SCAN SCREEN
// ═══════════════════════════════════════════════════════════
class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});
  @override State<QRScanScreen> createState() => _QRScanScreenState();
}
class _QRScanScreenState extends State<QRScanScreen> {
  final MobileScannerController _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.normal, facing: CameraFacing.back, torchEnabled: false);
  bool _scanned = false;
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final value = capture.barcodes.firstOrNull?.rawValue ?? '';
    if (value.isEmpty) return;
    setState(() => _scanned = true); _ctrl.stop();
    String deviceId = '';
    final v = value.trim();
    try {
      if (v.contains('?')) {
        final uri = Uri.parse(v);
        deviceId = uri.queryParameters['id'] ?? uri.queryParameters['device_id'] ?? '';
      }
      if (deviceId.isEmpty && v.contains('id='))        deviceId = v.split('id=').last.split('&').first.trim();
      if (deviceId.isEmpty && v.contains('device_id=')) deviceId = v.split('device_id=').last.split('&').first.trim();
      if (deviceId.isEmpty)                             deviceId = v;
    } catch (_) { deviceId = v; }
    if (deviceId.isNotEmpty) {
      Navigator.pushReplacement(context, _route(ScooterDetailScreen(deviceId: deviceId)));
    } else {
      setState(() => _scanned = false); _ctrl.start();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR კოდი ვერ წაიკითხა')));
    }
  }

  @override Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black,
      body: Stack(children: [
        MobileScanner(controller: _ctrl, onDetect: _onDetect),
        IgnorePointer(child: CustomPaint(size: MediaQuery.of(context).size, painter: _OverlayPainter())),
        Positioned(top: MediaQuery.of(context).padding.top+70, left: 0, right: 0,
            child: Column(children: [
              const Text('მოწყობილობის QR კოდი', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('მიახლოვდი და დაასკანირე', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13))])),
        Positioned(bottom: 60, left: 0, right: 0,
            child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.qr_code, color: Colors.white54, size: 16), const SizedBox(width: 6),
                  Text('QR კოდი მოათავსე ჩარჩოში', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13))])))),
        Positioned(bottom: 60, right: 28,
            child: GestureDetector(onTap: () => _ctrl.toggleTorch(),
                child: Container(width: 48, height: 48,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.flashlight_on, color: Colors.white)))),
        Positioned(top: MediaQuery.of(context).padding.top+8, left: 16,
            child: Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 24), onPressed: () => Navigator.pop(context)))),
      ]));
}

class _OverlayPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    const box = 240.0;
    final cx = size.width/2, cy = size.height/2;
    final rect = Rect.fromCenter(center: Offset(cx,cy), width: box, height: box);
    final overlayPath = ui.Path()..addRect(Rect.fromLTWH(0,0,size.width,size.height));
    final holePath = ui.Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
    final combined = ui.Path.combine(ui.PathOperation.difference, overlayPath, holePath);
    canvas.drawPath(combined, Paint()..color = Colors.black.withOpacity(0.55));
    final bp = Paint()..color = kGreen..strokeWidth = 3..style = PaintingStyle.stroke;
    const cs = 28.0;
    final l=rect.left,t=rect.top,r=rect.right,b=rect.bottom;
    canvas..drawLine(Offset(l,t+cs),Offset(l,t),bp)..drawLine(Offset(l,t),Offset(l+cs,t),bp);
    canvas..drawLine(Offset(r-cs,t),Offset(r,t),bp)..drawLine(Offset(r,t),Offset(r,t+cs),bp);
    canvas..drawLine(Offset(l,b-cs),Offset(l,b),bp)..drawLine(Offset(l,b),Offset(l+cs,b),bp);
    canvas..drawLine(Offset(r,b-cs),Offset(r,b),bp)..drawLine(Offset(r,b),Offset(r-cs,b),bp);
  }
  @override bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════
// SCOOTER DETAIL SCREEN — Dynamic tariff + company_blocked
// ═══════════════════════════════════════════════════════════
class ScooterDetailScreen extends StatefulWidget {
  final String deviceId;
  const ScooterDetailScreen({super.key, required this.deviceId});
  @override State<ScooterDetailScreen> createState() => _ScooterDetailScreenState();
}
class _ScooterDetailScreenState extends State<ScooterDetailScreen> {
  Map<String,dynamic>? _scooter;
  bool _loading = true, _starting = false;
  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final h = await _authHeaders();
      final res = await http.get(Uri.parse('$BASE_URL/api/scooters'), headers: h);
      final d = jsonDecode(res.body);
      if (d is List) {
        final s = d.firstWhere((s) => s['device_id']==widget.deviceId, orElse: ()=>null);
        setState(() { _scooter=s; _loading=false; });
      } else setState(()=>_loading=false);
    } catch (_) { setState(()=>_loading=false); }
  }

  double get _perMinuteRate => double.tryParse(_scooter?['per_minute_rate']?.toString() ?? '') ?? 0.15;
  double get _unlockFee => double.tryParse(_scooter?['unlock_fee']?.toString() ?? '') ?? 0;
  double get _perKmRate => double.tryParse(_scooter?['per_km_rate']?.toString() ?? '') ?? 0;
  String get _vehicleType => _scooter?['vehicle_type']?.toString() ?? 'scooter';

  Future<bool> _showTariffSheet() async {
    final battery = int.tryParse(_scooter?['battery']?.toString() ?? '100') ?? 100;
    final perMin = _perMinuteRate;
    final unlock = _unlockFee;
    final perKm = _perKmRate;
    final typeName = kTypeNames[_vehicleType] ?? _vehicleType;
    final typeIcon = kTypeIcons[_vehicleType] ?? '🛴';

    // მაგალითი 5წთ + 2კმ
    final samplePrice = unlock + (5 * perMin) + (2 * perKm);

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(typeIcon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text('$typeName — გაქირავება',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kDark)),
          ]),
          const SizedBox(height: 18),

          // ── ბატარეა ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: battery > 20 ? kGreen.withOpacity(0.07) : Colors.orange.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: battery > 20 ? kGreen.withOpacity(0.2) : Colors.orange.withOpacity(0.2))),
            child: Row(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(
                  color: battery > 20 ? kGreen.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                  shape: BoxShape.circle),
                  child: Icon(Icons.battery_charging_full,
                      color: battery > 20 ? kGreen : Colors.orange, size: 28)),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ბატარეა', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                Text('$battery%',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                        color: battery > 20 ? kDark : Colors.orange)),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: battery > 50 ? kGreen.withOpacity(0.1) : battery > 20 ? Colors.orange.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                    battery > 50 ? 'კარგი' : battery > 20 ? 'საკმარისი' : 'დაბალი',
                    style: TextStyle(
                        color: battery > 50 ? kGreen : battery > 20 ? Colors.orange : Colors.red,
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // ── დინამიური ფასები ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              _tariffRow(Icons.access_time, 'წუთის ფასი', '₾${perMin.toStringAsFixed(2)} / წთ'),
              const SizedBox(height: 10), const Divider(height: 1), const SizedBox(height: 10),
              _tariffRow(Icons.lock_open, 'გახსნის საფასური',
                  unlock > 0 ? '₾${unlock.toStringAsFixed(2)}' : 'უფასო',
                  highlightFree: unlock == 0),
              if (perKm > 0) ...[
                const SizedBox(height: 10), const Divider(height: 1), const SizedBox(height: 10),
                _tariffRow(Icons.route, 'კმ-ის ფასი', '₾${perKm.toStringAsFixed(2)} / კმ'),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: kGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.calculate_outlined, color: kGreen, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('მაგ. 5წთ${perKm > 0 ? ' + 2კმ' : ''}',
                      style: const TextStyle(color: kDark, fontSize: 12))),
                  Text('≈ ₾${samplePrice.toStringAsFixed(2)}',
                      style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // BOG info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('გადახდა BOG ბარათით — უსაფრთხო',
                  style: TextStyle(color: Colors.blue[700], fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 20),

          SizedBox(width: double.infinity, height: 54,
              child: ElevatedButton.icon(
                  icon: const Icon(Icons.payment, color: Colors.white),
                  label: const Text('გადახდა და გახსნა',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: kGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => Navigator.pop(context, true))),
          const SizedBox(height: 8),
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('გაუქმება', style: TextStyle(color: Colors.grey, fontSize: 14))),
        ]),
      ),
    );
    return result == true;
  }

  Widget _tariffRow(IconData icon, String label, String value, {bool highlightFree = false}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Icon(icon, color: kGreen, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ]),
        Text(value, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold,
            color: highlightFree ? kGreen : kDark)),
      ]);

  Future<void> _startRide() async {
    final battery = int.tryParse(_scooter?['battery']?.toString() ?? '100') ?? 100;

    // 1. ბატარეა
    if (battery < 5) {
      if (mounted) showDialog(context: context, builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [Icon(Icons.battery_alert, color: Colors.red), SizedBox(width: 8), Text('ბატარეა დაბალია')]),
          content: Text('მოწყობილობის ბატარეა მხოლოდ $battery% არის.\n\nგაქირავება შეუძლებელია.'),
          actions: [ElevatedButton(onPressed: ()=>Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: kDark),
              child: const Text('გასაგებია', style: TextStyle(color: Colors.white)))]));
      return;
    }

    // 2. company_blocked შემოწმება (UI-level — სერვერი მაინც გადაამოწმებს)
    if (_scooter?['company_blocked'] == 1 ||
        (double.tryParse(_scooter?['company_balance']?.toString() ?? '1') ?? 1) <= 0) {
      if (mounted) showDialog(context: context, builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 8), Flexible(child: Text('მიუწვდომელია'))]),
          content: const Text('მოწყობილობა დროებით მიუწვდომელია.\nსცადე სხვა, ან მოგვიანებით.'),
          actions: [ElevatedButton(onPressed: ()=>Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: kDark),
              child: const Text('გასაგებია', style: TextStyle(color: Colors.white)))]));
      return;
    }

    // 3. ტარიფის confirmation
    final confirmed = await _showTariffSheet();
    if (!confirmed) return;

    // 4. Wallet flow — trip start პირდაპირ
    setState(()=>_starting=true);
    try {
      final h = await _authHeaders();
      final res = await http.post(
        Uri.parse('$BASE_URL/api/trips/start'),
        headers: h,
        body: jsonEncode({'device_id': widget.deviceId}),
      );
      final data = jsonDecode(res.body);

      // ── insufficient_balance ──
      if (data['error'] == 'insufficient_balance') {
        setState(()=>_starting=false);
        final balance  = (data['balance']  as num?)?.toDouble() ?? 0;
        final required = (data['required'] as num?)?.toDouble() ?? 0;
        if (mounted) showDialog(context: context, builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [Icon(Icons.account_balance_wallet_outlined, color: kOrange), SizedBox(width: 8), Flexible(child: Text('ბალანსი ცოტაა'))]),
            content: Text('მიმდინარე ბალანსი: ₾${balance.toStringAsFixed(2)}\nსაჭიროა მინიმუმ: ₾${required.toStringAsFixed(2)}\n\nშეავსე საფულე.'),
            actions: [
              TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('გაუქმება')),
              ElevatedButton(
                onPressed: () { Navigator.pop(context); Navigator.push(context, _route(const WalletScreen())); },
                style: ElevatedButton.styleFrom(backgroundColor: kGreen),
                child: const Text('საფულის შევსება', style: TextStyle(color: Colors.white)),
              ),
            ]));
        return;
      }

      if (data['error'] == 'low_battery') {
        setState(()=>_starting=false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red[700], content: Text(data['message'] ?? 'ბატარეა დაბალია')));
        return;
      }

      if (data['error'] == 'company_blocked') {
        setState(()=>_starting=false);
        if (mounted) showDialog(context: context, builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 8), Flexible(child: Text('მიუწვდომელია'))]),
            content: Text(data['message'] ?? 'მოწყობილობა დროებით მიუწვდომელია. სცადე სხვა.'),
            actions: [ElevatedButton(onPressed: ()=>Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: kDark),
                child: const Text('გასაგებია', style: TextStyle(color: Colors.white)))]));
        return;
      }

      // ── trip წარმატებით დაიწყო ──
      if (data['success'] == true && data['trip_id'] != null && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('active_trip_id', data['trip_id'] as int);
        await prefs.setString('active_device_id', widget.deviceId);
        Navigator.pushAndRemoveUntil(context,
            _route(ActiveRideScreen(
              tripId: data['trip_id'] as int,
              deviceId: widget.deviceId,
              perMinuteRate: (data['per_minute_rate'] as num?)?.toDouble() ?? _perMinuteRate,
              unlockFee:     (data['unlock_fee']      as num?)?.toDouble() ?? _unlockFee,
              perKmRate:     (data['per_km_rate']     as num?)?.toDouble() ?? _perKmRate,
              vehicleType:   (data['vehicle_type']    as String?) ?? _vehicleType,
            )),
            (_)=>false);
        return;
      }

      setState(()=>_starting=false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data['message']?.toString() ?? 'მგზავრობა ვერ დაიწყო'),
        backgroundColor: Colors.red[700],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('შეცდომა: $e')));
      if (mounted) setState(()=>_starting=false);
    }
  }

  @override Widget build(BuildContext context) {
    final ok = _scooter?['status']=='available';
    final typeIcon = kTypeIcons[_vehicleType] ?? '🛴';
    final typeName = kTypeNames[_vehicleType] ?? _vehicleType;
    return Scaffold(backgroundColor: kBg,
        appBar: AppBar(backgroundColor: kDark,
            title: Text('$typeName ${widget.deviceId}', style: const TextStyle(color: Colors.white, fontSize: 16)),
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: ()=>Navigator.pop(context))),
        body: _loading ? const Center(child: CircularProgressIndicator(color: kGreen))
            : _scooter==null ? const Center(child: Text('მოწყობილობა ვერ მოიძებნა'))
            : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
          Container(padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)]),
              child: Column(children: [
                Container(width: 90, height: 90,
                    decoration: BoxDecoration(color: ok ? kGreen.withOpacity(0.1) : Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
                    child: Center(child: Text(typeIcon, style: const TextStyle(fontSize: 48)))),
                const SizedBox(height: 16),
                Text(widget.deviceId, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kDark)),
                const SizedBox(height: 4),
                Text(typeName, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(color: ok ? kGreen.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(ok ? '✅ ხელმისაწვდომი' : '❌ დაკავებული',
                        style: TextStyle(color: ok ? kGreen : Colors.red, fontWeight: FontWeight.w600))),
                const SizedBox(height: 20),
                _iRow(Icons.business,              'კომპანია', _scooter!['company_name']??'—'),
                _iRow(Icons.battery_charging_full, 'ბატარეა',  '${_scooter!['battery']??0}%'),
                _iRow(Icons.location_on,           'ზონა',     _scooter!['zone_name']??'—'),
                _iRow(Icons.access_time,           'წუთის ფასი', '₾${_perMinuteRate.toStringAsFixed(2)} / წთ'),
                if (_unlockFee > 0)
                  _iRow(Icons.lock_open, 'გახსნა', '₾${_unlockFee.toStringAsFixed(2)}'),
                if (_perKmRate > 0)
                  _iRow(Icons.route, 'კმ', '₾${_perKmRate.toStringAsFixed(2)} / კმ'),
              ])),
          const SizedBox(height: 20),
          if (ok) SizedBox(width: double.infinity, height: 56,
              child: ElevatedButton.icon(
                  icon: _starting
                      ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2))
                      : const Icon(Icons.payment, color: Colors.white),
                  label: Text(_starting ? 'მუშავდება...' : 'გადახდა და გახსნა',
                      style: const TextStyle(fontSize:16, fontWeight:FontWeight.bold, color:Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: kGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: _starting ? null : _startRide))
          else Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.block, color: Colors.red), SizedBox(width: 8),
                Text('მოწყობილობა ხელმისაწვდომი არ არის', style: TextStyle(color: Colors.red))])),
        ])));
  }

  Widget _iRow(IconData icon, String label, String value) =>
      Padding(padding: const EdgeInsets.symmetric(vertical:8), child: Row(children: [
        Icon(icon, color:kGreen, size:20), const SizedBox(width:12),
        Text(label, style:TextStyle(color:Colors.grey[600], fontSize:14)), const Spacer(),
        Text(value, style:const TextStyle(fontWeight:FontWeight.w600, color:kDark))]));
}

// ═══════════════════════════════════════════════════════════
// ACTIVE RIDE SCREEN — Camera follow + Dynamic pricing
// ═══════════════════════════════════════════════════════════
class ActiveRideScreen extends StatefulWidget {
  final int tripId;
  final String deviceId;
  final double perMinuteRate;
  final double unlockFee;
  final double perKmRate;
  final String vehicleType;
  const ActiveRideScreen({
    super.key,
    required this.tripId,
    required this.deviceId,
    this.perMinuteRate = 0.15,
    this.unlockFee = 0,
    this.perKmRate = 0,
    this.vehicleType = 'scooter',
  });
  @override State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}
class _ActiveRideScreenState extends State<ActiveRideScreen> {
  int _seconds = 0;
  Timer? _timer;
  Timer? _locationTimer;
  bool _ending = false;

  GoogleMapController? _mapCtrl;
  LatLng _currentPos = const LatLng(41.6938, 44.8015);
  LatLng? _prevPos;
  double _distanceKm = 0.0;
  List _geofences = [];
  final Set<Polygon> _polygons = {};
  bool _inZone = true;
  bool _cameraReady = false;

  // ფასები — constructor-დან მოდის, ან Sync-ი ხდება server-დან
  double _perMinuteRate = 0.15;
  double _unlockFee = 0;
  double _perKmRate = 0;
  String _vehicleType = 'scooter';

  @override
  void initState() {
    super.initState();
    _perMinuteRate = widget.perMinuteRate;
    _unlockFee = widget.unlockFee;
    _perKmRate = widget.perKmRate;
    _vehicleType = widget.vehicleType;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) => _updateLocation());
    _syncPricing();    // server-დან აქტუალური ფასები (splash-დან resume-ის შემთხვევაში)
    _loadGeofences();
    _updateLocation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  // splash-დან resume-ისას constructor-ში default-ები მოდის — server-დან ვიღებთ რეალურს
  Future<void> _syncPricing() async {
    try {
      final h = await _authHeaders();
      final res = await http.get(Uri.parse('$BASE_URL/api/scooters'), headers: h);
      final d = jsonDecode(res.body);
      if (d is List) {
        final s = d.firstWhere((s) => s['device_id'] == widget.deviceId, orElse: () => null);
        if (s != null && mounted) {
          setState(() {
            _perMinuteRate = double.tryParse(s['per_minute_rate']?.toString() ?? '') ?? _perMinuteRate;
            _unlockFee = double.tryParse(s['unlock_fee']?.toString() ?? '') ?? _unlockFee;
            _perKmRate = double.tryParse(s['per_km_rate']?.toString() ?? '') ?? _perKmRate;
            _vehicleType = s['vehicle_type']?.toString() ?? _vehicleType;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadGeofences() async {
    try {
      final h = await _authHeaders();
      final res = await http.get(Uri.parse('$BASE_URL/api/geofences'), headers: h);
      final d = jsonDecode(res.body);
      if (d is List) {
        setState(() => _geofences = d);
        _rebuildPolygons();
      }
    } catch (_) {}
  }

  void _rebuildPolygons() {
    final polygons = <Polygon>{};
    int gi = 0;
    for (final g in _geofences) {
      final pts = _parseGeofence(g);
      if (pts.isEmpty) continue;
      polygons.add(Polygon(
        polygonId: PolygonId('geo_$gi'),
        points: pts,
        fillColor: kGreen.withOpacity(0.15),
        strokeColor: kGreen,
        strokeWidth: 2,
      ));
      gi++;
    }
    if (mounted) setState(() => _polygons
      ..clear()
      ..addAll(polygons));
    _recheckZone();
  }

  List<LatLng> _parseGeofence(dynamic g) {
    try {
      // Server აბრუნებს polygon_coords (უკვე parsed array of [lat, lng])
      final pc = g['polygon_coords'];
      if (pc is List && pc.isNotEmpty) {
        return pc
            .where((p) => p is List && p.length >= 2)
            .map<LatLng>((p) => LatLng(
                double.parse(p[0].toString()),
                double.parse(p[1].toString())))
            .toList();
      }
      // legacy ფორმატი — coordinates string-ად
      if (g['coordinates'] != null) {
        final c = jsonDecode(g['coordinates'].toString());
        if (c is List) {
          return c
              .where((p) => p is List && p.length >= 2)
              .map<LatLng>((p) => LatLng(
                  double.parse(p[1].toString()),
                  double.parse(p[0].toString())))
              .toList();
        }
      }
      // არ ვხატავთ ცრუ ოთხკუთხედს — თუ პოლიგონი არ მოვიდა, ცარიელი დააბრუნე
      return [];
    } catch (_) { return []; }
  }

  bool _pointInPolygon(LatLng p, List<LatLng> polygon) {
    final x = p.latitude, y = p.longitude;
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].latitude, yi = polygon[i].longitude;
      final xj = polygon[j].latitude, yj = polygon[j].longitude;
      if (((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  void _recheckZone() {
    if (_geofences.isEmpty) { setState(() => _inZone = true); return; }
    var inAny = false;
    for (final g in _geofences) {
      final pts = _parseGeofence(g);
      if (pts.isNotEmpty && _pointInPolygon(_currentPos, pts)) { inAny = true; break; }
    }
    if (mounted) setState(() => _inZone = inAny);
  }

  Future<void> _updateLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final newPos = LatLng(pos.latitude, pos.longitude);
      if (_prevPos != null) {
        final dist = Geolocator.distanceBetween(
            _prevPos!.latitude, _prevPos!.longitude,
            newPos.latitude, newPos.longitude);
        if (dist > 2) {
          setState(() => _distanceKm += dist / 1000);
        }
      }
      setState(() {
        _prevPos = _currentPos;
        _currentPos = newPos;
      });
      // Camera follow user
      if (!_cameraReady) {
        _cameraReady = true;
        _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 17));
      } else {
        _mapCtrl?.animateCamera(CameraUpdate.newLatLng(newPos));
      }
      _recheckZone();
    } catch (_) {}
  }

  String get _timeStr {
    final m = _seconds ~/ 60, s = _seconds % 60;
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  // დინამიური cost: unlock + (წუთები × per_min) + (კმ × per_km)
  double get _cost {
    final minutes = _seconds / 60;
    return _unlockFee + (minutes * _perMinuteRate) + (_distanceKm * _perKmRate);
  }

  Future<void> _endRide() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('მგზავრობის დასრულება'),
        content: Text('დრო: $_timeStr\nმანძილი: ${_distanceKm.toStringAsFixed(2)} კმ\nღირებულება: ₾${_cost.toStringAsFixed(2)}\n\nდარწმუნებული ხარ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('გაგრძელება')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('დასრულება', style: TextStyle(color: Colors.white))),
        ]));
    if (ok != true) return;
    setState(() => _ending = true);
    try {
      final h = await _authHeaders();
      final body = <String, dynamic>{
        'trip_id': widget.tripId,
        'device_id': widget.deviceId,
        'latitude': _currentPos.latitude,
        'longitude': _currentPos.longitude,
        'duration_seconds': _seconds,
        'distance_km': double.parse(_distanceKm.toStringAsFixed(3)),
      };
      final res = await http.post(Uri.parse('$BASE_URL/api/trips/end'), headers: h, body: jsonEncode(body));
      final data = jsonDecode(res.body);
      if (data['error'] == 'zone_violation') {
        setState(() => _ending = false);
        if (mounted) showDialog(context: context, builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [Icon(Icons.location_off, color: kOrange), SizedBox(width: 8), Flexible(child: Text('ზონის გარეთ ხარ!'))]),
            content: Text('${data['message']}\n\nტარიფი გრძელდება სანამ მწვანე ზონაში არ დაბრუნდები.'),
            actions: [ElevatedButton(onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: kGreen),
                child: const Text('გავიგე', style: TextStyle(color: Colors.white)))]));
        return;
      }
      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('active_trip_id');
        await prefs.remove('active_device_id');
        _timer?.cancel();
        _locationTimer?.cancel();
        if (mounted) showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [Icon(Icons.check_circle, color: kGreen), SizedBox(width: 8), Text('მგზავრობა დასრულდა')]),
            content: Text('დრო: ${data['minutes']} წუთი\nმანძილი: ${_distanceKm.toStringAsFixed(2)} კმ\nგადახდილი: ₾${data['amount']}'),
            actions: [ElevatedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(context, _route(const MainScreen()), (_) => false),
                style: ElevatedButton.styleFrom(backgroundColor: kGreen),
                child: const Text('დახურვა', style: TextStyle(color: Colors.white)))]));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('შეცდომა — სცადე ახლიდან')));
    }
    if (mounted) setState(() => _ending = false);
  }

  @override
  Widget build(BuildContext context) {
    final typeIcon = kTypeIcons[_vehicleType] ?? '🛴';
    return Scaffold(
      body: Column(children: [
        // ══ Google Maps ══
        Expanded(
          child: Stack(children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _currentPos, zoom: 16),
              onMapCreated: (c) {
                _mapCtrl = c;
                if (_currentPos.latitude != 41.6938) {
                  _cameraReady = true;
                  _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(_currentPos, 17));
                }
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              polygons: _polygons,
              markers: {
                Marker(
                  markerId: const MarkerId('scooter'),
                  position: _currentPos,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                ),
              },
            ),
            // device + type
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: kDark.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(typeIcon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(widget.deviceId, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            // zone status
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: _inZone ? kGreen.withOpacity(0.9) : kOrange.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_inZone ? Icons.check_circle : Icons.warning, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(_inZone ? 'ზონაშია' : 'ზონის გარეთ!',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            // re-center button
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'fab_recenter',
                mini: true,
                backgroundColor: Colors.white,
                onPressed: () => _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(_currentPos, 17)),
                child: const Icon(Icons.my_location, color: kGreen),
              ),
            ),
          ]),
        ),

        // ══ სტატისტიკა + ღილაკი ══
        Container(
          color: kDark,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(children: [
            Row(children: [
              _statCard('დრო', _timeStr, 'წთ:წმ', Icons.access_time),
              const SizedBox(width: 8),
              _statCard('მანძილი', _distanceKm.toStringAsFixed(2), 'კმ', Icons.route),
              const SizedBox(width: 8),
              _statCard('ღირებულება', '₾${_cost.toStringAsFixed(2)}', '${_perMinuteRate.toStringAsFixed(2)}/წთ', Icons.attach_money, green: true),
            ]),
            const SizedBox(height: 12),
            SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                    icon: _ending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.stop_circle, color: Colors.white, size: 22),
                    label: Text(
                        _ending ? 'მუშავდება...' : 'მგზავრობის დასრულება',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: _ending ? null : _endRide),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ]),
    );
  }

  Widget _statCard(String label, String value, String unit, IconData icon, {bool green = false}) =>
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(icon, color: green ? kGreen : Colors.white54, size: 18),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(
              color: green ? kGreen : Colors.white,
              fontSize: 16, fontWeight: FontWeight.bold)),
          Text(unit, style: const TextStyle(color: Colors.white38, fontSize: 9)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ]),
      ));
}

// ═══════════════════════════════════════════════════════════
// TRIPS SCREEN
// ═══════════════════════════════════════════════════════════
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
  @override State<TripsScreen> createState() => _TripsScreenState();
}
class _TripsScreenState extends State<TripsScreen> {
  List _trips = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final h = await _authHeaders();
      final res = await http.get(Uri.parse('$BASE_URL/api/trips'), headers: h);
      final d = jsonDecode(res.body);
      setState(() { _trips=d is List?d:(d['trips']??[]); _loading=false; });
    } catch (_) { setState(()=>_loading=false); }
  }

  Future<void> _openActiveTrip(Map t) async {
    final prefs = await SharedPreferences.getInstance();
    final tripId = t['id'] is int ? t['id'] as int : int.parse(t['id'].toString());
    final deviceId = t['device_id']?.toString() ?? '';
    await prefs.setInt('active_trip_id', tripId);
    await prefs.setString('active_device_id', deviceId);
    // pricing trip-ის snapshot-დან (server-ი ინახავს trip-ში)
    final perMin = double.tryParse(t['per_minute_rate']?.toString() ?? '') ?? 0.15;
    final unlock = double.tryParse(t['unlock_fee']?.toString() ?? '') ?? 0;
    final perKm = double.tryParse(t['per_km_rate']?.toString() ?? '') ?? 0;
    final vType = t['vehicle_type']?.toString() ?? 'scooter';
    if (mounted) Navigator.pushAndRemoveUntil(context,
        _route(ActiveRideScreen(
          tripId: tripId, deviceId: deviceId,
          perMinuteRate: perMin, unlockFee: unlock, perKmRate: perKm, vehicleType: vType,
        )),
            (_)=>false);
  }

  @override Widget build(BuildContext context) => Scaffold(backgroundColor: kBg,
      appBar: AppBar(backgroundColor: kDark, automaticallyImplyLeading: false,
          title: const Text('ჩემი მგზავრობები',style:TextStyle(color:Colors.white)),
          actions: [IconButton(icon:const Icon(Icons.refresh,color:Colors.white),onPressed:_load)]),
      body: _loading?const Center(child:CircularProgressIndicator(color:kGreen))
          :_trips.isEmpty?Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
        Icon(Icons.history,size:80,color:Colors.grey[300]),const SizedBox(height:16),
        Text('მგზავრობები ჯერ არ გაქვს',style:TextStyle(color:Colors.grey[500],fontSize:16)),
        const SizedBox(height:8),Text('QR სკანირებით დაიწყე!',style:TextStyle(color:Colors.grey[400],fontSize:13))]))
          :ListView.builder(padding:const EdgeInsets.all(16),itemCount:_trips.length,itemBuilder:(_,i){
        final t=_trips[i];
        final done=t['status']=='completed';
        final active = t['status']=='active';
        final vType = t['vehicle_type']?.toString() ?? 'scooter';
        final typeIcon = kTypeIcons[vType] ?? '🛴';
        return Container(margin:const EdgeInsets.only(bottom:12),
            decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.04),blurRadius:8)]),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: active ? () => _openActiveTrip(t) : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children:[
                    Container(width:48,height:48,decoration:BoxDecoration(color:kGreen.withOpacity(0.1),shape:BoxShape.circle),
                        child:Center(child: Text(typeIcon, style: const TextStyle(fontSize: 24)))),
                    const SizedBox(width:14),
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Text(t['device_id']??'—',style:const TextStyle(fontWeight:FontWeight.bold,color:kDark)),
                      if(t['duration_minutes']!=null)Text('${t['duration_minutes']} წუთი',style:TextStyle(color:Colors.grey[500],fontSize:12)),
                      Text('₾${t['amount_paid']??0}',style:const TextStyle(color:kGreen,fontWeight:FontWeight.w600))])),
                    Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
                        decoration:BoxDecoration(color:done?kGreen.withOpacity(0.1):kOrange.withOpacity(0.1),borderRadius:BorderRadius.circular(8)),
                        child:Text(done?'დასრულდა':(t['status']??'—'),
                            style:TextStyle(color:done?kGreen:kOrange,fontSize:12,fontWeight:FontWeight.w600))),
                    if (active) const Padding(padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.arrow_forward_ios, size: 14, color: kOrange)),
                  ]),
                ),
              ),
            ));
      }));
}

// ═══════════════════════════════════════════════════════════
// MENU SCREEN
// ═══════════════════════════════════════════════════════════
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override State<MenuScreen> createState() => _MenuScreenState();
}
class _MenuScreenState extends State<MenuScreen> {
  String _username='', _email='', _photoUrl='';
  bool _verified=false, _hasCard=false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username')  ?? '—';
      _email    = prefs.getString('email')     ?? '';
      _photoUrl = prefs.getString('photo_url') ?? '';
      _verified = prefs.getBool('verified')    ?? false;
      _hasCard  = prefs.getBool('has_card')    ?? false;
    });
    try {
      final h = await _authHeaders();
      final res = await http.get(Uri.parse('$BASE_URL/api/user/card-status'), headers: h);
      final d = jsonDecode(res.body);
      if (d['has_card']!=null) { await prefs.setBool('has_card',d['has_card']==true); if (mounted) setState(()=>_hasCard=d['has_card']==true); }
    } catch (_) {}
  }

  Future<void> _logout() async {
    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.pushAndRemoveUntil(context,_route(const LoginScreen()),(_)=>false);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try { if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); return; } } catch (_) {}
    try { await launchUrl(uri, mode: LaunchMode.platformDefault); return; } catch (_) {}
    try { await launchUrl(uri, mode: LaunchMode.inAppBrowserView); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ვერ გაიხსნა'))); }
  }

  @override Widget build(BuildContext context) => Scaffold(backgroundColor: kBg,
      appBar: AppBar(backgroundColor: kDark, automaticallyImplyLeading: false,
          title: const Text('მენიუ', style: TextStyle(color: Colors.white))),
      body: SingleChildScrollView(child: Column(children: [
        Container(width: double.infinity, color: kDark, padding: const EdgeInsets.fromLTRB(24,28,24,28),
            child: Row(children: [
              _photoUrl.isNotEmpty
                  ? CircleAvatar(radius: 34, backgroundImage: NetworkImage(_photoUrl), onBackgroundImageError: (_,__)  {})
                  : Container(width:68,height:68, decoration:const BoxDecoration(gradient:LinearGradient(colors:[kGreen,kOrange]),shape:BoxShape.circle),
                  child:const Icon(Icons.person,size:36,color:Colors.white)),
              const SizedBox(width:16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hello, $_username', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                if (_email.isNotEmpty) ...[const SizedBox(height:2), Text(_email, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12))],
                const SizedBox(height:6),
                Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:3),
                    decoration: BoxDecoration(color: _verified?kGreen.withOpacity(0.2):Colors.yellow.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text(_verified?'✅ Verified':'⚠️ Unverified',
                        style: TextStyle(color: _verified?kGreen:Colors.yellow[700], fontSize:11, fontWeight:FontWeight.w600))),
              ])),
            ])),
        const SizedBox(height: 12),
        _section([
          _tile(Icons.person_outline, 'Account & Settings',
              trailing: !_verified ? _badge('Unverified', Colors.yellow[700]!) : null,
              onTap: () => Navigator.push(context, _route(AccountSettingsScreen(onUpdate: _load)))),
          _div(),
          _tile(Icons.account_balance_wallet_outlined, 'საფულე',
              onTap: () => Navigator.push(context, _route(const WalletScreen()))),
          _div(),
          _tile(Icons.credit_card_outlined, 'Wallet & Payments',
              trailing: !_hasCard ? _badge('ბარათი არ არის', kOrange) : null,
              onTap: () => Navigator.push(context, _route(const CardScreen())).then((_)=>_load())),
        ]),
        const SizedBox(height: 12),
        _section([
          _tile(Icons.privacy_tip_outlined,     'Privacy Policy',  onTap: () => _openUrl('$BASE_URL/privacy')),
          _div(),
          _tile(Icons.chat_bubble_outline,      'Live Chat',       onTap: () => _openUrl('https://wa.me/995568877899')),
          _div(),
          _tile(Icons.help_outline,             'FAQ',             onTap: () => Navigator.push(context, _route(FaqScreen()))),
          _div(),
          _tile(Icons.shield_outlined,          'Safety',          onTap: () => Navigator.push(context, _route(SafetyScreen()))),
          _div(),
          _tile(Icons.directions_bike_outlined, 'How to Ride',     onTap: () => Navigator.push(context, _route(HowToRideScreen()))),
        ]),
        const SizedBox(height: 12),
        _section([_tile(Icons.logout, 'გამოსვლა', color: Colors.red, onTap: _logout)]),
        const SizedBox(height: 32),
        Column(children: [
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Ride Green ', style: TextStyle(color: Colors.grey, fontSize: 14)),
            Text('💚', style: TextStyle(fontSize: 14))]),
          const SizedBox(height: 4),
          Text('Version $APP_VERSION', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ]),
        const SizedBox(height: 24),
      ])));

  Widget _section(List<Widget> children) => Container(margin: const EdgeInsets.symmetric(horizontal:16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(children: children));

  Widget _tile(IconData icon, String title, {VoidCallback? onTap, Color? color, Widget? trailing}) =>
      ListTile(
          leading: Container(width:38,height:38,
              decoration:BoxDecoration(color:(color??kGreen).withOpacity(0.1),borderRadius:BorderRadius.circular(10)),
              child:Icon(icon,color:color??kGreen,size:20)),
          title: Text(title, style: TextStyle(color:color??kDark, fontWeight:FontWeight.w500, fontSize:15)),
          trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size:14, color:Colors.grey),
          onTap: onTap);

  Widget _div() => const Divider(height:1, indent:68, endIndent:16);

  Widget _badge(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal:8,vertical:3),
      decoration: BoxDecoration(color:color.withOpacity(0.15),borderRadius:BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color:color,fontSize:11,fontWeight:FontWeight.w600)));
}

// ═══════════════════════════════════════════════════════════
// ACCOUNT SETTINGS SCREEN
// ═══════════════════════════════════════════════════════════
class AccountSettingsScreen extends StatefulWidget {
  final VoidCallback? onUpdate;
  const AccountSettingsScreen({super.key, this.onUpdate});
  @override State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}
class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  String _username='', _email='', _photoUrl=''; bool _verified=false;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username=prefs.getString('username')??'—';
      _email=prefs.getString('email')??'';
      _photoUrl=prefs.getString('photo_url')??'';
      _verified=prefs.getBool('verified')??false;
    });
  }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: kBg,
      appBar: AppBar(backgroundColor: kDark,
          title: const Text('Account & Settings',style:TextStyle(color:Colors.white)),
          leading: IconButton(icon:const Icon(Icons.arrow_back,color:Colors.white),onPressed:()=>Navigator.pop(context))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        Container(padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.05),blurRadius:10)]),
            child: Column(children: [
              _photoUrl.isNotEmpty
                  ? CircleAvatar(radius:44,backgroundImage:NetworkImage(_photoUrl),onBackgroundImageError:(_,__)  {})
                  : Container(width:88,height:88,decoration:const BoxDecoration(gradient:LinearGradient(colors:[kGreen,kOrange]),shape:BoxShape.circle),
                  child:const Icon(Icons.person,size:44,color:Colors.white)),
              const SizedBox(height:14),
              Text(_username,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold,color:kDark)),
              const SizedBox(height:10),
              Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:5),
                  decoration:BoxDecoration(color:_verified?kGreen.withOpacity(0.1):Colors.yellow.withOpacity(0.15),borderRadius:BorderRadius.circular(20)),
                  child:Text(_verified?'✅ Verified':'⚠️ Unverified',
                      style:TextStyle(color:_verified?kGreen:Colors.yellow[800],fontWeight:FontWeight.w600)))])),
        const SizedBox(height:20),
        if (!_verified) Container(padding:const EdgeInsets.all(16),
            decoration:BoxDecoration(color:Colors.yellow.withOpacity(0.08),borderRadius:BorderRadius.circular(14),border:Border.all(color:Colors.yellow.withOpacity(0.3))),
            child:const Row(children:[Icon(Icons.warning_amber,color:Colors.orange),SizedBox(width:12),
              Expanded(child:Text('ანგარიშის ვერიფიკაციისთვის დაუკავშირდი მხარდაჭერას',style:TextStyle(fontSize:13,color:kDark)))])),
        const SizedBox(height:16),
        Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.04),blurRadius:8)]),
            child:Column(children:[
              _iRow(Icons.person,'სახელი',_username),
              const Divider(height:1,indent:56),
              _iRow(Icons.email_outlined,'ელ-ფოსტა',_email.isNotEmpty?_email:'—')])),
      ])));

  Widget _iRow(IconData icon, String label, String value) => ListTile(
      leading: Icon(icon,color:kGreen,size:22),
      title: Text(label,style:TextStyle(color:Colors.grey[500],fontSize:12)),
      subtitle: Text(value,style:const TextStyle(color:kDark,fontWeight:FontWeight.w500,fontSize:15)));
}

// ═══════════════════════════════════════════════════════════
// CARD SCREEN
// ═══════════════════════════════════════════════════════════
class CardScreen extends StatefulWidget {
  const CardScreen({super.key});
  @override State<CardScreen> createState() => _CardScreenState();
}
class _CardScreenState extends State<CardScreen> {
  bool _loading=false, _hasCard=false; Map? _cardInfo;
  @override void initState() { super.initState(); _loadCard(); }

  Future<void> _loadCard() async {
    setState(()=>_loading=true);
    try {
      final h = await _authHeaders();
      final res = await http.get(Uri.parse('$BASE_URL/api/user/card-status'), headers: h);
      final d = jsonDecode(res.body);
      if (mounted) setState(() { _hasCard=d['has_card']==true; _cardInfo=d['card']; });
    } catch (_) {}
    if (mounted) setState(()=>_loading=false);
  }

  Future<void> _addCard() async {
    setState(()=>_loading=true);
    try {
      final h = await _authHeaders();
      final res = await http.post(Uri.parse('$BASE_URL/api/bog/save-card'), headers: h,
          body: jsonEncode({'return_url': '$BASE_URL/card-success'}));
      final d = jsonDecode(res.body);
      if (d['redirect_url']!=null) {
        setState(()=>_loading=false);
        if (!mounted) return;
        final result = await Navigator.push<bool>(context, MaterialPageRoute<bool>(builder: (_) =>
            BogWebViewScreen(
              url: d['redirect_url'] as String,
              title: 'ბარათის დამატება — BOG',
              onSuccess: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('has_card', true);
              },
            )
        ));
        if (result == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('has_card', true);
          await _loadCard();
        }
        return;
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('სერვერის შეცდომა')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('კავშირის შეცდომა')));
    }
    if (mounted) setState(()=>_loading=false);
  }

  Future<void> _removeCard() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        title: const Text('ბარათის წაშლა'), content: const Text('დარწმუნებული ხარ?'),
        actions: [TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('გაუქმება')),
          ElevatedButton(onPressed:()=>Navigator.pop(context,true),style:ElevatedButton.styleFrom(backgroundColor:Colors.red),
              child:const Text('წაშლა',style:TextStyle(color:Colors.white)))]));
    if (ok!=true) return;
    setState(()=>_loading=true);
    try {
      final h = await _authHeaders();
      await http.delete(Uri.parse('$BASE_URL/api/user/card'), headers: h);
      final prefs = await SharedPreferences.getInstance(); await prefs.setBool('has_card',false);
      await _loadCard();
    } catch (_) {}
    if (mounted) setState(()=>_loading=false);
  }

  @override Widget build(BuildContext context) => Scaffold(backgroundColor: kBg,
      appBar: AppBar(backgroundColor: kDark,
          title: const Text('Wallet & Payments',style:TextStyle(color:Colors.white)),
          leading: IconButton(icon:const Icon(Icons.arrow_back,color:Colors.white),onPressed:()=>Navigator.pop(context))),
      body: _loading?const Center(child:CircularProgressIndicator(color:kGreen))
          :Padding(padding:const EdgeInsets.all(20),child:Column(children:[
        Container(width:double.infinity,height:190,
            decoration:BoxDecoration(gradient:const LinearGradient(colors:[kDark,Color(0xFF2E4D3A)],begin:Alignment.topLeft,end:Alignment.bottomRight),
                borderRadius:BorderRadius.circular(20),boxShadow:[BoxShadow(color:kDark.withOpacity(0.35),blurRadius:20,offset:const Offset(0,8))]),
            padding:const EdgeInsets.all(24),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                const Text('VELOCAR',style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.bold,letterSpacing:2)),
                Icon(_hasCard?Icons.credit_card:Icons.credit_card_off,color:Colors.white.withOpacity(0.6),size:28)]),
              const Spacer(),
              Text(_hasCard&&_cardInfo?['masked_number']!=null?_cardInfo!['masked_number']:'•••• •••• •••• ••••',
                  style:TextStyle(color:Colors.white.withOpacity(0.9),fontSize:20,letterSpacing:4,fontWeight:FontWeight.w300)),
              const SizedBox(height:16),
              Row(mainAxisAlignment:MainAxisAlignment.start,children:[
                Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('CARDHOLDER',style:TextStyle(color:Colors.white.withOpacity(0.4),fontSize:10,letterSpacing:1)),
                  const SizedBox(height:2),
                  Text(_hasCard?(_cardInfo?['holder']??'Velocar User'):'—',style:const TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w500))]),
                const Spacer(),
                if (_hasCard&&_cardInfo?['expiry']!=null) Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('EXPIRES',style:TextStyle(color:Colors.white.withOpacity(0.4),fontSize:10,letterSpacing:1)),
                  const SizedBox(height:2),
                  Text(_cardInfo!['expiry'],style:const TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w500))])])])),
        const SizedBox(height:20),
        Container(padding:const EdgeInsets.all(16),
            decoration:BoxDecoration(color:_hasCard?kGreen.withOpacity(0.08):Colors.orange.withOpacity(0.08),borderRadius:BorderRadius.circular(14),border:Border.all(color:_hasCard?kGreen.withOpacity(0.2):kOrange.withOpacity(0.2))),
            child:Row(children:[Icon(_hasCard?Icons.check_circle:Icons.info_outline,color:_hasCard?kGreen:kOrange),const SizedBox(width:12),
              Expanded(child:Text(_hasCard?'ბარათი მიბმულია. გაქირავება ავტომატურად ჩამოეჭრება.':'ბარათი არ არის მიბმული.',
                  style:TextStyle(color:_hasCard?kGreen:kOrange,fontSize:13)))])),
        const SizedBox(height:20),
        SizedBox(width:double.infinity,height:54,
            child:ElevatedButton.icon(icon:Icon(_hasCard?Icons.edit:Icons.add_card,color:Colors.white),
                label:Text(_hasCard?'ბარათის შეცვლა':'ბარათის დამატება (BOG)',style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold,color:Colors.white)),
                style:ElevatedButton.styleFrom(backgroundColor:kGreen,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
                onPressed:_addCard)),
        if (_hasCard)...[const SizedBox(height:12),
          SizedBox(width:double.infinity,height:48,
              child:OutlinedButton.icon(icon:const Icon(Icons.delete_outline,color:Colors.red),
                  label:const Text('ბარათის წაშლა',style:TextStyle(color:Colors.red,fontWeight:FontWeight.w600)),
                  style:OutlinedButton.styleFrom(side:const BorderSide(color:Colors.red),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
                  onPressed:_removeCard))],
        const Spacer(),
        Text('გადახდა უზრუნველყოფილია Bank of Georgia-ს მიერ',style:TextStyle(color:Colors.grey[400],fontSize:12)),
      ])));
}

// ═══════════════════════════════════════════════════════════
// FAQ SCREEN
// ═══════════════════════════════════════════════════════════
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});
  static final _faqs = [
    ('როგორ დავიწყო გაქირავება?',    'გახსენი აპი, დააჭირე QR სკანირება და დაასკანირე მოწყობილობაზე არსებული QR კოდი.'),
    ('რა ღირს გაქირავება?',          'დამოკიდებულია მოწყობილობის ტიპზე — სქროლი ₾0.15/წთ, ველო ₾0.10/წთ, მანქანა ₾0.50/წთ + კმ-ის ფასი.'),
    ('სად შემიძლია მოწყობილობის დატოვება?','დატოვე მწვანე ზონაში — რუკაზე ნაჩვენები სერვის არეალი.'),
    ('ბატარეა გამოილია — რა ვქნა?',  'მაინც შეაჩერე აპიდან. დაგვიკავშირდი Live Chat-ის გზით.'),
    ('გადახდა ვერ მოხდა — რა ვქნა?', 'შეამოწმე ბარათი Wallet & Payments-ში. BOG ბარათი უნდა იყოს მიბმული.'),
    ('მგზავრობა ვერ ვხედავ?',         'ისტორია ტაბზე ნახავ ყველა მგზავრობას. პრობლემის შემთხვევაში Live Chat-ზე გვწერე.'),
  ];
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: kBg,
      appBar: AppBar(backgroundColor:kDark, title:const Text('FAQ',style:TextStyle(color:Colors.white)),
          leading:IconButton(icon:const Icon(Icons.arrow_back,color:Colors.white),onPressed:()=>Navigator.pop(context))),
      body: ListView.builder(padding:const EdgeInsets.all(16),itemCount:_faqs.length,itemBuilder:(_,i){
        final (q,a) = _faqs[i];
        return Container(margin:const EdgeInsets.only(bottom:12),
            decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.04),blurRadius:8)]),
            child:ExpansionTile(
                leading:Container(width:32,height:32,decoration:BoxDecoration(color:kGreen.withOpacity(0.1),shape:BoxShape.circle),child:const Icon(Icons.help_outline,color:kGreen,size:18)),
                title:Text(q,style:const TextStyle(fontWeight:FontWeight.w600,color:kDark,fontSize:14)),
                children:[Padding(padding:const EdgeInsets.fromLTRB(16,0,16,16),
                    child:Text(a,style:TextStyle(color:Colors.grey[600],fontSize:13,height:1.5)))]));
      }));
}

// ═══════════════════════════════════════════════════════════
// SAFETY SCREEN
// ═══════════════════════════════════════════════════════════
class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});
  static final _rules = [
    (Icons.security,      'ჩაფხუტი',       'გამოიყენე ჩაფხუტი სიარულის დროს.'),
    (Icons.speed,         'სიჩქარე',        'ქალაქში მაქსიმუმ 25 კმ/სთ.'),
    (Icons.no_drinks,     'ალკოჰოლი',       'ალკოჰოლის ზემოქმედებით სიარული მკაცრად აკრძალულია.'),
    (Icons.people,        'ერთი მგზავრი',   'მოწყობილობაზე ერთი ადამიანი იჯდება.'),
    (Icons.phone_android, 'ტელეფონი',       'სიარულის დროს ტელეფონის გამოყენება საშიშია.'),
    (Icons.park,          'ქვეითთა ბილიკი', 'ქვეითთა ბილიკებზე სიარული აკრძალულია.'),
  ];
  @override Widget build(BuildContext context) => Scaffold(backgroundColor:kBg,
      appBar:AppBar(backgroundColor:kDark,title:const Text('Safety',style:TextStyle(color:Colors.white)),
          leading:IconButton(icon:const Icon(Icons.arrow_back,color:Colors.white),onPressed:()=>Navigator.pop(context))),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Container(padding:const EdgeInsets.all(16),margin:const EdgeInsets.only(bottom:16),
            decoration:BoxDecoration(color:kGreen.withOpacity(0.08),borderRadius:BorderRadius.circular(14),border:Border.all(color:kGreen.withOpacity(0.2))),
            child:const Row(children:[Icon(Icons.shield,color:kGreen),SizedBox(width:12),
              Expanded(child:Text('შენი უსაფრთხოება ჩვენთვის პრიორიტეტია.',style:TextStyle(color:kGreen,fontWeight:FontWeight.w600)))])),
        ..._rules.map((r){
          final icon=r.$1; final title=r.$2; final desc=r.$3;
          return Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.04),blurRadius:8)]),
              child:Row(children:[Container(width:44,height:44,decoration:BoxDecoration(color:kGreen.withOpacity(0.1),shape:BoxShape.circle),child:Icon(icon,color:kGreen,size:22)),
                const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(title,style:const TextStyle(fontWeight:FontWeight.bold,color:kDark)),const SizedBox(height:2),
                  Text(desc,style:TextStyle(color:Colors.grey[600],fontSize:13))]))]));
        })
      ]));
}

// ═══════════════════════════════════════════════════════════
// HOW TO RIDE SCREEN
// ═══════════════════════════════════════════════════════════
class HowToRideScreen extends StatelessWidget {
  const HowToRideScreen({super.key});
  static final _steps = [
    (Icons.download_done,        'აპის გახსნა',   'გახსენი Velocar და შედი შენი ანგარიშით.'),
    (Icons.qr_code_scanner,      'QR სკანირება',  'მოწყობილობასთან მიახლოვდი და დაასკანირე QR კოდი.'),
    (Icons.payment,              'გადახდა',       'BOG ბარათით გაიარე გადახდა. მოწყობილობა იხსნება.'),
    (Icons.electric_scooter,     'სიარული',       'გამოიყენე მოწყობილობა. ყურადღება მიმოქცევაზე!'),
    (Icons.location_on,          'სერვის ზონა',   'დარჩი მწვანე ზონაში — გარეთ გასვლა დაუშვებელია.'),
    (Icons.stop_circle_outlined, 'დასრულება',     'ჩააპარკე სწორ ადგილას და დაასრულე გაქირავება.'),
  ];
  @override Widget build(BuildContext context) => Scaffold(backgroundColor:kBg,
      appBar:AppBar(backgroundColor:kDark,title:const Text('How to Ride',style:TextStyle(color:Colors.white)),
          leading:IconButton(icon:const Icon(Icons.arrow_back,color:Colors.white),onPressed:()=>Navigator.pop(context))),
      body:ListView.builder(padding:const EdgeInsets.all(16),itemCount:_steps.length,itemBuilder:(_,i){
        final step=_steps[i];
        final icon=step.$1; final title=step.$2; final desc=step.$3;
        return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Column(children:[Container(width:44,height:44,decoration:const BoxDecoration(color:kGreen,shape:BoxShape.circle),
              child:Center(child:Icon(icon,color:Colors.white,size:22))),
            if(i<_steps.length-1)Container(width:2,height:40,color:kGreen.withOpacity(0.2))]),
          const SizedBox(width:16),
          Expanded(child:Padding(padding:const EdgeInsets.only(bottom:24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const SizedBox(height:10),Text(title,style:const TextStyle(fontWeight:FontWeight.bold,color:kDark,fontSize:15)),
            const SizedBox(height:4),Text(desc,style:TextStyle(color:Colors.grey[600],fontSize:13,height:1.5))])))]);
      }));
}

// ═══════════════════════════════════════════════════════════
// WALLET SCREEN — ბალანსი + Top-up ღილაკები + Transactions
// ═══════════════════════════════════════════════════════════
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 0;
  List _transactions = [];
  bool _loading = true;
  bool _topupBusy = false;

  @override void initState() { super.initState(); _load(); }

  Future<Map<String, String>> _hdr() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('session_token') ?? '';
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $t'};
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final r = await http.get(Uri.parse('$BASE_URL/api/wallet/balance'), headers: await _hdr());
      final d = jsonDecode(r.body);
      if (d is Map && d['success'] == true && mounted) {
        setState(() {
          final b = d['balance'];
          _balance = (b is num) ? b.toDouble() : double.tryParse(b?.toString() ?? '') ?? 0;
          final txs = d['transactions'];
          _transactions = (txs is List) ? txs : [];
        });
      }
    } catch (e) {
      // ignore — UI keeps last known state
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _topup(double amount) async {
    if (_topupBusy) return;
    setState(() => _topupBusy = true);
    try {
      final r = await http.post(
        Uri.parse('$BASE_URL/api/wallet/topup'),
        headers: await _hdr(),
        body: jsonEncode({'amount': amount}),
      );
      final d = jsonDecode(r.body);

      if (d['success'] != true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red[700],
          content: Text(d['message']?.toString() ?? 'შევსება ვერ მოხერხდა'),
        ));
        return;
      }

      // auto_completed — saved card-ით 3DS გარეშე
      if (d['auto_completed'] == true) {
        await Future.delayed(const Duration(seconds: 2)); // callback-ის ლოდინი
        await _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text('საფულე შეივსო: +₾${amount.toStringAsFixed(2)}'),
        ));
        return;
      }

      // BOG WebView
      if (d['redirect_url'] != null && mounted) {
        final ok = await Navigator.push<bool>(context, MaterialPageRoute<bool>(
          builder: (_) => BogWebViewScreen(
            url: d['redirect_url'] as String,
            title: 'საფულის შევსება — ₾${amount.toStringAsFixed(2)}',
            onSuccess: () async {},
          ),
        ));
        if (ok == true) {
          // 15 ცდა × 2 წამი — callback-ის ლოდინი
          double oldBal = _balance;
          for (int i = 0; i < 15; i++) {
            await Future.delayed(const Duration(seconds: 2));
            await _load();
            if (_balance > oldBal) break;
          }
          if (mounted && _balance > oldBal) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: kGreen,
              content: Text('საფულე შეივსო: +₾${(_balance - oldBal).toStringAsFixed(2)}'),
            ));
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              backgroundColor: Colors.orange,
              content: Text('გადახდა მუშავდება. ისტორიის ჩანართში შეამოწმე.'),
            ));
          }
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red[700],
        content: Text('შეცდომა: ${e.toString()}'),
      ));
    } finally {
      if (mounted) setState(() => _topupBusy = false);
    }
  }

  String _txTypeLabel(String type) {
    switch (type) {
      case 'topup':  return 'შევსება';
      case 'trip':   return 'მგზავრობა';
      case 'refund': return 'დაბრუნება';
      case 'adjust': return 'კორექცია';
      default:       return type;
    }
  }

  IconData _txIcon(String type) {
    switch (type) {
      case 'topup':  return Icons.add_circle_outline;
      case 'trip':   return Icons.electric_scooter;
      case 'refund': return Icons.replay_circle_filled_outlined;
      default:       return Icons.swap_horiz;
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return iso; }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('საფულე', style: TextStyle(color: Colors.white)),
        backgroundColor: kDark,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          // ── ბალანსის ბარათი ──
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kDark, Color(0xFF2A4034)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 14, offset: const Offset(0, 4))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.account_balance_wallet, color: kGreen, size: 22),
                SizedBox(width: 8),
                Text('მიმდინარე ბალანსი', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ]),
              const SizedBox(height: 12),
              _loading
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                  : Text('₾${_balance.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Top-up ღილაკები ──
          const Text('სწრაფი შევსება', style: TextStyle(color: kDark, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _topupButton(5)),
            const SizedBox(width: 10),
            Expanded(child: _topupButton(10)),
            const SizedBox(width: 10),
            Expanded(child: _topupButton(20)),
          ]),
          const SizedBox(height: 24),

          // ── Transactions ──
          const Text('ბოლო ოპერაციები', style: TextStyle(color: kDark, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (_transactions.isEmpty && !_loading)
            Padding(padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('ჯერ არ გაქვს ოპერაციები', style: TextStyle(color: Colors.grey[600]))))
          else
            ..._transactions.map((tx) => _txTile(tx)).toList(),
        ]),
      ),
    );
  }

  Widget _topupButton(double amount) {
    return ElevatedButton(
      onPressed: _topupBusy ? null : () => _topup(amount),
      style: ElevatedButton.styleFrom(
        backgroundColor: kGreen,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        disabledBackgroundColor: kGreen.withOpacity(0.4),
      ),
      child: _topupBusy
          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text('₾${amount.toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _txTile(dynamic tx) {
    if (tx == null || tx is! Map) return const SizedBox.shrink();
    final type = tx['type']?.toString() ?? '';
    final amount = (tx['amount'] is num) ? (tx['amount'] as num).toDouble() : double.tryParse(tx['amount']?.toString() ?? '') ?? 0;
    final balanceAfter = (tx['balance_after'] is num) ? (tx['balance_after'] as num).toDouble() : double.tryParse(tx['balance_after']?.toString() ?? '') ?? 0;
    final status = tx['status']?.toString() ?? '';
    final desc = tx['description']?.toString() ?? '';
    final created = tx['created_at']?.toString();

    final isCredit = amount > 0;
    final isPending = status == 'pending';
    final isFailed = status == 'failed';

    Color amountColor;
    if (isFailed) amountColor = Colors.grey;
    else if (isPending) amountColor = kOrange;
    else amountColor = isCredit ? kGreen : Colors.red[700]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: amountColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(_txIcon(type), color: amountColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(_txTypeLabel(type), style: const TextStyle(fontWeight: FontWeight.bold, color: kDark, fontSize: 14)),
            if (isPending) ...[const SizedBox(width: 6), Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: kOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Text('მიმდინარე', style: TextStyle(color: kOrange, fontSize: 10, fontWeight: FontWeight.w600)))],
            if (isFailed) ...[const SizedBox(width: 6), Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Text('წარუმატებელი', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600)))],
          ]),
          if (desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2),
              child: Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 12))),
          Text(_fmtDate(created), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${isCredit ? '+' : ''}₾${amount.toStringAsFixed(2)}',
              style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 15)),
          if (!isPending && !isFailed)
            Text('₾${balanceAfter.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ]),
      ]),
    );
  }
}
