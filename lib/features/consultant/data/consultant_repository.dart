import '../../../core/network/api_client.dart';
import 'consultant_models.dart';

/// Selected context toggles for a consultation request.
class ConsultantSelection {
  ConsultantSelection({
    this.includeUserInfo = false,
    this.includeMacroWeather = false,
    Set<int>? deviceIds,
    Set<int>? leafScans,
    Set<int>? soilScans,
    Set<int>? cropRecs,
    Set<int>? yieldPreds,
    Set<int>? satellites,
    Set<int>? aerialPalms,
  })  : deviceIds = deviceIds ?? {},
        leafScans = leafScans ?? {},
        soilScans = soilScans ?? {},
        cropRecs = cropRecs ?? {},
        yieldPreds = yieldPreds ?? {},
        satellites = satellites ?? {},
        aerialPalms = aerialPalms ?? {};

  bool includeUserInfo;
  bool includeMacroWeather;
  final Set<int> deviceIds;
  final Set<int> leafScans;
  final Set<int> soilScans;
  final Set<int> cropRecs;
  final Set<int> yieldPreds;
  final Set<int> satellites;
  final Set<int> aerialPalms;
}

/// Async AI consultant: fetch options, start a task, poll for the answer.
class ConsultantRepository {
  ConsultantRepository(this._api);

  final ApiClient _api;

  Future<ConsultantOptions> getOptions() async {
    final data = await _api.get('/ai-consultant/options', query: _api.authQuery());
    return ConsultantOptions.fromJson((data as Map).cast<String, dynamic>());
  }

  /// `POST /ai-consultant/start` → returns the task id to poll.
  Future<String> start({
    required int userId,
    required List<ChatMessage> history,
    required ConsultantSelection selection,
  }) async {
    final data = await _api.post('/ai-consultant/start', body: {
      'history': [for (final m in history) m.toJson()],
      'user_id': userId,
      'include_user_info': selection.includeUserInfo,
      'include_macro_weather': selection.includeMacroWeather,
      'selected_device_ids': selection.deviceIds.toList(),
      'selected_leaf_scans': selection.leafScans.toList(),
      'selected_soil_scans': selection.soilScans.toList(),
      'selected_crop_recs': selection.cropRecs.toList(),
      'selected_yield_preds': selection.yieldPreds.toList(),
      'selected_satellites': selection.satellites.toList(),
      'selected_aerial_palms': selection.aerialPalms.toList(),
    });
    final map = (data as Map).cast<String, dynamic>();
    return '${map['task_id']}';
  }

  /// `GET /ai-consultant/status/{task_id}`.
  Future<TaskStatus> pollStatus(String taskId) async {
    final data = await _api.get('/ai-consultant/status/$taskId');
    final map = (data as Map).cast<String, dynamic>();
    return TaskStatus(
      status: (map['status'] ?? 'unknown').toString(),
      answer: map['answer'] as String?,
      error: map['error'] as String?,
    );
  }
}

class TaskStatus {
  const TaskStatus({required this.status, this.answer, this.error});
  final String status; // pending | processing | completed | failed | not_found
  final String? answer;
  final String? error;

  bool get isDone => status == 'completed';
  bool get isFailed => status == 'failed' || status == 'not_found';
}
