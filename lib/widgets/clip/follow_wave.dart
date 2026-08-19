import 'package:flutter/material.dart';

class FollowClipper extends CustomClipper<Path> {
  final double clickdx;
  final double waveLength;
  final double waveDepth;
  final bool isConcave;
  final bool isTraceable;
  const FollowClipper({
    required this.clickdx,
    required this.waveLength,
    required this.waveDepth,
    required this.isConcave,
    this.isTraceable = true,
  });

  @override
  Path getClip(Size size) {
    double sh = isConcave ? 0 : size.height;
    double wl = isConcave ? waveLength : -waveLength;
    double wd = isConcave ? waveDepth : -waveDepth;
    Path path = Path();

    double dy = isTraceable ? sh + wd - 5 : sh + wd;
    Offset ctrl2 = Offset(clickdx, dy);

    Offset start1 = Offset(ctrl2.dx + wl / 2, sh);
    Offset end1 = Offset(ctrl2.dx + wl / 6, sh + wd / 2);
    Offset ctrl1 = Offset(ctrl2.dx + wl / 3, sh);

    if (isConcave) {
      // 下凹
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
      path.lineTo(start1.dx, start1.dy);
      path.quadraticBezierTo(ctrl1.dx, ctrl1.dy, end1.dx, end1.dy);

      Offset end2 = Offset(ctrl2.dx - wl / 6, sh + wd / 2);
      path.quadraticBezierTo(ctrl2.dx, ctrl2.dy, end2.dx, end2.dy);

      Offset end3 = Offset(ctrl2.dx - wl / 2, sh);
      Offset ctrl3 = Offset(ctrl2.dx - wl / 3, sh);
      path.quadraticBezierTo(ctrl3.dx, ctrl3.dy, end3.dx, end3.dy);
      path.lineTo(0, sh);
      path.close();
    } else {
      // 上凸
      path.lineTo(0, size.height);
      path.lineTo(start1.dx, start1.dy);
      path.quadraticBezierTo(ctrl1.dx, ctrl1.dy, end1.dx, end1.dy);

      Offset end2 = Offset(ctrl2.dx - wl / 6, sh + wd / 2);
      path.quadraticBezierTo(ctrl2.dx, ctrl2.dy, end2.dx, end2.dy);

      Offset end3 = Offset(ctrl2.dx - wl / 2, sh);
      Offset ctrl3 = Offset(ctrl2.dx - wl / 3, sh);
      path.quadraticBezierTo(ctrl3.dx, ctrl3.dy, end3.dx, end3.dy);
      path.lineTo(size.width, size.height);

      path.lineTo(size.width, 0);
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant FollowClipper oldClipper) {
    return oldClipper.clickdx != clickdx ||
        oldClipper.waveLength != waveLength ||
        oldClipper.waveDepth != waveDepth;
  }
}
