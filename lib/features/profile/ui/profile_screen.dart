import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/env.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/image_pick_sheet.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/bloc/auth_cubit.dart';
import '../../dashboard/bloc/history_cubit.dart' show LoadState;
import '../bloc/assets_cubit.dart';
import '../bloc/profile_cubit.dart';
import '../data/assets_repository.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';
import 'assets_tab.dart';

/// Profile, Assets, and Team management.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (ctx) =>
              ProfileCubit(ProfileRepository(api), ctx.read<AuthCubit>())..load(),
        ),
        BlocProvider(
          create: (_) => AssetsCubit(AssetsRepository(api))..loadFarms(),
        ),
      ],
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
        final msg = state.error ?? state.message;
        if (msg != null) {
          ScaffoldMessenger.of(ctx)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(msg)));
        }
      },
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(tabs: [
              Tab(text: context.tr('tab_profile')),
              Tab(text: context.tr('tab_assets')),
              Tab(text: context.tr('tab_team')),
            ]),
            Expanded(
              child: TabBarView(
                children: const [
                  _ProfileTab(),
                  AssetsTab(),
                  _TeamTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();
  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  DateTime? _dob;
  String _sex = 'Male';
  bool _hydrated = false;
  String? _nameError;
  String? _mobileError;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    super.dispose();
  }

  void _hydrate(UserProfile p) {
    if (_hydrated) return;
    _hydrated = true;
    _name.text = p.name;
    _mobile.text = p.mobile ?? '';
    if (p.age != null && p.age! > 0) {
      final approxYear = DateTime.now().year - p.age!;
      _dob = DateTime(approxYear, 1, 1);
    }
    if (p.sex == 'Male' || p.sex == 'Female') _sex = p.sex!;
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

  void _validateName(String val) {
    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      setState(() => _nameError = 'Name is required');
    } else if (trimmed.length < 2) {
      setState(() => _nameError = 'Name must be at least 2 characters');
    } else {
      setState(() => _nameError = null);
    }
  }

  void _validateMobile(String val) {
    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      setState(() => _mobileError = null);
      return;
    }
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length < 8 || digitsOnly.length > 15) {
      setState(() => _mobileError = 'Enter a valid phone number (8-15 digits)');
    } else {
      setState(() => _mobileError = null);
    }
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
    _validateName(_name.text);
    _validateMobile(_mobile.text);
    if (_nameError != null || _mobileError != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please correct profile field errors.')),
        );
      return;
    }
    context.read<ProfileCubit>().updateProfile(
          name: _name.text.trim(),
          mobile: _mobile.text.trim(),
          age: _computedAge,
          sex: _sex,
        );
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
            message: state.error ?? context.tr('error_generic'),
            onRetry: () => context.read<ProfileCubit>().load(),
          );
        }
        final p = state.profile!;
        _hydrate(p);
        final ageLabel = _computedAge != null ? ' ($_computedAge yrs)' : '';
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: (p.picture != null && p.picture!.isNotEmpty)
                        ? CachedNetworkImageProvider(Env.resolveMedia(p.picture))
                        : null,
                    child: (p.picture == null || p.picture!.isEmpty)
                        ? const Icon(Icons.person, size: 48)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 16,
                      child: IconButton(
                        iconSize: 16,
                        icon: const Icon(Icons.camera_alt),
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
            ),
            const SizedBox(height: 8),
            Center(child: Text(p.email)),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              onChanged: _validateName,
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              onChanged: _validateMobile,
              decoration: InputDecoration(
                labelText: 'Mobile',
                errorText: _mobileError,
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
                            ? '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}$ageLabel'
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
                    ],
                    onChanged: (v) => setState(() => _sex = v ?? 'Male'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saveProfile,
              icon: const Icon(Icons.save),
              label: Text(context.tr('save')),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showPasswordDialog(context, p.hasPassword),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Change password'),
            ),
          ],
        );
      },
    );
  }

  void _showPasswordDialog(BuildContext context, bool hasPassword) {
    final oldP = TextEditingController();
    final newP = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Change password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPassword)
                  TextField(
                    controller: oldP,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Current password'),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: newP,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    helperText: 'Must be at least 6 characters long',
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    dialogError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dctx).pop(),
                child: Text(context.tr('cancel')),
              ),
              FilledButton(
                onPressed: () {
                  final newText = newP.text;
                  if (hasPassword && oldP.text.trim().isEmpty) {
                    setDialogState(() {
                      dialogError = 'Please enter your current password.';
                    });
                    return;
                  }
                  if (newText.length < 6) {
                    setDialogState(() {
                      dialogError = 'New password must be at least 6 characters long.';
                    });
                    return;
                  }
                  context.read<ProfileCubit>().changePassword(
                        oldPassword: hasPassword ? oldP.text : null,
                        newPassword: newText,
                      );
                  Navigator.of(dctx).pop();
                },
                child: Text(context.tr('save')),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TeamTab extends StatelessWidget {
  const _TeamTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        return Scaffold(
          body: state.team.isEmpty
              ? const EmptyView(
                  message: 'No team members yet.', icon: Icons.group_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.team.length,
                  itemBuilder: (ctx, i) {
                    final m = state.team[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              (m.picture != null && m.picture!.isNotEmpty)
                                  ? CachedNetworkImageProvider(
                                      Env.resolveMedia(m.picture))
                                  : null,
                          child: (m.picture == null || m.picture!.isEmpty)
                              ? Text(m.name.isNotEmpty ? m.name[0] : '?')
                              : null,
                        ),
                        title: Text(m.name),
                        subtitle: Text('${m.email}\nShared: ${m.sharedCredits} ⚡'),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: () => context
                              .read<ProfileCubit>()
                              .removeTeamMember(m.memberId),
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddDialog(context),
            icon: const Icon(Icons.person_add),
            label: const Text('Add member'),
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    final email = TextEditingController();
    final credits = TextEditingController();
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Add team member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Member email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: credits,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Credits to share (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () {
              context.read<ProfileCubit>().addTeamMember(
                    email.text.trim(),
                    sharedCredits: int.tryParse(credits.text),
                  );
              Navigator.of(dctx).pop();
            },
            child: Text(context.tr('add')),
          ),
        ],
      ),
    );
  }
}
