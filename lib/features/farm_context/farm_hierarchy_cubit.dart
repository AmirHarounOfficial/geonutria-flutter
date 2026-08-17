import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_client.dart';
import '../auth/bloc/auth_cubit.dart';
import '../deep_analysis/data/analysis_context.dart';

class FarmItem extends Equatable {
  const FarmItem({required this.id, required this.name});
  final int id;
  final String name;

  factory FarmItem.fromJson(Map<String, dynamic> j) => FarmItem(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? j['farm_name'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [id, name];
}

class CropItem extends Equatable {
  const CropItem({
    required this.id,
    required this.farmId,
    required this.name,
    this.isTree = false,
  });
  final int id;
  final int farmId;
  final String name;
  final bool isTree;

  factory CropItem.fromJson(Map<String, dynamic> j) => CropItem(
        id: (j['id'] as num).toInt(),
        farmId: (j['farm_id'] as num).toInt(),
        name: (j['name'] ?? j['crop_name'] ?? '').toString(),
        isTree: j['is_tree'] == true || j['is_tree'] == 1,
      );

  @override
  List<Object?> get props => [id, farmId, name, isTree];
}

class TreeItem extends Equatable {
  const TreeItem({
    required this.id,
    required this.cropId,
    required this.treeName,
    required this.treeCode,
  });
  final int id;
  final int cropId;
  final String treeName;
  final String treeCode;

  factory TreeItem.fromJson(Map<String, dynamic> j) => TreeItem(
        id: (j['id'] as num).toInt(),
        cropId: (j['crop_id'] as num).toInt(),
        treeName: (j['tree_name'] ?? '').toString(),
        treeCode: (j['tree_code'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [id, cropId, treeName, treeCode];
}

class FarmHierarchyState extends Equatable {
  const FarmHierarchyState({
    this.farms = const [],
    this.crops = const [],
    this.trees = const [],
    this.selectedFarmId,
    this.selectedCropId,
    this.selectedTreeId,
    this.isLoading = false,
  });

  final List<FarmItem> farms;
  final List<CropItem> crops;
  final List<TreeItem> trees;
  final int? selectedFarmId;
  final int? selectedCropId;
  final int? selectedTreeId;
  final bool isLoading;

  List<CropItem> get filteredCrops => selectedFarmId == null
      ? const []
      : crops.where((c) => c.farmId == selectedFarmId).toList();

  CropItem? get selectedCropObj {
    if (selectedCropId == null) return null;
    for (final c in crops) {
      if (c.id == selectedCropId) return c;
    }
    return null;
  }

  bool get isTreeCrop => selectedCropObj?.isTree ?? false;

  List<TreeItem> get filteredTrees => selectedCropId == null
      ? const []
      : trees.where((t) => t.cropId == selectedCropId).toList();

  FarmHierarchyState copyWith({
    List<FarmItem>? farms,
    List<CropItem>? crops,
    List<TreeItem>? trees,
    int? selectedFarmId,
    int? selectedCropId,
    int? selectedTreeId,
    bool? isLoading,
    bool clearFarm = false,
    bool clearCrop = false,
    bool clearTree = false,
  }) =>
      FarmHierarchyState(
        farms: farms ?? this.farms,
        crops: crops ?? this.crops,
        trees: trees ?? this.trees,
        selectedFarmId:
            clearFarm ? null : (selectedFarmId ?? this.selectedFarmId),
        selectedCropId:
            clearCrop ? null : (selectedCropId ?? this.selectedCropId),
        selectedTreeId:
            clearTree ? null : (selectedTreeId ?? this.selectedTreeId),
        isLoading: isLoading ?? this.isLoading,
      );

  @override
  List<Object?> get props => [
        farms,
        crops,
        trees,
        selectedFarmId,
        selectedCropId,
        selectedTreeId,
        isLoading,
      ];
}

class FarmHierarchyCubit extends Cubit<FarmHierarchyState> {
  FarmHierarchyCubit(this._api, this._auth) : super(const FarmHierarchyState());

  final ApiClient _api;
  final AuthCubit _auth;
  final AnalysisContextStore _contextStore = AnalysisContextStore();

  Future<void> loadHierarchy() async {
    final uid = _auth.state.userId ?? _api.userId;
    if (uid == null) return;
    emit(state.copyWith(isLoading: true));
    try {
      final json = await _api.get('/user-hierarchy/$uid');
      if (json is Map) {
        final fList = (json['farms'] as List? ?? [])
            .map((f) => FarmItem.fromJson(f as Map<String, dynamic>))
            .toList();
        final cList = (json['crops'] as List? ?? [])
            .map((c) => CropItem.fromJson(c as Map<String, dynamic>))
            .toList();
        final tList = (json['trees'] as List? ?? [])
            .map((t) => TreeItem.fromJson(t as Map<String, dynamic>))
            .toList();

        emit(state.copyWith(
          farms: fList,
          crops: cList,
          trees: tList,
          isLoading: false,
        ));
      }
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  void selectFarm(int? farmId) {
    emit(state.copyWith(
      selectedFarmId: farmId,
      clearCrop: true,
      clearTree: true,
    ));
    _syncWithContextStore();
  }

  void selectCrop(int? cropId) {
    emit(state.copyWith(
      selectedCropId: cropId,
      clearTree: true,
    ));
    _syncWithContextStore();
  }

  void selectTree(int? treeId) {
    emit(state.copyWith(selectedTreeId: treeId));
    _syncWithContextStore();
  }

  Future<void> _syncWithContextStore() async {
    final currentCtx = await _contextStore.read();
    FarmItem? farm;
    if (state.selectedFarmId != null) {
      for (final f in state.farms) {
        if (f.id == state.selectedFarmId) {
          farm = f;
          break;
        }
      }
    }
    CropItem? crop = state.selectedCropObj;

    final updated = currentCtx.copyWith(
      location: farm != null ? farm.name : currentCtx.location,
      cropType: crop != null ? crop.name : currentCtx.cropType,
    );
    await _contextStore.write(updated);
  }
}
