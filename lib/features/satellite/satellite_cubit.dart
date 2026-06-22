import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/error/app_exception.dart';
import '../ai_models/data/model_repository.dart';
import '../auth/bloc/auth_cubit.dart';
import '../dashboard/bloc/history_cubit.dart' show LoadState;
import 'data/satellite_models.dart';
import 'data/satellite_repository.dart';

class SatelliteState extends Equatable {
  const SatelliteState({
    this.analysisState = LoadState.initial,
    this.result,
    this.palmState = LoadState.initial,
    this.palm,
    this.error,
  });

  final LoadState analysisState;
  final SatelliteResult? result;
  final LoadState palmState;
  final PalmCountResult? palm;
  final String? error;

  SatelliteState copyWith({
    LoadState? analysisState,
    SatelliteResult? result,
    LoadState? palmState,
    PalmCountResult? palm,
    String? error,
  }) =>
      SatelliteState(
        analysisState: analysisState ?? this.analysisState,
        result: result ?? this.result,
        palmState: palmState ?? this.palmState,
        palm: palm ?? this.palm,
        error: error,
      );

  @override
  List<Object?> get props => [analysisState, result, palmState, palm, error];
}

class SatelliteCubit extends Cubit<SatelliteState> {
  SatelliteCubit(this._repo, this._models, this._auth)
      : super(const SatelliteState());

  final SatelliteRepository _repo;
  final ModelRepository _models;
  final AuthCubit _auth;

  Future<void> analyze({
    double? lat,
    double? lon,
    double radiusKm = 1.0,
    required String startDate,
    required String endDate,
    int compareValue = 3,
    String compareUnit = 'months',
    List<List<double>>? polygonCoords,
    int maxCloudCover = 10,
  }) async {
    final uid = _auth.state.userId;
    if (uid == null) return;
    emit(state.copyWith(analysisState: LoadState.loading, error: null));
    try {
      final result = await _repo.analyze(
        userId: uid,
        lat: lat,
        lon: lon,
        radiusKm: radiusKm,
        startDate: startDate,
        endDate: endDate,
        compareValue: compareValue,
        compareUnit: compareUnit,
        polygonCoords: polygonCoords,
        maxCloudCover: maxCloudCover,
      );
      emit(state.copyWith(analysisState: LoadState.loaded, result: result));
      _auth.onCreditsSpent(5);
    } on InsufficientCreditsException {
      emit(state.copyWith(analysisState: LoadState.initial));
    } on AppException catch (e) {
      emit(state.copyWith(analysisState: LoadState.error, error: e.message));
    } catch (e) {
      emit(state.copyWith(
          analysisState: LoadState.error,
          error: e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> countPalms(XFile file) async {
    final uid = _auth.state.userId;
    if (uid == null) return;
    emit(state.copyWith(palmState: LoadState.loading, error: null));
    try {
      final palm = await _models.countPalms(uid, file);
      emit(state.copyWith(palmState: LoadState.loaded, palm: palm));
      _auth.onCreditsSpent(5);
    } on InsufficientCreditsException {
      emit(state.copyWith(palmState: LoadState.initial));
    } on AppException catch (e) {
      emit(state.copyWith(palmState: LoadState.error, error: e.message));
    }
  }
}
