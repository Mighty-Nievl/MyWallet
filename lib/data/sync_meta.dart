import 'dart:math';

/// Util sync-ready (Fase 0, v1.16) — identitas global TANPA dependensi.
///
/// [newSyncUuid] = UUID v4 (Random.secure) format 8-4-4-4-12, dipakai
/// sebagai `clientDefault` kolom `uuid` semua tabel. Opaque string buat
/// sync engine (Fase 2, Google Sign-In + Firestore): yang penting unik
/// global antar-HP, bukan urutannya. ID int AUTOINCREMENT tetap dipakai
/// lokal (join cepat + urutan), uuid dipakai saat tukar data antar-HP.
///
/// [syncNow] = jam HP saat tulis — jejak last-write-wins per-baris.
/// Dipakai `clientDefault` kolom `updatedAt` + bump manual tiap update.
String newSyncUuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // versi 4
  b[8] = (b[8] & 0x3f) | 0x80; // varian RFC 4122
  final h = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// Jam tulis standar (satu sumber biar gampang di-mock test nanti).
DateTime syncNow() => DateTime.now();

/// Format UUID v4 — dipakai test validasi (bukan validasi ketat RFC,
/// cukup pastikan bentuknya benar hasil [newSyncUuid]).
final RegExp syncUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
