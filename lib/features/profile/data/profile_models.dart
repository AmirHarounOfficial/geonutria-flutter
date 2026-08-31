import 'package:equatable/equatable.dart';

import '../../../core/config/env.dart';

/// Helper to format profile image URLs exactly like `getFullImageUrl` in the dashboard (`ProfileView.js`).
String resolveProfileImageUrl(String? url, {String defaultName = 'User'}) {
  if (url == null || url.trim().isEmpty) {
    final encodedName = Uri.encodeComponent(defaultName.isNotEmpty ? defaultName : 'User');
    return 'https://ui-avatars.com/api/?name=$encodedName&background=C47A2C&color=fff';
  }
  var clean = url.trim();
  if (clean.contains('127.0.0.1:8009') || clean.contains('localhost:8009')) {
    clean = clean.replaceAll('http://127.0.0.1:8009', '').replaceAll('http://localhost:8009', '');
    if (!clean.startsWith('/')) clean = '/$clean';
    return '${Env.staticBaseUrl}$clean';
  }
  if (clean.startsWith('http://') || clean.startsWith('https://') || clean.startsWith('data:')) {
    return clean;
  }
  final path = clean.startsWith('/') ? clean : '/$clean';
  return '${Env.staticBaseUrl}$path';
}

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.mobile = '',
    this.age,
    this.sex = 'Male',
    this.aiCredits = 0,
    this.subscriptionPlan = 'Free',
    this.picture = '',
    this.hasPassword = true,
    this.role,
  });

  final int id;
  final String name;
  final String email;
  final String mobile;
  final int? age;
  final String sex;
  final int aiCredits;
  final String subscriptionPlan;
  final String picture;
  final bool hasPassword;
  final String? role;

  String get avatarUrl => resolveProfileImageUrl(picture, defaultName: name);

  bool get isAdmin =>
      role?.toLowerCase() == 'admin' ||
      email == 'ACFM_IT_Admin9573' ||
      id == 1 ||
      subscriptionPlan.toLowerCase() == 'admin';

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    final rawId = j['id'] ?? j['user_id'];
    return UserProfile(
      id: (rawId as num?)?.toInt() ?? 0,
      name: (j['name'] ?? 'User').toString(),
      email: (j['email'] ?? '').toString(),
      mobile: (j['mobile'] ?? '').toString(),
      age: (j['age'] as num?)?.toInt(),
      sex: (j['sex'] == null || j['sex'].toString().isEmpty)
          ? 'Male'
          : j['sex'].toString(),
      aiCredits: (j['ai_credits'] as num?)?.toInt() ?? 0,
      subscriptionPlan: (j['subscription_plan'] ?? 'Free').toString(),
      picture: (j['picture'] ?? '').toString(),
      hasPassword: j['has_password'] != false,
      role: j['role']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        mobile,
        age,
        sex,
        aiCredits,
        subscriptionPlan,
        picture,
        hasPassword,
        role,
      ];
}

class TeamMember extends Equatable {
  const TeamMember({
    required this.memberId,
    required this.name,
    required this.email,
    this.picture = '',
    this.sharedCredits = 0,
  });

  final int memberId;
  final String name;
  final String email;
  final String picture;
  final int sharedCredits;

