import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'receipt_parse.dart';

/// Hasil scan struk: draf + teks mentah (untuk debug/diagnosa).
class ReceiptScanResult {
  const ReceiptScanResult({required this.draft, required this.rawText});

  final ReceiptDraft draft;
  final String rawText;
}

/// Layanan scan struk on-device.
///
/// Alur: `image_picker` (kamera/galeri) → ML Kit text recognition
/// (latin, 100% di HP) → [parseReceiptText] → [ReceiptDraft].
///
/// Privasi: foto tidak keluar HP. Di Windows/desktop ML Kit tidak
/// tersedia — cek [isScanSupported] dulu, atau tangkap
/// [ReceiptScanUnsupported].
class ReceiptScanService {
  static final _picker = ImagePicker();

  /// `false` di platform tanpa ML Kit (Windows/macOS/Linux/web).
  static bool get isScanSupported {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    return true;
  }

  /// Ambil foto dari [source] lalu OCR. Return null bila user batal.
  /// Throw [ReceiptScanUnsupported] bila platform tidak didukung,
  /// [ReceiptScanEmpty] bila teks tidak terbaca.
  static Future<ReceiptScanResult?> scanFrom(
    ImageSource source,
  ) async {
    if (!isScanSupported) throw const ReceiptScanUnsupported();
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      imageQuality: 92,
    );
    if (file == null) return null;
    return scanFile(file.path);
  }

  /// OCR satu file gambar di [path].
  static Future<ReceiptScanResult> scanFile(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(path);
      final recognized = await recognizer.processImage(input);
      final text = recognized.text.trim();
      if (text.isEmpty) throw const ReceiptScanEmpty();
      final draft = parseReceiptText(text);
      return ReceiptScanResult(draft: draft, rawText: text);
    } on ReceiptScanEmpty {
      rethrow;
    } catch (e) {
      // MethodChannel tidak ada (Windows) atau Play Services bermasalah.
      if (e.toString().contains('MissingPluginException') ||
          e.toString().contains('Unimplemented')) {
        throw const ReceiptScanUnsupported();
      }
      rethrow;
    } finally {
      try {
        await recognizer.close();
      } catch (_) {
        // Tutup gagal = abaikan, hasil sudah didapat.
      }
    }
  }
}

/// Platform tidak mendukung scan (desktop).
class ReceiptScanUnsupported implements Exception {
  const ReceiptScanUnsupported();
  @override
  String toString() => 'Scan struk hanya tersedia di HP Android/iOS.';
}

/// Teks struk tidak terbaca (foto gelap/blur).
class ReceiptScanEmpty implements Exception {
  const ReceiptScanEmpty();
  @override
  String toString() => 'Teks struk tidak terbaca — coba foto lebih terang.';
}
