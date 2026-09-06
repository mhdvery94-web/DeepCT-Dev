import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/prediction.dart';
import '../../models/prediction_frame.dart';
import '../../widgets/frame_stack_viewer.dart';
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

  /// What the record says about how [name] was produced, or null — either
  /// because it came off the scanner, or because the job predates the platform
  /// recording this at all.
  FrameProvenance? _provenanceFor(String name) {
    for (final p in widget.prediction.frameProvenance) {
      if (p.frame == name) return p;
    }
    return null;
  }

  void _openViewer(int indexInVisible) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FrameStackViewer(
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
          // The grid answers "what came out"; this answers "does the sequence
          // move properly", which is the question a CT stack is actually for
          // and the reason people were opening ImageJ alongside the platform.
          // It was reachable only by tapping a thumbnail, which does not
          // announce that a scrubber exists at all.
          if (_visible.isNotEmpty)
            TextButton.icon(
              key: const Key('open-stack-viewer'),
              onPressed: () => _openViewer(0),
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('PLAY STACK'),
            ),
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
              provenance: _provenanceFor(visible[index].name),
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

  /// Null for a scanned frame, and also for a generated one belonging to a job
  /// that finished before the platform began recording this.
  final FrameProvenance? provenance;

  final Future<Uint8List> Function() load;
  final VoidCallback onTap;

  const _FrameTile({
    required this.frame,
    required this.provenance,
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
                  if (frame.isGenerated) _badge(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `AI` for a frame drawn between two scanned neighbours, `AI G2` and up for
  /// one drawn against a frame the model had itself invented.
  ///
  /// The distinction is the point. Every generated frame used to carry the
  /// same badge, and a reader had no way to tell the model's output from the
  /// model's output fed back into the model — which is not the same evidence.
  /// Second generation and beyond is drawn in the warning colour, and the
  /// tooltip names the two frames it came from.
  Widget _badge() {
    final p = provenance;
    final compounded = p != null && !p.isFirstGeneration;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      color: compounded ? AppTheme.warningLight : AppTheme.primaryLight,
      child: Text(
        p == null || p.isFirstGeneration ? 'AI' : 'AI G${p.generation}',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: compounded ? AppTheme.warning : AppTheme.primary,
        ),
      ),
    );

    if (p == null) return chip;

    return Tooltip(
      message: p.isFirstGeneration
          ? 'Interpolated between frames ${p.leftIndex} and ${p.rightIndex}, '
                'both of which came off the scanner.'
          : 'Interpolated between frames ${p.leftIndex} and ${p.rightIndex}. '
                '${p.syntheticParents == 2 ? "Both were" : "One was"} '
                'generated by the model, so this is generation '
                '${p.generation}.',
      child: chip,
    );
  }
}
