import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

const String BASE_URL = 'http://178.104.196.214:5005';

void main() {
  runApp(const GeoScrollApp());
}

class GeoScrollApp extends StatelessWidget {
  const GeoScrollApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoScroll',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1a1a2e),
          primary: const Color(0xFF1a1a2e),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

// ==================== HELPERS ====================
Future<Map<String, String>> _authHeaders() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('session_token') ?? '';
  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    'Cookie': 'session_token=$token',
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
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => token != null && token.isNotEmpty
              ? const HomeScreen()
              : const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.electric_scooter, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'GeoScroll',
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            Text('სქროლის გაქირავება', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Color(0xFF60a5fa)),
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
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';

  Future<void> _login() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': _usernameCtrl.text, 'password': _passwordCtrl.text}),
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_token', data['token'] ?? '');
        await prefs.setString('username', data['user']?['username'] ?? _usernameCtrl.text);
        await prefs.setString('role', data['user']?['role'] ?? 'client');
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
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
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.electric_scooter, size: 80, color: Color(0xFF60a5fa)),
              const SizedBox(height: 16),
              const Text('GeoScroll', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('შედი სქროლის გასაქირავებლად', style: TextStyle(color: Colors.white.withOpacity(0.6))),
              const SizedBox(height: 48),
              TextField(
                controller: _usernameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'მომხმარებელი',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  prefixIcon: const Icon(Icons.person, color: Color(0xFF60a5fa)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'პაროლი',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF60a5fa)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF60a5fa),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}

// ==================== HOME ====================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _username = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'მომხმარებელი';
      _role = prefs.getString('role') ?? 'client';
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf0f2f5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('GeoScroll 🛴', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('გამარჯობა, $_username! 👋',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1a1a2e))),
            const SizedBox(height: 8),
            Text('აირჩიე რა გინდა გააკეთო', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 32),
            _MenuCard(
              icon: Icons.qr_code_scanner,
              title: 'QR სკანირება',
              subtitle: 'დაასკანირე სქროლი გასაქირავებლად',
              color: const Color(0xFF60a5fa),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScanScreen())),
            ),
            const SizedBox(height: 16),
            _MenuCard(
              icon: Icons.history,
              title: 'ჩემი მოგზაურობები',
              subtitle: 'ნახე წინა გაქირავებები',
              color: const Color(0xFF34d399),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripsScreen())),
            ),
            const SizedBox(height: 16),
            _MenuCard(
              icon: Icons.electric_scooter,
              title: 'სქროლების სია',
              subtitle: 'ნახე ხელმისაწვდომი სქროლები',
              color: const Color(0xFFf59e0b),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())),
            ),
            const SizedBox(height: 16),
            _MenuCard(
              icon: Icons.credit_card,
              title: 'ბარათის მართვა',
              subtitle: 'მიაბი ან შეცვალე გადახდის ბარათი',
              color: const Color(0xFF8b5cf6),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CardScreen())),
            ),
            const SizedBox(height: 16),
            _MenuCard(
              icon: Icons.person,
              title: 'პროფილი',
              subtitle: 'პირადი ინფორმაცია და პარამეტრები',
              color: const Color(0xFFec4899),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1a1a2e))),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
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
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf0f2f5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('პროფილი', style: TextStyle(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF60a5fa).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, size: 48, color: Color(0xFF60a5fa)),
                  ),
                  const SizedBox(height: 16),
                  Text(_username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34d399).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_role, style: const TextStyle(color: Color(0xFF34d399), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _ProfileTile(icon: Icons.credit_card, title: 'ბარათის მართვა',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CardScreen()))),
                  const Divider(height: 1),
                  _ProfileTile(icon: Icons.history, title: 'ჩემი მოგზაურობები',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripsScreen()))),
                  const Divider(height: 1),
                  _ProfileTile(icon: Icons.logout, title: 'გამოსვლა', color: Colors.red, onTap: _logout),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _ProfileTile({required this.icon, required this.title, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF1a1a2e)),
      title: Text(title, style: TextStyle(color: color ?? const Color(0xFF1a1a2e), fontWeight: FontWeight.w500)),
      trailing: color == null ? const Icon(Icons.arrow_forward_ios, size: 16) : null,
      onTap: onTap,
    );
  }
}

