import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// "Continue with Google" outlined button with the Google "G" logo.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.label = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: context.colors.surfaceLowest,
          foregroundColor: context.colors.onSurface,
          disabledForegroundColor: context.colors.outline,
          side: BorderSide(color: context.colors.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: context.colors.primary),
              )
            else
              const SizedBox(
                width: 20,
                height: 20,
                child: CustomPaint(painter: _GoogleLogoPainter()),
              ),
            const SizedBox(width: 12),
            Text(loading ? 'Connecting…' : label),
          ],
        ),
      ),
    );
  }
}

// Google brand colors: part of the logo, they do not follow the app theme
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  double _rad(double deg) => deg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.22;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, s - stroke, s - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // Angles start at 3 o'clock and go clockwise
    canvas.drawArc(rect, _rad(0), _rad(45), false, paint..color = _blue);
    canvas.drawArc(rect, _rad(45), _rad(105), false, paint..color = _green);
    canvas.drawArc(rect, _rad(150), _rad(65), false, paint..color = _yellow);
    canvas.drawArc(rect, _rad(215), _rad(103), false, paint..color = _red);

    // Horizontal bar of the "G"
    canvas.drawRect(
      Rect.fromLTWH(s / 2, s / 2 - stroke / 2, s / 2, stroke),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
