import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    final authCubit = context.read<AuthCubit>();

    return BlocProvider(
      create: (ctx) => ProfileCubit(
        ProfileRepository(api),
        authCubit,
      )..load(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileCubit, ProfileState>(
      listenWhen: (a, b) => a.message != b.message || a.error != b.error,
      listener: (ctx, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(ctx)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.redAccent,
            ));
        } else if (state.message != null) {
          ScaffoldMessenger.of(ctx)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.message!),
              backgroundColor: Colors.green,
            ));
        }
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.tr('tab_profile')),
            centerTitle: true,
            bottom: const TabBar(
              indicatorColor: Color(0xFFC47A2C),
              labelColor: Color(0xFFC47A2C),
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'Profile Settings'),
                Tab(text: 'Farms & Assets'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              _ProfileSettingsTab(),
              _FarmsAndAssetsTab(),
            ],
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
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  DateTime? _dob;
  String _sex = 'Male';
  bool _hydrated = false;

  // Password Form
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  String? _passError;

  // Team Form
  final _teamEmailController = TextEditingController();
  final _teamCreditsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
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
    _mobileController.text = p.mobile;
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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    context.read<ProfileCubit>().updateProfile(
          name: name,
          mobile: _mobileController.text.trim(),
          age: _computedAge,
          sex: _sex,
        );
  }

  void _updatePassword(bool hasPassword) {
    final oldP = _oldPasswordController.text.trim();
    final newP = _newPasswordController.text;

    setState(() => _passError = null);

    if (newP.length < 8) {
      setState(() => _passError =
          'Password must be at least 8 characters long.');
      return;
    }
    if (hasPassword && oldP.isEmpty) {
      setState(() => _passError = 'Old password is required.');
      return;
    }

    context.read<ProfileCubit>().changePassword(
          oldPassword: hasPassword ? oldP : null,
          newPassword: newP,
        );
    _oldPasswordController.clear();
    _newPasswordController.clear();
  }

  void _addTeamMember() {
    final email = _teamEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid member email')),
      );
      return;
    }
    final sharedCredits = int.tryParse(_teamCreditsController.text.trim());
    context.read<ProfileCubit>().addTeamMember(email, sharedCredits: sharedCredits);
    _teamEmailController.clear();
    _teamCreditsController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        if (state.state == LoadState.loading && state.profile == null) {
          return const LoadingView();
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
          padding: const EdgeInsets.all(16),
          children: [
            // --- HEADER AVATAR & SUBSCRIPTION BADGE ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                              color: const Color(0xFFC47A2C),
                              child: const Center(
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (ctx, url, err) => Container(
                              width: 72,
                              height: 72,
                              color: const Color(0xFFC47A2C),
                              child: const Icon(Icons.person, size: 40, color: Colors.white),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: IconButton(
                              iconSize: 14,
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.camera_alt, color: Colors.white),
                              onPressed: () async {
                                final file = await pickImage(context);
                                if (file != null && context.mounted) {
                                  context.read<ProfileCubit>().uploadPicture(file);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name.isNotEmpty ? p.name : 'User',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.email,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC47A2C).withAlpha(30),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p.subscriptionPlan,
                                  style: const TextStyle(
                                    color: Color(0xFFC47A2C),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${p.aiCredits} ⚡ AI Credits',
                                style: const TextStyle(
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
            const SizedBox(height: 16),

            // --- PERSONAL INFORMATION FORM ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person_outline, color: Color(0xFFC47A2C)),
                        SizedBox(width: 8),
                        Text(
                          'Personal Information',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        hintText: '+20 1XX XXX XXXX',
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDob,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date of Birth',
                                suffixIcon: Icon(Icons.calendar_today, size: 18),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _sex,
                            decoration: const InputDecoration(labelText: 'Gender'),
                            items: const [
                              DropdownMenuItem(value: 'Male', child: Text('Male')),
                              DropdownMenuItem(value: 'Female', child: Text('Female')),
                              DropdownMenuItem(value: 'Other', child: Text('Other')),
                            ],
                            onChanged: (v) => setState(() => _sex = v ?? 'Male'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saveProfile,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFC47A2C),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.save),
                        label: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- PASSWORD UPDATE CARD ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock_outline, color: Color(0xFFC47A2C)),
                        const SizedBox(width: 8),
                        Text(
                          p.hasPassword ? 'Update Password' : 'Create Password',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (p.hasPassword) ...[
                      TextField(
                        controller: _oldPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Old Password',
                          prefixIcon: Icon(Icons.key),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        helperText: 'Requirements: 8+ chars',
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                    if (_passError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _passError!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _updatePassword(p.hasPassword),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.shield),
                        label: Text(p.hasPassword ? 'Update Password' : 'Create Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- TEAM MANAGEMENT CARD ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.group_outlined, color: Color(0xFFC47A2C)),
                        SizedBox(width: 8),
                        Text(
                          'Team Management',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Team Members List
                    if (state.team.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            'No team members added yet.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
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
                                  child: Text(m.name.isNotEmpty ? m.name[0] : '?'),
                                ),
                              ),
                            ),
                            title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${m.email}\nShared Credits: ${m.sharedCredits} ⚡'),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => context.read<ProfileCubit>().removeTeamMember(m.memberId),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withAlpha(50)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add New Member',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _teamEmailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Member Email',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _teamCreditsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Shared Credits (optional)',
                              hintText: 'Leave blank to share full balance',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _addTeamMember,
                              icon: const Icon(Icons.person_add, size: 18),
                              label: const Text('Add Member'),
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
          padding: const EdgeInsets.all(16),
          children: [
            // FARMS SECTION
            _FarmSection(farms: state.farms, selectedFarm: state.selectedFarm),
            const SizedBox(height: 20),

            // CROPS SECTION
            if (state.selectedFarm != null) ...[
              _CropSection(
                farm: state.selectedFarm!,
                crops: state.crops,
                selectedCrop: state.selectedCrop,
              ),
              const SizedBox(height: 20),
            ],

            // TREES SECTION
            if (state.selectedCrop != null) ...[
              _TreeSection(
                crop: state.selectedCrop!,
                trees: state.trees,
              ),
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
      'total_area': double.tryParse(_area.text.trim()) ?? 0.0,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on, color: Color(0xFFC47A2C)),
                SizedBox(width: 8),
                Text('My Farms', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),

            if (widget.farms.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No farms added yet.', style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.farms.length,
                itemBuilder: (ctx, i) {
                  final f = widget.farms[i];
                  final isSelected = widget.selectedFarm?.id == f.id;
                  return Card(
                    color: isSelected
                        ? const Color(0xFFC47A2C).withAlpha(30)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFFC47A2C) : Colors.grey.withAlpha(40),
                      ),
                    ),
                    child: ListTile(
                      onTap: () => context.read<ProfileCubit>().selectFarm(f),
                      title: Text(f.farmName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${f.address}\nArea: ${f.totalArea} Acres'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => context.read<ProfileCubit>().deleteEntity('Farm', f.id),
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Add New Farm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Farm Name')),
                      const SizedBox(height: 8),
                      TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _area,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Total Area (Acres)'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _createFarm,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Farm'),
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
      'planted_area': double.tryParse(_area.text.trim()) ?? 0.0,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grass, color: Color(0xFFC47A2C)),
                const SizedBox(width: 8),
                Text('Crops in ${widget.farm.farmName}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),

            if (widget.crops.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No crops registered for this farm.', style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.crops.length,
                itemBuilder: (ctx, i) {
                  final c = widget.crops[i];
                  final isSelected = widget.selectedCrop?.id == c.id;
                  return Card(
                    color: isSelected ? const Color(0xFFC47A2C).withAlpha(30) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFFC47A2C) : Colors.grey.withAlpha(40),
                      ),
                    ),
                    child: ListTile(
                      onTap: () => context.read<ProfileCubit>().selectCrop(c),
                      title: Text(c.cropName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Category: ${c.cropCategory} | Area: ${c.plantedArea} Acres\nHealth: ${c.healthStatus}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => context.read<ProfileCubit>().deleteEntity('Crop', c.id),
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Add New Crop', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(controller: _cropName, decoration: const InputDecoration(labelText: 'Crop Name (e.g. Wheat)')),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _area,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Planted Area'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: const [
                          DropdownMenuItem(value: 'Cereal', child: Text('Cereal')),
                          DropdownMenuItem(value: 'Fruit', child: Text('Fruit')),
                          DropdownMenuItem(value: 'Vegetable', child: Text('Vegetable')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (v) => setState(() => _category = v ?? 'Cereal'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _createCrop,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Crop'),
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
  const _TreeSection({
    required this.crop,
    required this.trees,
  });

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
      'tree_code': _treeCode.text.trim().isNotEmpty ? _treeCode.text.trim() : 'T-1',
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.park, color: Color(0xFFC47A2C)),
                const SizedBox(width: 8),
                Text('Trees in ${widget.crop.cropName}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),

            if (widget.trees.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No trees registered for this crop.', style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.trees.length,
                itemBuilder: (ctx, i) {
                  final t = widget.trees[i];
                  return ListTile(
                    title: Text('${t.treeName} (${t.treeCode})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Health: ${t.healthStatus}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => context.read<ProfileCubit>().deleteEntity('Tree', t.id),
                    ),
                  );
                },
              ),

            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Add New Tree', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(controller: _treeName, decoration: const InputDecoration(labelText: 'Tree Name')),
                      const SizedBox(height: 8),
                      TextField(controller: _treeCode, decoration: const InputDecoration(labelText: 'Tree Code (e.g. TR-01)')),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _createTree,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Tree'),
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
