import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/prediction_frame.dart';
import '../theme/app_theme.dart';

/// Scrub through a stack of frames the way ImageJ does.
///
/// Lives here rather than inside the gallery screen because three places need
/// it: the upload screen shows the frames just sent, the results screen shows
/// those merged with what the model produced, and training shows its own.
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
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
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
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pages,
                    itemCount: widget.frames.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, index) {
                      return FutureBuilder<Uint8List>(
                        future: widget.loader(widget.frames[index].name),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Could not render this frame.\n'
                                  '${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white54,
                              ),
                            );
                          }

                          return InteractiveViewer(
                            minScale: 1,
                            maxScale: 8,
                            child: Center(
                              child: Image.memory(
                                snapshot.data!,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                                gaplessPlayback: true,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  // On the image, not under it. The eye is on the picture, and
                  // a caption away from it does not get read.
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      color: frame.isGenerated
                          ? AppTheme.warning
                          : Colors.white24,
                      child: Text(
                        frame.isGenerated ? 'MODEL OUTPUT' : 'INPUT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: frame.isGenerated
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildTrack(context),
          ],
        ),
      ),
    );
  }

  /// The slider, with a mark above every frame the model produced.
  ///
  /// Two-way: dragging the slider turns the page, and swiping the page moves
  /// the slider. One-way would leave the slider lying as soon as someone
  /// swiped the image.
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
              value: _index.toDouble(),
              min: 0,
              max: last.toDouble(),
              divisions: last,
              activeColor: Colors.white,
              inactiveColor: Colors.white24,
              // jumpToPage, not animateToPage: scrubbing is a search, and a
              // 300ms animation on every step makes it feel gluey.
              onChanged: (v) {
                final next = v.round();
                if (next == _index) return;
                setState(() => _index = next);
                _pages.jumpToPage(next);
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