  String get avatarUrl => resolveProfileImageUrl(picture, defaultName: name);

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
        memberId: (j['member_id'] as num?)?.toInt() ?? (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? 'Member').toString(),
        email: (j['email'] ?? '').toString(),
        picture: (j['picture'] ?? '').toString(),
        sharedCredits: (j['shared_credits'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [memberId, name, email, picture, sharedCredits];
}

class Farm extends Equatable {
  const Farm({
    required this.id,
    required this.farmName,
    required this.address,
    this.totalArea = 0.0,
    this.latitude = 30.0444,
    this.longitude = 31.2357,
  });

  final int id;
  final String farmName;
  final String address;
  final double totalArea;
  final double latitude;
  final double longitude;

  factory Farm.fromJson(Map<String, dynamic> j) => Farm(
        id: (j['id'] as num?)?.toInt() ?? 0,
        farmName: (j['farm_name'] ?? 'Unnamed Farm').toString(),
        address: (j['address'] ?? '').toString(),
        totalArea: (j['total_area'] as num?)?.toDouble() ?? 0.0,
        latitude: (j['latitude'] as num?)?.toDouble() ?? 30.0444,
        longitude: (j['longitude'] as num?)?.toDouble() ?? 31.2357,
      );

  @override
  List<Object?> get props => [id, farmName, address, totalArea, latitude, longitude];
}

class Crop extends Equatable {
  const Crop({
    required this.id,
    required this.farmId,
    required this.cropName,
    this.cropCategory = 'Cereal',
    this.plantedArea = 0.0,
    this.age = 0,
    this.waterConsumption = 0.0,
    this.healthStatus = 'Healthy',
    this.yieldCapacity = 0.0,
  });

  final int id;
  final int farmId;
  final String cropName;
  final String cropCategory;
  final double plantedArea;
  final int age;
  final double waterConsumption;
  final String healthStatus;
  final double yieldCapacity;

  factory Crop.fromJson(Map<String, dynamic> j) => Crop(
        id: (j['id'] as num?)?.toInt() ?? 0,
        farmId: (j['farm_id'] as num?)?.toInt() ?? 0,
        cropName: (j['crop_name'] ?? 'Crop').toString(),
        cropCategory: (j['crop_category'] ?? 'Cereal').toString(),
        plantedArea: (j['planted_area'] as num?)?.toDouble() ?? 0.0,
        age: (j['age'] as num?)?.toInt() ?? 0,
        waterConsumption: (j['water_consumption'] as num?)?.toDouble() ?? 0.0,
        healthStatus: (j['health_status'] ?? 'Healthy').toString(),
        yieldCapacity: (j['yield_capacity'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  List<Object?> get props => [
        id,
        farmId,
        cropName,
        cropCategory,
        plantedArea,
        age,
        waterConsumption,
        healthStatus,
        yieldCapacity,
      ];
}

class TreeItem extends Equatable {
  const TreeItem({
    required this.id,
    required this.cropId,
    required this.treeName,
    required this.treeCode,
    this.area = 0.0,
    this.latitude = 30.0444,
    this.longitude = 31.2357,
    this.age = 0,
    this.waterConsumption = 0.0,
    this.healthStatus = 'Healthy',
    this.yieldCapacity = 0.0,
  });

  final int id;
  final int cropId;
  final String treeName;
  final String treeCode;
  final double area;
  final double latitude;
  final double longitude;
  final int age;
  final double waterConsumption;
  final String healthStatus;
  final double yieldCapacity;

  factory TreeItem.fromJson(Map<String, dynamic> j) => TreeItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        cropId: (j['crop_id'] as num?)?.toInt() ?? 0,
        treeName: (j['tree_name'] ?? 'Tree').toString(),
        treeCode: (j['tree_code'] ?? '').toString(),
        area: (j['area'] as num?)?.toDouble() ?? 0.0,
        latitude: (j['latitude'] as num?)?.toDouble() ?? 30.0444,
        longitude: (j['longitude'] as num?)?.toDouble() ?? 31.2357,
        age: (j['age'] as num?)?.toInt() ?? 0,
        waterConsumption: (j['water_consumption'] as num?)?.toDouble() ?? 0.0,
        healthStatus: (j['health_status'] ?? 'Healthy').toString(),
        yieldCapacity: (j['yield_capacity'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  List<Object?> get props => [
        id,
        cropId,
        treeName,
        treeCode,
        area,
        latitude,
        longitude,
        age,
        waterConsumption,
        healthStatus,
        yieldCapacity,
      ];
}

class AssetMedia extends Equatable {
  const AssetMedia({
    required this.fileUrl,
    required this.filePath,
  });

  final String fileUrl;
  final String filePath;

  String get fullUrl => resolveProfileImageUrl(fileUrl.isNotEmpty ? fileUrl : filePath);

  factory AssetMedia.fromJson(Map<String, dynamic> j) => AssetMedia(
        fileUrl: (j['file_url'] ?? '').toString(),
        filePath: (j['file_path'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [fileUrl, filePath];
}
