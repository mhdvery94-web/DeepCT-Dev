import 'package:flutter/material.dart';

import '../models/news_post.dart';
import '../theme/app_theme.dart';
import 'app_dialog.dart';
import 'authed_image.dart';
import 'news_video_player.dart';

/// Opens [post] in full.
///
/// Returns when the reader closes it. Nothing on the landing page moves while
/// it is open — `NewsSection` replaced the rotating carousel that used to have
/// to be held still.
Future<void> showNewsArticle({
  required BuildContext context,
  required NewsPost post,
}) {
  return showAppDialog<void>(
    context: context,
    // Wider than an ordinary dialog: this one carries a photograph and a clip
    // as well as prose, and 480 makes a landscape still postage-stamp sized.
    maxWidth: 640,
    builder: (dialogContext) => NewsArticleView(post: post),
  );
}

/// Everything a post carries, in one scroll.
///
/// The slide on the landing page is a teaser and truncates on purpose: two
/// lines of summary, a cropped photo, a title clipped at two lines. **This is
/// the other half of that bargain** — once someone has asked for the post,
/// nothing is held back and nothing is cropped. The photo in particular is
/// laid out `BoxFit.contain` rather than `cover`: a portrait diagram lost
/// roughly three quarters of its height to the teaser's 180px letterbox, and
/// the only place it can be read is here.
///
/// Order is deliberate: what it is (date, title), then the short version, then
/// the long one, then the pictures. A reader who wanted only the gist has it
/// before the media starts loading.
class NewsArticleView extends StatelessWidget {
  final NewsPost post;

  const NewsArticleView({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = post.summary.trim();
    final body = (post.body ?? '').trim();
    final videoUrl = post.videoUrl;
    final hasVideo = post.hasVideo && videoUrl != null;

    // Half the viewport, so the whole of a tall image is visible without
    // pushing the text off the top of a phone. The dialog scrolls, so this is
    // a budget rather than a limit on what can be seen.
    final imageHeight = (MediaQuery.sizeOf(context).height * 0.5).clamp(
      200.0,
      460.0,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 14, height: 2, color: AppTheme.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  post.publishedAt == null
                      ? 'NEWS'
                      : formatNewsDate(post.publishedAt!).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            post.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),

          if (summary.isNotEmpty) ...[
            const SizedBox(height: 16),
            // No maxLines. The slide showed two lines of this; a reader who
            // opened the post asked for the rest.
            Text(
              summary,
              key: const Key('news-article-summary'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
                height: 1.6,
              ),
            ),
          ],

          if (body.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
            ),
          ],

          if (post.imagePath != null) ...[
            const SizedBox(height: 22),
            SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: ColoredBox(
                // The same dark panel the placeholder uses, so a portrait
                // image letterboxes onto it instead of onto white.
                color: AppTheme.textPrimary,
                child: AuthedImage(
                  path: post.imagePath,
                  fit: BoxFit.contain,
                  placeholder: const NewsPhotoFrame(),
                ),
              ),
            ),
          ],

          if (hasVideo) ...[
            const SizedBox(height: 16),
            AspectRatio(
              // A frame to hold the player before it knows its own shape; the
              // player centres the real aspect ratio inside it once it does.
              aspectRatio: 16 / 9,
              // No poster passed in. It used to be the post's own photograph,
              // which put the picture from the block directly above this one
              // behind a play button — the same image twice, and nothing that
              // said anything about the clip. The player loads its own first
              // frame now.
              child: NewsVideoPlayer(
                url: videoUrl,
                sizeLabel: post.videoSizeLabel,
                sizeBytes: post.videoSizeBytes,
              ),
            ),
          ],

          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              // This context comes from the dialog's own builder, not from the
              // slide that opened it. A slide can be disposed while its dialog
              // is still on screen, and `Navigator.pop` on a dead element
              // throws instead of closing — which is what "the close button
              // does nothing" was.
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The empty frame shown when a post has no photo, or the photo will not load.
///
/// A dark panel rather than a blank: the media half of a slide is where a
/// picture or a clip lives, and letterboxed video sits on this same colour, so
/// an item without a photograph still reads as part of the same card.
///
/// Shared by the teaser and by the opened article, which is why it lives here
/// rather than staying private to one of them.
class NewsPhotoFrame extends StatelessWidget {
  const NewsPhotoFrame({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.textPrimary,
      alignment: Alignment.center,
      // No separate loading state: AuthedImage shows this frame while it
      // fetches, and a spinner that flickers for 200ms on a cached image is
      // worse than the frame it replaces.
      child: Icon(
        Icons.image_outlined,
        size: 36,
        color: Colors.white.withValues(alpha: 0.25),
      ),
    );
  }
}

/// `10 Aug 2026`. Shared with the teaser so both read the same way.
String formatNewsDate(DateTime value) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = value.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
