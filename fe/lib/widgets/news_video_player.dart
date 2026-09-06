import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../services/api_client.dart';
import '../services/secure_store.dart';
import '../theme/app_theme.dart';
import '../utils/blob_url.dart';

/// True where `video_player` actually has an implementation.
///
/// Android, iOS/macOS and web. There is no Windows or Linux plugin, and the
/// project carries `windows/` and `linux/` folders only because `flutter
/// create` made them — the product ships to web and Android.
///
/// Checked up front rather than caught: an exception thrown after the screen
/// is built is too late to change what was drawn.
bool get videoPlaybackSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// What every request for a clip has to carry.
///
/// The player is the one thing in this app that fetches from the API without
/// going through [ApiClient]: the decoding happens in native code, from a URL,
/// so it has to repeat by hand what ApiClient's `BaseOptions` do for everyone
/// else.
///
/// `ngrok-skip-browser-warning` is the one that matters. ngrok answers its
/// HTML interstitial with **HTTP 200 and `Content-Type: text/html`** to
/// anything it takes for a browser — verified against this tunnel with a real
/// `<video>` element's `Accept: video/*` and `Sec-Fetch-Dest: video`, which it
/// intercepted anyway. A player handed HTML where it expected MP4 cannot
/// initialise, and all it is able to report is that the video would not play.
/// That is the sentence this header exists to prevent.
///
/// **It does not reach the web build**, and that is why the widget below has a
/// separate path for it: a browser will not let a page put headers on the
/// request a `<video src>` makes, so on web the bytes are fetched by hand.
Future<Map<String, String>> newsVideoHeaders() async {
  final headers = <String, String>{'ngrok-skip-browser-warning': 'true'};

  // A published post needs no token. A draft an administrator is previewing
  // does — the same bargain AuthedImage already makes for the photo.
  final token = await SecureStore.read(ApiClient.tokenKey);
  if (token != null) headers['Authorization'] = 'Bearer $token';

  return headers;
}

/// Plays a post's clip in place.
///
/// Nothing is fetched until someone asks for it: the slide shows [poster] with
/// a play button over it, and only a tap opens the stream. A landing page that
/// pulled tens of megabytes on load, for a clip most visitors will not watch,
/// would be a poor trade on a phone.
///
/// ## Web plays the same clip a different way
///
/// On Android the player streams: ExoPlayer opens the URL with
/// [newsVideoHeaders] and pulls ranges as it needs them. On web it cannot —
/// see [newsVideoHeaders] — so the whole file is fetched through [ApiClient]
/// first, which *is* allowed to send headers because Dio uses XHR there, and
/// the player is handed a `blob:` URL of the result.
///
/// The cost is worth stating plainly: **no streaming**. Nothing plays until
/// the last byte has arrived, and the file sits in memory until this widget is
/// disposed. That is a fair trade for a short news clip and the wrong one for
/// anything large, hence [webDownloadLimitBytes]. It is also temporary — the
/// day the API answers on a domain with no interstitial in front of it, this
/// branch can go and `<video src>` will stream properly on its own.
class NewsVideoPlayer extends StatefulWidget {
  /// Absolute, as `NewsPost.videoUrl` gives it.
  final String url;

  /// Shown beside the controls; null hides the label.
  final String? sizeLabel;

  /// Used on web only, to refuse a download too big to hold in memory before
  /// it starts. Null means the size is unknown — the download is attempted
  /// rather than refused on a guess.
  final int? sizeBytes;

  /// Fires true when playback starts and false when it stops, so a carousel
  /// can hold its slide still rather than rotating out from under a viewer.
  final ValueChanged<bool>? onPlayingChanged;

  /// The most a browser is asked to pull into memory in one go.
  ///
  /// Above this, the fallback — open the file in a new tab and let the browser
  /// deal with it — is the better answer, even though it means meeting the
  /// ngrok interstitial on the way. Thirty megabytes is around two minutes at
  /// the bitrate these clips are recorded at.
  static const int webDownloadLimitBytes = 30 * 1024 * 1024;

  const NewsVideoPlayer({
    super.key,
    required this.url,
    this.sizeLabel,
    this.sizeBytes,
    this.onPlayingChanged,
  });

  @override
  State<NewsVideoPlayer> createState() => _NewsVideoPlayerState();
}

enum _Stage { idle, opening, ready, failed }

class _NewsVideoPlayerState extends State<NewsVideoPlayer> {
  VideoPlayerController? _controller;
  _Stage _stage = _Stage.idle;

  /// Object URL handed to the player on web, kept so it can be revoked. The
  /// browser holds the whole file alive behind it until we do.
  String? _blobUrl;

  /// How much of the web download has arrived, 0..1, or null while that is not
  /// yet known. Native streams, so it stays null there.
  double? _progress;

  /// Why the clip could not be played, where there is something more useful to
  /// say than "it could not".
  String? _failureNote;

