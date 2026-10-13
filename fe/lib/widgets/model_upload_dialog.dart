import 'dart:async';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/model_upload_service.dart';
import '../utils/archive_source.dart';
import '../utils/file_archive.dart';

class ModelUploadDialog extends StatefulWidget {
  const ModelUploadDialog({super.key, this.service});
  final ModelUploadService? service;
  @override
  State<ModelUploadDialog> createState() => _ModelUploadDialogState();
}

class _ModelUploadDialogState extends State<ModelUploadDialog> {
  late final _service = widget.service ?? ModelUploadService();
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _version = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  List<Map<String, dynamic>> _sessions = [];
  Map<String, dynamic>? _session;
  ArchiveSource? _source;
  Timer? _poll;
  CancelToken? _cancel;
  bool _busy = false;
  int _progress = 0;
  String _phase = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      final selected = _session;
      if (selected == null) return;
      try {
        final fresh = await _service.control(
          '/admin/model-uploads/${selected['id']}',
          'GET',
          null,
        );
        if (mounted && _session?['id'] == selected['id']) {
          setState(() => _session = fresh);
        }
      } catch (error) {
        if (mounted) setState(() => _error = '$error');
      }
    });
  }

  Future<void> _reload() async {
    try {
      final sessions = await _service.list();
      if (mounted) setState(() => _sessions = sessions);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cancel?.cancel();
    _source?.close();
    for (final controller in [_id, _version, _name, _description]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    // Web picker supplies whole bytes: prohibit that path before opening it.
    if (kIsWeb) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['h5', 'keras'],
      withData: false,
    );
    if (result == null || result.files.single.path == null) return;
    final source = await openFileArchive(
      result.files.single.path!,
      filename: result.files.single.name,
    );
    await _source?.close();
    if (!mounted) {
      await source.close();
      return;
    }
    setState(() {
      _source = source;
      _error = null;
    });
  }

  Future<void> _select(int? id) async {
    await _source?.close();
    _source = null;
    if (id == null) {
      setState(() {
        _session = null;
        _phase = '';
      });
      return;
    }
    try {
      final session = await _service.control(
        '/admin/model-uploads/$id',
        'GET',
        null,
      );
      final manifest = session['manifest'] as Map;
      if (!mounted) return;
      setState(() {
        _session = session;
        _id.text = manifest['model_id'];
        _version.text = manifest['version'];
        _name.text = manifest['name'];
        _description.text = manifest['description'];
        _phase = '';
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _upload() async {
    if (!_form.currentState!.validate() || _source == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _phase = 'Menghitung SHA256';
      _progress = 0;
    });
    final cancellation = CancelToken();
    _cancel = cancellation;
    void hashing(int value) {
      if (mounted) {
        setState(() {
          _phase = 'Memverifikasi SHA256';
          _progress = value;
        });
      }
    }

    try {
      final source = _source!;
      var session = _session;
      if (session == null) {
        final digest = await _service.hash(
          source,
          hashing,
          cancellation: cancellation,
        );
        session = await _service.control('/admin/model-uploads', 'POST', {
          'schema_version': 1,
          'model_id': _id.text.trim(),
          'version': _version.text.trim(),
          'name': _name.text.trim(),
          'description': _description.text.trim(),
          'framework': 'tensorflow',
          'adapter': 'ginet-tcd-v1',
          'weight_file': source.filename.toLowerCase().endsWith('.h5')
              ? 'model.h5'
              : 'model.keras',
          'sha256': digest,
          'size_bytes': source.length,
          'input': {
            'width': 1024,
            'height': 1024,
            'dtype': 'uint16',
            'time_scalar': 0.5,
          },
        });
        if (mounted) setState(() => _session = session);
        await _reload();
      }
      final done = await _service.upload(source, session, hashing, (value) {
        if (mounted) {
          setState(() {
            _phase = 'Mengunggah langsung ke TUF';
            _progress = value;
          });
        }
      }, cancellation: cancellation);
      if (mounted) {
        setState(() {
          _session = done;
          _phase = 'Upload selesai';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _cancel = null;
        });
      }
    }
  }

  Future<void> _action(String action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await _service.control(
        '/admin/model-uploads/${_session!['id']}/$action',
        'POST',
        {},
      );
      if (mounted) setState(() => _session = session);
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _synchronize() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.control('/admin/model-uploads/sync', 'POST', {});
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _button(String label, String action) => OutlinedButton(
    onPressed: _busy ? null : () => _action(action),
    child: Text(label),
  );

  @override
  Widget build(BuildContext context) {
    final state = _session?['state'];
    final published = _session?['published'] == true;
    final running = _session?['operation'] != null;
    final sessions = [
      ..._sessions,
      if (_session != null && !_sessions.any((s) => s['id'] == _session!['id']))
        _session!,
    ];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Upload bobot model ke TUF',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            '.h5 / .keras · maksimum 10 GiB · adapter GINet TC-D. Publikasi dan aktivasi adalah langkah terpisah.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _session?['id'] as int?,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Sesi tersimpan'),
            items: [
              const DropdownMenuItem<int>(
                value: null,
                child: Text('Versi baru'),
              ),
              ...sessions.map(
                (s) => DropdownMenuItem<int>(
                  value: s['id'] as int,
                  child: Text(
                    '${s['manifest']['model_id']} / ${s['manifest']['version']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: _busy ? null : _select,
          ),
          const SizedBox(height: 16),
          if (kIsWeb)
            const Text(
              'Upload bobot dinonaktifkan pada Flutter Web karena picker memuat seluruh file ke memori. Gunakan portal Next.js atau aplikasi native untuk upload dan resume. Pengelolaan sesi tetap tersedia.',
            ),
          if (!kIsWeb)
            Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    controller: _id,
                    readOnly: _session != null,
                    decoration: const InputDecoration(labelText: 'ID model'),
                    validator: (v) =>
                        RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(v ?? '')
                        ? null
                        : 'Gunakan huruf kecil, angka, dan tanda hubung.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _version,
                    readOnly: _session != null,
                    decoration: const InputDecoration(
                      labelText: 'Versi immutable (1.0.0)',
                    ),
                    validator: (v) =>
                        RegExp(
                          r'^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)$',
                        ).hasMatch(v ?? '')
                        ? null
                        : 'Gunakan versi seperti 1.0.0.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    readOnly: _session != null,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Nama tampilan',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Nama diperlukan.' : null,
                  ),
                  TextFormField(
                    controller: _description,
                    readOnly: _session != null,
                    maxLength: 4000,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Deskripsi'),
                  ),
                  if (_session == null ||
                      ['uploading', 'uploaded'].contains(state)) ...[
                    OutlinedButton(
                      onPressed: _busy ? null : _pick,
                      child: Text(
                        _source?.filename ??
                            'Pilih ulang file bobot untuk upload / resume',
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _busy || _source == null ? null : _upload,
                      child: const Text('Verifikasi SHA256 & upload'),
                    ),
                  ],
                ],
              ),
            ),
          if (_phase.isNotEmpty) ...[
            Text(
              '$_phase · $_progress%',
              semanticsLabel: '$_phase $_progress persen',
            ),
            LinearProgressIndicator(value: _progress / 100),
          ],
          if (_session != null)
            Text(
              'Status: $state${running ? ' · ${_session!['operation']} sedang berjalan' : ''}',
            ),
          if (_session?['last_error'] != null)
            Text('Operasi belum berhasil: ${_session!['last_error']}'),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_cancel != null)
                TextButton(
                  onPressed: () => _cancel?.cancel(),
                  child: const Text('Jeda upload'),
                ),
              if (!running) ...[
                if (state == 'uploaded')
                  _button('Validasi manifest & format', 'finalize'),
                if (state == 'ready_for_test')
                  _button('Uji kompatibilitas GPU', 'test'),
                if (state == 'ready_for_activate' && !published)
                  _button('Publikasikan nonaktif', 'publish'),
                if (state == 'ready_for_activate' && published)
                  _button('Aktifkan versi', 'activate'),
                if (state == 'active')
                  _button('Nonaktifkan versi', 'deactivate'),
                if (_session != null &&
                    !published &&
                    !['cancelled', 'failed'].contains(state))
                  _button('Batalkan sesi', 'cancel'),
              ],
              TextButton(
                onPressed: _busy ? null : _synchronize,
                child: const Text('Sinkronisasi katalog TUF'),
              ),
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Uji kompatibilitas bukan validasi ilmiah. GPU harus tersedia. Versi lama dipertahankan untuk rollback.',
          ),
        ],
      ),
    );
  }
}
