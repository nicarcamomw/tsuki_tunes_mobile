import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';

class SakuraOverlay extends StatefulWidget {
  const SakuraOverlay({super.key});

  @override
  State<SakuraOverlay> createState() => _SakuraOverlayState();
}

class _SakuraOverlayState extends State<SakuraOverlay>
    with SingleTickerProviderStateMixin {
  static const _birthdayKey = 'tsuki_birthday';
  static const _petalCount = 28;

  late final Ticker _ticker;
  final _rng = Random();
  List<_Petal> _petals = const [];
  bool _active = false;
  double _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _checkBirthday();
  }

  Future<void> _checkBirthday() async {
    final prefs = await SharedPreferences.getInstance();
    final birthday = prefs.getString(_birthdayKey);
    if (birthday == null || !mounted) return;

    final parts = birthday.split('-');
    if (parts.length != 2) return;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    if (month == null || day == null) return;

    final now = DateTime.now();
    if (now.month == month && now.day == day) {
      setState(() {
        _active = true;
        _petals = List.generate(_petalCount, (_) => _Petal.random(_rng));
      });
    }
  }

  void _onTick(Duration elapsed) {
    if (!_active) return;
    _elapsed = elapsed.inMilliseconds / 1000.0;
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();
    return CustomPaint(
      size: Size.infinite,
      painter: _SakuraPainter(_petals, _elapsed),
    );
  }
}

class _Petal {
  final double x;
  final double startY;
  final double size;
  final double speed;
  final double drift;
  final double wobblePhase;
  final double wobbleAmp;
  final double rotation;
  final double rotSpeed;
  final double alpha;

  const _Petal({
    required this.x,
    required this.startY,
    required this.size,
    required this.speed,
    required this.drift,
    required this.wobblePhase,
    required this.wobbleAmp,
    required this.rotation,
    required this.rotSpeed,
    required this.alpha,
  });

  factory _Petal.random(Random rng) {
    return _Petal(
      x: rng.nextDouble(),
      startY: -rng.nextDouble() * 1.5,
      size: 4.0 + rng.nextDouble() * 6.0,
      speed: 0.03 + rng.nextDouble() * 0.04,
      drift: (rng.nextDouble() - 0.5) * 0.015,
      wobblePhase: rng.nextDouble() * pi * 2,
      wobbleAmp: 8.0 + rng.nextDouble() * 16.0,
      rotation: rng.nextDouble() * pi * 2,
      rotSpeed: 0.3 + rng.nextDouble() * 0.8,
      alpha: 0.15 + rng.nextDouble() * 0.30,
    );
  }
}

class _SakuraPainter extends CustomPainter {
  final List<_Petal> petals;
  final double t;

  _SakuraPainter(this.petals, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in petals) {
      final y = (p.startY + p.speed * t) % 1.3 - 0.15;
      final wobble = sin(t * 1.2 + p.wobblePhase) * p.wobbleAmp;
      final px = (p.x + p.drift * t) % 1.0 * size.width + wobble;
      final py = y * size.height;
      final rot = p.rotation + p.rotSpeed * t;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rot);

      final paint = Paint()
        ..color = AppColors.sakura.withValues(alpha: p.alpha);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(p.size * 0.25, p.size * 0.1),
          width: p.size * 0.7,
          height: p.size * 0.4,
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SakuraPainter old) => true;
}
