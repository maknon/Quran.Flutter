import 'package:flutter/cupertino.dart';

class MyPainter extends CustomPainter {
  final Path path;
  final bool nightTheme;

  MyPainter(this.path, this.nightTheme);

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = nightTheme ? const Color(0x40FFFFFF) : const Color(0x30CD5C5C)
      ..style = PaintingStyle.fill;
    //canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}