  /// Last value handed to [NewsVideoPlayer.onPlayingChanged], so the callback
  /// fires on transitions rather than on every frame of playback.
  bool _reportedPlaying = false;

  @override
  void initState() {
    super.initState();

    // Load the clip's own first frame, and use *that* as the poster.
    //
    // The poster used to be the post's photograph, handed in by the caller.
    // It made a video look like the picture above it with a play button
    // stamped on, which told a reader nothing about the clip and made the two
    // media blocks read as one thing shown twice. A still from the video says
    // "video", and it is the only poster that is actually about the video.
    //
    // Native players stream: `initialize()` reads the container header and one
    // frame, a few hundred kilobytes, not the file. **Web is excluded on
    // purpose** — there is no streaming on that path, `_downloadForWeb` pulls
    // the entire clip into memory, and doing that for something nobody has
    // asked to watch is a bill rather than a poster. A browser keeps the play
    // button and the dark panel.
    if (!kIsWeb && videoPlaybackSupported) _prepare();
  }

  /// Opens the clip without playing it, so its first frame can stand in as the
  /// poster. Failure is deliberately quiet: the play button still works, and
  /// that path is the one that can explain what went wrong.
  Future<void> _prepare() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: await newsVideoHeaders(),
    );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller.addListener(_onPlaybackChanged);
      setState(() {
        _controller = controller;
        _stage = _Stage.ready;
      });
    } catch (_) {
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlaybackChanged);
    _controller?.dispose();

    // After the controller, so the element has let go of the URL first.
    final blob = _blobUrl;
    if (blob != null) revokeBlobUrl(blob);

    // Whatever was holding the carousel still has to be released, or the
    // slideshow never starts again after someone watches a clip.
    _report(false);
    super.dispose();
  }

  void _report(bool playing) {
    if (playing == _reportedPlaying) return;
    _reportedPlaying = playing;
    widget.onPlayingChanged?.call(playing);
  }

  void _onPlaybackChanged() {
    final controller = _controller;
    if (controller == null) return;
    _report(controller.value.isPlaying);
  }

  void _fail(String? note) {
    if (!mounted) return;
    setState(() {
      _failureNote = note;
      _stage = _Stage.failed;
    });
  }

  Future<void> _open() async {
    if (_stage == _Stage.opening) return;
    setState(() {
      _stage = _Stage.opening;
      _progress = null;
      _failureNote = null;
    });

    // On web the source is a blob of bytes fetched by hand; everywhere else
    // the player streams the URL directly.
    String source = widget.url;
    if (kIsWeb && blobUrlsSupported) {
      final blob = await _downloadForWeb();
      if (blob == null) return; // _downloadForWeb has already said why.
      if (!mounted) {
        revokeBlobUrl(blob);
        return;
      }
      _blobUrl = blob;
      source = blob;
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(source),
      // Pointless on web — a blob URL is local, and a browser drops these
      // anyway — and a needless read of the keystore besides.
      httpHeaders: kIsWeb ? const {} : await newsVideoHeaders(),
    );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller.addListener(_onPlaybackChanged);
      await controller.play();

      setState(() {
        _controller = controller;
        _stage = _Stage.ready;
      });
    } catch (_) {
      await controller.dispose();
      _fail(null);
    }
  }

  /// Pulls the whole clip through [ApiClient] and wraps it in an object URL.
  ///
  /// Returns null when it could not, having already moved the widget to
  /// [_Stage.failed] with the reason.
  Future<String?> _downloadForWeb() async {
    final size = widget.sizeBytes;
    if (size != null && size > NewsVideoPlayer.webDownloadLimitBytes) {
      final label = widget.sizeLabel;
      _fail(
        'This clip is too large for a browser to load in one piece'
        '${label == null ? '' : ' ($label)'}.',
      );
      return null;
    }

    try {
      final result = await ApiClient.instance.getBytes(
        // Absolute, so Dio uses it as given rather than appending it to the
        // base URL. The token interceptor and the ngrok header still apply,
        // which is the whole point of coming through ApiClient.
        widget.url,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          // The tunnel does not always send a Content-Length; the post's own
          // recorded size is the fallback, and where neither exists the ring
          // simply stays indeterminate.
          final expected = total > 0 ? total : (size ?? 0);
          if (expected <= 0) return;
          setState(() => _progress = (received / expected).clamp(0.0, 1.0));
        },
      );

      final contentType = result.headers.value('content-type') ?? '';

      // The interstitial, arriving with HTTP 200 as it always does. It should
      // not get this far — the header that suppresses it goes out with every
      // ApiClient request — but handing HTML to a decoder produces a far worse
      // message than this does.
      if (contentType.contains('text/html') || result.bytes.isEmpty) {
        _fail(null);
        return null;
      }

      final mime = contentType.split(';').first.trim();
      return createBlobUrl(
        result.bytes,
        mimeType: mime.startsWith('video/') ? mime : 'video/mp4',
      );
    } catch (_) {
      _fail(null);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.ready:
        return _player(_controller!);
      case _Stage.failed:
        return _unavailable(context);
      case _Stage.opening:
        return _cover(_Progress(value: _progress));
      case _Stage.idle:
        return _cover(_PlayButton(onTap: _start));
    }
  }

  /// Opening the file in the system player is the honest option where this app
  /// cannot decode it — on desktop there is no plugin to decode it with.
  void _start() {
    if (videoPlaybackSupported) {
      _open();
    } else {
      launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication);
    }
  }

  /// The poster, with [child] centred on top of it.
  Widget _cover(Widget child) {
    return GestureDetector(
      onTap: _stage == _Stage.idle ? _start : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: AppTheme.textPrimary),

          // A scrim, so a white play button reads against a pale photo and a
          // dark one alike.
          Container(color: Colors.black.withValues(alpha: 0.32)),

          Center(child: child),

          if (widget.sizeLabel != null)
            Positioned(
              left: 12,
              bottom: 12,
              child: _Chip(
                key: const Key('news-video-badge'),
                icon: Icons.movie_outlined,
                label: widget.sizeLabel!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _player(VideoPlayerController controller) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),

          // Tapping the picture toggles playback, which is the gesture people
          // already expect from every other player.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.value.isPlaying
                  ? controller.pause()
                  : controller.play(),
            ),
          ),

          // The clip now opens itself, so the first thing on screen is a
          // paused frame rather than a placeholder. It still needs to look
          // pressable, or a still is indistinguishable from a photograph.
          // Listens to the controller directly: the overlay has to leave the
          // moment playback starts, and nothing else here rebuilds for that.
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.isPlaying || value.position > Duration.zero) {
                return const SizedBox.shrink();
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.black.withValues(alpha: 0.28)),
                  Center(child: _PlayButton(onTap: controller.play)),
                ],
              );
            },
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Controls(controller: controller),
          ),
        ],
      ),
    );
  }

  /// Shown when the file will not open, or where there is no decoder.
  ///
  /// Hands the URL to the system rather than fetching it: the file may be
  /// 50 MB, and pulling that into memory only to write it back out is the
  /// wrong way round when the OS already knows how to download.
  Widget _unavailable(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_outlined, size: 28, color: AppTheme.textMuted),
          const SizedBox(height: 8),
          Text(
            _failureNote ?? 'This video could not be played here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(widget.url),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(
              widget.sizeLabel == null
                  ? 'OPEN VIDEO'
                  : 'OPEN VIDEO (${widget.sizeLabel})',
            ),
          ),
        ],
      ),
    );
  }
}

