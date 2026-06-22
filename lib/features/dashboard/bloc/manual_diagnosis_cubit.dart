import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_exception.dart';
import '../../auth/bloc/auth_cubit.dart';
import '../data/iot_models.dart';
import '../data/iot_repository.dart';
import 'history_cubit.dart' show LoadState;

class ManualDiagnosisState extends Equatable {
  const ManualDiagnosisState({
    this.state = LoadState.initial,
    this.result,
    this.error,
  });

  final LoadState state;
  final Diagnosis? result;
  final String? error;

  ManualDiagnosisState copyWith({
    LoadState? state,
    Diagnosis? result,
    String? error,
  }) =>
      ManualDiagnosisState(
        state: state ?? this.state,
        result: result ?? this.result,
        error: error,
      );

  @override
  List<Object?> get props => [state, result, error];
}

/// Runs the tabular health model on manually-entered sensor values
/// (`POST /manual-diagnosis`, costs 5 credits).
class ManualDiagnosisCubit extends Cubit<ManualDiagnosisState> {
  ManualDiagnosisCubit(this._repo, this._auth)
      : super(const ManualDiagnosisState());

  final IotRepository _repo;
  final AuthCubit _auth;

  Future<void> run({
    required double moisture,
    required double ambientTemp,
    required double soilTemp,
    required double humidity,
    required double ph,
    required double nitrogen,
    required double phosphorus,
    required double potassium,
    required double ec,
  }) async {
    final uid = _auth.state.userId;
    if (uid == null) return;
    emit(state.copyWith(state: LoadState.loading, error: null));
    try {
      final diag = await _repo.manualDiagnosis(
        userId: uid,
        moisture: moisture,
        ambientTemp: ambientTemp,
        soilTemp: soilTemp,
        humidity: humidity,
        ph: ph,
        nitrogen: nitrogen,
        phosphorus: phosphorus,
        potassium: potassium,
        ec: ec,
      );
      emit(state.copyWith(state: LoadState.loaded, result: diag));
      _auth.onCreditsSpent(5);
    } on InsufficientCreditsException {
      emit(state.copyWith(state: LoadState.error, error: 'Insufficient credits'));
    } on AppException catch (e) {
      emit(state.copyWith(state: LoadState.error, error: e.message));
    }
  }
}
