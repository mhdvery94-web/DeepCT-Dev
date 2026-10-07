import 'package:flutter/material.dart';

import '../models/news_post.dart';
import '../services/news_service.dart';
import '../theme/app_theme.dart';
import 'authed_image.dart';
import 'news_article_view.dart';
import 'news_video_player.dart';

/// Research news on the landing page: one featured post, then the rest as a
/// list.
///
/// **This replaced a rotating carousel**, and the reasons are worth keeping.
/// A slideshow showed one post at a time and made a reader wait seven seconds
/// for the next, on a page where four items would fit at once. It also had to
/// own a periodic timer, a `PageView` that disposed slides behind the reader's
/// back, and a hold counter to stop it rotating out from under an open dialog
/// — the machinery that made the article's CLOSE button appear dead. None of
/// that exists here, because there is nothing to rotate.
///
/// Loads its own data and **renders nothing at all** when there is none, or
/// when the request fails. A visitor should never meet an error box on the
/// front page over something optional — if the news cannot be fetched, the
/// page reads as it did before any news existed.
class NewsSection extends StatefulWidget {
  const NewsSection({super.key});

  /// Replaces the network fetch. Tests only — production leaves it null.
  ///
  /// This is the same bargain as `GoogleFonts.config.allowRuntimeFetching` in
  /// the test setup: the widget loads itself, so every test that pumps the
  /// landing page would otherwise start a real HTTP request whose timeout
  /// timer is still pending when the test ends, and Flutter fails a test with
  /// pending timers.
  static Future<List<NewsPost>> Function()? debugLoader;

  @override
  State<NewsSection> createState() => _NewsSectionState();
}

class _NewsSectionState extends State<NewsSection> {
  final NewsService _service = NewsService();

  List<NewsPost> _posts = const [];

  /// Editorial content should not become wider just because a monitor does.
  /// Without this, the featured media stretched to almost 1,850px on a 1080p
  /// desktop and its height cap turned a photograph into a very wide strip.
  static const double _contentMaxWidth = 1280;

  /// A landing page is a front door, not an archive. One featured item and
  /// five below it is as much as this section should ever grow to; the feed
  /// itself will serve twenty if asked.
  static const int _maxOnLanding = 6;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loader = NewsSection.debugLoader;
      final posts = loader != null
          ? await loader()
          : await _service.publicFeed(limit: _maxOnLanding);
      if (!mounted) return;

      setState(() => _posts = posts.take(_maxOnLanding).toList());
    } catch (_) {
      // Deliberately silent — see the class comment.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_posts.isEmpty) return const SizedBox.shrink();

    final isNarrow = MediaQuery.sizeOf(context).width < 700;
    final rest = _posts.skip(1).toList();

    return Center(
      child: ConstrainedBox(
        key: const Key('news-content-frame'),
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            const SizedBox(height: 18),

            _FeaturedPost(post: _posts.first, isNarrow: isNarrow),

            if (rest.isNotEmpty) ...[
              SizedBox(height: isNarrow ? 20 : 24),
              _PostList(posts: rest, isNarrow: isNarrow),
            ],
          ],
        ),
      ),
    );
  }

  /// Title and the rule the rest of the landing page uses under a heading.
  ///
  /// It carried a post count for a while, put there to fill the space the
  /// slide dots left behind. Nobody needs to know how many news items exist,
  /// and a number nobody reads is not decoration.
  Widget _header(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Latest News', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Container(width: 40, height: 3, color: AppTheme.primary),
      ],
    );
  }
}

/// The newest post, given room: media on one side, the story on the other.
class _FeaturedPost extends StatelessWidget {
  final NewsPost post;
  final bool isNarrow;

