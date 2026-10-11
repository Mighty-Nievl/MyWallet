import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lock_service.dart';
import '../../data/settings.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';

/// Gerbang kunci aplikasi: PIN atau biometrik, sesuai pengaturan.
///
/// STEP 4 — hanya presentasi yang diubah. Logika TETAP:
/// controller, validasi, autentikasi, obscure, keyboard,
/// biometrik, error, loading, unlock.
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
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await LockService.verifyPin(_pinCtrl.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      // B2C v1.20: haptic sukses/buka.
      HapticFeedback.lightImpact();
      _unlock();
    } else {
      HapticFeedback.vibrate();
      setState(() => _error = 'PIN salah, coba lagi.');
      _pinCtrl.clear();
    }
  }

  Future<void> _tryBiometric() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await LockService.authenticateBiometric();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      // B2C v1.20: haptic sukses/buka.
      HapticFeedback.lightImpact();
      _unlock();
    } else {
      HapticFeedback.vibrate();
      setState(() => _error = 'Autentikasi gagal.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLock = ref.watch(appLockProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s32),
            child: appLock.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Text(
                  'Gagal memuat pengaturan kunci.',
                  style: AppType.secondary(context),
                ),
              ),
              data: (mode) {
                final bio = mode == 'biometric';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          // v1.24.4: logo baru dari bg-white.jpg.
                          'assets/images/bg-white.jpg',
                          width: 88,
                          height: 88,
                          errorBuilder: (_, _, _) => const Text(
                            '💰',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 48),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text('MyWallet',
                        textAlign: TextAlign.center,
                        style: AppType.screenTitle(context)),
                    const SizedBox(height: AppSpacing.s16),
                    const Text('🔒',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 48)),
                    const SizedBox(height: AppSpacing.s16),
                    Text(
                      'Aplikasi terkunci',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                              fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      bio
                          ? 'Buka dengan sidik jari / wajah, atau PIN.'
                          : 'Masukkan PIN untuk melanjutkan.',
                      textAlign: TextAlign.center,
                      style: AppType.secondary(context),
                    ),
                    const SizedBox(height: AppSpacing.s24),
                    if (bio) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed:
                              _busy ? null : _tryBiometric,
                          icon: const Icon(
                              Icons.fingerprint,
                              size: 20),
                          label: const Text(
                              'Buka dengan Biometrik'),
                          style: FilledButton.styleFrom(
                            minimumSize:
                                const Size.fromHeight(52),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Text(
                        'atau pakai PIN',
                        textAlign: TextAlign.center,
                        style: AppType.secondary(context),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                    ],
                    TextField(
                      controller: _pinCtrl,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: 'PIN',
                        errorText: _error,
                      ),
                      onSubmitted: (_) => _submitPin(),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            _busy ? null : _submitPin,
                        style: FilledButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(52),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                        strokeWidth: 2),
                              )
                            : const Text('Buka'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
