# StudyMate Mobile Final Revisi 2

Revisi berdasarkan testing web dan mobile:

1. Register
   - Input nama, NIM, universitas, dan program studi otomatis FULL KAPITAL.
   - Semester tidak lagi diketik bebas; sekarang berupa pilihan Semester 1 sampai Semester 8.

2. Scroll
   - Scroll app dibuat lebih halus dengan `BouncingScrollPhysics` dan keyboard dismiss saat drag.
   - Scroll behavior global ditambahkan untuk touch, mouse, stylus, dan trackpad.

3. Buat Grup Belajar
   - Dropdown master data mata kuliah dan lokasi dihapus dari form mobile.
   - Form hanya memakai input manual: Nama grup, Topik, Deskripsi, Jadwal, Kapasitas, Mata kuliah, dan Lokasi.
   - Input teks utama otomatis FULL KAPITAL agar konsisten dengan backend Laravel.

4. Dashboard
   - Dashboard sekarang menampilkan kartu `Rekomendasi Jadwal Belajar`.
   - Data diambil dari endpoint Laravel `/users/{id}/study-plan`.
   - Rekomendasi mengikuti mata kuliah aktif dan availability yang disimpan di profil.

5. Study Plan
   - Tampilan AI Study Assistant diperbaiki agar membaca field `sessions`, `tips`, dan `recommendedFocusWindow` dari backend StudyMate.

Catatan:
- Backend tetap memakai Laravel API, bukan WebView.
- Base URL default tetap `http://10.0.2.2:4000/api` untuk Android Emulator.
