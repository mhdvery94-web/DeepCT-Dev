import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../theme/app_theme.dart';
import 'authed_image.dart';

/// A person's profile photo, or an initials frame when there is none.
///
/// The frame is the designed state, not a placeholder: most accounts will
/// never upload a photo, and a grey box or a broken-image glyph would read as
/// a fault. Initials on the account's own colour look deliberate and stay
/// legible at 24px.
class UserAvatar extends StatelessWidget {
  /// `avatar_url` from the API — a path relative to the API root. Null means
  /// no photo.
  final String? avatarPath;

  /// Used for the initials and to pick a stable colour.
  final String name;

  final double size;

  /// Draws the ring around the frame. Off inside dense list rows.
  final bool bordered;

  const UserAvatar({
    super.key,
    required this.avatarPath,
    required this.name,
    this.size = 36,
    this.bordered = true,
  });

  /// Up to two letters: "Fajri Rahman" → FR, "admin" → AD.
  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final word = parts.first;
      return (word.length == 1 ? word : word.substring(0, 2)).toUpperCase();
    }

    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// A stable colour per person, so the same face keeps the same tile between
  /// sessions. Hashing the name rather than the id means it also works for a
  /// guest ticket, where there is no id.
  Color get _tint {
    const palette = [
      AppTheme.primary,
      AppTheme.accent,
      AppTheme.success,
      AppTheme.warning,
    ];

    var hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash + unit) % palette.length;
    }

    return palette[hash];
  }

  @override
  Widget build(BuildContext context) {
    final path = avatarPath;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _tint.withValues(alpha: 0.12),
        border: bordered ? Border.all(color: AppTheme.border) : null,
      ),
      clipBehavior: Clip.hardEdge,
      // Loading, missing and failed all fall back to the frame rather than a
      // broken-image glyph.
      child: AuthedImage(
        path: path,
        width: size,
        height: size,
        placeholder: _buildInitials(context),
      ),
    );
  }

  Widget _buildInitials(BuildContext context) {
    return Center(
      child: Text(
        _initials,
        style: TextStyle(
          // Two letters have to fit inside the frame at any size.
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: _tint,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// The signed-in account's own avatar in a sidebar, tappable to change it.
///
/// Both shells show the same thing in the same corner, so it lives here rather
/// than being written twice.
class AvatarButton extends StatelessWidget {
  final UserModel? user;
  final VoidCallback onTap;
  final double size;

  const AvatarButton({
    super.key,
    required this.user,
    required this.onTap,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Change photo',
      child: InkWell(
        onTap: onTap,
        child: UserAvatar(
          avatarPath: user?.avatarPath,
          name: user?.name ?? '?',
          size: size,
        ),
      ),
    );
  }
}
