# StudyMate Mobile Final - Notification & Upload Fix

Perbaikan pada paket ini:

1. Label asal/jenis notifikasi dibuat rapi tanpa underscore.
   - `study_invite` -> Undangan Belajar
   - `group_activity` -> Aktivitas Grup
   - `group_join` -> Anggota Baru Grup
   - `private_message` -> Pesan Pribadi

2. Komposisi kartu notifikasi diperbaiki.
   - Tombol Tandai Dibaca full width.
   - Tombol Terima dan Tolak dipisah rapi dalam satu baris.
   - Status pending/accepted/rejected diterjemahkan menjadi Menunggu/Diterima/Ditolak.

3. Action notifikasi diperbaiki.
   - Tandai dibaca mengembalikan status sukses/gagal.
   - Terima undangan memanggil endpoint `/notifications/{id}/accept`, reload notifikasi, teman, dashboard, dan match.
   - Tolak undangan memanggil endpoint `/notifications/{id}/reject` dan reload notifikasi.
   - Feedback snackbar ditampilkan setelah tombol ditekan.

4. Upload Foto dan Upload KTM sekarang menggunakan file browser lokal.
   - Menggunakan `file_picker`.
   - Mendukung ekstensi `jpg`, `jpeg`, `png`, dan `webp`.
   - Tetap fallback ke image picker jika file manager tidak tersedia.

Dependency baru:

```yaml
file_picker: ^8.1.2
```

Jalankan ulang:

```powershell
flutter pub get
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000/api
```
