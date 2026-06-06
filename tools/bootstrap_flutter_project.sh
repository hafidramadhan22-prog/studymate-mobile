#!/usr/bin/env bash
set -euo pipefail

echo "== StudyMate Mobile Bootstrap =="
echo "Folder: $(pwd)"

if [ ! -f "pubspec.yaml" ]; then
  echo "pubspec.yaml tidak ditemukan. Jalankan script ini dari root folder studymate_mobile_final." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK tidak ditemukan di PATH. Install Flutter lalu buka ulang terminal." >&2
  exit 1
fi

backup_dir=".bootstrap_backup"
mkdir -p "$backup_dir"
cp pubspec.yaml "$backup_dir/pubspec.yaml"
cp lib/main.dart "$backup_dir/main.dart"
[ -f analysis_options.yaml ] && cp analysis_options.yaml "$backup_dir/analysis_options.yaml"

echo "Membuat file platform Flutter yang belum ada..."
flutter create --project-name studymate_mobile --platforms android,ios,web,windows .

echo "Mengembalikan source StudyMate..."
cp "$backup_dir/pubspec.yaml" pubspec.yaml
cp "$backup_dir/main.dart" lib/main.dart
[ -f "$backup_dir/analysis_options.yaml" ] && cp "$backup_dir/analysis_options.yaml" analysis_options.yaml

echo "Mengambil dependency..."
flutter pub get

echo "Menjalankan analyzer..."
flutter analyze

echo "Selesai. Jalankan: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api"
