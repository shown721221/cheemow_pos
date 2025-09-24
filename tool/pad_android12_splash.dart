import 'dart:io';
import 'package:image/image.dart' as img;

/// Adds transparent padding around an image by [paddingRatio] (e.g. 0.12 -> 12%)
/// to reduce visual size on Android 12 splash.
img.ColorUint8 _parseBg(String? s) {
  if (s == null || s.isEmpty || s.toLowerCase() == 'transparent') {
    return img.ColorUint8.rgba(0, 0, 0, 0);
  }
  if (s.toLowerCase() == 'white') {
    return img.ColorUint8.rgba(255, 255, 255, 255);
  }
  // Parse #RRGGBB
  final hex = s.startsWith('#') ? s.substring(1) : s;
  if (hex.length == 6) {
    final r = int.parse(hex.substring(0, 2), radix: 16);
    final g = int.parse(hex.substring(2, 4), radix: 16);
    final b = int.parse(hex.substring(4, 6), radix: 16);
    return img.ColorUint8.rgba(r, g, b, 255);
  }
  return img.ColorUint8.rgba(0, 0, 0, 0);
}

Future<void> main(List<String> args) async {
  final srcPath = args.isNotEmpty
      ? args[0]
      : 'assets/images/splash_android12.png';
  final outPath = args.length > 1
      ? args[1]
      : 'assets/images/splash_android12_padded.png';
  final paddingRatio = args.length > 2 ? double.parse(args[2]) : 0.12;
  final bg = _parseBg(args.length > 3 ? args[3] : null);

  final bytes = await File(srcPath).readAsBytes();
  final src = img.decodeImage(bytes);
  if (src == null) {
    stderr.writeln('Failed to decode image: $srcPath');
    exit(1);
  }

  final padX = (src.width * paddingRatio).round();
  final padY = (src.height * paddingRatio).round();
  final outW = src.width + padX * 2;
  final outH = src.height + padY * 2;

  final out = img.Image(width: outW, height: outH);
  // Fill with requested background (transparent by default)
  img.fill(out, color: bg);
  img.compositeImage(out, src, dstX: padX, dstY: padY);

  final encoded = img.encodePng(out);
  await File(outPath).writeAsBytes(encoded);
  stdout.writeln(
    'Wrote padded image to: $outPath (padding ${paddingRatio * 100}%, bg=$bg)',
  );
}
