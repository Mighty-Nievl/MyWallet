# 08 — Karakteristik Tampilan (Identitas Visual v1.28)

> Satu-satunya acuan gaya UI MyWallet. Bila kode dan dokumen ini bertentangan,
> **kode yang menang** — tapi test di bawah akan merah, dan merah = wajib selaraskan.

Lima karakteristik di bawah berasal dari `messages.txt` (masukan mas, Okt 2026)
dan dikunci tiga lapis: **token** (`lib/ui/design/`) + **widget bersama**
(`lib/ui/components/`) + **test** (`test/visual_identity_test.dart`, golden).

## 1. Gradasi cair pastel (mesh)

- Hero + overview status memakai `MeshGradient` — dasar `AppGradients.heroBase`
  (ikut aksen, L terang 0.26 / gelap 0.22) + 3 blob hue-shift (+30/-35/+60°,
  lift +0.04/+0.08, alpha **0.35**).
- **Dilarang** bikin `LinearGradient`/`RadialGradient` manual di layar — semua
  lewat `MeshGradient` (param `base`/`blobs` hanya untuk varian status).
- Teks di atas mesh **wajib putih** + kontras ≥ 4,5:1 di 6 aksen × 2 tema,
  diukur matematik di `visual_identity_test.dart` (bukan eyeball).
- Angka terukur saat ini: dasar min 6,69:1, blend blob min 6,32:1.
- Jangan naikkan lift/alpha tanpa hitung ulang — lift murni +0,10 jebol ke 4,2:1.

## 2. Bayangan lembut menyebar (floating)

- Kartu = `AppCard` (shadow `AppShadows.card`: hitam 8 % blur 28 + aksen 8 %).
- Hero/nav melayang = `AppShadows.floating` (aksen 28 % + hitam 8 %, blur 32).
- Tombol tengah nav + medali kosong = `AppShadows.glow` (aksen 28 % blur 24).
- **Dilarang** shadow hitam pekat (alpha > 0,30) di kartu mana pun — dikunci test.
- Blur ≥ 20, offset tegak (0, y) — tidak ada shadow miring/tajam.

## 3. Sudut melengkung besar (pill)

| Token | Nilai | Pakai untuk |
|---|---|---|
| `AppRadius.pill` | 999 | tombol, chip, search, CTA hero |
| `AppRadius.card` | 24 | kartu, nav melayang, sheet |
| `AppRadius.thumb` | 16 | thumbnail kategori |
| `AppRadius.md` | 12 | ripple InkWell kecil |

- **Dilarang** angka radius literal (`BorderRadius.circular(12/999/…)`) di
  layar/komponen — semua wajib dari `AppRadius` (tema global sudah pill:
  tombol, input, chip, dialog, sheet, segmented).
- Nilai token dikunci test (`pill=999, card=24, thumb=16`).

## 4. Tata letak bersih & ringan

- Satu layar **satu raja visual** (Beranda = angka saldo 48 px); sekunder tidak bold.
- Spacing dari `AppSpacing` (page 16, section 24/32); tipografi dari `AppType`.
- Latar terang luas — kartu putih + border subtle, bukan panel penuh warna.
- Dijaga via **golden test**: geser spacing 1 px = test merah.

## 5. Card-based + thumbnail konsisten

- Semua list (transaksi, budget, utang) = `AppCard` + `CategoryGlyph`.
- Ukuran glyph: 40 px (list) / 44 px (detail) / 36 px (sheet) — radius `thumb`.
- Emoji DB **tidak diubah** (kompatibel mundur); glyph hanya memetakan ke ikon.
- Dilarang bikin `Container` kartu custom di layar.

## Menambah layar baru (checklist)

1. Hero/varian status → `MeshGradient` (jangan gradient manual).
2. Kartu/list → `AppCard` + `CategoryGlyph`.
3. Radius/shadow/spacing/tipe → token, tidak ada literal.
4. Tambah golden light+dark + invarian kontras bila ada teks di atas mesh.
5. `dart format` → CRLF-normalize → `flutter analyze` → `flutter test`.
