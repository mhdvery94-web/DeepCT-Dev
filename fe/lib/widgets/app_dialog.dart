import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The one way this app opens a dialog.
///
/// Every call site used to hand `showDialog` its own
/// `shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero)` and, for
/// anything wider than a plain confirmation, its own hard-coded
/// `SizedBox(width: N)` — which overflows the moment N is wider than the
/// phone in someone's hand. `Dialog` already centers on screen on its own;
/// this adds the two things it does not do by default: clamp width to
/// whichever is smaller of [maxWidth] and 90% of the viewport, cap height at
/// 85% of the viewport, and scroll instead of overflowing when content is
/// taller than that.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 480,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      final size = MediaQuery.sizeOf(dialogContext);

      return Dialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        // The default 40px horizontal inset is generous enough to fight our
        // own width clamp on a narrow phone; a smaller, fixed inset leaves
        // the clamp below as the one thing deciding the width.
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.min(maxWidth, size.width * 0.9),
            maxHeight: size.height * 0.85,
          ),
          // Its own, because `showDialog` pushes a route into the overlay: a
          // SelectionArea around a shell's body is not an ancestor of anything
          // shown here. Dialogs are where the values worth copying live — a
          // generated password, an account's credentials.
          child: SelectionArea(
            child: SingleChildScrollView(child: builder(dialogContext)),
          ),
        ),
      );
    },
  );
}

/// Convenience for the title / content / actions shape that used to be an
/// `AlertDialog`. Lays the three out the same way `AlertDialog` did, inside
/// [showAppDialog]'s centered, width-clamped, scrollable frame — so a call
/// site that only ever set `title`, `content` and `actions` can swap over
/// without rebuilding its layout by hand.
Future<T?> showAppAlertDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  required List<Widget> actions,
  double maxWidth = 480,
  bool barrierDismissible = true,
}) {
  return showAppDialog<T>(
    context: context,
    maxWidth: maxWidth,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(dialogContext).textTheme.headlineSmall),
          const SizedBox(height: 16),
          content,
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                actions[i],
              ],
            ],
          ),
        ],
      ),
    ),
  );
}