/// The wait before playback: a ring, and a percentage when there is one.
///
/// A determinate value only ever appears on web, where the whole file has to
/// land before the first frame can be drawn. Someone watching an indeterminate
/// spinner for eighteen megabytes has no way to tell it from one that hung.
class _Progress extends StatelessWidget {
  final double? value;

  const _Progress({required this.value});

  @override
  Widget build(BuildContext context) {
    final percent = value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 38,
          height: 38,
          child: CircularProgressIndicator(
            value: percent,
            strokeWidth: 3,
            color: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
          ),
        ),
        if (percent != null) ...[
          const SizedBox(height: 10),
          Text(
            '${(percent * 100).round()}%',
            key: const Key('news-video-progress'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primary,
      shape: const RoundedRectangleBorder(),
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 60,
          height: 48,
          child: Icon(Icons.play_arrow, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

/// Play/pause, a scrubber and a clock, over the foot of the picture.
class _Controls extends StatelessWidget {
  final VideoPlayerController controller;

  const _Controls({required this.controller});

  static String _clock(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return ColoredBox(
          color: Colors.black.withValues(alpha: 0.66),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scrubbing works because the server answers Range requests — a
              // BinaryFileResponse does that on its own, so nothing here had
              // to be written for it. On web it is a blob in memory, which
              // seeks better still.
              VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: VideoProgressColors(
                  playedColor: AppTheme.primary,
                  bufferedColor: Colors.white.withValues(alpha: 0.35),
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
                child: Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 20,
                      color: Colors.white,
                      icon: Icon(
                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: () =>
                          value.isPlaying ? controller.pause() : controller.play(),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      color: Colors.white,
                      icon: Icon(
                        value.volume == 0
                            ? Icons.volume_off_outlined
                            : Icons.volume_up_outlined,
                      ),
                      onPressed: () =>
                          controller.setVolume(value.volume == 0 ? 1 : 0),
                    ),
                    Expanded(
                      child: Text(
                        '${_clock(value.position)} / ${_clock(value.duration)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A small dark label over a photo.
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: Colors.black.withValues(alpha: 0.7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
