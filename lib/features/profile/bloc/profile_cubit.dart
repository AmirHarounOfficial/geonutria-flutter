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
    this.farms = const [],
    this.crops = const [],
    this.trees = const [],
    this.selectedFarm,
    this.selectedCrop,
    this.mediaGallery = const [],
    this.message,
    this.error,
  });

  final LoadState state;
  final UserProfile? profile;
  final List<TeamMember> team;
  final List<Farm> farms;
  final List<Crop> crops;
  final List<TreeItem> trees;
  final Farm? selectedFarm;
  final Crop? selectedCrop;
  final List<AssetMedia> mediaGallery;
  final String? message;
  final String? error;

  ProfileState copyWith({
    LoadState? state,
    UserProfile? profile,
    List<TeamMember>? team,
    List<Farm>? farms,
    List<Crop>? crops,
    List<TreeItem>? trees,
    Farm? selectedFarm,
    bool clearSelectedFarm = false,
    Crop? selectedCrop,
    bool clearSelectedCrop = false,
    List<AssetMedia>? mediaGallery,
    String? message,
    String? error,
  }) =>
      ProfileState(
        state: state ?? this.state,
        profile: profile ?? this.profile,
        team: team ?? this.team,
        farms: farms ?? this.farms,
        crops: crops ?? this.crops,
        trees: trees ?? this.trees,
        selectedFarm: clearSelectedFarm ? null : (selectedFarm ?? this.selectedFarm),
        selectedCrop: clearSelectedCrop ? null : (selectedCrop ?? this.selectedCrop),
        mediaGallery: mediaGallery ?? this.mediaGallery,
        message: message,
        error: error,
      );

  @override
  List<Object?> get props => [
        state,
        profile,
        team,
        farms,
        crops,
        trees,
        selectedFarm,
        selectedCrop,
        mediaGallery,
        message,
        error,
      ];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repo, this._auth) : super(const ProfileState());

  final ProfileRepository _repo;
  final AuthCubit _auth;

  int _resolveUserId() {
    final authUid = _auth.state.userId;
    if (authUid != null && authUid > 0) return authUid;
    final repoUid = _repo.currentUserId;
    if (repoUid != null && repoUid > 0) return repoUid;
    return 0;
  }

  Future<void> load() async {
    final uid = _resolveUserId();
    if (uid <= 0) {
      emit(state.copyWith(
        state: LoadState.error,
        error: 'Session expired. Please login again.',
      ));
      return;
    }

    emit(state.copyWith(state: LoadState.loading, error: null));
    try {
      final profile = await _repo.getProfile(uid);
      final team = await _repo.getTeam(uid);
      final farms = await _repo.getFarms(uid);

      emit(state.copyWith(
        state: LoadState.loaded,
        profile: profile,
        team: team,
        farms: farms,
      ));
    } on AppException catch (e) {
      emit(state.copyWith(state: LoadState.error, error: e.message));
    } catch (e) {
      emit(state.copyWith(state: LoadState.error, error: 'Failed to load profile: $e'));
    }
  }

  Future<void> updateProfile({
    String? name,
    String? mobile,
    int? age,
    String? sex,
  }) async {
    final uid = _resolveUserId();
    if (uid <= 0) return;
    try {
      await _repo.updateProfile(uid, name: name, mobile: mobile, age: age, sex: sex);
      emit(state.copyWith(message: 'Profile updated successfully ✅'));
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to update profile: $e'));
    }
  }

  Future<void> changePassword({
    String? oldPassword,
    required String newPassword,
  }) async {
    final uid = _resolveUserId();
    if (uid <= 0) return;
    try {
      await _repo.changePassword(uid, oldPassword: oldPassword, newPassword: newPassword);
      emit(state.copyWith(message: 'Password updated successfully ✅'));
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    } catch (e) {
      emit(state.copyWith(error: 'Password update failed: $e'));
    }
  }

  Future<void> uploadPicture(XFile file) async {
    final uid = _resolveUserId();
    if (uid <= 0) return;
    try {
      await _repo.uploadPicture(uid, file);
      emit(state.copyWith(message: 'Profile picture updated ✅'));
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    } catch (e) {
      emit(state.copyWith(error: 'Picture upload failed: $e'));
    }
  }

  Future<void> addTeamMember(String email, {int? sharedCredits}) async {
    final uid = _resolveUserId();
    if (uid <= 0) return;
    try {
      await _repo.addTeamMember(uid, memberEmail: email, sharedCredits: sharedCredits);
      emit(state.copyWith(message: 'Team member added ✅'));
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to add team member: $e'));
    }
  }

  Future<void> removeTeamMember(int memberId) async {
    final uid = _resolveUserId();
    if (uid <= 0) return;
    try {
      await _repo.removeTeamMember(uid, memberId);
      emit(state.copyWith(message: 'Team member removed ✅'));
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to remove team member: $e'));
    }
  }

  // --- Asset Operations ---
  Future<void> selectFarm(Farm farm) async {
    emit(state.copyWith(
      selectedFarm: farm,
      clearSelectedCrop: true,
      crops: const [],
      trees: const [],
    ));
    try {
      final crops = await _repo.getCrops(farm.id);
      emit(state.copyWith(crops: crops));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to fetch crops: $e'));
    }
  }

  Future<void> selectCrop(Crop crop) async {
    emit(state.copyWith(
      selectedCrop: crop,
      trees: const [],
    ));
    try {
      final trees = await _repo.getTrees(crop.id);
      emit(state.copyWith(trees: trees));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to fetch trees: $e'));
    }
  }

  Future<void> fetchMedia(String entityType, int entityId) async {
    try {
      final media = await _repo.getMedia(entityType, entityId);
      emit(state.copyWith(mediaGallery: media));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to fetch media: $e'));
    }
  }

  Future<void> createFarm(Map<String, dynamic> farmData) async {
    final uid = _resolveUserId();
    if (uid <= 0) return;
    try {
      await _repo.createFarm(uid, farmData);
      emit(state.copyWith(message: 'Farm created successfully ✅'));
      final farms = await _repo.getFarms(uid);
      emit(state.copyWith(farms: farms));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to create farm: $e'));
    }
  }

  Future<void> createCrop(Map<String, dynamic> cropData) async {
    final farmId = state.selectedFarm?.id;
    if (farmId == null) return;
    try {
      await _repo.createCrop({...cropData, 'farm_id': farmId});
      emit(state.copyWith(message: 'Crop created successfully ✅'));
      final crops = await _repo.getCrops(farmId);
      emit(state.copyWith(crops: crops));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to create crop: $e'));
    }
  }

  Future<void> createTree(Map<String, dynamic> treeData) async {
    final cropId = state.selectedCrop?.id;
    if (cropId == null) return;
    try {
      await _repo.createTree({...treeData, 'crop_id': cropId});
      emit(state.copyWith(message: 'Tree created successfully ✅'));
      final trees = await _repo.getTrees(cropId);
      emit(state.copyWith(trees: trees));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to create tree: $e'));
    }
  }

  Future<void> deleteEntity(String type, int id) async {
    try {
      await _repo.deleteEntity(type, id);
      emit(state.copyWith(message: '$type deleted ✅'));
      final uid = _resolveUserId();
      if (type == 'Farm') {
        emit(state.copyWith(clearSelectedFarm: true, clearSelectedCrop: true));
        if (uid > 0) {
          final farms = await _repo.getFarms(uid);
          emit(state.copyWith(farms: farms));
        }
      } else if (type == 'Crop') {
        emit(state.copyWith(clearSelectedCrop: true));
        if (state.selectedFarm != null) {
          final crops = await _repo.getCrops(state.selectedFarm!.id);
          emit(state.copyWith(crops: crops));
        }
      } else if (type == 'Tree') {
        if (state.selectedCrop != null) {
          final trees = await _repo.getTrees(state.selectedCrop!.id);
          emit(state.copyWith(trees: trees));
        }
      }
    } catch (e) {
      emit(state.copyWith(error: 'Failed to delete $type: $e'));
    }
  }
}
