import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/app_exception.dart';
import '../../auth/bloc/auth_cubit.dart';
import '../../dashboard/bloc/history_cubit.dart' show LoadState;
import '../data/profile_models.dart';
import '../data/profile_repository.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.state = LoadState.initial,
    this.profile,
    this.team = const [],
    this.message,
    this.error,
  });

  final LoadState state;
  final UserProfile? profile;
  final List<TeamMember> team;
  final String? message;
  final String? error;

  ProfileState copyWith({
    LoadState? state,
    UserProfile? profile,
    List<TeamMember>? team,
    String? message,
    String? error,
  }) =>
      ProfileState(
        state: state ?? this.state,
        profile: profile ?? this.profile,
        team: team ?? this.team,
        message: message,
        error: error,
      );

  @override
  List<Object?> get props => [state, profile, team, message, error];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repo, this._auth) : super(const ProfileState());

  final ProfileRepository _repo;
  final AuthCubit _auth;

  Future<void> load() async {
    emit(state.copyWith(state: LoadState.loading, error: null));
    try {
      final profile = await _repo.getProfile();
      final team = await _repo.getTeam();
      emit(state.copyWith(state: LoadState.loaded, profile: profile, team: team));
    } on AppException catch (e) {
      emit(state.copyWith(state: LoadState.error, error: e.message));
    }
  }

  Future<void> updateProfile({String? name, String? mobile, int? age, String? sex}) async {
    try {
      await _repo.updateProfile(name: name, mobile: mobile, age: age, sex: sex);
      emit(state.copyWith(message: 'Profile updated'));
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> changePassword({String? oldPassword, required String newPassword}) async {
    try {
      await _repo.changePassword(oldPassword: oldPassword, newPassword: newPassword);
      emit(state.copyWith(message: 'Password changed'));
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> uploadPicture(XFile file) async {
    final uid = _auth.state.userId;
    if (uid == null) return;
    try {
      await _repo.uploadPicture(uid, file);
      emit(state.copyWith(message: 'Picture updated'));
      await load();
      _auth.refreshCredits();
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> addTeamMember(String email, {int? sharedCredits}) async {
    try {
      await _repo.addTeamMember(email, sharedCredits: sharedCredits);
      emit(state.copyWith(message: 'Member added'));
      await load();
      _auth.refreshCredits();
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> removeTeamMember(int memberId) async {
    try {
      await _repo.removeTeamMember(memberId);
      emit(state.copyWith(message: 'Member removed'));
      await load();
      _auth.refreshCredits();
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }
}
