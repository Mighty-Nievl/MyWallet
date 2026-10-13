import 'package:flutter/material.dart';

import '../design/app_gradients.dart';
import '../design/app_radius.dart';
import '../design/app_shadows.dart';

/// Latar mesh cair pastel vibrant — SATU-SATUNYA cara memakai gradien
/// mesh di aplikasi (v1.28).
///
/// Murah di HP kentang: 1 warna dasar ([AppGradients.heroBase]) + 3 blob
/// radial ([AppGradients.heroBlobs]) yang memudar transparan, tanpa
/// shader. Teks di atasnya WAJIB putih — kontras ≥4.5:1 dikunci
/// `test/visual_identity_test.dart` di 6 aksen × 2 tema.
///
/// Public API: [child] + [padding] + [margin] (mirip [AppCard]).
class MeshGradient extends StatelessWidget {
  const MeshGradient({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.borderRadius = AppRadius.cardAll,
    this.floating = true,
    this.base,
    this.blobs,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;

  /// `false` = tanpa bayangan melayang (mis. di dalam kartu lain).
  final bool floating;

  /// Dasar custom (mis. status error/waspada di overview Budget).
  /// null = [AppGradients.heroBase] ikut aksen.
  final Color? base;

  /// Blob custom (3 warna). null = [AppGradients.heroBlobs].
  final List<Color>? blobs;

  @override
  Widget build(BuildContext context) {
    final b = base ?? AppGradients.heroBase(context);
    final bl = blobs ?? AppGradients.heroBlobs(context);
    final c0 = bl[0];
    final c1 = bl.length > 1 ? bl[1] : bl[0];
    final c2 = bl.length > 2 ? bl[2] : bl[0];
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: b,
        borderRadius: borderRadius,
        boxShadow: floating ? AppShadows.floating(context) : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            // Blob 1: kanan atas (ungu-biru pastel).
            Positioned(right: -70, top: -90, child: _blob(c0)),
            // Blob 2: kiri bawah (toska pastel).
            Positioned(left: -80, bottom: -100, child: _blob(c1)),
            // Blob 3: kanan bawah (oranye pastel).
            Positioned(right: -50, bottom: -110, child: _blob(c2)),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }

  /// Satu blob: lingkaran radial yang memudar ke transparan di tepi.
  /// Alpha 0.35 = hasil blend vs putih ≥4.5:1 di 6 aksen × 2 tema
  /// (terukur; alpha 0.65 jebol ke 2.6:1 di aksen hijau/teal light).
  /// Dikunci test/visual_identity_test.dart.
  static Widget _blob(Color color) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}
