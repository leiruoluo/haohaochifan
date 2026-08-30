// 好好吃饭 应用图标生成器（纯 Dart，零依赖）
// 用法: dart tools/make_icon.dart
// 输出: tools/icon_out/master_icon.png + 各尺寸 PNG + app_icon.ico
// 设计: 暖橙圆角背景 + 白色碗（蒸汽 + 笑脸 + 碗中米饭）
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int S = 1024; // 画布尺寸

// 调色板
const bgTop = (247, 127, 60); // 暖橙（上）
const bgBottom = (176, 68, 24); // 深橙（下）
const white = (255, 255, 255);
const cream = (236, 216, 192); // 碗底足（深米色，与背景区分）
const rice = (255, 218, 138); // 碗中米饭（米黄，与背景区分）
const smileInk = (150, 82, 30); // 笑脸暖棕

List<int> _px = List.filled(S * S * 4, 0);

typedef RGB = (int, int, int);

void _set(int x, int y, RGB c) {
  if (x < 0 || y < 0 || x >= S || y >= S) return;
  final i = (y * S + x) * 4;
  _px[i] = c.$1;
  _px[i + 1] = c.$2;
  _px[i + 2] = c.$3;
  _px[i + 3] = 255;
}

/// 圆角矩形
void _fillRoundedRect(double x0, double y0, double x1, double y1,
    double radius, RGB c) {
  for (var y = y0.floor(); y <= y1.ceil(); y++) {
    for (var x = x0.floor(); x <= x1.ceil(); x++) {
      final cx = x + 0.5, cy = y + 0.5;
      if (cx < x0 || cx > x1 || cy < y0 || cy > y1) continue;
      // 判断是否在圆角外
      final r = radius;
      final inR = _inRoundedRect(cx, cy, x0, y0, x1, y1, r);
      if (inR) _set(x, y, c);
    }
  }
}

bool _inRoundedRect(double x, double y, double x0, double y0, double x1,
    double y1, double r) {
  if (x >= x0 + r && x <= x1 - r) return true;
  if (y >= y0 + r && y <= y1 - r) return true;
  // 四角
  final corners = [
    (x0 + r, y0 + r),
    (x1 - r, y0 + r),
    (x0 + r, y1 - r),
    (x1 - r, y1 - r),
  ];
  for (final (cx, cy) in corners) {
    final dx = x - cx, dy = y - cy;
    if (dx * dx + dy * dy <= r * r) return true;
  }
  return false;
}

/// 椭圆填充
void _fillEllipse(double cx, double cy, double rx, double ry, RGB c) {
  for (var y = (cy - ry).floor(); y <= (cy + ry).ceil(); y++) {
    for (var x = (cx - rx).floor(); x <= (cx + rx).ceil(); x++) {
      final dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry;
      if (dx * dx + dy * dy <= 1.0) _set(x, y, c);
    }
  }
}

/// 饼图：椭圆的下半部分（180°..360°）
void _fillLowerHalfEllipse(
    double cx, double cy, double rx, double ry, RGB c) {
  for (var y = cy.floor(); y <= (cy + ry).ceil(); y++) {
    for (var x = (cx - rx).floor(); x <= (cx + rx).ceil(); x++) {
      final dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry;
      if (dx * dx + dy * dy <= 1.0 && (y + 0.5) >= cy) _set(x, y, c);
    }
  }
}

/// 沿贝塞尔曲线画粗线（圆点印章）
void _strokeBezier(List<Offset> pts, double width, RGB c) {
  const steps = 80;
  final radius = width / 2;
  Offset p(double t) {
    final a = (1 - t), b = t;
    final x = a * a * a * pts[0].x +
        3 * a * a * b * pts[1].x +
        3 * a * b * b * pts[2].x +
        b * b * b * pts[3].x;
    final y = a * a * a * pts[0].y +
        3 * a * a * b * pts[1].y +
        3 * a * b * b * pts[2].y +
        b * b * b * pts[3].y;
    return Offset(x, y);
  }

  for (var i = 0; i <= steps; i++) {
    final pt = p(i / steps);
    _fillEllipse(pt.x, pt.y, radius, radius, c);
  }
}

/// 椭圆弧线（笑脸）
void _strokeArc(double cx, double cy, double rx, double ry, double startDeg,
    double sweepDeg, double width, RGB c) {
  const steps = 40;
  final radius = width / 2;
  for (var i = 0; i <= steps; i++) {
    final deg = startDeg + sweepDeg * i / steps;
    final rad = deg * pi / 180;
    final x = cx + rx * cos(rad);
    final y = cy - ry * sin(rad);
    _fillEllipse(x, y, radius, radius, c);
  }
}

