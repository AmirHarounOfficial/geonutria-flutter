import 'package:geonutria_mobile/core/localization/localized_number.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/image_pick_sheet.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/bloc/auth_cubit.dart';
import '../../dashboard/bloc/history_cubit.dart' show LoadState;
import '../bloc/profile_cubit.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';
import '../data/phone_number.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    final authCubit = context.read<AuthCubit>();

    return BlocProvider(
      create: (ctx) => ProfileCubit(ProfileRepository(api), authCubit)..load(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileCubit, ProfileState>(
      listenWhen: (a, b) =>
          (a.message != b.message || a.error != b.error) &&
          (b.state != LoadState.error || b.profile != null),
      listener: (ctx, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(ctx)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(context.errorText(state.error!)),
                backgroundColor: Colors.redAccent,
              ),
            );
        } else if (state.message != null) {
          ScaffoldMessenger.of(ctx)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(context.ui(state.message!)),
                backgroundColor: Colors.green,
              ),
            );
        }
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.tr('tab_profile')),
            centerTitle: true,
            bottom: TabBar(
              indicatorColor: Color(0xFFC47A2C),
              labelColor: Color(0xFFC47A2C),
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: context.ui('Profile Settings')),
                Tab(text: context.ui('Farms & Assets')),
              ],
            ),
          ),
          body: TabBarView(
            children: [_ProfileSettingsTab(), _FarmsAndAssetsTab()],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SUB-TAB 1: PROFILE SETTINGS & TEAM
// ==========================================
class _ProfileSettingsTab extends StatefulWidget {
  const _ProfileSettingsTab();

  @override
  State<_ProfileSettingsTab> createState() => _ProfileSettingsTabState();
}

class _ProfileSettingsTabState extends State<_ProfileSettingsTab> {
  static final _phoneDigits = TextInputFormatter.withFunction((oldValue, next) {
    final normalized = normalizeNumber(next.text);
    if (!RegExp(r'^[0-9\s()-]*$').hasMatch(normalized)) return oldValue;
    final digits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  });
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _dialController = TextEditingController(text: '20');
  String _countryCode = '20';
  String _loadedDial = '';
  String _loadedNumber = '';
  String? _phoneError;
  DateTime? _dob;
  String _sex = 'Male';
  bool _hydrated = false;

  // Password Form
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  String? _passError;
  bool _passwordSaving = false;
  bool _passwordSaved = false;
  bool _passwordCreated = false;

  // Team Form
  final _teamEmailController = TextEditingController();
  final _teamCreditsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _dialController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _teamEmailController.dispose();
    _teamCreditsController.dispose();
    super.dispose();
  }

  void _hydrate(UserProfile p) {
    if (_hydrated) return;
    _hydrated = true;
    _nameController.text = p.name;
    final phone = splitProfilePhone(p.mobile);
    _countryCode = phoneCountries.containsKey(phone.$1) ? phone.$1 : 'custom';
    _dialController.text = phone.$1;
    _mobileController.text = phone.$2;
    _loadedDial = phone.$1;
    _loadedNumber = phone.$2;
    if (p.age != null && p.age! > 0) {
      final approxYear = DateTime.now().year - p.age!;
      _dob = DateTime(approxYear, 1, 1);
    }
    _sex = (p.sex == 'Female' || p.sex == 'Other') ? p.sex : 'Male';
  }

  int? get _computedAge {
    if (_dob == null) return null;
    final now = DateTime.now();
    int age = now.year - _dob!.year;
    if (now.month < _dob!.month ||
        (now.month == _dob!.month && now.day < _dob!.day)) {
      age--;
    }
    return age.clamp(0, 120);
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  void _saveProfile() {
    final phoneChanged =
        _dialController.text != _loadedDial ||
        _mobileController.text != _loadedNumber;
    final mobile = phoneChanged
        ? profilePhone(_dialController.text, _mobileController.text)
        : null;
    setState(
      () => _phoneError = phoneChanged && mobile == null
          ? 'Enter a valid mobile number.'
          : null,
    );
    if (phoneChanged && mobile == null) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.ui('Name is required'))));
      return;
    }
    context.read<ProfileCubit>().updateProfile(
      name: name,
      mobile: mobile,
      age: _computedAge,
      sex: _sex,
    );
  }

  Future<void> _updatePassword(bool hasPassword) async {
    if (_passwordSaving) return;
    final oldP = _oldPasswordController.text;
    final newP = _newPasswordController.text;

    setState(() {
      _passError = null;
      _passwordSaved = false;
    });

    if (newP.length < 8) {
      setState(
        () => _passError = 'Password must be at least 8 characters long.',
      );
      return;
    }
    if (hasPassword && oldP.isEmpty) {
      setState(() => _passError = 'Old password is required.');
      return;
    }

    setState(() => _passwordSaving = true);
    final cubit = context.read<ProfileCubit>();
    final success = await cubit.changePassword(
      oldPassword: hasPassword ? oldP : null,
      newPassword: newP,
    );
    if (!mounted) return;
    setState(() {
      _passwordSaving = false;
      _passwordSaved = success;
      if (success) {
        _passwordCreated = true;
        _oldPasswordController.clear();
        _newPasswordController.clear();
      } else {
        _passError =
            cubit.state.error ?? 'Password update failed. Please try again.';
      }
    });
  }

  void _addTeamMember() {
    final email = _teamEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.ui('Please enter a valid member email')),
        ),
      );
      return;
    }
    final sharedCredits = parseLocalizedInt(_teamCreditsController.text.trim());
    context.read<ProfileCubit>().addTeamMember(
      email,
      sharedCredits: sharedCredits,
    );
    _teamEmailController.clear();
    _teamCreditsController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        if (state.state == LoadState.loading && state.profile == null) {
          return LoadingView();
        }
        if (state.profile == null) {
          return ErrorView(
            message: state.error ?? 'Failed to load profile data',
            onRetry: () => context.read<ProfileCubit>().load(),
          );
        }

        final p = state.profile!;
        _hydrate(p);

        return ListView(
          padding: EdgeInsets.all(16),
          children: [
            // --- HEADER AVATAR & SUBSCRIPTION BADGE ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: p.avatarUrl,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            placeholder: (ctx, url) => Container(
                              width: 72,
                              height: 72,
                              color: Color(0xFFC47A2C),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (ctx, url, err) => Container(
                              width: 72,
                              height: 72,
                              color: Color(0xFFC47A2C),
                              child: Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            child: IconButton(
                              iconSize: 14,
                              padding: EdgeInsets.zero,
                              icon: Icon(Icons.camera_alt, color: Colors.white),
                              onPressed: () async {
                                final file = await pickImage(context);
                                if (file != null && context.mounted) {
                                  context.read<ProfileCubit>().uploadPicture(
                                    file,
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name.isNotEmpty ? p.name : 'User',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            p.email,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(0xFFC47A2C).withAlpha(30),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p.subscriptionPlan,
                                  style: TextStyle(
                                    color: Color(0xFFC47A2C),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '${p.aiCredits} ⚡ ${context.tr('credits')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // --- PERSONAL INFORMATION FORM ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline, color: Color(0xFFC47A2C)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.ui('Personal Information'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 24),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: context.ui('Name'),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _countryCode,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.ui('Country code'),
                      ),
                      items: [
                        for (final country in phoneCountries.entries)
                          DropdownMenuItem(
                            value: country.key,
                            child: Text(
                              '${Directionality.of(context) == TextDirection.rtl ? country.value.$2 : country.value.$1} (\u2066+${country.key}\u2069)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text(context.ui('Other country code')),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        _countryCode = value ?? '20';
                        _dialController.text = _countryCode == 'custom'
                            ? ''
                            : _countryCode;
                        _phoneError = null;
                      }),
                    ),
                    if (_countryCode == 'custom') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _dialController,
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          _phoneDigits,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: InputDecoration(
                          labelText: context.ui('Country code'),
                          prefixText: '+',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      inputFormatters: [
                        _phoneDigits,
                        LengthLimitingTextInputFormatter(15),
                      ],
                      onChanged: (_) => setState(() => _phoneError = null),
                      decoration: InputDecoration(
                        labelText: context.ui('Mobile Number'),
                        errorText: _phoneError == null
                            ? null
                            : context.ui(_phoneError!),
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDob,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: context.ui('Date of Birth'),
                                suffixIcon: Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                ),
                              ),
                              child: Text(
                                _dob != null
                                    ? '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')} (${_computedAge ?? 0} yrs)'
                                    : 'Select Date of Birth',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _sex,
                            decoration: InputDecoration(
                              labelText: context.ui('Gender'),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'Male',
                                child: Text(context.ui('Male')),
                              ),
                              DropdownMenuItem(
                                value: 'Female',
                                child: Text(context.ui('Female')),
                              ),
                              DropdownMenuItem(
                                value: 'Other',
                                child: Text(context.ui('Other')),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _sex = v ?? 'Male'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saveProfile,
                        style: FilledButton.styleFrom(
                          backgroundColor: Color(0xFFC47A2C),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: Icon(Icons.save),
                        label: Text(context.ui('Save Changes')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // --- PASSWORD UPDATE CARD ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_outline, color: Color(0xFFC47A2C)),
                        SizedBox(width: 8),
                        Text(
                          context.ui(
                            (p.hasPassword || _passwordCreated)
                                ? 'Update Password'
                                : 'Create Password',
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 24),
                    if (p.hasPassword || _passwordCreated) ...[
                      TextField(
                        controller: _oldPasswordController,
                        enabled: !_passwordSaving,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: context.ui('Old Password'),
                          prefixIcon: Icon(Icons.key),
                        ),
                      ),
                      SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _newPasswordController,
                      enabled: !_passwordSaving,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: context.ui('New Password'),
                        helperText: context.ui('Requirements: 8+ chars'),
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                    if (_passError != null) ...[
                      SizedBox(height: 8),
                      Text(
                        context.errorText(_passError!),
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ],
                    if (_passwordSaved)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          context.ui('Password updated successfully ✅'),
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _passwordSaving
                            ? null
                            : () => _updatePassword(
                                p.hasPassword || _passwordCreated,
                              ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: _passwordSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.shield),
                        label: Text(
                          context.ui(
                            (p.hasPassword || _passwordCreated)
                                ? 'Update Password'
                                : 'Create Password',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // --- TEAM MANAGEMENT CARD ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.group_outlined, color: Color(0xFFC47A2C)),
                        SizedBox(width: 8),
                        Text(
                          context.ui('Team Management'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 24),

                    // Team Members List
                    if (state.team.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            context.ui('No team members added yet.'),
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: state.team.length,
                        itemBuilder: (ctx, i) {
                          final m = state.team[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: m.avatarUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                placeholder: (ctx, url) => Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey[300],
                                ),
                                errorWidget: (ctx, url, err) => CircleAvatar(
                                  radius: 20,
                                  child: Text(
                                    m.name.isNotEmpty ? m.name[0] : '?',
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              m.name,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${m.email}\n${context.ui('Shared Credits')}: ${m.sharedCredits} ⚡',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => context
                                  .read<ProfileCubit>()
                                  .removeTeamMember(m.memberId),
                            ),
                          );
                        },
                      ),

                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withAlpha(50)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.ui('Add New Member'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _teamEmailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: context.ui('Member Email'),
                              isDense: true,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _teamCreditsController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.ui(
                                'Shared Credits (optional)',
                              ),
                              hintText: context.ui(
                                'Leave blank to share full balance',
                              ),
                              isDense: true,
                            ),
                          ),
                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _addTeamMember,
                              icon: Icon(Icons.person_add, size: 18),
                              label: Text(context.ui('Add Member')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================
// SUB-TAB 2: FARMS & ASSETS (CROPS & TREES)
// ==========================================
class _FarmsAndAssetsTab extends StatelessWidget {
  const _FarmsAndAssetsTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        return ListView(
          padding: EdgeInsets.all(16),
          children: [
            // FARMS SECTION
            _FarmSection(farms: state.farms, selectedFarm: state.selectedFarm),
            SizedBox(height: 20),

            // CROPS SECTION
            if (state.selectedFarm != null) ...[
              _CropSection(
                farm: state.selectedFarm!,
                crops: state.crops,
                selectedCrop: state.selectedCrop,
              ),
              SizedBox(height: 20),
            ],

            // TREES SECTION
            if (state.selectedCrop != null) ...[
              _TreeSection(crop: state.selectedCrop!, trees: state.trees),
            ],
          ],
        );
      },
    );
  }
}

class _FarmSection extends StatefulWidget {
  const _FarmSection({required this.farms, this.selectedFarm});

  final List<Farm> farms;
  final Farm? selectedFarm;

  @override
  State<_FarmSection> createState() => _FarmSectionState();
}

class _FarmSectionState extends State<_FarmSection> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _area = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _area.dispose();
    super.dispose();
  }

  void _createFarm() {
    if (_name.text.trim().isEmpty) return;
    context.read<ProfileCubit>().createFarm({
      'farm_name': _name.text.trim(),
      'address': _address.text.trim(),
      'total_area': parseLocalizedDouble(_area.text.trim()) ?? 0.0,
      'latitude': 30.0444,
      'longitude': 31.2357,
    });
    _name.clear();
    _address.clear();
    _area.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Color(0xFFC47A2C)),
                SizedBox(width: 8),
                Text(
                  context.ui('My Farms'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Divider(height: 20),

            if (widget.farms.isEmpty)
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  context.ui('No farms added yet.'),
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: widget.farms.length,
                itemBuilder: (ctx, i) {
                  final f = widget.farms[i];
                  final isSelected = widget.selectedFarm?.id == f.id;
                  return Card(
                    color: isSelected ? Color(0xFFC47A2C).withAlpha(30) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? Color(0xFFC47A2C)
                            : Colors.grey.withAlpha(40),
                      ),
                    ),
                    child: ListTile(
                      onTap: () => context.read<ProfileCubit>().selectFarm(f),
                      title: Text(
                        f.farmName,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${f.address}\n${context.ui('Area')}: ${f.totalArea} ${context.ui('Acres')}',
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => context
                            .read<ProfileCubit>()
                            .deleteEntity('Farm', f.id),
                      ),
                    ),
                  );
                },
              ),

            SizedBox(height: 12),
            ExpansionTile(
              title: Text(
                context.ui('Add New Farm'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              children: [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _name,
                        decoration: InputDecoration(
                          labelText: context.ui('Farm Name'),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _address,
                        decoration: InputDecoration(
                          labelText: context.ui('Address'),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _area,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.ui('Total Area (Acres)'),
                        ),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _createFarm,
                        icon: Icon(Icons.add),
                        label: Text(context.ui('Add Farm')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CropSection extends StatefulWidget {
  const _CropSection({
    required this.farm,
    required this.crops,
    this.selectedCrop,
  });

  final Farm farm;
  final List<Crop> crops;
  final Crop? selectedCrop;

  @override
  State<_CropSection> createState() => _CropSectionState();
}

class _CropSectionState extends State<_CropSection> {
  final _cropName = TextEditingController();
  final _area = TextEditingController();
  String _category = 'Cereal';

  @override
  void dispose() {
    _cropName.dispose();
    _area.dispose();
    super.dispose();
  }

  void _createCrop() {
    if (_cropName.text.trim().isEmpty) return;
    context.read<ProfileCubit>().createCrop({
      'crop_name': _cropName.text.trim(),
      'crop_category': _category,
      'planted_area': parseLocalizedDouble(_area.text.trim()) ?? 0.0,
      'age': 1,
      'water_consumption': 0.0,
      'health_status': 'Healthy',
      'yield_capacity': 0.0,
    });
    _cropName.clear();
    _area.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.grass, color: Color(0xFFC47A2C)),
                SizedBox(width: 8),
                Text(
                  '${context.ui('Crops in')} ${widget.farm.farmName}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Divider(height: 20),

            if (widget.crops.isEmpty)
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  context.ui('No crops registered for this farm.'),
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: widget.crops.length,
                itemBuilder: (ctx, i) {
                  final c = widget.crops[i];
                  final isSelected = widget.selectedCrop?.id == c.id;
                  return Card(
                    color: isSelected ? Color(0xFFC47A2C).withAlpha(30) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? Color(0xFFC47A2C)
                            : Colors.grey.withAlpha(40),
                      ),
                    ),
                    child: ListTile(
                      onTap: () => context.read<ProfileCubit>().selectCrop(c),
                      title: Text(
                        c.cropName,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${context.ui('Category')}: ${context.ui(c.cropCategory)} | ${context.ui('Area')}: ${c.plantedArea} Acres\n${context.ui('Health')}: ${context.ui(c.healthStatus)}',
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => context
                            .read<ProfileCubit>()
                            .deleteEntity('Crop', c.id),
                      ),
                    ),
                  );
                },
              ),

            SizedBox(height: 12),
            ExpansionTile(
              title: Text(
                context.ui('Add New Crop'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              children: [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _cropName,
                        decoration: InputDecoration(
                          labelText: context.ui('Crop Name (e.g. Wheat)'),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _area,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.ui('Planted Area'),
                        ),
                      ),
                      SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: InputDecoration(
                          labelText: context.ui('Category'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'Cereal',
                            child: Text(context.ui('Cereal')),
                          ),
                          DropdownMenuItem(
                            value: 'Fruit',
                            child: Text(context.ui('Fruit')),
                          ),
                          DropdownMenuItem(
                            value: 'Vegetable',
                            child: Text(context.ui('Vegetable')),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text(context.ui('Other')),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _category = v ?? 'Cereal'),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _createCrop,
                        icon: Icon(Icons.add),
                        label: Text(context.ui('Add Crop')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeSection extends StatefulWidget {
  const _TreeSection({required this.crop, required this.trees});

  final Crop crop;
  final List<TreeItem> trees;

  @override
  State<_TreeSection> createState() => _TreeSectionState();
}

class _TreeSectionState extends State<_TreeSection> {
  final _treeName = TextEditingController();
  final _treeCode = TextEditingController();

  @override
  void dispose() {
    _treeName.dispose();
    _treeCode.dispose();
    super.dispose();
  }

  void _createTree() {
    if (_treeName.text.trim().isEmpty) return;
    context.read<ProfileCubit>().createTree({
      'tree_name': _treeName.text.trim(),
      'tree_code': _treeCode.text.trim().isNotEmpty
          ? _treeCode.text.trim()
          : 'T-1',
      'area': 1.0,
      'latitude': 30.0444,
      'longitude': 31.2357,
      'age': 1,
      'water_consumption': 0.0,
      'health_status': 'Healthy',
      'yield_capacity': 0.0,
    });
    _treeName.clear();
    _treeCode.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.park, color: Color(0xFFC47A2C)),
                SizedBox(width: 8),
                Text(
                  '${context.ui('Trees in')} ${widget.crop.cropName}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Divider(height: 20),

            if (widget.trees.isEmpty)
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  context.ui('No trees registered for this crop.'),
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: widget.trees.length,
                itemBuilder: (ctx, i) {
                  final t = widget.trees[i];
                  return ListTile(
                    title: Text(
                      '${t.treeName} (${t.treeCode})',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${context.ui('Health')} ${t.healthStatus}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => context
                          .read<ProfileCubit>()
                          .deleteEntity('Tree', t.id),
                    ),
                  );
                },
              ),

            SizedBox(height: 12),
            ExpansionTile(
              title: Text(
                context.ui('Add New Tree'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              children: [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _treeName,
                        decoration: InputDecoration(
                          labelText: context.ui('Tree Name'),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _treeCode,
                        decoration: InputDecoration(
                          labelText: context.ui('Tree Code (e.g. TR-01)'),
                        ),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _createTree,
                        icon: Icon(Icons.add),
                        label: Text(context.ui('Add Tree')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
