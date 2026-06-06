# StudyMate Mobile Flutter

Aplikasi mobile Flutter untuk backend Laravel StudyMate.

## 1. Backend Laravel

Pastikan database `studymate` sudah dibuat/import di Laragon dan file `.env` memakai:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=studymate
DB_USERNAME=root
DB_PASSWORD=
```

Jalankan backend:

```powershell
cd "C:\studymate_web\studymate-main (1)\studymate-main\backend-laravel"
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan serve --host=127.0.0.1 --port=4000
```

Tes:

```text
http://127.0.0.1:4000/api/health
```

## 2. Flutter

Jika folder platform belum ada, jalankan:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\bootstrap_flutter_project.ps1
```

Install dependency:

```powershell
flutter pub get
```

Run Android Emulator:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api
```

Run HP fisik:

```powershell
flutter run --dart-define=API_BASE_URL=http://IP-LAPTOP-ANDA:4000/api
```

Contoh:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:4000/api
```

## 3. Catatan Android Upload Foto/KTM

Paket ini memakai `image_picker`. Jika setelah bootstrap Android muncul permintaan permission, izinkan akses galeri/foto saat aplikasi dijalankan.
