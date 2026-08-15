import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/news_post.dart';
import '../../models/pagination.dart';
import '../../services/api_client.dart';
import '../../services/news_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/pagination_bar.dart';

/// Research news: write a post, attach a photo, switch it on.
///
/// The switch is the whole point — a post is invisible to the public until an
/// administrator publishes it, so drafts can be prepared ahead of an
/// announcement.
class NewsManagementScreen extends StatefulWidget {
  const NewsManagementScreen({super.key});

  @override
  State<NewsManagementScreen> createState() => _NewsManagementScreenState();
}

class _NewsManagementScreenState extends State<NewsManagementScreen> {
  final NewsService _service = NewsService();

  List<NewsPost> _items = const [];
  Pagination _pagination = const Pagination.empty();

  bool _isLoading = true;
  String? _error;
  int _page = 1;
  String? _statusFilter;

  int _publishedCount = 0;
  int _draftCount = 0;

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
      final result = await _service.adminList(
        page: _page,
        status: _statusFilter,
      );

      if (!mounted) return;
      setState(() {
        _items = result.page.items;
        _pagination = result.page.pagination;
        _publishedCount = result.publishedCount;
        _draftCount = result.draftCount;
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

  void _report(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
      ),
    );
  }

  Future<void> _toggle(NewsPost post) async {
    try {
      final updated = await _service.toggle(post.id);
      _report(updated.isPublished ? 'Published.' : 'Hidden from the site.');
      await _load();
    } on ApiException catch (e) {
      _report(e.message, isError: true);
    }
  }

  Future<void> _edit([NewsPost? post]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PostEditor(post: post),
    );

    if (saved == true) await _load();
  }

  Future<void> _delete(NewsPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('Delete post'),
        content: Text('Delete "${post.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.delete(post.id);
      _report('Post deleted.');
      await _load();
    } on ApiException catch (e) {
      _report(e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: EdgeInsets.all(isNarrow ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Research News',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '$_publishedCount published, $_draftCount draft'
                      '${_draftCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 20),
              ),
              ElevatedButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('NEW'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            children: [
              for (final option in const [
                (null, 'ALL'),
                ('published', 'PUBLISHED'),
                ('draft', 'DRAFTS'),
              ])
                _FilterChip(
                  label: option.$2,
                  selected: _statusFilter == option.$1,
                  onTap: () {
                    setState(() {
                      _statusFilter = option.$1;
                      _page = 1;
                    });
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingView(message: 'Loading posts...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    if (_items.isEmpty) {
      return const EmptyView(
        message: 'No posts yet — tap NEW to write one',
        icon: Icons.article_outlined,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _PostCard(
              post: _items[index],
              onToggle: () => _toggle(_items[index]),
              onEdit: () => _edit(_items[index]),
              onDelete: () => _delete(_items[index]),
            ),
          ),
        ),
        PaginationBar(
          pagination: _pagination,
          onPageChanged: (p) {
            setState(() => _page = p);
            _load();
          },
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surface,
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final NewsPost post;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PostCard({
    required this.post,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            height: 64,
            child: post.imageUrl != null
                ? Image.network(
                    post.imageUrl!,
                    fit: BoxFit.cover,
                    headers: const {'ngrok-skip-browser-warning': 'true'},
                    errorBuilder: (_, _, _) => const _Thumb(),
                  )
                : const _Thumb(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        post.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      color: post.isPublished
                          ? AppTheme.successLight
                          : AppTheme.background,
                      child: Text(
                        post.isPublished ? 'PUBLISHED' : 'DRAFT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: post.isPublished
                              ? AppTheme.success
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  post.summary,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  children: [
                    TextButton.icon(
                      onPressed: onToggle,
                      icon: Icon(
                        post.isPublished
                            ? Icons.toggle_on
                            : Icons.toggle_off_outlined,
                        size: 18,
                      ),
                      label: Text(post.isPublished ? 'HIDE' : 'PUBLISH'),
                    ),
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('EDIT'),
                    ),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('DELETE'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 20,
        color: AppTheme.borderDark,
      ),
    );
  }
}

/// Write or edit a post. Publishing is a separate action on the card, so
/// saving never puts something on the public site by surprise.
class _PostEditor extends StatefulWidget {
  final NewsPost? post;

  const _PostEditor({this.post});

  @override
  State<_PostEditor> createState() => _PostEditorState();
}

class _PostEditorState extends State<_PostEditor> {
  final NewsService _service = NewsService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _summary;
  late final TextEditingController _body;
  late final TextEditingController _order;

  Uint8List? _imageBytes;
  String? _imageName;
  bool _removeImage = false;

  bool _saving = false;
  String? _error;

  bool get _isNew => widget.post == null;

  @override
  void initState() {
    super.initState();
    final post = widget.post;
    _title = TextEditingController(text: post?.title ?? '');
    _summary = TextEditingController(text: post?.summary ?? '');
    _body = TextEditingController(text: post?.body ?? '');
    _order = TextEditingController(text: '${post?.sortOrder ?? 0}');
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _body.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      // Web has no path to read from, and the upload sends bytes either way.
      withData: true,
    );

    final file = result?.files.firstOrNull;
    if (file?.bytes == null) return;

    if (!mounted) return;
    setState(() {
      _imageBytes = file!.bytes;
      _imageName = file.name;
      _removeImage = false;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _service.save(
        id: widget.post?.id,
        title: _title.text.trim(),
        summary: _summary.text.trim(),
        body: _body.text.trim(),
        sortOrder: int.tryParse(_order.text.trim()) ?? 0,
        imageBytes: _imageBytes,
        imageName: _imageName,
        removeImage: _removeImage,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: Text(_isNew ? 'New post' : 'Edit post'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _summary,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Summary',
                    hintText: 'The line shown on the slide',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Summary is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _body,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Full article (optional)',
                    hintText: 'Shown behind "Read more"',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Slide order',
                    hintText: 'Lower numbers come first',
                  ),
                ),
                const SizedBox(height: 20),

                _buildImagePicker(context),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorLight,
                      border: Border.all(color: AppTheme.error),
                    ),
                    child: Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('SAVE'),
        ),
      ],
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    final existing = widget.post?.imageUrl;
    final hasNew = _imageBytes != null;
    final showsExisting = existing != null && !hasNew && !_removeImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 96,
              height: 72,
              child: hasNew
                  ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                  : showsExisting
                  ? Image.network(
                      existing,
                      fit: BoxFit.cover,
                      headers: const {'ngrok-skip-browser-warning': 'true'},
                      errorBuilder: (_, _, _) => const _Thumb(),
                    )
                  : const _Thumb(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.upload_outlined, size: 16),
                    label: Text(hasNew ? 'CHANGE' : 'CHOOSE'),
                  ),
                  if (hasNew)
                    Text(
                      _imageName ?? '',
                      style: Theme.of(context).textTheme.labelSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (showsExisting)
                    TextButton(
                      onPressed: () => setState(() => _removeImage = true),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.error,
                      ),
                      child: const Text('REMOVE PHOTO'),
                    ),
                  if (_removeImage)
                    Text(
                      'Photo will be removed on save',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'JPEG, PNG or WebP, up to 4 MB. Images are stored as uploaded — '
          'nothing on the server can resize them.',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
