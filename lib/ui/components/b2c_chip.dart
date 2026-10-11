import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_motion.dart';
import '../design/app_spacing.dart';

/// Filter chip B2C (v1.20): pil semibold dengan haptic + scale-down
/// saat ditekan. Public API TETAP: [label] + [selected] + [onTap].
class B2CFilterChip extends StatelessWidget {
  const B2CFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // v1.24.9: semantik tombol eksplisit (kritik L1 — dulu GestureDetector
    // mentah: tak ada buat pembaca layar/keyboard). excludeSemantics agar
    // output bersih satu label, bukan label + teks anak dobel.
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: _PressScale(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.easeOut,
          // v1.24.9: min 48 = touchMin apa pun font-nya (padding 14×2 +
          // label ≈ 48 di font asli; constraint yang menjamin, bukan
          // aritmetika metrik).
          constraints:
              const BoxConstraints(minHeight: AppSpacing.touchMin),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            // v1.24.9: 10→14 — dulu total ~40px, di bawah target sentuh
            // yang kita pegang di semua tombol lain (kritik L1).
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            // v1.24.9: elipsis eksplisit (kritik L1 — dulu ke-clip tiba-tiba).
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Skala tekan B2C: bungkus child interaktif apa pun — menyusut ke
/// 96% saat jari menekan, kembali saat lepas. Murni visual.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.animationsOff(context)) {
      return GestureDetector(onTap: widget.onTap, child: widget.child);
    }
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: AppMotion.fast,
        curve: AppMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}
