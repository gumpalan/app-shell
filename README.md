# app-shell (Gumpalan)

Aplikasi utama Flutter Android yang merangkai paket fondasi (`core_api`, `core_ui`) dan seluruh modul fitur (`mod_iot`, dll.).

## Struktur

```
lib/
├── app.dart                   # Root MaterialApp.router dengan konfigurasi tema
├── main.dart                  # Entry point aplikasi Flutter
├── modules_registry.dart      # Registri & penyaring modul dinamis
└── router.dart                # GoRouter komposit dan layar beranda/pendaftaran
```

## Mekanisme Penyaringan Modul (Build & Runtime)

Shell dirancang agar orang lain dapat mengompilasi aplikasi dengan sebagian modul saja tanpa mengubah kode:

1. **Compile-Time Filter (`--dart-define=MODULES=...`)**:
   Daftar modul yang disertakan saat build dipisahkan dengan koma. Jika tidak diisi, seluruh modul yang terdaftar di `ModulesRegistry` diikutsertakan.
   ```bash
   # Hanya modul IoT
   flutter build apk --dart-define=MODULES=iot

   # Beberapa modul
   flutter build apk --dart-define=MODULES=auth,iot
   ```
2. **Server-Side Authorization Filter**:
   `ModulesRegistry` menyaring modul berdasarkan respons endpoint `/auth/v1/modules` dari `svc-auth`. Modul yang tidak diizinkan oleh server untuk perangkat ini otomatis disembunyikan dari antarmuka.

## Layar Scaffold

- **Beranda (`/`)**: Menampilkan daftar modul aktif secara modular via `AppModule.homeCard`.
- **Pendaftaran Perangkat (`/register`)**: Meminta input nama perangkat dan mengirimkan kunci publik ke `svc-auth`.

## Lisensi dan Dependensi

Lisensi repositori ini **belum ditentukan**.

### Dependensi Langsung:
- `go_router` (BSD-3-Clause)
- `cupertino_icons` (MIT)
- `core_api` (internal)
- `core_ui` (internal)
- `mod_iot` (internal)

### Memeriksa Lisensi:
Periksa berkas `pubspec.lock` atau gunakan:
```bash
flutter pub pub run -- flutter pub deps
```
