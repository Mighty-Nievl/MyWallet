// v1.38.5 — sync latar: aturan penjatahan + pengikat daur hidup.
//
// Yang diuji di sini bukan `syncNow` (itu sudah dites di tempat lain),
// tapi kapan sync BOLEH jalan. Delapan kali sync dalam semenit dan nol
// sync sama-sama bug; test ini mengunci keduanya.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/auto_sync.dart';
import 'package:mywallet/data/connectivity.dart';
import 'package:mywallet/data/sync_service.dart';
import 'package:mywallet/ui/widgets/auto_sync_binder.dart';

_Harness _harness() => _Harness();

class _Harness {
  int runCount = 0;
  bool offline = false;
  bool ready = true;
  bool throwOnRun = false;
  DateTime now = DateTime(2026, 10, 22, 9);

  late final AutoSyncController c = AutoSyncController(
    run: () async {
      runCount++;
      if (throwOnRun) throw StateError('firestore hilang');
      return const SyncState(phase: SyncPhase.done, message: 'ok');
    },
    isOffline: () async => offline,
    isReady: () async => ready,
    clock: () => now,
    minInterval: const Duration(minutes: 2),
  );
}

/// Kirim event daur hidup lewat channel platform. `binding
/// .handleAppLifecycleStateChanged` itu `@protected`, jadi memanggilnya
/// dari test memicu `invalid_use_of_protected_member` → analyze merah.
Future<void> _lifecycle(WidgetTester tester, AppLifecycleState s) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage(s.toString()),
    (_) {},
  );
  await tester.pump();
}

void main() {
  group('AutoSyncController', () {
    test('offline: tidak menyentuh jaringan sama sekali', () async {
      final h = _harness()..offline = true;
      expect(await h.c.maybeSync('start'), isNull);
      expect(h.runCount, 0);
      expect(h.c.skippedOffline, 1);
    });

    test('belum login / belum punya rumah tangga: tidak jalan', () async {
      final h = _harness()..ready = false;
      expect(await h.c.maybeSync('start'), isNull);
      expect(h.runCount, 0);
      expect(h.c.skippedNotReady, 1);
    });

    test('start hanya sekali per sesi', () async {
      final h = _harness();
      await h.c.maybeSync('start');
      await h.c.maybeSync('start');
      await h.c.maybeSync('start');
      expect(h.runCount, 1, reason: 'buka app berkali-kali != push berkali-kali');
    });

    test('resume dijatah minInterval, lalu jalan lagi setelah lewat', () async {
      final h = _harness();
      await h.c.maybeSync('resume');
      expect(h.runCount, 1);

      h.now = h.now.add(const Duration(seconds: 30));
      await h.c.maybeSync('resume');
      expect(h.runCount, 1, reason: '30 dtk < 2 mnt → dijatah');
      expect(h.c.throttled, 1);

      h.now = h.now.add(const Duration(minutes: 3));
      await h.c.maybeSync('resume');
      expect(h.runCount, 2);
    });

    test('online kembali setelah offline langsung dicoba', () async {
      final h = _harness();
      final st = await h.c.maybeSync('online');
      expect(h.runCount, 1);
      expect(st?.phase, SyncPhase.done);
    });

    test('run melempar: jadi failed, tidak naik ke pemanggil', () async {
      final h = _harness()..throwOnRun = true;
      final st = await h.c.maybeSync('start');
      expect(st, isNotNull);
      expect(st!.phase, SyncPhase.failed);
      expect(h.c.lastResult?.phase, SyncPhase.failed);
    });

    test('start lalu resume beruntun: resume tetap kena jatah', () async {
      final h = _harness();
      await h.c.maybeSync('start');
      await h.c.maybeSync('resume'); // cold start: app langsung resume
      expect(h.runCount, 1);
    });
  });

  group('AutoSyncBinder', () {
    testWidgets('menembak start sekali setelah frame pertama', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isOfflineProvider.overrideWith((ref) => Stream.value(false)),
          ],
          child: MaterialApp(
            home: AutoSyncBinder(
              trigger: (t) async => calls.add(t),
              child: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, ['start']);
    });

    testWidgets('menembak resume saat app kembali dari background', (
      tester,
    ) async {
      final calls = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isOfflineProvider.overrideWith((ref) => Stream.value(false)),
          ],
          child: MaterialApp(
            home: AutoSyncBinder(
              trigger: (t) async => calls.add(t),
              child: const SizedBox(),
            ),
          ),
        ),
      );
      await _lifecycle(tester, AppLifecycleState.paused);
      await _lifecycle(tester, AppLifecycleState.resumed);
      expect(calls, contains('resume'));
    });

    testWidgets('menembak online saat sinyal kembali', (tester) async {
      final calls = <String>[];
      final offline = StreamController<bool>();
      addTearDown(offline.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isOfflineProvider.overrideWith((ref) => offline.stream),
          ],
          child: MaterialApp(
            home: AutoSyncBinder(
              trigger: (t) async => calls.add(t),
              child: const SizedBox(),
            ),
          ),
        ),
      );
      offline.add(true);
      await tester.pump();
      offline.add(false);
      await tester.pump();
      expect(calls, contains('online'));
    });
  });
}
