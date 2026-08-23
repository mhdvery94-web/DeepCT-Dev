import 'dart:async';

import 'package:flutter/material.dart';

import '../models/news_post.dart';
import '../services/news_service.dart';
import 'authed_image.dart';
import 'news_video_player.dart';
import '../theme/app_theme.dart';
import 'app_dialog.dart';

/// Research news, as a slideshow on the landing page.
///
/// Loads its own data and **renders nothing at all** when there is none, or
/// when the request fails. A visitor should never meet an error box on the
/// front page over something optional — if the news cannot be fetched, the
/// page simply reads as it did before any news existed.
class NewsCarousel extends StatefulWidget {
  const NewsCarousel({super.key});

  /// Replaces the network fetch. Tests only — production leaves it null.
  ///
  /// This is the same bargain as `GoogleFonts.config.allowRuntimeFetching`
  /// in the test setup: the widget loads itself, so every test that pumps the
  /// landing page would otherwise start a real HTTP request whose timeout
  /// timer is still pending when the test ends, and Flutter fails a test with
  /// pending timers.
  static Future<List<NewsPost>> Function()? debugLoader;

  @override
  State<NewsCarousel> createState() => _NewsCarouselState();
}

class _NewsCarouselState extends State<NewsCarousel> {
  final NewsService _service = NewsService();
  final PageController _controller = PageController();

  List<NewsPost> _posts = const [];
  Timer? _timer;
  int _index = 0;

  /// How long each slide is held. Long enough to read a summary.
  static const Duration _dwell = Duration(seconds: 7);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final loader = NewsCarousel.debugLoader;
      final posts = loader != null ? await loader() : await _service.publicFeed();
      if (!mounted) return;

      setState(() => _posts = posts);
      if (posts.length > 1) _startTimer();
    } catch (_) {
      // Deliberately silent — see the class comment.
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_dwell, (_) => _goTo(_index + 1));
  }

  void _goTo(int target) {
    if (_posts.isEmpty || !_controller.hasClients) return;

    final next = (target + _posts.length) % _posts.length;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  /// Any manual navigation restarts the clock, so a slide the reader just
  /// chose is not swapped out half a second later.
  void _manual(int target) {
    _goTo(target);
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (_posts.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 700;
    final height = isNarrow ? 380.0 : 320.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Latest News', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),

        SizedBox(
          height: height,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: _posts.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) =>
                    _NewsSlide(post: _posts[i], isNarrow: isNarrow),
              ),

              // Arrows are pointer affordances; on a phone the swipe is the
              // gesture people already reach for, and two 40px targets over a
              // 380px slide would cover the photo.
              if (!isNarrow && _posts.length > 1) ...[
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: _ArrowButton(
                    icon: Icons.chevron_left,
                    onTap: () => _manual(_index - 1),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: _ArrowButton(
                    icon: Icons.chevron_right,
                    onTap: () => _manual(_index + 1),
                  ),
                ),
              ],
            ],
          ),
        ),

        if (_posts.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _posts.length; i++)
                GestureDetector(
                  onTap: () => _manual(i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 20 : 8,
                    height: 8,
                    color: i == _index ? AppTheme.primary : AppTheme.border,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _NewsSlide extends StatelessWidget {
  final NewsPost post;
  final bool isNarrow;

  const _NewsSlide({required this.post, required this.isNarrow});

  @override
  Widget build(BuildContext context) {
    final image = _buildImage(context);
    final text = _buildText(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isNarrow ? 0 : 44),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border.all(color: AppTheme.border),
      ),
      child: isNarrow
          ? Column(
              children: [
                SizedBox(height: 180, width: double.infinity, child: image),
                Expanded(child: text),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 5, child: SizedBox.expand(child: image)),
                Expanded(flex: 6, child: text),
              ],
            ),
    );
  }

  Widget _buildImage(BuildContext context) {
    // Through the API client rather than `Image.network`: it carries the ngrok
    // header, and the bearer token when there is one. A visitor has no token
    // and needs none — these posts are published — but an administrator
    // previewing the site gets the same code path.
    final image = AuthedImage(
      path: post.imagePath,
      placeholder: const _PhotoFrame(),
    );

    if (!post.hasVideo) return image;

    // A clip attached to a post that also has a body was invisible: the
    // button said READ MORE, nothing on the slide mentioned a video, and it
    // sat behind a tap nobody had a reason to make. The badge is the reason.
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        Positioned(
          left: 12,
          bottom: 12,
          child: Container(
            key: const Key('news-video-badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.black.withValues(alpha: 0.7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_circle_outline,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  post.videoSizeLabel == null
                      ? 'VIDEO'
                      : 'VIDEO · ${post.videoSizeLabel}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildText(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (post.publishedAt != null)
            Text(
              _formatDate(post.publishedAt!),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          const SizedBox(height: 6),
          Text(
            post.title,
            style: Theme.of(context).textTheme.headlineSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Flexible(
            child: Text(
              post.summary,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: isNarrow ? 4 : 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // A video is reason enough to open the post, even with no body —
          // otherwise a clip attached to a one-line item would be
          // unreachable. The slide itself stays a teaser: a player inside it
          // would fight a fixed height and a maxLines summary.
          if ((post.body ?? '').isNotEmpty || post.hasVideo) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => _showFull(context),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              // Naming the video whenever there is one. It used to say
              // WATCH VIDEO only when the body was empty, so a post with
              // both hid the clip behind a READ MORE nobody would read as
              // "there is a video in here".
              child: Text(
                post.hasVideo
                    ? ((post.body ?? '').isEmpty
                          ? 'WATCH VIDEO'
                          : 'READ MORE & WATCH')
                    : 'READ MORE',
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFull(BuildContext context) {
    showAppAlertDialog<void>(
      context: context,
      title: post.title,
      maxWidth: 560,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.body ?? post.summary,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (post.hasVideo && post.videoUrl != null) ...[
            const SizedBox(height: 16),
            NewsVideoPlayer(
              url: post.videoUrl!,
              sizeLabel: post.videoSizeLabel,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE'),
        ),
      ],
    );
  }

  static String _formatDate(DateTime value) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = value.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

/// The empty frame shown when a post has no photo, or the photo will not load.
///
/// A frame rather than a blank: an empty rectangle looks like a bug, and this
/// reads as "no picture" without pretending to be one.
class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      alignment: Alignment.center,
      // No separate loading state any more: AuthedImage shows this frame while
      // it fetches, and a spinner that flickers for 200ms on a cached image is
      // worse than the frame it replaces.
      child: const Icon(
        Icons.image_outlined,
        size: 40,
        color: AppTheme.border,
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: AppTheme.surface,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppTheme.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 56,
            child: Icon(icon, color: AppTheme.textPrimary),
          ),
        ),
      ),
    );
  }
}
