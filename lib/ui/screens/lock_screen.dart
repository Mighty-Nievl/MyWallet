import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lock_service.dart';
import '../../data/settings.dart';

/// Gerbang kunci aplikasi: PIN atau biometrik, sesuai pengaturan.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pinCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _unlock() {
    ref.read(unlockedProvider.notifier).state = true;
  }

  Future<void> _submitPin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await LockService.verifyPin(_pinCtrl.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _unlock();
    } else {
      setState(() => _error = 'PIN salah, coba lagi.');
      _pinCtrl.clear();
    }
  }

  Future<void> _tryBiometric() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await LockService.authenticateBiometric();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _unlock();
    } else {
      setState(() => _error = 'Autentikasi gagal.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLock = ref.watch(appLockProvider);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: appLock.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Gagal memuat: $e'),
            data: (mode) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔐', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                const Text('MyWallet Terkunci',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  mode == 'biometric'
                      ? 'Buka dengan sidik jari / wajah, atau PIN.'
                      : 'Masukkan PIN untuk membuka.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (mode == 'biometric') ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : _tryBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Buka dengan Biometrik'),
                  ),
                  const SizedBox(height: 8),
                  const Text('atau pakai PIN:'),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submitPin(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _submitPin,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Buka'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
