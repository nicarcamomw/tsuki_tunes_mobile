import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../providers/audio_provider.dart';

/// Like `ref.watch(audioProvider.select(...))`, but also follows the playback
/// position, which the provider reports on its own [AudioProvider.progressListenable]
/// instead of through notifyListeners. Rebuilds only when the selected value
/// changes, so a selector that rounds (a line index, whole seconds) rebuilds
/// as rarely as it can.
class AudioProgressSelector<T> extends ConsumerStatefulWidget {
  final T Function(AudioProvider audio) selector;
  final Widget Function(BuildContext context, T value) builder;

  const AudioProgressSelector({
    super.key,
    required this.selector,
    required this.builder,
  });

  @override
  ConsumerState<AudioProgressSelector<T>> createState() => _AudioProgressSelectorState<T>();
}

class _AudioProgressSelectorState<T> extends ConsumerState<AudioProgressSelector<T>> {
  AudioProvider? _audio;
  Listenable? _listenable;
  late T _value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final audio = ref.read(audioProvider);
    if (!identical(audio, _audio)) {
      _listenable?.removeListener(_onChange);
      _audio = audio;
      _listenable = Listenable.merge([audio, audio.progressListenable])
        ..addListener(_onChange);
      _value = widget.selector(audio);
    }
  }

  @override
  void didUpdateWidget(AudioProgressSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The selector is usually a fresh closure over new inputs.
    _value = widget.selector(_audio!);
  }

  void _onChange() {
    final next = widget.selector(_audio!);
    if (next != _value) setState(() => _value = next);
  }

  @override
  void dispose() {
    _listenable?.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
