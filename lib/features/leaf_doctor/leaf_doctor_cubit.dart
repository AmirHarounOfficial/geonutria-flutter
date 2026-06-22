import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/error/app_exception.dart';
import '../auth/bloc/auth_cubit.dart';
import '../ai_models/data/model_repository.dart';

enum LeafStatus { idle, processing, success, failure }

enum LeafMode { general, palm }

class LeafState extends Equatable {
  const LeafState({
    this.status = LeafStatus.idle,
    this.mode = LeafMode.general,
    this.result,
    this.error,
  });

  final LeafStatus status;
  final LeafMode mode;
  final LeafResult? result;
  final String? error;

  LeafState copyWith({
    LeafStatus? status,
    LeafMode? mode,
    LeafResult? result,
    String? error,
    bool clearResult = false,
  }) =>
      LeafState(
        status: status ?? this.status,
        mode: mode ?? this.mode,
        result: clearResult ? null : (result ?? this.result),
        error: error,
      );

  @override
  List<Object?> get props => [status, mode, result, error];
}

class LeafDoctorCubit extends Cubit<LeafState> {
  LeafDoctorCubit(this._repo, this._auth) : super(const LeafState());

  final ModelRepository _repo;
  final AuthCubit _auth;

  void setMode(LeafMode mode) =>
      emit(state.copyWith(mode: mode, clearResult: true, status: LeafStatus.idle));

  Future<void> diagnose(XFile file) async {
    final uid = _auth.state.userId;
    if (uid == null) return;
    emit(state.copyWith(status: LeafStatus.processing, error: null, clearResult: true));
    try {
      final result = state.mode == LeafMode.palm
          ? await _repo.diagnosePalm(uid, file)
          : await _repo.diagnoseGeneralLeaf(uid, file);
      emit(state.copyWith(status: LeafStatus.success, result: result));
      // Palm = 5 credits; general = segment(5) + classify(5) = 10.
      _auth.onCreditsSpent(state.mode == LeafMode.palm ? 5 : 10);
    } on InsufficientCreditsException {
      emit(state.copyWith(status: LeafStatus.idle));
    } on AppException catch (e) {
      emit(state.copyWith(status: LeafStatus.failure, error: e.message));
    } catch (e) {
      emit(state.copyWith(
          status: LeafStatus.failure,
          error: e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
