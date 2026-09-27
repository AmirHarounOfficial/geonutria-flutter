import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../dashboard/bloc/history_cubit.dart' show LoadState;
import '../data/admin_repository.dart';

class AdminState extends Equatable {
  const AdminState({
    this.state = LoadState.initial,
    this.analytics = const AdminAnalytics(),
    this.users = const [],
    this.pendingPayments = const [],
    this.error,
    this.actionMessage,
  });

  final LoadState state;
  final AdminAnalytics analytics;
  final List<AdminUser> users;
  final List<PendingPayment> pendingPayments;
  final String? error;
  final String? actionMessage;

  AdminState copyWith({
    LoadState? state,
    AdminAnalytics? analytics,
    List<AdminUser>? users,
    List<PendingPayment>? pendingPayments,
    String? error,
    String? actionMessage,
  }) => AdminState(
    state: state ?? this.state,
    analytics: analytics ?? this.analytics,
    users: users ?? this.users,
    pendingPayments: pendingPayments ?? this.pendingPayments,
    error: error,
    actionMessage: actionMessage,
  );

  @override
  List<Object?> get props => [
    state,
    analytics,
    users,
    pendingPayments,
    error,
    actionMessage,
  ];
}

class AdminCubit extends Cubit<AdminState> {
  AdminCubit(this._repo) : super(const AdminState());

  final AdminRepository _repo;

  Future<void> loadAll() async {
    emit(state.copyWith(state: LoadState.loading, error: null));
    try {
      final results = await Future.wait([
        _repo.fetchAnalytics(),
        _repo.fetchUsers(),
        _repo.fetchPendingPayments(),
      ]);

      if (isClosed) return;
      emit(
        state.copyWith(
          state: LoadState.loaded,
          analytics: results[0] as AdminAnalytics,
          users: results[1] as List<AdminUser>,
          pendingPayments: results[2] as List<PendingPayment>,
        ),
      );
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(state: LoadState.error, error: e.toString()));
      }
    }
  }

  Future<void> processPayment(int billingId, bool approved) async {
    try {
      final status = approved ? 'Approved' : 'Rejected';
      await _repo.updatePaymentStatus(billingId, status);
      if (isClosed) return;
      emit(
        state.copyWith(
          actionMessage: 'Payment #$billingId $status successfully',
        ),
      );
      await loadAll();
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(error: 'Failed to update payment: $e'));
      }
    }
  }
}
