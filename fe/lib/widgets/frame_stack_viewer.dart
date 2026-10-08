import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/prediction_frame.dart';
import '../theme/app_theme.dart';

/// Scrub through a stack of frames the way ImageJ does.
///
/// Lives here rather than inside the gallery screen because three places need
/// it: the upload screen shows the frames just sent, the results screen shows
/// those merged with what the model produced, and show their retained evidence.
///
/// WHY THE WHOLE STACK IS HELD IN MEMORY
/// -------------------------------------
/// This used to be a `PageView` whose `itemBuilder` opened a `FutureBuilder`
/// around [loader]. Every step therefore started a fresh fetch and put a
/// spinner on screen until it answered, so dragging the slider produced a
/// stutter of grey circles rather than movement. Nothing about the widget was
/// slow — it was being asked to fetch during the very gesture that needed to
/// be smooth.
///
/// ImageJ feels continuous because the stack is already in RAM before the
/// scrollbar does anything. So this loads every frame up front, reports how
/// far it has got, and only then lets the slider move freely. After that a
/// step costs one `setState` and no I/O at all, which is the whole difference.
///
/// The frames are the ones the platform already renders to PNG for preview —
/// a few hundred kilobytes each, not the 16-bit originals — so a stack of a
/// few dozen is an ordinary amount of memory to hold.
class FrameStackViewer extends StatefulWidget {
  final List<PredictionFrame> frames;
  final int initialIndex;
  final Future<Uint8List> Function(String name) loader;

  const FrameStackViewer({
    super.key,
    required this.frames,
    required this.initialIndex,
    required this.loader,
  });

  @override
  State<FrameStackViewer> createState() => _FrameStackViewerState();
}

class _FrameStackViewerState extends State<FrameStackViewer> {
  /// Decoded bytes per frame, null until fetched.
  late final List<Uint8List?> _bytes = List.filled(widget.frames.length, null);

  /// The first failure per frame, so one unreadable frame explains itself
  /// instead of silently staying blank forever.
  late final List<Object?> _errors = List.filled(widget.frames.length, null);

  late int _index = widget.initialIndex;
  int _done = 0;
  bool _disposed = false;

  /// Animation, the ImageJ way: a fixed interval rather than real timing.
  Timer? _playing;
  int _fps = 8;

  final FocusNode _keys = FocusNode();

  /// How many fetches are in flight at once.
  ///
  /// Serial loading of forty frames over a tunnel is a long wait before
  /// anything moves; unbounded parallelism opens forty sockets and finishes
  /// no sooner. Four keeps the link busy without starving the rest of the app.
  static const int _concurrency = 4;

  @override
  void initState() {
    super.initState();
    _prefetch();
  }

  @override
  void dispose() {
    _disposed = true;
    _playing?.cancel();
    _keys.dispose();
    super.dispose();
  }

  /// Fetch every frame, nearest to the one being looked at first.
  ///
  /// Order matters more than it looks: the frame on screen and its immediate
  /// neighbours are what someone reaches for first, so loading outward from
  /// [initialIndex] makes the viewer usable long before the last frame lands.
  Future<void> _prefetch() async {
    final order = _outwardFrom(widget.initialIndex, widget.frames.length);
    var next = 0;

    Future<void> worker() async {
      while (!_disposed) {
        if (next >= order.length) return;
        final i = order[next++];

        try {
          // Bytes only. Decoding ahead with `precacheImage` was tried and
          // removed: it schedules a frame per image, so a widget test could
          // never settle, and it buys little here — the stutter being fixed
          // is the fetch, and Flutter caches each decode after its first
          // display anyway.
          final bytes = await widget.loader(widget.frames[i].name);
          if (_disposed) return;
          _bytes[i] = bytes;
        } catch (e) {
          if (_disposed) return;
          _errors[i] = e;
        }

        if (_disposed || !mounted) return;
        setState(() => _done++);
      }
    }

    await Future.wait(
      List.generate(_concurrency.clamp(1, order.length), (_) => worker()),
    );
  }

  /// `[3, 4, 2, 5, 1, …]` for a stack of six centred on three.
  static List<int> _outwardFrom(int centre, int length) {
    final order = <int>[];
    for (var step = 0; order.length < length; step++) {
      final right = centre + step;
      final left = centre - step;
      if (step == 0) {
        if (centre >= 0 && centre < length) order.add(centre);
        continue;
      }
      if (right < length) order.add(right);
      if (left >= 0) order.add(left);
    }
    return order;
  }

  bool get _ready => _done >= widget.frames.length;

  void _goTo(int next) {
    final clamped = next.clamp(0, widget.frames.length - 1);
    if (clamped == _index) return;
    setState(() => _index = clamped);
  }

  void _togglePlay() {
    if (_playing != null) {
      setState(() {
        _playing?.cancel();
        _playing = null;
      });
      return;
    }

    setState(() {
      _playing = Timer.periodic(
        Duration(milliseconds: (1000 / _fps).round()),
        (_) {
          if (!mounted) return;
          // Wraps rather than stopping at the end: a loop is what makes a
          // stack read as motion, and it is what ImageJ's animator does.
          setState(() => _index = (_index + 1) % widget.frames.length);
        },
      );
    });
  }

