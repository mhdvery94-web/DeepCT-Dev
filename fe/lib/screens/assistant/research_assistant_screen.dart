import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/ai_service.dart';
import '../../services/ai_chat_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/assistant_evidence.dart';

class ResearchAssistantScreen extends StatefulWidget {
  final AiService? service;
  final int? analysisRecordId;
  const ResearchAssistantScreen({
    super.key,
    this.service,
    this.analysisRecordId,
  });
  @override
  State<ResearchAssistantScreen> createState() =>
      _ResearchAssistantScreenState();
}

class _ResearchAssistantScreenState extends State<ResearchAssistantScreen> {
  late final AiChatController chat = AiChatController(
    widget.service ?? AiService(),
    contextId: widget.analysisRecordId,
  );
  final TextEditingController draft = TextEditingController();
  final ScrollController scroll = ScrollController();
  final GlobalKey<ScaffoldState> scaffold = GlobalKey<ScaffoldState>();
  int? copied;
  @override
  void initState() {
    super.initState();
    chat.initialize();
  }

  @override
  void dispose() {
    chat.dispose();
    draft.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _send({bool retry = false, bool regenerate = false}) async {
    final sent = regenerate
        ? await chat.regenerate()
        : await chat.send(draft.text, retry: retry);
    if (!mounted || !sent) return;
    draft.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
      }
    });
  }

  void _open(Map<String, dynamic> item) {
    if (chat.busy || chat.pending != null) return;
    scaffold.currentState?.closeDrawer();
    draft.clear();
    chat.open(item);
  }

  void _new() {
    if (chat.busy || chat.pending != null) return;
    scaffold.currentState?.closeDrawer();
    draft.clear();
    chat.newChat();
  }

  Widget _history() => SizedBox(
    width: 270,
    child: Material(
      color: AppTheme.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Percakapan saya',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: chat.busy || chat.pending != null ? null : _new,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Chat baru'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Riwayat pribadi akun Anda',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: chat.conversations
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            selected: item['id'] == chat.conversation?['id'],
                            selectedTileColor: AppTheme.primaryLight,
                            title: Text(
                              item['title'].toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: item['updated_at'] == null
                                ? null
                                : Text(
                                    item['updated_at']
                                        .toString()
                                        .split('T')
                                        .first,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                            enabled: !chat.busy && chat.pending == null,
                            onTap: () => _open(item),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Percakapan sebelumnya',
                    onPressed: chat.historyPage > 1 && !chat.busy
                        ? () => chat.loadHistory(chat.historyPage - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    '${chat.historyPage} / ${chat.historyLast}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  IconButton(
                    tooltip: 'Percakapan berikutnya',
                    onPressed: chat.historyPage < chat.historyLast && !chat.busy
                        ? () => chat.loadHistory(chat.historyPage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _message(Map<String, dynamic> message) {
    final user = message['role'] == 'user';
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: .9,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: user
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                user ? 'Anda' : 'Asisten · eksperimental',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: user ? AppTheme.textPrimary : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  message['content'].toString(),
                  style: TextStyle(
                    color: user ? Colors.white : AppTheme.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  try {
                    await Clipboard.setData(
                      ClipboardData(text: message['content'].toString()),
                    );
                    if (mounted) setState(() => copied = message['id'] as int);
                  } catch (_) {
                    chat.reportError(
                      'Tidak dapat menyalin. Pilih teks untuk menyalin secara manual.',
                    );
                  }
                },
                icon: const Icon(Icons.copy_outlined, size: 13),
                label: Text(
                  copied == message['id'] ? 'Tersalin' : 'Salin',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _error(String message, String label, VoidCallback? action) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 12, color: AppTheme.primaryDark),
          ),
          TextButton(
            onPressed: action,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    ),
  );

  Widget _composer() => Container(
    color: AppTheme.surface,
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chat.knownActive != null &&
            chat.knownActive!['conversation_id'] != chat.conversation?['id'])
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              const Text(
                'Permintaan lain masih aktif.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              TextButton(
                onPressed: chat.busy || chat.pending != null
                    ? null
                    : () => _open({
                        'id': chat.knownActive!['conversation_id'],
                        'title': 'Permintaan aktif',
                      }),
                child: const Text(
                  'Buka permintaan aktif',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        if (chat.error != null)
          _error(
            chat.error!,
            chat.pending != null ? 'Coba kirim lagi' : 'Muat ulang',
            chat.busy
                ? null
                : chat.pending != null
                ? () => _send(retry: true)
                : () => chat.conversation == null
                      ? chat.initialize()
                      : chat.open(chat.conversation!),
          ),
        if (chat.pollError != null)
          _error(
            chat.pollError!,
            'Coba polling lagi',
            chat.busy ? null : chat.retryPoll,
          ),
        if (chat.contextId != null)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                'Konteks prediksi #${chat.contextId}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryDark,
                ),
              ),
              TextButton(
                onPressed: chat.busy || chat.pending != null
                    ? null
                    : chat.clearContext,
                child: const Text(
                  'Lepas konteks',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderDark),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('ai-input'),
                  controller: draft,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: chat.limits['message_characters'] as int? ?? 2000,
                  enabled: !chat.busy && chat.pending == null,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Tulis pertanyaan riset Anda…',
                    counterText: '',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('ai-send'),
                onPressed: chat.canSend && draft.text.trim().isNotEmpty
                    ? () => _send()
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('Kirim'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Verifikasi jawaban model',
              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
            Text(
              '${draft.text.length}/${chat.limits['message_characters'] ?? 2000}',
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
          ],
        ),
        if (chat.limits['requests_per_day'] != null)
          Text(
            'Batas maksimum ${chat.limits['requests_per_day']} permintaan per hari · Bukan sisa kuota',
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
      ],
    ),
  );

  Widget _chat(bool wide) => Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          children: [
            if (Navigator.canPop(context))
              IconButton(
                tooltip: 'Kembali',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
            if (!wide)
              IconButton(
                tooltip: 'Riwayat percakapan',
                onPressed: () => scaffold.currentState?.openDrawer(),
                icon: const Icon(Icons.menu),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.conversation?['title']?.toString() ?? 'Asisten riset',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'BRIN · ${chat.status?['model'] ?? 'DeepSeek'} · Eksperimental',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!wide)
              IconButton(
                tooltip: 'Chat baru',
                onPressed: chat.busy || chat.pending != null ? null : _new,
                icon: const Icon(Icons.add),
              ),
          ],
        ),
      ),
      Container(
        width: double.infinity,
        color: const Color(0xFFFFFBEB),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(
          chat.enabled
              ? (chat.status?['mode'] == 'metadata')
                    ? 'Asisten eksperimental menjelaskan status, metrik, dan ketersediaan berkas dari metadata analisis Anda. Asisten tidak membaca piksel TIFF atau menjalankan prediksi. Jawaban tidak menjamin kebenaran ilmiah hasil.'
                    : 'DeepSeek eksperimental. Verifikasi jawaban sebelum digunakan dalam riset.'
              : 'DeepSeek eksperimental belum tersedia sampai evaluasi kualitas lulus. Riwayat tetap dapat dibaca.',
          style: const TextStyle(fontSize: 11, color: Color(0xFF854D0E)),
        ),
      ),
      Expanded(
        child: ListView(
          key: const Key('ai-messages'),
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            if (chat.loading) const Center(child: Text('Memuat percakapan…')),
            if (chat.messagePage < chat.messageLast)
              Center(
                child: TextButton(
                  onPressed: chat.busy ? null : chat.olderMessages,
                  child: const Text('Pesan lebih lama'),
                ),
              ),
            if (!chat.loading && chat.messages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'BRIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Ruang diskusi riset Anda',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tanyakan tentang status atau hasil analisis CT. Konteks hanya memakai metadata prediksi milik Anda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, height: 1.7),
                    ),
                  ],
                ),
              ),
            ...chat.messages.map(_message),
            if (chat.request != null)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                children: [
                  Text(
                    '${const {'queued': 'Dalam antrean', 'processing': 'Sedang diproses', 'completed': 'Selesai', 'failed': 'Gagal', 'cancelled': 'Dibatalkan'}[chat.request!['status']]}${chat.request!['status'] == 'failed' ? ' · ${chat.request!['error_code'] ?? 'generation_failed'}' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  if (chat.active)
                    TextButton(
                      onPressed: chat.busy ? null : chat.cancel,
                      child: const Text('Batalkan'),
                    ),
                  if ([
                        'failed',
                        'cancelled',
                      ].contains(chat.request!['status']) &&
                      chat.messages.any(
                        (m) => m['id'] == chat.request!['user_message_id'],
                      ))
                    TextButton(
                      onPressed: chat.canSend
                          ? () => _send(regenerate: true)
                          : null,
                      child: const Text('Buat ulang jawaban'),
                    ),
                ],
              ),
            if (chat.request?['status'] == 'completed')
              AssistantEvidence(request: chat.request!),
          ],
        ),
      ),
      _composer(),
    ],
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: chat,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return Scaffold(
          key: scaffold,
          backgroundColor: AppTheme.surface,
          drawer: wide ? null : Drawer(width: 270, child: _history()),
          body: SafeArea(
            child: Row(
              children: [
                if (wide) ...[_history(), const VerticalDivider(width: 1)],
                Expanded(child: _chat(wide)),
              ],
            ),
          ),
        );
      },
    ),
  );
}
