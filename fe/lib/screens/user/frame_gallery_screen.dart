import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/prediction.dart';
import '../../models/prediction_frame.dart';
import '../../services/api_client.dart';
import '../../services/prediction_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_state_views.dart';

/// Look at the frames a job produced, without downloading the archive first.
///
/// The frames on disk are 16-bit TIFFs, which neither a browser nor Flutter can
/// decode, so the server renders each one to PNG on request and caches it
/// beside the job. Thumbnails are fetched small and the full view larger, so a
/// gallery of forty frames does not pull forty full-resolution images.
class FrameGalleryScreen extends StatefulWidget {
  final Prediction prediction;

  const FrameGalleryScreen({super.key, required this.prediction});

  @override
  State<FrameGalleryScreen> createState() => _FrameGalleryScreenState();
}

class _FrameGalleryScreenState extends State<FrameGalleryScreen> {
  final PredictionService _service = PredictionService();

  /// Rendered PNGs, keyed by "name@size". Kept for the life of the screen so
  /// scrolling back does not re-fetch.
  final Map<String, Uint8List> _cache = {};

  static const int _thumbSize = 256;
  static const int _fullSize = 1024;

  bool _isLoading = true;
  String? _error;
  List<PredictionFrame> _frames = const [];

  /// Show only the frames the model generated.
  bool _generatedOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final frames = await _service.frames(widget.prediction.id);

      // Order by frame number so inputs and outputs interleave the way the
      // sequence actually runs, rather than grouping by kind.
      frames.sort((a, b) {
        final an = a.frameNumber;
        final bn = b.frameNumber;
        if (an == null || bn == null) return a.name.compareTo(b.name);
        return an.compareTo(bn);
      });

      if (!mounted) return;
      setState(() {
        _frames = frames;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<Uint8List> _preview(String name, int size) async {
    final key = '$name@$size';
    final cached = _cache[key];
    if (cached != null) return cached;

    final bytes = await _service.framePreview(
      id: widget.prediction.id,
      name: name,
      size: size,
    );

    _cache[key] = bytes;
    return bytes;
  }

  List<PredictionFrame> get _visible =>
      _generatedOnly ? _frames.where((f) => f.isGenerated).toList() : _frames;

  void _openViewer(int indexInVisible) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FrameViewer(
          frames: _visible,
          initialIndex: indexInVisible,
          loader: (name) => _preview(name, _fullSize),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final generated = _frames.where((f) => f.isGenerated).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Frames'),
        backgroundColor: AppTheme.surface,
        shape: const Border(bottom: BorderSide(color: AppTheme.border)),
        actions: [
          if (generated > 0 && generated < _frames.length)
            TextButton(
              onPressed: () => setState(() => _generatedOnly = !_generatedOnly),
              child: Text(_generatedOnly ? 'SHOW ALL' : 'GENERATED ONLY'),
            ),
        ],
      ),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingView(message: 'Loading frames...');
    }

    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    if (_frames.isEmpty) {
      return const EmptyView(message: 'This job has no frames on disk');
    }

    final visible = _visible;
    final width = MediaQuery.of(context).size.width;
    final columns = width < 500
        ? 2
        : width < 900
        ? 3
        : width < 1300
        ? 4
        : 5;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.prediction.displayName} — '
                  '${_frames.length - generatedCount} uploaded, '
                  '$generatedCount generated',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              // Square image plus a caption strip.
              childAspectRatio: 0.82,
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) => _FrameTile(
              frame: visible[index],
              load: () => _preview(visible[index].name, _thumbSize),
              onTap: () => _openViewer(index),
            ),
          ),
        ),
      ],
    );
  }

  int get generatedCount => _frames.where((f) => f.isGenerated).length;
}

/// One thumbnail. Loads its own bytes so the grid can build lazily.
class _FrameTile extends StatelessWidget {
  final PredictionFrame frame;
  final Future<Uint8List> Function() load;
  final VoidCallback onTap;

  const _FrameTile({
    required this.frame,
    required this.load,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(
            color: frame.isGenerated ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: FutureBuilder<Uint8List>(
                future: load(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppTheme.borderDark,
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    // Frames are greyscale detail; smoothing them helps.
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      frame.name,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (frame.isGenerated)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      color: AppTheme.primaryLight,
                      child: const Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-size viewer with pan/zoom and stepping between frames.
class _FrameViewer extends StatefulWidget {
  final List<PredictionFrame> frames;
  final int initialIndex;
  final Future<Uint8List> Function(String name) loader;

  const _FrameViewer({
    required this.frames,
    required this.initialIndex,
    required this.loader,
  });

  @override
  State<_FrameViewer> createState() => _FrameViewerState();
}

class _FrameViewerState extends State<_FrameViewer> {
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
      // and this is the one screen where the app's light surface would fight
      // the content.
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
              child: PageView.builder(
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
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                frame.isGenerated
                    ? 'Generated by the model'
                    : 'Uploaded boundary frame',
                style: TextStyle(
                  color: frame.isGenerated ? AppTheme.warning : Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
