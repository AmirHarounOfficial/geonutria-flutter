import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/map_location_picker.dart';
import '../bloc/auth_cubit.dart';
import '../bloc/register_cubit.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import 'otp_screen.dart';

/// 3-step sign-up wizard mirroring the web `OnboardingWizard`:
/// 1) identity, 2) entity/age/gender, 3) optional farms (crops, trees, map).
/// Used both for standard registration and for completing a Google sign-up
/// ([googleOnboarding] != null).
class OnboardingWizard extends StatelessWidget {
  const OnboardingWizard({super.key, this.googleOnboarding});

  final GoogleOnboarding? googleOnboarding;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => RegisterCubit(ctx.read<AuthRepository>()),
      child: _WizardView(googleOnboarding: googleOnboarding),
    );
  }
}

class _WizardView extends StatefulWidget {
  const _WizardView({this.googleOnboarding});
  final GoogleOnboarding? googleOnboarding;

  @override
  State<_WizardView> createState() => _WizardViewState();
}

class _WizardViewState extends State<_WizardView> {
  int _step = 0;
  bool get _isGoogle => widget.googleOnboarding != null;

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _companyName = TextEditingController();
  final _age = TextEditingController(text: '30');

  String _entityType = 'Individual';
  String _gender = 'Male';

  final List<_FarmDraft> _farms = [_FarmDraft()];

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final g = widget.googleOnboarding;
    if (g != null) {
      _firstName.text = g.givenName;
      _lastName.text = g.familyName;
      _email.text = g.email;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _firstName,
      _lastName,
      _email,
      _password,
      _phone,
      _address,
      _companyName,
      _age,
    ]) {
      c.dispose();
    }
    for (final f in _farms) {
      f.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (_step == 0 && !(_step1Key.currentState?.validate() ?? false)) return;
    if (_step == 1 && !(_step2Key.currentState?.validate() ?? false)) return;
    setState(() => _step = (_step + 1).clamp(0, 2));
  }

  void _back() => setState(() => _step = (_step - 1).clamp(0, 2));

  RegistrationData _buildData() {
    final farms = _farms
        .map((f) => f.toJson())
        .where((j) => j != null)
        .cast<Map<String, dynamic>>()
        .toList();
    return RegistrationData(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      phoneNumber: _phone.text.trim(),
      address: _address.text.trim(),
      age: int.tryParse(_age.text) ?? 0,
      gender: _gender,
      entityType: _entityType,
      companyName: _entityType == 'Company' ? _companyName.text.trim() : null,
      farms: farms.isEmpty ? null : farms,
    );
  }

  void _submit() {
    final cubit = context.read<RegisterCubit>();
    final data = _buildData();
    if (_isGoogle) {
      cubit.googleRegister(widget.googleOnboarding!.googleToken, data);
    } else {
      cubit.register(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isGoogle ? 'Complete profile' : context.tr('create_account'),
        ),
      ),
      body: BlocConsumer<RegisterCubit, RegisterState>(
        listener: (ctx, state) async {
          if (state.status == RegisterStatus.awaitingOtp && !_isGoogle) {
            // Move to OTP verification, sharing the same cubit.
            final cubit = ctx.read<RegisterCubit>();
            await Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (_) =>
                    BlocProvider.value(value: cubit, child: OtpScreen()),
              ),
            );
          } else if (state.status == RegisterStatus.success &&
              state.result != null) {
            ctx.read<AuthCubit>().onAuthenticated(state.result!);
          } else if (state.status == RegisterStatus.failure &&
              state.error != null) {
            ScaffoldMessenger.of(ctx)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(context.errorText(state.error!))),
              );
          }
        },
        builder: (ctx, state) {
          final busy = state.status == RegisterStatus.submitting;
          return Column(
            children: [
              _ProgressBar(step: _step),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: switch (_step) {
                    0 => _stepIdentity(),
                    1 => _stepEntity(),
                    _ => _stepFarms(),
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (_step > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy ? null : _back,
                            child: Text(
                              context.tr('cancel') == 'Cancel'
                                  ? 'Back'
                                  : 'رجوع',
                            ),
                          ),
                        ),
                      if (_step > 0) SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: busy
                              ? null
                              : (_step < 2 ? _next : _submit),
                          child: busy
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  context.ui(
                                    _step < 2 ? 'Next' : 'Complete setup',
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stepIdentity() {
    return Form(
      key: _step1Key,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstName,
                  decoration: InputDecoration(
                    labelText: context.tr('first_name'),
                  ),
                  validator: _required,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastName,
                  decoration: InputDecoration(
                    labelText: context.tr('last_name'),
                  ),
                  validator: _required,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _email,
            readOnly: _isGoogle,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: context.tr('email')),
            validator: _required,
          ),
          if (!_isGoogle) ...[
            SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: context.tr('password')),
              validator: (v) =>
                  (v == null || v.length < 6) ? '≥ 6 characters' : null,
            ),
          ],
          SizedBox(height: 16),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: context.tr('phone_number')),
            validator: _required,
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _address,
            decoration: InputDecoration(labelText: context.tr('address')),
            validator: _required,
          ),
        ],
      ),
    );
  }

  Widget _stepEntity() {
    return Form(
      key: _step2Key,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _entityType,
            decoration: InputDecoration(labelText: context.ui('Entity type')),
            items: [
              DropdownMenuItem(
                value: 'Individual',
                child: Text(context.ui('Individual')),
              ),
              DropdownMenuItem(
                value: 'Company',
                child: Text(context.ui('Company')),
              ),
            ],
            onChanged: (v) => setState(() => _entityType = v ?? 'Individual'),
          ),
          if (_entityType == 'Company') ...[
            SizedBox(height: 16),
            TextFormField(
              controller: _companyName,
              decoration: InputDecoration(
                labelText: context.ui('Company name'),
              ),
              validator: _required,
            ),
          ],
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: context.ui('Age')),
                  validator: _required,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: InputDecoration(labelText: context.ui('Gender')),
                  items: [
                    DropdownMenuItem(
                      value: 'Male',
                      child: Text(context.ui('Male')),
                    ),
                    DropdownMenuItem(
                      value: 'Female',
                      child: Text(context.ui('Female')),
                    ),
                  ],
                  onChanged: (v) => setState(() => _gender = v ?? 'Male'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepFarms() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.ui('Farms & locations (optional)'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        SizedBox(height: 12),
        for (var i = 0; i < _farms.length; i++)
          _FarmEditor(
            farm: _farms[i],
            index: i,
            canRemove: _farms.length > 1,
            onRemove: () => setState(() => _farms.removeAt(i)),
            onChanged: () => setState(() {}),
          ),
        SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() => _farms.add(_FarmDraft())),
          icon: Icon(Icons.add),
          label: Text(context.ui('Add another farm')),
        ),
      ],
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? context.tr('required_field') : null;
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: step >= i
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- Farm editor + draft models ---