// ==================== CARD SCREEN ====================
class CardScreen extends StatefulWidget {
  const CardScreen({super.key});

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _hasSavedCard = false;
  String _savedCardLast4 = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCard();
  }

  Future<void> _loadCard() async {
    final prefs = await SharedPreferences.getInstance();
    final last4 = prefs.getString('card_last4') ?? '';
    setState(() {
      _hasSavedCard = last4.isNotEmpty;
      _savedCardLast4 = last4;
    });
  }

  Future<void> _saveCard() async {
    if (_cardNumberCtrl.text.length < 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ბარათის ნომერი არასწორია')),
      );
      return;
    }
    setState(() { _loading = true; });
    await Future.delayed(const Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    final last4 = _cardNumberCtrl.text.replaceAll(' ', '').substring(_cardNumberCtrl.text.replaceAll(' ', '').length - 4);
    await prefs.setString('card_last4', last4);
    await prefs.setString('card_name', _nameCtrl.text);
    setState(() {
      _hasSavedCard = true;
      _savedCardLast4 = last4;
      _loading = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ ბარათი წარმატებით დაემატა'), backgroundColor: Color(0xFF34d399)),
      );
    }
  }

  Future<void> _removeCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('card_last4');
    await prefs.remove('card_name');
    setState(() { _hasSavedCard = false; _savedCardLast4 = ''; });
    _cardNumberCtrl.clear();
    _expiryCtrl.clear();
    _cvvCtrl.clear();
    _nameCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf0f2f5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('ბარათის მართვა', style: TextStyle(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasSavedCard) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('GeoScroll Card', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const Icon(Icons.credit_card, color: Color(0xFF60a5fa), size: 32),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('•••• •••• •••• $_savedCardLast4',
                        style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 3, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text(_nameCtrl.text.isEmpty ? 'ბარათის მფლობელი' : _nameCtrl.text,
                        style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('ბარათის წაშლა', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _removeCard,
                ),
              ),
            ] else ...[
              const Text('ახალი ბარათის დამატება', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1a1a2e))),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                child: Column(
                  children: [
                    _CardField(controller: _nameCtrl, label: 'სახელი გვარი', hint: 'GIORGI BERIDZE', icon: Icons.person),
                    const SizedBox(height: 16),
                    _CardField(controller: _cardNumberCtrl, label: 'ბარათის ნომერი', hint: '0000 0000 0000 0000',
                        icon: Icons.credit_card, keyboardType: TextInputType.number, maxLength: 19),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _CardField(controller: _expiryCtrl, label: 'ვადა', hint: 'MM/YY',
                            icon: Icons.calendar_today, maxLength: 5)),
                        const SizedBox(width: 16),
                        Expanded(child: _CardField(controller: _cvvCtrl, label: 'CVV', hint: '•••',
                            icon: Icons.lock, keyboardType: TextInputType.number, maxLength: 3, obscure: true)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ბარათის შენახვა', style: TextStyle(fontSize: 16, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8b5cf6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loading ? null : _saveCard,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('დაცული გადახდა', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool obscure;

  const _CardField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.maxLength,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1a1a2e))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF8b5cf6), size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
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
    final barcode = capture.barcodes.first;
    final value = barcode.rawValue ?? '';
    if (value.contains('device_id=')) {
      setState(() { _scanned = true; });
      final deviceId = value.split('device_id=').last;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ScooterDetailScreen(deviceId: deviceId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('QR სკანირება', style: TextStyle(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Center(
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF60a5fa), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 60, left: 0, right: 0,
            child: Text('QR კოდი მოათავსე ჩარჩოში', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16)),
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

  @override
  void initState() {
    super.initState();
    _loadScooter();
  }

  Future<void> _loadScooter() async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(Uri.parse('$BASE_URL/api/scooters'), headers: headers);
      final data = jsonDecode(res.body);
      if (data is List) {
        final scooter = data.firstWhere((s) => s['device_id'] == widget.deviceId, orElse: () => null);
        setState(() { _scooter = scooter; _loading = false; });
      } else {
        setState(() { _loading = false; });
      }
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf0f2f5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text('სქროლი: ${widget.deviceId}', style: const TextStyle(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _scooter == null
          ? const Center(child: Text('სქროლი ვერ მოიძებნა'))
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: Column(
                children: [
                  const Icon(Icons.electric_scooter, size: 80, color: Color(0xFF60a5fa)),
                  const SizedBox(height: 16),
                  Text(widget.deviceId, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _InfoRow('კომპანია', _scooter!['company_name'] ?? '—'),
                  _InfoRow('სტატუსი', _scooter!['status'] ?? '—'),
                  _InfoRow('ბატარეა', '${_scooter!['battery'] ?? 0}%'),
                  _InfoRow('ზონა', _scooter!['zone_name'] ?? '—'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_scooter!['status'] == 'available') ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.payment, color: Colors.white),
                  label: const Text('გაქირავება / გადახდა', style: TextStyle(fontSize: 16, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34d399),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(scooter: _scooter!))),
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block, color: Colors.red),
                    SizedBox(width: 8),
                    Text('სქროლი ხელმისაწვდომი არ არის', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            if (_scooter!['latitude'] != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('Google Maps-ზე ნახვა'),
                  onPressed: () async {
                    final lat = _scooter!['latitude'];
                    final lng = _scooter!['longitude'];
                    final url = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
                    await launchUrl(url);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
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
  final _amountCtrl = TextEditingController(text: '5');
  bool _loading = false;
  String _savedCardLast4 = '';

  @override
  void initState() {
    super.initState();
    _loadCard();
  }

  Future<void> _loadCard() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { _savedCardLast4 = prefs.getString('card_last4') ?? ''; });
  }

  Future<void> _pay() async {
    if (_savedCardLast4.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('ბარათი არ არის'),
          content: const Text('გადახდისთვის საჭიროა ბარათის მიბმა'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('გაუქმება')),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CardScreen()));
              },
              child: const Text('ბარათის დამატება'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() { _loading = true; });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() { _loading = false; });
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('✅ გადახდა წარმატებული'),
          content: Text('სქროლი ${widget.scooter['device_id']} გაქირავდა!\nთანხა: ₾${_amountCtrl.text}\nბარათი: •••• $_savedCardLast4'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('დახურვა'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf0f2f5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('გადახდა', style: TextStyle(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('გადახდის დეტალები', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _InfoRow('სქროლი', widget.scooter['device_id'] ?? ''),
                  _InfoRow('კომპანია', widget.scooter['company_name'] ?? ''),
                  if (_savedCardLast4.isNotEmpty)
                    _InfoRow('ბარათი', '•••• •••• •••• $_savedCardLast4'),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('თანხა (₾)', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: '₾ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_savedCardLast4.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('ბარათი არ არის მიბმული', style: TextStyle(color: Colors.orange))),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CardScreen())),
                      child: const Text('დამატება'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.credit_card, color: Colors.white),
                label: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('გადახდა 💳', style: TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1a1a2e),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading ? null : _pay,
              ),
            ),
          ],
        ),
      ),
    );
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
      setState(() {
        _trips = data is List ? data : (data['trips'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf0f2f5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('ჩემი მოგზაურობები', style: TextStyle(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('მოგზაურობები ჯერ არ გაქვს', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            const SizedBox(height: 8),
            Text('QR კოდის სკანირებით დაიწყე!', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trips.length,
        itemBuilder: (_, i) {
          final t = _trips[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.electric_scooter, color: Color(0xFF60a5fa), size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['device_id'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('₾${t['amount_paid'] ?? 0}', style: const TextStyle(color: Color(0xFF34d399), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF34d399).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(t['status'] ?? '—', style: const TextStyle(color: Color(0xFF34d399), fontSize: 12)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==================== MAP (სქროლების სია) ====================
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List _scooters = [];
  bool _loading = true;
  String _error = '';

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
        setState(() { _scooters = data; _loading = false; });
      } else {
        setState(() { _error = data['error'] ?? 'შეცდომა'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'სერვერთან კავშირის შეცდომა'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf0f2f5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('სქროლების სია', style: TextStyle(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () {
            setState(() { _loading = true; _error = ''; });
            _load();
          }),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load, child: const Text('თავიდან ცდა')),
        ],
      ))
          : _scooters.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.electric_scooter, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('სქროლები ვერ მოიძებნა', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _scooters.length,
        itemBuilder: (_, i) {
          final s = _scooters[i];
          final available = s['status'] == 'available';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.electric_scooter, color: available ? const Color(0xFF34d399) : Colors.grey, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['device_id'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(s['zone_name'] ?? 'ზონა არ არის', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text('🔋 ${s['battery'] ?? 0}%', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                if (available)
                  ElevatedButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ScooterDetailScreen(deviceId: s['device_id']))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF60a5fa),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('გაქირავება', style: TextStyle(color: Colors.white, fontSize: 12)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Text('დაკავებული', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}