

import '../config/api_config.dart';
import '../models/pagination.dart';
import '../models/training.dart';
import 'api_client.dart';

/// Managed model training, from the administrator's side.
///
/// The platform never trains anything: these endpoints record what should be
/// trained and what came back. The GPU worker talks to a separate set of
/// routes with its own credential.
class TrainingService {
  final ApiClient _api = ApiClient.instance;

  // ------------------------------------------------------------ datasets

  /// GET /admin/training/datasets
  Future<List<TrainingDataset>> datasets() async {
    final body = await _api.get(ApiConfig.adminTrainingDatasets);

    return (body['data'] as List? ?? [])
        .map(
          (e) => TrainingDataset.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// POST /admin/training/datasets — a URL the worker fetches for itself.
  ///
  /// There is no upload here any more, and the endpoint refuses one. An
  /// administrator registering a dataset is recording where data already
  /// lives; carrying 20 GB through this server so the GPU host can pull it
  /// back down wastes both trips. Researchers upload, chunked and resumable,
  /// through their own screen.
  Future<TrainingDataset> addDataset({
    required String name,
    String? description,
    required String sourceUrl,
    int? frameCount,
  }) async {
    final body = await _api.post(
      ApiConfig.adminTrainingDatasets,
      data: {
        'name': name,
        'description': ?description,
        'source_url': sourceUrl,
        'frame_count': ?frameCount,
      },
    );

    return TrainingDataset.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  /// DELETE /admin/training/datasets/{id}
  Future<void> deleteDataset(int id) async {
    await _api.delete('${ApiConfig.adminTrainingDatasets}/$id');
  }

  // ---------------------------------------------------------------- jobs

  /// GET /admin/training/jobs
  Future<({
    PaginatedResult<TrainingJob> page,
    int queuedCount,
    int runningCount,
    bool workerConfigured,
  })> jobs({int page = 1, String? status}) async {
    final body = await _api.get(
      ApiConfig.adminTrainingJobs,
      query: {'page': page, 'status': status},
    );

    final items = (body['data'] as List? ?? [])
        .map((e) => TrainingJob.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final meta = body['meta'];
    int metaInt(String key) =>
        meta is Map ? (meta[key] as num?)?.toInt() ?? 0 : 0;

    return (
      page: PaginatedResult(
        items: items,
        pagination: body['pagination'] != null
            ? Pagination.fromJson(
                Map<String, dynamic>.from(body['pagination'] as Map),
              )
            : const Pagination.empty(),
      ),
      queuedCount: metaInt('queued_count'),
      runningCount: metaInt('running_count'),
      // False means no worker can authenticate, so nothing will ever start.
      // The screen says so rather than leaving an admin watching a queue that
      // cannot move.
      workerConfigured: meta is Map && meta['worker_configured'] == true,
    );
  }

  /// GET /admin/training/jobs/{id}
  Future<TrainingJob> job(int id) async {
    final body = await _api.get('${ApiConfig.adminTrainingJobs}/$id');
    return TrainingJob.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  /// POST /admin/training/jobs/{id}/dispatch
  ///
  /// Push the job to a trainer URL on the GPU host, the same way a prediction
  /// is pushed to a model endpoint. The job stays `queued` until the trainer's
  /// first heartbeat — accepting is not starting.
  Future<String> dispatchJob(int id, {String? trainerUrl}) async {
    final body = await _api.post(
      '${ApiConfig.adminTrainingJobs}/$id/dispatch',
      data: {'trainer_url': ?trainerUrl},
    );

    return body['message']?.toString() ?? 'Sent to the trainer.';
  }

  /// POST /admin/training/jobs/{id}/cancel
  Future<void> cancelJob(int id) async {
    await _api.post('${ApiConfig.adminTrainingJobs}/$id/cancel');
  }

  /// DELETE /admin/training/jobs/{id}
  Future<void> deleteJob(int id) async {
    await _api.delete('${ApiConfig.adminTrainingJobs}/$id');
  }

  /// POST /admin/training/jobs/{id}/register-model
  ///
  /// Turns finished weights into a registry entry. The new model is inactive
  /// and offline until someone deploys the weights and sets its endpoint —
  /// weights are a file, a model here is a running worker with a URL.
  Future<String> registerModel({
    required int jobId,
    required String name,
    required String version,
    String? endpointUrl,
    String? description,
  }) async {
    final body = await _api.post(
      '${ApiConfig.adminTrainingJobs}/$jobId/register-model',
      data: {
        'name': name,
        'version': version,
        'endpoint_url': ?endpointUrl,
        'description': ?description,
      },
    );

    return body['message']?.toString() ?? 'Registered.';
  }
}
