/// Mirrors the `pagination` block returned by every paginated Laravel
/// endpoint (UserController, ModelController, UserActivityController).
class Pagination {
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;
  final int? from;
  final int? to;

  const Pagination({
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
    this.from,
    this.to,
  });

  static int _toInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static int? _toIntOrNull(dynamic value) {
    if (value == null) return null;
    return _toInt(value);
  }

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      total: _toInt(json['total']),
      // Laravel serialises per_page as a string when it comes from a query param.
      perPage: _toInt(json['per_page'], 15),
      currentPage: _toInt(json['current_page'], 1),
      lastPage: _toInt(json['last_page'], 1),
      from: _toIntOrNull(json['from']),
      to: _toIntOrNull(json['to']),
    );
  }

  const Pagination.empty()
      : total = 0,
        perPage = 15,
        currentPage = 1,
        lastPage = 1,
        from = null,
        to = null;

  bool get hasPrevious => currentPage > 1;
  bool get hasNext => currentPage < lastPage;
  bool get isEmpty => total == 0;

  /// e.g. "1-15 of 42"
  String get rangeLabel {
    if (isEmpty) return '0 of 0';
    return '${from ?? 0}-${to ?? 0} of $total';
  }
}

/// A page of results plus its pagination metadata.
class PaginatedResult<T> {
  final List<T> items;
  final Pagination pagination;

  const PaginatedResult({required this.items, required this.pagination});

  const PaginatedResult.empty()
      : items = const [],
        pagination = const Pagination.empty();
}