  const _FeaturedPost({required this.post, required this.isNarrow});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        // The red edge is the whole of this card's decoration. It marks the
        // featured item without a shadow, a gradient or a rounded corner —
        // none of which this design system has.
        border: Border(
          left: BorderSide(color: AppTheme.primary, width: 4),
          top: BorderSide(color: AppTheme.border),
          right: BorderSide(color: AppTheme.border),
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MediaGallery(post: post, isNarrow: isNarrow),
          _text(context),
        ],
      ),
    );
  }

  Widget _text(BuildContext context) {
    final theme = Theme.of(context);
    final hasBody = (post.body ?? '').trim().isNotEmpty;

    // What this card still cannot show: the rest of the article. A clip plays
    // here, and the photograph is no longer cropped, so a post carrying only
    // those two needs no button at all.
    final hasMore = hasBody || post.imagePath != null;

    final content = Padding(
      padding: EdgeInsets.all(isNarrow ? 20 : 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Eyebrow(publishedAt: post.publishedAt),
          const SizedBox(height: 12),

          Text(
            post.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          Text(
            post.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
              height: 1.55,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          if (hasMore) ...[
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => showNewsArticle(context: context, post: post),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: const RoundedRectangleBorder(
                    side: BorderSide(color: AppTheme.border),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      // "Read" would be a lie on a post that is a photograph
                      // and a two-line summary.
                      hasBody ? 'READ MORE' : 'VIEW POST',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 15),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    // Long copy spanning an entire desktop card is difficult to scan. Mobile
    // keeps using every pixel; wider layouts get a readable text measure while
    // remaining aligned with the card's left edge.
    if (isNarrow) return content;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: content,
      ),
    );
  }
}

/// Responsive featured media.
///
/// Phones keep the proven full-width stack. Tablet and desktop place a photo
/// and clip beside one another as proper 16:9 panels. Together with the
/// section's 1280px maximum width this avoids both failure modes from the old
/// layout: a 6:1 cropped photo and a page-wide black video letterbox.
class _MediaGallery extends StatelessWidget {
  final NewsPost post;
  final bool isNarrow;

  const _MediaGallery({required this.post, required this.isNarrow});

  @override
  Widget build(BuildContext context) {
    final videoUrl = post.videoUrl;

    final blocks = <({String label, IconData icon, Widget child})>[
      if (post.imagePath != null)
        (
          label: 'PHOTO',
          icon: Icons.image_outlined,
          child: ColoredBox(
            color: AppTheme.textPrimary,
            child: AuthedImage(
              path: post.imagePath,
              // `cover` here, `contain` in the opened article. Cropping remains
              // useful for a teaser; the responsive 16:9 frame now keeps that
              // crop moderate instead of turning it into a panoramic slice.
              placeholder: const NewsPhotoFrame(),
            ),
          ),
        ),
      if (post.hasVideo && videoUrl != null)
        (
          label: 'VIDEO',
          icon: Icons.movie_outlined,
          child: NewsVideoPlayer(
            key: const Key('news-featured-video'),
            url: videoUrl,
            sizeLabel: post.videoSizeLabel,
            // Web needs the number, not the label: it has to decide whether the
            // clip is small enough to pull into memory before it starts.
            sizeBytes: post.videoSizeBytes,
            // No poster, deliberately. The photograph has a panel of its own;
            // reusing it behind the clip would make the two look duplicated.
          ),
        ),
    ];

    // A post with neither still gets a band, so the card keeps its shape.
    if (blocks.isEmpty) return const _MediaBand(child: NewsPhotoFrame());

    if (isNarrow) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            _MediaBand(
              maxHeight: blocks.length > 1 ? 240 : 340,
              child: blocks[i].child,
            ),
          ],
        ],
      );
    }

    if (blocks.length == 1) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: _WideMediaPanel(item: blocks.first, maxHeight: 520),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: _WideMediaPanel(item: blocks[i])),
          ],
        ],
      ),
    );
  }
}

/// A labelled media panel used only where there is room for a gallery.
class _WideMediaPanel extends StatelessWidget {
  final ({String label, IconData icon, Widget child}) item;
  final double maxHeight;

  const _WideMediaPanel({required this.item, this.maxHeight = 360});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('news-media-${item.label.toLowerCase()}'),
      decoration: BoxDecoration(
        color: AppTheme.textPrimary,
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: AppTheme.background,
              border: Border(bottom: BorderSide(color: AppTheme.borderDark)),
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 15, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          _MediaBand(maxHeight: maxHeight, child: item.child),
        ],
      ),
    );
  }
}

/// One full-width band of media: 16:9, but never taller than [maxHeight].
///
/// The cap is what keeps this honest on a desktop. Sixteen-by-nine across a
/// 1100px card is 619px tall — a photograph that fills the window and pushes
/// the headline off the bottom of it. On a phone the cap never binds and the
/// band is simply 16:9.
class _MediaBand extends StatelessWidget {
  final Widget child;
  final double maxHeight;

  const _MediaBand({required this.child, this.maxHeight = 340});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final byRatio = constraints.maxWidth * 9 / 16;

        return SizedBox(
          width: double.infinity,
          height: byRatio < maxHeight ? byRatio : maxHeight,
          child: child,
        );
      },
    );
  }
}

/// Everything after the featured post, as rows.
///
/// A row is a thumbnail, a date and a title — enough to decide whether to open
/// it, and no more. The clip is named by a chip rather than played here: five
/// players on a landing page is five video elements nobody asked for.
class _PostList extends StatelessWidget {
  final List<NewsPost> posts;
  final bool isNarrow;

  const _PostList({required this.posts, required this.isNarrow});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < posts.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AppTheme.border),
            _PostRow(post: posts[i], isNarrow: isNarrow),
          ],
        ],
      ),
    );
  }
}

class _PostRow extends StatelessWidget {
  final NewsPost post;
  final bool isNarrow;

  const _PostRow({required this.post, required this.isNarrow});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => showNewsArticle(context: context, post: post),
      hoverColor: AppTheme.primaryLight,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 12 : 16,
          vertical: 14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: isNarrow ? 96 : 132,
              height: isNarrow ? 72 : 88,
              child: ColoredBox(
                color: AppTheme.textPrimary,
                // `cover` is right here, unlike the featured block: at 96px
                // wide a contained portrait would be a sliver of ink in a
                // field of black.
                child: AuthedImage(
                  path: post.imagePath,
                  placeholder: const NewsPhotoFrame(),
                ),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Eyebrow(publishedAt: post.publishedAt),
                  const SizedBox(height: 8),

                  Text(
                    post.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (post.hasVideo) ...[
                    const SizedBox(height: 8),
                    // Its own line under the title. The clip is announced, not
                    // laid over the thumbnail.
                    _VideoChip(sizeLabel: post.videoSizeLabel),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `▮ 23 AUG 2026` — the red tick and the date, shared by the featured card
/// and every row so both read the same way.
class _Eyebrow extends StatelessWidget {
  final DateTime? publishedAt;

  const _Eyebrow({required this.publishedAt});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 14, height: 2, color: AppTheme.primary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            publishedAt == null
                ? 'NEWS'
                : formatNewsDate(publishedAt!).toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoChip extends StatelessWidget {
  final String? sizeLabel;

  const _VideoChip({required this.sizeLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('news-row-video'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: AppTheme.borderDark)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow, size: 13, color: AppTheme.primary),
          const SizedBox(width: 5),
          Text(
            sizeLabel == null ? 'VIDEO' : 'VIDEO · $sizeLabel',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