void draw() {
  _px = List.filled(S * S * 4, 0);

  // 背景：圆角矩形 + 垂直渐变
  _fillRoundedRect(0, 0, S.toDouble(), S.toDouble(), 200, bgTop); // 先铺底色
  // 渐变叠加：逐行插值
  for (var y = 0; y < S; y++) {
    final t = y / S;
    final r = (bgTop.$1 + (bgBottom.$1 - bgTop.$1) * t).round();
    final g = (bgTop.$2 + (bgBottom.$2 - bgTop.$2) * t).round();
    final b = (bgTop.$3 + (bgBottom.$3 - bgTop.$3) * t).round();
    for (var x = 0; x < S; x++) {
      if (_px[(y * S + x) * 4 + 3] == 255) {
        _px[(y * S + x) * 4] = r;
        _px[(y * S + x) * 4 + 1] = g;
        _px[(y * S + x) * 4 + 2] = b;
      }
    }
  }
  // 重新裁剪圆角外透明
  for (var y = 0; y < S; y++) {
    for (var x = 0; x < S; x++) {
      if (!_inRoundedRect(x + 0.5, y + 0.5, 0, 0, S.toDouble(), S.toDouble(), 200)) {
        _px[(y * S + x) * 4 + 3] = 0;
      }
    }
  }

  // 碗
  final bowlW = 560.0, bowlH = 330.0;
  final bx = (S - bowlW) / 2, by = 640.0;
  final bowlTop = by - bowlH;
  // 主体：下半椭圆
  _fillLowerHalfEllipse(S / 2, bowlTop, bowlW / 2, bowlH, white);
  // 碗口唇
  _fillEllipse(S / 2, bowlTop - 10, bowlW / 2 + 24, 28, white);
  // 碗底足（与碗底交叠，避免悬空）
  _fillEllipse(S / 2, by + 26, 100, 30, cream);
  // 碗中米饭
  _fillEllipse(S / 2, bowlTop + 34, (bowlW / 2 - 45), 46, rice);
  // 笑脸（暖棕，画在米饭上，与蒸汽呼应成一张脸）
  _strokeArc(S / 2, bowlTop + 26, 120, 58, 25, 130, 14, smileInk);
  // 蒸汽（两条粗细略不同，更灵动）
  _strokeBezier(
      [Offset(bx + 170, 270), Offset(bx + 200, 215), Offset(bx + 148, 160), Offset(bx + 188, 110)],
      15, white);
  _strokeBezier(
      [Offset(bx + 420, 270), Offset(bx + 450, 215), Offset(bx + 398, 160), Offset(bx + 438, 110)],
      11, white);
}

// ---------------- PNG 编码 ----------------
Uint8List _png(Uint8List rgba, int w, int h) {
  final out = BytesBuilder();
  out.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final len = data.length;
    out.add([(len >> 24) & 0xFF, (len >> 16) & 0xFF, (len >> 8) & 0xFF, len & 0xFF]);
    final typeBytes = type.codeUnits;
    out.add(typeBytes);
    out.add(data);
    final crcInput = <int>[...typeBytes, ...data];
    out.add(_crc32(crcInput));
  }

  final ihdr = BytesBuilder();
  void u32(int v) =>
      ihdr.add([(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]);
  u32(w);
  u32(h);
  ihdr.add([8, 6, 0, 0, 0]); // 8bit RGBA
  chunk('IHDR', ihdr.toBytes());

  // 扫描线：filter 0 + RGBA
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0);
    raw.add(rgba.sublist(y * w * 4, (y + 1) * w * 4));
  }
  final compressed = ZLibCodec(level: 9).encode(raw.toBytes());
  chunk('IDAT', compressed);
  chunk('IEND', const []);
  return out.toBytes();
}

Uint8List _crc32(List<int> data) {
  final table = _crcTable;
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc = table[(crc ^ b) & 0xFF] ^ (crc >> 8);
  }
  crc ^= 0xFFFFFFFF;
  return Uint8List.fromList([
    (crc >> 24) & 0xFF,
    (crc >> 16) & 0xFF,
    (crc >> 8) & 0xFF,
    crc & 0xFF,
  ]);
}

final _crcTable = _buildCrcTable();

List<int> _buildCrcTable() {
  final table = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}

/// 双线性缩小
Uint8List _resize(Uint8List src, int sw, int sh, int dw, int dh) {
  final out = Uint8List(dw * dh * 4);
  for (var y = 0; y < dh; y++) {
    for (var x = 0; x < dw; x++) {
      final sx = x * sw / dw, sy = y * sh / dh;
      final x0 = sx.floor().clamp(0, sw - 1), y0 = sy.floor().clamp(0, sh - 1);
      final x1 = (x0 + 1).clamp(0, sw - 1), y1 = (y0 + 1).clamp(0, sh - 1);
      final fx = sx - x0, fy = sy - y0;
      for (var c = 0; c < 4; c++) {
        final v = (1 - fx) * (1 - fy) * src[(y0 * sw + x0) * 4 + c] +
            fx * (1 - fy) * src[(y0 * sw + x1) * 4 + c] +
            (1 - fx) * fy * src[(y1 * sw + x0) * 4 + c] +
            fx * fy * src[(y1 * sw + x1) * 4 + c];
        out[(y * dw + x) * 4 + c] = v.round().clamp(0, 255);
      }
    }
  }
  return out;
}

