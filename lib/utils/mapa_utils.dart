// lib/utils/mapa_utils.dart

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';

class MapaUtils {
  static Future<Uint8List> generarIconoPremium(Color colorFondo, IconData icono, {double size = 90.0}) async {
    final recorder = ui.PictureRecorder(); 
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    final center = Offset(size / 2, size / 2);
    final radius = size / 2.5;

    final shadowPath = Path()..addOval(Rect.fromCircle(center: Offset(center.dx, center.dy + 4), radius: radius));
    canvas.drawShadow(shadowPath, Colors.black.withAlpha(128), 10.0, true);

    final paintWhite = Paint()..color = Colors.white..isAntiAlias = true;
    canvas.drawCircle(center, radius, paintWhite);

    final paintColor = Paint()..color = colorFondo..isAntiAlias = true;
    canvas.drawCircle(center, radius - 5.0, paintColor);

    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icono.codePoint),
      style: TextStyle(fontSize: radius * 1.1, fontFamily: icono.fontFamily, package: icono.fontPackage, color: Colors.white),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(center.dx - (textPainter.width / 2), center.dy - (textPainter.height / 2)));

    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }
}