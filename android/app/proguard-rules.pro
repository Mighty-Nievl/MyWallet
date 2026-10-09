# R8 / ProGuard untuk MyWallet (rilis).
#
# Konteks insiden 9 Okt 2026 (CI `Build APK & AAB` + `Release` merah):
#   ERROR: Missing class com.google.mlkit.vision.text.chinese.
#   ChineseTextRecognizerOptions$Builder
#   (referenced from: ...google_mlkit_text_recognition.TextRecognizer)
# Plugin google_mlkit_text_recognition mendeklarasikan paket script
# opsional (chinese/devanagari/japanese/korean) sebagai `compileOnly`,
# tapi kode inisialisasinya mereferensikannya. R8 full-mode menganggap
# itu error. Scan struk MyWallet hanya memakai recognizer LATIN, jadi
# paket script lain cukup di-dontwarn (tidak perlu dibundel), latin di-keep.

# --- Paket script opsional ML Kit: abaikan saja bila tak ada ---
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# --- Yang dipakai scan struk: jangan diobrak-abrik R8 ---
-keep class com.google.mlkit.vision.text.latin.** { *; }
-keep class com.google.mlkit.vision.text.TextRecognizer { *; }
-keep class com.google.mlkit.vision.text.TextRecognition { *; }
-keep class com.google.mlkit.vision.text.RecognizedText { *; }
-keep class com.google_mlkit_text_recognition.** { *; }

# --- Umum: jangan berisik soal dependensi opsional lain ---
-dontnote com.google.mlkit.**
