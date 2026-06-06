$ErrorActionPreference = "Stop"

Write-Host "== StudyMate Mobile Bootstrap =="
Write-Host "Folder: $(Get-Location)"

if (-not (Test-Path "pubspec.yaml")) {
  Write-Error "pubspec.yaml tidak ditemukan. Jalankan script ini dari root folder studymate_mobile_final."
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Error "Flutter SDK tidak ditemukan di PATH. Install Flutter lalu buka ulang VS Code/terminal."
}

$backupDir = ".bootstrap_backup"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item "pubspec.yaml" "$backupDir/pubspec.yaml" -Force
Copy-Item "lib/main.dart" "$backupDir/main.dart" -Force
if (Test-Path "analysis_options.yaml") { Copy-Item "analysis_options.yaml" "$backupDir/analysis_options.yaml" -Force }

Write-Host "Membuat file platform Flutter yang belum ada..."
flutter create --project-name studymate_mobile --platforms android,ios,web,windows .

Write-Host "Mengembalikan source StudyMate..."
Copy-Item "$backupDir/pubspec.yaml" "pubspec.yaml" -Force
Copy-Item "$backupDir/main.dart" "lib/main.dart" -Force
if (Test-Path "$backupDir/analysis_options.yaml") { Copy-Item "$backupDir/analysis_options.yaml" "analysis_options.yaml" -Force }

Write-Host "Mengambil dependency..."
flutter pub get

Write-Host "Menjalankan analyzer..."
flutter analyze

Write-Host "Selesai. Jalankan: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api"
