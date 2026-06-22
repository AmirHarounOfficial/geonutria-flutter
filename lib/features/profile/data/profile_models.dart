import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.mobile,
    this.age,
    this.sex,
    this.aiCredits = 0,
    this.subscriptionPlan,
    this.picture,
    this.hasPassword = true,
  });

  final int id;
  final String name;
  final String email;
  final String? mobile;
  final int? age;
  final String? sex;
  final int aiCredits;
  final String? subscriptionPlan;
  final String? picture;
  final bool hasPassword;

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        mobile: j['mobile']?.toString(),
        age: (j['age'] as num?)?.toInt(),
        sex: j['sex']?.toString(),
        aiCredits: (j['ai_credits'] as num?)?.toInt() ?? 0,
        subscriptionPlan: j['subscription_plan']?.toString(),
        picture: j['picture']?.toString(),
        hasPassword: j['has_password'] != false,
      );

  @override
  List<Object?> get props => [id, name, email, mobile, age, sex, aiCredits, picture];
}

class TeamMember extends Equatable {
  const TeamMember({
    required this.memberId,
    required this.name,
    required this.email,
    this.picture,
    this.sharedCredits = 0,
  });

  final int memberId;
  final String name;
  final String email;
  final String? picture;
  final int sharedCredits;

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
        memberId: (j['member_id'] as num).toInt(),
        name: (j['name'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        picture: j['picture']?.toString(),
        sharedCredits: (j['shared_credits'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [memberId, sharedCredits];
}
