# app-shell (Gumpalan)

Host container aplikasi Flutter yang mengintegrasikan paket fondasi (`core_api`, `core_ui`) dengan modul-modul fitur mandiri (`app-mod-*`).

Aplikasi shell bertanggung jawab atas autentikasi perangkat pada tingkat OS, persistensi sesi kredensial, penanganan status otorisasi, dan perakitan rute dinamis antar-modul.

---

## Struktur Direktori

```text
app-shell/
├── .env.example                # Template konfigurasi variabel lingkungan
├── lib/
│   ├── app.dart                # MaterialApp.router, inisialisasi tema & guard splash
│   ├── main.dart               # Entry point eksekusi & loader .env
│   ├── modules_registry.dart   # Registri modul fitur & logika filter aktif
│   ├── router.dart             # Konfigurasi GoRouter komposit & HomeScreen
│   ├── screens/
│   │   ├── auth_status_screen.dart # Pemantauan status & instruksi approve CLI
│   │   └── landing_screen.dart     # Onboarding pendaftaran perangkat otomatis
│   └── services/
│       └── auth_service.dart   # Orkestrasi auth, token storage, & fingerprinting
└── test/
    ├── register_flow_test.dart # Unit & widget test alur pendaftaran, approve, & revoke
    └── widget_test.dart        # Smoke test startup aplikasi
```

---

## Alur Autentikasi dan State Machine Navigasi

Aplikasi shell mengelola tiga rute utama:

```text
             ┌────────────────┐
             │ Cold Start App │
             └───────┬────────┘
                     │ (Periksa token lokal & verifikasi backend)
                     ▼
             ┌───────────────┐
       ┌─────┤ _resolveRoute ├─────┐
       │     └───────┬───────┘     │
 (Belum ada)         │ (Pending/   │ (Approved)
       ▼             │  Revoked)   ▼
┌──────────────┐     │      ┌────────────┐
│   Landing    │     ▼      │    Home    │
│  Screen (/)  │  ┌───────┐ │Screen(/home│
└──────┬───────┘  │ Status│ └─────┬──────┘
       │          │ Screen│       │
       │(Daftar)  │(/auth/│       │ (Auto-guard:
       └─────────>│status)│<──────┘  Deteksi revoke
                  └───┬───┘          dari admin)
                      │
                      │ (Approved via polling)
                      └───────────> (/home)
```

1. **`/` (LandingScreen)**: Ditampilkan saat perangkat belum pernah terdaftar. Tombol pendaftaran mengekstrak identitas hardware secara otomatis dan mengirimkannya ke `svc-auth`.
2. **`/auth/status` (AuthStatusScreen)**: Menampilkan status persetujuan perangkat. Melakukan polling berkala setiap 10 detik. Menampilkan instruksi perintah terminal admin saat status `pending`, dan indikator peringatan visual saat status `revoked`.
3. **`/home` (HomeScreen)**: Layar utama yang merangkai antarmuka modul fitur aktif. Dilengkapi mekanisme **Auto-Guard** yang memverifikasi status perangkat secara periodik di latar belakang; jika akses dicabut oleh admin, token sesi dihapus dan pengguna dialihkan seketika ke halaman status.

---

## Hardware Fingerprint Deterministik

Untuk mencegah pendaftaran perangkat ganda (duplikat entitas pada basis data), `AuthService` membentuk identitas perangkat unik berbasis atribut platform perangkat keras:

- **Android:** Kombinasi build ID, hardware model, dan device fingerprint.
- **iOS:** Vendor identifier (`identifierForVendor`) dan versi sistem operasi.
- **Linux:** Nilai unik `machine-id` sistem.
- **macOS:** Nilai `systemGUID` dan nama mesin.
- **Windows:** Hardware device ID sistem operasi.

---

## Konfigurasi Lingkungan (`.env`)

Aplikasi menggunakan `flutter_dotenv` untuk memisahkan konfigurasi sensitif dari kode sumber:

```bash
# Salin template berkas environment
cp .env.example .env
```

Parameter yang didukung:
- `API_URL`: Alamat dasar endpoint reverse proxy API (misal: `http://192.168.1.12:8080`).
- `MODULES`: Daftar modul fitur yang diaktifkan (misal: `iot`).

---

## Menjalankan dan Menguji

### 1. Menjalankan Aplikasi
```bash
flutter run
```

### 2. Menjalankan Pengujian Otomatis
```bash
# Analisis kode statis
flutter analyze

# Eksekusi seluruh pengujian unit dan widget
flutter test
```

---

## Lisensi dan Dependensi

- `flutter_dotenv` (MIT) - Loader variabel lingkungan `.env`.
- `device_info_plus` (BSD-3-Clause) - Ekstraksi informasi perangkat keras dan platform.
- `go_router` (BSD-3-Clause) - Router deklaratif dan komposit.
- `shared_preferences` (BSD-3-Clause) - Persistensi penyimpanan lokal.
- `core_api` (Internal) - Klien HTTP dan kontrak antarmuka autentikasi.
- `core_ui` (Internal) - Desain sistem tema dan kontrak modul.
- `mod_iot` (Internal) - Modul fitur antarmuka IoT.
