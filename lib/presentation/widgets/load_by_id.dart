import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../state/app_providers.dart';
import 'haptics.dart';
import 'skeleton_loader.dart';

/// A page opened with only an id (a deep link): shows [initial] right away
/// when the caller already had the object, otherwise loads it, and says so
/// plainly when it doesn't exist.
class LoadById<T extends Object> extends ConsumerStatefulWidget {
  const LoadById({
    super.key,
    required this.initial,
    required this.load,
    required this.builder,
  });

  final T? initial;
  final Future<T?> Function(WidgetRef ref) load;
  final Widget Function(T value) builder;

  @override
  ConsumerState<LoadById<T>> createState() => _LoadByIdState<T>();
}

class _LoadByIdState<T extends Object> extends ConsumerState<LoadById<T>> {
  T? _value;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
    if (_value == null) _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final value = await widget.load(ref);
    if (!mounted) return;
    setState(() {
      _value = value;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    if (value != null) return widget.builder(value);
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: _loading
          ? const SkeletonDetailPage()
          : Center(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_off_rounded, color: AppColors.textMuted, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    ref.watch(stringsProvider).linkNotFound,
                    style: ref.watch(localeProvider).getTextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () { Haptics.tap(); _fetch(); },
                    child: Text(
                      ref.watch(stringsProvider).retry,
                      style: const TextStyle(color: AppColors.accent),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
