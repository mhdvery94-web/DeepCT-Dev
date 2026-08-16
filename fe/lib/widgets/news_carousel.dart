import 'dart:async';

import 'package:flutter/material.dart';

import '../models/news_post.dart';
import '../services/news_service.dart';
import 'authed_image.dart';
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
    return AuthedImage(
      path: post.imagePath,
      placeholder: const _PhotoFrame(),
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
          if ((post.body ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => _showFull(context),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('READ MORE'),
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
      content: Text(
        post.body ?? post.summary,
        style: Theme.of(context).textTheme.bodyMedium,
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
