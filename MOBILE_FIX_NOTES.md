# StudyMate Mobile Fix

Paket ini menyesuaikan aplikasi Flutter dengan ZIP web StudyMate terbaru.

## Perubahan utama

1. Register
   - Nama, NIM, universitas, dan program studi dipaksa FULL KAPITAL.
   - Semester memakai pilihan Semester 1 sampai Semester 8.

2. Profil Akademik
   - Program studi memakai dropdown dari endpoint `/api/bootstrap`.
   - Minat akademik memakai katalog kode seperti web: AI, ML, DATA, WEB, UIUX, dan lainnya.
   - Mata kuliah aktif dipilih dari katalog course, bukan input teks bebas.
   - Course dikirim ke backend sebagai `courseIds` dan `selectedCoursePayloads`.

3. Jadwal Belajar
   - Availability sudah terstruktur per mata kuliah.
   - Format payload mengikuti dokumen web:
     ```json
     {
       "courseId": "...",
       "courseCode": "...",
       "courseName": "...",
       "day": "SENIN",
       "time": "19:00",
       "durationMinutes": 90
     }
     ```
   - Dashboard membaca rekomendasi jadwal belajar dari `/api/users/{id}/study-plan`.

4. Grup Belajar
   - Form buat grup tidak memakai dropdown master data.
   - Form hanya memakai input manual: nama grup, topik, deskripsi, jadwal, kapasitas, mata kuliah, lokasi.
   - Owner grup bisa edit dan hapus grup.

5. Verifikasi
   - Profil mobile sudah menambahkan upload foto profil dan upload KTM memakai endpoint Laravel:
     - `POST /api/users/{id}/avatar`
     - `POST /api/users/{id}/ktm`

## Jalankan

Backend Laravel:

```powershell
cd "C:\studymate_web\studymate-main (1)\studymate-main\backend-laravel"
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan serve --host=127.0.0.1 --port=4000
```

Flutter:

```powershell
cd "C:\studymate_flutter\studymate_mobile_fix"
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api
```
