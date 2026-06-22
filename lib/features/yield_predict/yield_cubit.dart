import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/app_exception.dart';
import '../ai_models/data/model_repository.dart';
import '../auth/bloc/auth_cubit.dart';
import '../dashboard/bloc/history_cubit.dart' show LoadState;

class YieldState extends Equatable {
  const YieldState({
    this.state = LoadState.initial,
    this.kgPerHa,
    this.error,
  });

  final LoadState state;
  final int? kgPerHa;
  final String? error;

  double? get kgPerAcre => kgPerHa == null ? null : kgPerHa! / 2.47;

  YieldState copyWith({LoadState? state, int? kgPerHa, String? error}) =>
      YieldState(
        state: state ?? this.state,
        kgPerHa: kgPerHa ?? this.kgPerHa,
        error: error,
      );

  @override
  List<Object?> get props => [state, kgPerHa, error];
}

class YieldCubit extends Cubit<YieldState> {
  YieldCubit(this._repo, this._auth) : super(const YieldState());

  final ModelRepository _repo;
  final AuthCubit _auth;

  Future<void> predict({
    required String crop,
    required int n,
    required int p,
    required int k,
    required int temperature,
    required int humidity,
    required double ph,
    required int rainfall,
  }) async {
    final uid = _auth.state.userId;
    if (uid == null) return;
    emit(state.copyWith(state: LoadState.loading, error: null));
    try {
      final kg = await _repo.predictYield(
        userId: uid,
        crop: crop,
        n: n,
        p: p,
        k: k,
        temperature: temperature,
        humidity: humidity,
        ph: ph,
        rainfall: rainfall,
      );
      emit(state.copyWith(state: LoadState.loaded, kgPerHa: kg));
      _auth.onCreditsSpent(5);
    } on InsufficientCreditsException {
      emit(state.copyWith(state: LoadState.initial));
    } on AppException catch (e) {
      emit(state.copyWith(state: LoadState.error, error: e.message));
    }
  }
}
