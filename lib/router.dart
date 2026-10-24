import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'services/auth_service.dart';

GoRouter createRouter({
  required List<AppModule> activeModules,
  required AuthService authService,
}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => HomeScreen(activeModules: activeModules),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => RegisterScreen(authService: authService),
      ),
      // Susun seluruh rute dari setiap modul aktif
      ...activeModules.expand((m) => m.routes),
    ],
  );
}

/// Layar beranda utama yang menyusun kartu navigasi setiap modul.
class HomeScreen extends StatelessWidget {
  final List<AppModule> activeModules;

  const HomeScreen({super.key, required this.activeModules});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gumpalan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.app_registration),
            tooltip: 'Pendaftaran Perangkat',
            onPressed: () => context.push('/register'),
          ),
        ],
      ),
      body: activeModules.isEmpty
          ? const Center(child: Text('Tidak ada modul aktif.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: activeModules.length,
              itemBuilder: (context, index) {
                final module = activeModules[index];
                final card = module.homeCard;
                if (card != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: card,
                  );
                }
                return ListTile(
                  leading: Icon(module.icon),
                  title: Text(module.name),
                  onTap: () => context.push('/${module.id}'),
                );
              },
            ),
    );
  }
}

/// Layar pendaftaran perangkat dan cek status persetujuan terminal.
class RegisterScreen extends StatefulWidget {
  final AuthService authService;

  const RegisterScreen({super.key, required this.authService});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _deviceId;
  DeviceStatus? _status;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _deviceId = widget.authService.registeredDeviceId;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Nama perangkat wajib diisi');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await widget.authService.register(name);
      setState(() {
        _deviceId = res.deviceId;
        _status = res.status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mendaftar: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCheckStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await widget.authService.checkStatus();
      setState(() {
        _status = res.status;
        _isLoading = false;
      });

      if (!mounted) return;

      if (res.status == DeviceStatus.approved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perangkat DISETUJUI! Token berhasil disimpan.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/');
      } else if (res.status == DeviceStatus.revoked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Akses perangkat telah DICABUT (Revoked).'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status masih menunggu persetujuan di terminal.'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memeriksa status: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendaftaran Perangkat'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_deviceId == null) ...[
              const Text(
                'Daftarkan perangkat ini ke server Gumpalan.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'Nama Perangkat (contoh: HP Ruang Tamu)',
                  border: const OutlineInputBorder(),
                  errorText: _errorMessage,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Kirim Permintaan Pendaftaran'),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Perangkat',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text('Device ID: $_deviceId'),
                      const SizedBox(height: 4),
                      Text('Status: ${_status?.name ?? "pending"}'),
                      const Divider(height: 24),
                      const Text(
                        'Persetujuan Admin Diperlukan:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jalankan perintah ini di terminal server:\nauth device approve $_deviceId',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cek Status Persetujuan'),
                onPressed: _isLoading ? null : _handleCheckStatus,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
