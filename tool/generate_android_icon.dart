import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  const paddingRatio = 0.16;
  final input = File('assets/logo/DLogo.png').readAsBytesSync();
  final src = img.decodeImage(input)!;

  var canvas = img.Image(width: size, height: size);
  canvas = img.fill(canvas, color: img.ColorRgb8(10, 10, 10));

  final safe = (size * (1 - paddingRatio * 2)).round();
  final scale = (src.width >= src.height) ? safe / src.width : safe / src.height;
  final targetW = (src.width * scale).round();
  final targetH = (src.height * scale).round();
  final resized = img.copyResize(src, width: targetW, height: targetH, interpolation: img.Interpolation.linear);

  final dx = ((size - targetW) / 2).round();
  final dy = ((size - targetH) / 2).round();
  canvas = img.compositeImage(canvas, resized, dstX: dx, dstY: dy);

  final outBytes = img.encodePng(canvas);
  File('assets/logo/icon_android.png').writeAsBytesSync(outBytes);
  stdout.writeln('Wrote assets/logo/icon_android.png');
}
