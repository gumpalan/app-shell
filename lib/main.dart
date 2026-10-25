import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';

/// Entry point aplikasi Gumpalan.
/// Menginisialisasi binding framework dan memuat konfigurasi lingkungan dari .env.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const GumpalanApp());
}