class _FarmEditor extends StatelessWidget {
  const _FarmEditor({
    required this.farm,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  final _FarmDraft farm;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${context.ui('Farm')} ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (canRemove)
                  IconButton(
                    icon: Icon(Icons.delete_outline),
                    onPressed: onRemove,
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: farm.name,
                    decoration: InputDecoration(
                      labelText: context.ui('Farm name'),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: farm.area,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.ui('Area (Ha)'),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            MapLocationPicker(
              label: 'Farm location',
              latitude: farm.lat,
              longitude: farm.lon,
              onChanged: (lat, lon) {
                farm.lat = lat;
                farm.lon = lon;
                onChanged();
              },
            ),
            SizedBox(height: 12),
            Text(
              context.ui('Crops'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            for (var i = 0; i < farm.crops.length; i++)
              _CropEditor(
                crop: farm.crops[i],
                onRemove: farm.crops.length > 1
                    ? () => _removeCrop(i, context)
                    : null,
                onChanged: onChanged,
              ),
            TextButton.icon(
              onPressed: () {
                farm.crops.add(_CropDraft());
                onChanged();
              },
              icon: Icon(Icons.add, size: 18),
              label: Text(context.ui('Add crop')),
            ),
          ],
        ),
      ),
    );
  }

  void _removeCrop(int i, BuildContext context) {
    farm.crops.removeAt(i);
    onChanged();
  }
}

class _CropEditor extends StatelessWidget {
  const _CropEditor({
    required this.crop,
    required this.onChanged,
    this.onRemove,
  });

