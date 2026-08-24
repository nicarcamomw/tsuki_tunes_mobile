import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class AudioVisualizer extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double maxHeight;
  final Color activeColor;

  const AudioVisualizer({
    super.key,
    required this.isPlaying,
    this.barCount = 24,
    this.maxHeight = 36,
    this.activeColor = AppColors.accent,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  late List<double> _targetHeights;

  @override
  void initState() {
    super.initState();
    _targetHeights = List.generate(widget.barCount, (_) => 0.2);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..addListener(() {
        if (widget.isPlaying && mounted) {
          setState(() {
            _targetHeights = List.generate(
              widget.barCount,
              (i) => 0.15 + _random.nextDouble() * 0.85,
            );
          });
        }
      });

    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        setState(() {
          _targetHeights = List.generate(widget.barCount, (_) => 0.15);
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.maxHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (index) {
          final heightFactor = _targetHeights[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 3,
              height: widget.maxHeight * heightFactor,
              decoration: BoxDecoration(
                color: widget.isPlaying ? widget.activeColor : AppColors.borderGlow,
                borderRadius: BorderRadius.circular(1.5),
                boxShadow: widget.isPlaying
                    ? [
                        BoxShadow(
                          color: widget.activeColor.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}
