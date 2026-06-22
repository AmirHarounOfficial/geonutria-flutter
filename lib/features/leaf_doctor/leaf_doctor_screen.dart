import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/data_uri_image.dart';
import '../../core/widgets/image_pick_sheet.dart';
import '../../core/widgets/picked_image.dart';
import '../ai_models/data/model_repository.dart';
import '../auth/bloc/auth_cubit.dart';
import 'leaf_doctor_cubit.dart';

/// Leaf disease detection: choose General leaf or Palm, pick/take a photo, and
/// view the diagnosis + isolated leaf image.
class LeafDoctorScreen extends StatelessWidget {
  const LeafDoctorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => LeafDoctorCubit(
        ModelRepository(ctx.read<ApiClient>()),
        ctx.read<AuthCubit>(),
      ),
      child: const _LeafView(),
    );
  }
}

class _LeafView extends StatefulWidget {
  const _LeafView();
  @override
  State<_LeafView> createState() => _LeafViewState();
}

class _LeafViewState extends State<_LeafView> {
  XFile? _file;

  Future<void> _pick() async {
    final picked = await pickImage(context);
    if (picked != null) setState(() => _file = picked);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeafDoctorCubit, LeafState>(
      builder: (context, state) {
        final busy = state.status == LeafStatus.processing;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<LeafMode>(
              segments: [
                ButtonSegment(
                    value: LeafMode.general,
                    label: Text(context.tr('leaf_general')),
                    icon: const Icon(Icons.local_florist)),
                ButtonSegment(
                    value: LeafMode.palm,
                    label: Text(context.tr('leaf_palm')),
                    icon: const Icon(Icons.park)),
              ],
              selected: {state.mode},
              onSelectionChanged: busy
                  ? null
                  : (s) => context.read<LeafDoctorCubit>().setMode(s.first),
            ),
            const SizedBox(height: 16),
            _ImageArea(file: _file, onPick: busy ? null : _pick),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: (_file == null || busy)
                  ? null
                  : () => context.read<LeafDoctorCubit>().diagnose(_file!),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.biotech),
              label: Text(
                  '${context.tr('run_diagnosis')}  ·  ${state.mode == LeafMode.palm ? 5 : 10} ⚡'),
            ),
            if (state.status == LeafStatus.failure && state.error != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: state.error!),
            ],
            if (state.result != null) ...[
              const SizedBox(height: 16),
              _ResultCard(result: state.result!),
            ],
          ],
        );
      },
    );
  }
}

class _ImageArea extends StatelessWidget {
  const _ImageArea({required this.file, required this.onPick});
  final XFile? file;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        clipBehavior: Clip.antiAlias,
        child: file == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_a_photo_outlined, size: 40),
                  SizedBox(height: 8),
                  Text('Tap to add a leaf photo'),
                ],
              )
            : PickedImage(file: file!),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final LeafResult result;

  @override
  Widget build(BuildContext context) {
    final healthy = result.diagnosis.toLowerCase().contains('healthy');
    final color = healthy ? Colors.green : Colors.orange;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.isolatedImage != null) ...[
              Center(
                child: DataUriImage(dataUri: result.isolatedImage!, height: 200),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Icon(Icons.coronavirus_outlined, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(result.diagnosis,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Confidence: ${result.confidence.toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (result.confidence / 100).clamp(0, 1),
                minHeight: 8,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