  void _setFps(int fps) {
    final wasPlaying = _playing != null;
    _playing?.cancel();
    _playing = null;
    setState(() => _fps = fps);
    if (wasPlaying) _togglePlay();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _goTo(_index + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _goTo(_index - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.space) {
      _togglePlay();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final frame = widget.frames[_index];

    return Scaffold(
      // Dark ground: greyscale CT detail is far easier to read against black,
      // and this is the one screen where the light surface would fight the
      // content.
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          frame.name,
          style: const TextStyle(fontSize: 15, color: Colors.white),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_index + 1} / ${widget.frames.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Focus(
          focusNode: _keys,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Column(
            children: [
              Expanded(child: _buildStage(frame)),
              if (!_ready) _buildLoading(context),
              _buildControls(context),
              _buildTrack(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStage(PredictionFrame frame) {
    final bytes = _bytes[_index];
    final error = _errors[_index];

    return Stack(
      children: [
        Positioned.fill(
          child: error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not render this frame.\n$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              : bytes == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                )
              : InteractiveViewer(
                  minScale: 1,
                  maxScale: 8,
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      // The frame swap must not blank the screen between two
                      // pictures — that flash is the thing this widget exists
                      // to remove.
                      gaplessPlayback: true,
                    ),
                  ),
                ),
        ),
        // On the image, not under it. The eye is on the picture, and a caption
        // away from it does not get read.
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: frame.isGenerated ? AppTheme.warning : Colors.white24,
            child: Text(
              frame.isGenerated ? 'MODEL OUTPUT' : 'INPUT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: frame.isGenerated ? Colors.black : Colors.white,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Determinate, not a spinner: a stack of forty takes long enough that
  /// "something is happening" is not an answer.
  Widget _buildLoading(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            key: const Key('frame-stack-loading'),
            value: widget.frames.isEmpty ? 1 : _done / widget.frames.length,
            minHeight: 2,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(Colors.white54),
          ),
          const SizedBox(height: 4),
          Text(
            'Loading frames $_done / ${widget.frames.length} — '
            'playback is smooth once they are all here',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final playing = _playing != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('frame-step-back'),
            tooltip: 'Previous frame',
            onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
            icon: const Icon(Icons.skip_previous, color: Colors.white70),
          ),
          IconButton(
            key: const Key('frame-play'),
            tooltip: playing ? 'Pause' : 'Play through the stack',
            // Only once everything is in memory. Starting the animation
            // mid-load would show exactly the stutter this replaced.
            onPressed: _ready ? _togglePlay : null,
            icon: Icon(
              playing ? Icons.pause_circle : Icons.play_circle,
              color: _ready ? Colors.white : Colors.white24,
              size: 34,
            ),
          ),
          IconButton(
            key: const Key('frame-step-forward'),
            tooltip: 'Next frame',
            onPressed: _index < widget.frames.length - 1
                ? () => _goTo(_index + 1)
                : null,
            icon: const Icon(Icons.skip_next, color: Colors.white70),
          ),
          const Spacer(),
          const Text(
            'Speed',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(width: 8),
          for (final fps in const [4, 8, 15])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                key: Key('frame-fps-$fps'),
                onPressed: () => _setFps(fps),
                style: TextButton.styleFrom(
                  minimumSize: const Size(40, 32),
                  padding: EdgeInsets.zero,
                  foregroundColor: _fps == fps
                      ? Colors.white
                      : Colors.white38,
                  backgroundColor: _fps == fps
                      ? Colors.white12
                      : Colors.transparent,
                ),
                child: Text('$fps', style: const TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  /// The slider, with a mark above every frame the model produced.
  Widget _buildTrack(BuildContext context) {
    final frame = widget.frames[_index];
    final last = widget.frames.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The ticks sit in their own row above the slider rather than being
          // painted into it: a Row of Expanded flexes lines each mark up with
          // its frame without a custom track painter.
          SizedBox(
            height: 6,
            child: Row(
              children: [
                for (var i = 0; i < widget.frames.length; i++)
                  Expanded(
                    child: widget.frames[i].isGenerated
                        ? Container(
                            key: Key('frame-tick-$i'),
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            color: AppTheme.warning,
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          if (last > 0)
            Slider(
              value: _index.toDouble().clamp(0, last.toDouble()),
              min: 0,
              max: last.toDouble(),
              // No `divisions`. Divisions make the thumb snap and add a value
              // popup, which is what made scrubbing feel notched rather than
              // continuous. The index is rounded on the way out instead, so
              // the thumb tracks the finger and the frame follows it.
              activeColor: Colors.white,
              inactiveColor: Colors.white24,
              onChanged: (v) {
                // Stop the animation the moment someone takes the handle:
                // fighting the timer for the position is never what was meant.
                if (_playing != null) _togglePlay();
                _goTo(v.round());
              },
            ),
          Text(
            frame.isGenerated
                ? 'Interpolated by the model'
                : 'Uploaded boundary frame',
            style: TextStyle(
              color: frame.isGenerated ? AppTheme.warning : Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