// ---------------- ICO ----------------
Uint8List _ico(Map<int, Uint8List> pngs) {
  final sizes = pngs.keys.toList()..sort((a, b) => b.compareTo(a));
  final out = BytesBuilder();
  out.add([0, 0, 1, 0]);
  out.add([(sizes.length >> 8) & 0xFF, sizes.length & 0xFF]);
  var offset = 6 + 16 * sizes.length;
  final entries = <List<int>>[];
  for (final s in sizes) {
    final data = pngs[s]!;
    final b = s >= 256 ? 0 : s;
    entries.add([
      b, b, 0, 0, 1, 0, 32, 0,
      (data.length >> 24) & 0xFF, (data.length >> 16) & 0xFF,
      (data.length >> 8) & 0xFF, data.length & 0xFF,
      (offset >> 24) & 0xFF, (offset >> 16) & 0xFF,
      (offset >> 8) & 0xFF, offset & 0xFF,
    ]);
    offset += data.length;
  }
  for (final e in entries) {
    out.add(e);
  }
  for (final s in sizes) {
    out.add(pngs[s]!);
  }
  return out.toBytes();
}

class Offset {
  final double x, y;
  const Offset(this.x, this.y);
}

void main() {
  draw();
  final master = Uint8List.fromList(_px);
  final outDir = Directory('${Directory.current.path}/tools/icon_out');
  outDir.createSync(recursive: true);

  File('${outDir.path}/master_icon.png').writeAsBytesSync(_png(master, S, S));
  stdout.writeln('master_icon.png 写入完成');

  // 缩放尺寸
  const targets = {
    'android_mdpi': 48, 'android_hdpi': 72, 'android_xhdpi': 96,
    'android_xxhdpi': 144, 'android_xxxhdpi': 192,
    'web_512': 512, 'web_192': 192, 'web_32': 32, 'web_16': 16,
  };
  final icoPngs = <int, Uint8List>{};
  targets.forEach((name, size) {
    final small = _resize(master, S, S, size, size);
    final png = _png(small, size, size);
    File('${outDir.path}/$name.png').writeAsBytesSync(png);
    if (name.startsWith('web_')) {
      final n = int.parse(name.split('_')[1]);
      if ([16, 32, 192, 512].contains(n)) {
        icoPngs[n] = png;
      }
    }
    stdout.writeln('$name.png ($size) 完成');
  });

  // ICO：16/32/48/64/128/256
  final icoPngsAll = <int, Uint8List>{};
  for (final s in [256, 128, 64, 48, 32, 16]) {
    final small = _resize(master, S, S, s, s);
    icoPngsAll[s] = _png(small, s, s);
  }
  File('${outDir.path}/app_icon.ico')
      .writeAsBytesSync(_ico(icoPngsAll));
  stdout.writeln('app_icon.ico 完成');

  // Android mipmaps 直接写入工程目录
  const androidDir = 'android/app/src/main/res';
  const mipmaps = {
    'mipmap-mdpi': 48, 'mipmap-hdpi': 72, 'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144, 'mipmap-xxxhdpi': 192,
  };
  mipmaps.forEach((dir, size) {
    final small = _resize(master, S, S, size, size);
    final d = Directory('${Directory.current.path}/$androidDir/$dir');
    d.createSync(recursive: true);
    File('${d.path}/ic_launcher.png').writeAsBytesSync(_png(small, size, size));
  });
  stdout.writeln('Android mipmaps 完成');

  // Web 图标
  final webDir = Directory('${Directory.current.path}/web');
  final webIcons = {
    'icons/Icon-192.png': 192, 'icons/Icon-512.png': 512,
    'icons/Icon-maskable-192.png': 192, 'icons/Icon-maskable-512.png': 512,
    'favicon.png': 32,
  };
  webIcons.forEach((rel, size) {
    final small = _resize(master, S, S, size, size);
    final f = File('${webDir.path}/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(_png(small, size, size));
  });
  stdout.writeln('Web 图标完成');

  // Windows ICO
  final winIco = File(
      '${Directory.current.path}/windows/runner/resources/app_icon.ico');
  winIco.parent.createSync(recursive: true);
  winIco.writeAsBytesSync(_ico(icoPngsAll));
  stdout.writeln('Windows app_icon.ico 完成');
  stdout.writeln('ALL ICON OUTPUT DONE');
}
