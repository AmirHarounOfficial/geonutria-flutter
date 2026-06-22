import 'package:equatable/equatable.dart';

/// A selectable data item (device or past scan) for the AI consultant.
class OptionItem extends Equatable {
  const OptionItem({required this.id, required this.name});
  final int id;
  final String name;

  factory OptionItem.fromJson(Map<String, dynamic> j) => OptionItem(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? 'Item ${j['id']}').toString(),
      );

  @override
  List<Object?> get props => [id, name];
}

/// Available context the user can attach to a consultation
/// (`GET /ai-consultant/options`).
class ConsultantOptions extends Equatable {
  const ConsultantOptions({
    this.devices = const [],
    this.leafScans = const [],
    this.soilScans = const [],
    this.cropRecs = const [],
    this.yieldPreds = const [],
    this.satellites = const [],
    this.aerialPalms = const [],
  });

  final List<OptionItem> devices;
  final List<OptionItem> leafScans;
  final List<OptionItem> soilScans;
  final List<OptionItem> cropRecs;
  final List<OptionItem> yieldPreds;
  final List<OptionItem> satellites;
  final List<OptionItem> aerialPalms;

  static List<OptionItem> _list(dynamic v) => (v is List)
      ? v
          .whereType<Map>()
          .map((e) => OptionItem.fromJson(e.cast<String, dynamic>()))
          .toList()
      : const [];

  factory ConsultantOptions.fromJson(Map<String, dynamic> j) =>
      ConsultantOptions(
        devices: _list(j['devices']),
        leafScans: _list(j['leaf_scans']),
        soilScans: _list(j['soil_scans']),
        cropRecs: _list(j['crop_recs']),
        yieldPreds: _list(j['yield_preds']),
        satellites: _list(j['satellites']),
        aerialPalms: _list(j['aerial_palms']),
      );

  @override
  List<Object?> get props =>
      [devices, leafScans, soilScans, cropRecs, yieldPreds, satellites, aerialPalms];
}

/// A chat message in the consultation (role: user | assistant).
///
/// [imageDataUrl] (optional) holds an attached image as a `data:image/...`
/// URL, used by the Advanced AI multimodal chat for display and for building
/// the OpenAI-style multimodal request content.
class ChatMessage extends Equatable {
  const ChatMessage({required this.role, required this.content, this.imageDataUrl});
  final String role;
  final String content;
  final String? imageDataUrl;

  bool get isUser => role == 'user';
  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  @override
  List<Object?> get props => [role, content, imageDataUrl];
}
