import 'package:flutter/material.dart';
import '../models/pagination.dart';
import '../theme/app_theme.dart';

/// Previous / next controls plus a "1-15 of 42" range label.
class PaginationBar extends StatelessWidget {
  final Pagination pagination;
  final ValueChanged<int> onPageChanged;

  const PaginationBar({
    super.key,
    required this.pagination,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (pagination.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Text(
            pagination.rangeLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Previous page',
            onPressed: pagination.hasPrevious
                ? () => onPageChanged(pagination.currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Page ${pagination.currentPage} / ${pagination.lastPage}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: pagination.hasNext
                ? () => onPageChanged(pagination.currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