  final _CropDraft crop;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: crop.name,
                  decoration: InputDecoration(
                    labelText: context.ui('Crop name'),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: crop.area,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: context.ui('Area')),
                ),
              ),
              if (onRemove != null)
                IconButton(icon: Icon(Icons.close), onPressed: onRemove),
            ],
          ),
          Row(
            children: [
              Checkbox(
                value: crop.isTree,
                onChanged: (v) {
                  crop.isTree = v ?? false;
                  onChanged();
                },
              ),
              Expanded(child: Text(context.ui('Tree / palm crop?'))),
            ],
          ),
          if (crop.isTree)
            Padding(
              padding: EdgeInsetsDirectional.only(start: 12),
              child: Column(
                children: [
                  for (var i = 0; i < crop.trees.length; i++)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: crop.trees[i].name,
                            decoration: InputDecoration(
                              labelText: context.ui('Tree name'),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: crop.trees[i].code,
                            decoration: InputDecoration(
                              labelText: context.ui('Code'),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () {
                            crop.trees.removeAt(i);
                            onChanged();
                          },
                        ),
                      ],
                    ),
                  TextButton.icon(
                    onPressed: () {
                      crop.trees.add(_TreeDraft());
                      onChanged();
                    },
                    icon: Icon(Icons.add, size: 16),
                    label: Text(context.ui('Add tree')),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FarmDraft {
  final name = TextEditingController();
  final area = TextEditingController();
  double? lat;
  double? lon;
  final List<_CropDraft> crops = [_CropDraft()];

  Map<String, dynamic>? toJson() {
    final hasName = name.text.trim().isNotEmpty;
    if (!hasName && lat == null) return null; // skip empty farm
    final crops = this.crops
        .where((c) => c.name.text.trim().isNotEmpty)
        .map((c) => c.toJson())
        .toList();
    return {
      'farm_name': name.text.trim(),
      'area': double.tryParse(area.text) ?? 0.0,
      'latitude': lat,
      'longitude': lon,
      'crops': crops,
    };
  }

  void dispose() {
    name.dispose();
    area.dispose();
    for (final c in crops) {
      c.dispose();
    }
  }
}

class _CropDraft {
  final name = TextEditingController();
  final area = TextEditingController();
  bool isTree = false;
  final List<_TreeDraft> trees = [];

  Map<String, dynamic> toJson() => {
    'crop_name': name.text.trim(),
    'planted_area': double.tryParse(area.text) ?? 0.0,
    'is_tree': isTree,
    'trees': isTree
        ? trees
              .where((t) => t.name.text.trim().isNotEmpty)
              .map((t) => t.toJson())
              .toList()
        : <Map<String, dynamic>>[],
  };

  void dispose() {
    name.dispose();
    area.dispose();
    for (final t in trees) {
      t.dispose();
    }
  }
}

class _TreeDraft {
  final name = TextEditingController();
  final code = TextEditingController();

  Map<String, dynamic> toJson() => {
    'tree_name': name.text.trim(),
    'tree_code': code.text.trim(),
  };

  void dispose() {
    name.dispose();
    code.dispose();
  }
}
