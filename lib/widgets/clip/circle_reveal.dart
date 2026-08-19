import 'package:flutter/material.dart';

class CircleRevealClipper extends CustomClipper<Rect> {
  final Offset center;
  final double radius;

  CircleRevealClipper({required this.center, required this.radius});

  @override
  Rect getClip(Size size) {
    return Rect.fromCircle(center: center, radius: radius);
  }

  @override
  bool shouldReclip(covariant CircleRevealClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radius != radius;
  }
}