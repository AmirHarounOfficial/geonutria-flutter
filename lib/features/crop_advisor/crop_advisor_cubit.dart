import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/error/app_exception.dart';
import '../ai_models/data/model_repository.dart';
import '../auth/bloc/auth_cubit.dart';
import '../dashboard/bloc/history_cubit.dart' show LoadState;

class CropAdvisorState extends Equatable {
  const CropAdvisorState({
    this.soilState = LoadState.initial,
    this.soil,
    this.recState = LoadState.initial,
    this.crops = const [],
    this.error,
  });

  final LoadState soilState;
  final SoilResult? soil;
  final LoadState recState;
  final List<CropRec> crops;
  final String? error;

  CropAdvisorState copyWith({
    LoadState? soilState,
    SoilResult? soil,
    LoadState? recState,
    List<CropRec>? crops,
    String? error,
  }) =>
      CropAdvisorState(
        soilState: soilState ?? this.soilState,
        soil: soil ?? this.soil,
        recState: recState ?? this.recState,
        crops: crops ?? this.crops,
        error: error,
      );

  @override
  List<Object?> get props => [soilState, soil, recState, crops, error];
}

class CropAdvisorCubit extends Cubit<CropAdvisorState> {
  CropAdvisorCubit(this._repo, this._auth) : super(const CropAdvisorState());

  final ModelRepository _repo;
  final AuthCubit _auth;

  Future<void> classifySoil(XFile file) async {
    final uid = _auth.state.userId;
    if (uid == null) return;
    emit(state.copyWith(soilState: LoadState.loading, error: null));
    try {
      final soil = await _repo.classifySoil(uid, file);
      emit(state.copyWith(soilState: LoadState.loaded, soil: soil));
      _auth.onCreditsSpent(5);
    } on InsufficientCreditsException {
      emit(state.copyWith(soilState: LoadState.initial));
    } on AppException catch (e) {
      emit(state.copyWith(soilState: LoadState.error, error: e.message));
    }
  }

  Future<void> recommend({
    required double n,
    required double p,
    required double k,
    required double temperature,
    required double humidity,
    required double ph,
    required double rainfall,
    required String soilType,
  }) async {
    final uid = _auth.state.userId;
    if (uid == null) return;
    emit(state.copyWith(recState: LoadState.loading, error: null));
    try {
      final crops = await _repo.recommendCrops(
        userId: uid,
        n: n,
        p: p,
        k: k,
        temperature: temperature,
        humidity: humidity,
        ph: ph,
        rainfall: rainfall,
        soilType: soilType,
      );
      emit(state.copyWith(recState: LoadState.loaded, crops: crops));
      _auth.onCreditsSpent(5);
    } on InsufficientCreditsException {
      emit(state.copyWith(recState: LoadState.initial));
    } on AppException catch (e) {
      emit(state.copyWith(recState: LoadState.error, error: e.message));
    }
  }
}
