import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

GoRouter createRouter({required List<AppModule> activeModules}) {
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
        builder: (context, state) => const RegisterScreen(),
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

/// Layar placeholder pendaftaran perangkat baru ke svc-auth.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendaftaran Perangkat'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Daftarkan perangkat ini ke server Gumpalan.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Nama Perangkat',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: Panggil DeviceRegistration.register dari core_api
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Permintaan pendaftaran terkirim (placeholder)')),
                );
              },
              child: const Text('Kirim Permintaan'),
            ),
          ],
        ),
      ),
    );
  }
}
