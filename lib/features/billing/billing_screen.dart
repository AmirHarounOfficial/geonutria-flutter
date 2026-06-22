import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/image_pick_sheet.dart';
import '../../core/widgets/picked_image.dart';
import '../auth/bloc/auth_cubit.dart';

/// Billing: shows the credit balance + transfer instructions and lets the user
/// upload a payment receipt for admin approval (`POST /admin/payments/upload`).
/// Credits are granted as amount × 10 once an admin approves.
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final _amount = TextEditingController();
  String _method = 'Vodafone Cash';
  XFile? _receipt;
  bool _submitting = false;

  static const _phone = '+20 111 611 4118';

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final api = context.read<ApiClient>();
    final uid = context.read<AuthCubit>().state.userId;
    final amount = double.tryParse(_amount.text);
    if (uid == null || amount == null || amount <= 0 || _receipt == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Enter an amount and attach a receipt image.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final bytes = await _receipt!.readAsBytes();
      await api.upload(
        '/admin/payments/upload',
        query: {'user_id': uid, 'amount': amount, 'method': _method},
        files: {'file': MultipartFile.fromBytes(bytes, filename: _receipt!.name)},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Receipt submitted. Credits arrive after approval.')));
      setState(() {
        _receipt = null;
        _amount.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            children: [
              const Icon(Icons.bolt, color: Colors.amber, size: 36),
              const SizedBox(height: 8),
              BlocBuilder<AuthCubit, AuthState>(
                buildWhen: (a, b) => a.aiCredits != b.aiCredits,
                builder: (ctx, state) => Text(
                  '${state.aiCredits} ${ctx.tr('credits')}',
                  style: Theme.of(ctx).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How to top up',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                    'Transfer via Vodafone Cash or InstaPay to $_phone, then upload your receipt below. You receive 10 credits per unit once approved.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount paid'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: const InputDecoration(labelText: 'Payment method'),
          items: const [
            DropdownMenuItem(value: 'Vodafone Cash', child: Text('Vodafone Cash')),
            DropdownMenuItem(value: 'InstaPay', child: Text('InstaPay')),
            DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
          ],
          onChanged: (v) => setState(() => _method = v ?? 'Vodafone Cash'),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final f = await pickImage(context);
            if (f != null) setState(() => _receipt = f);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: _receipt == null
                ? const Center(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 36),
                      SizedBox(height: 8),
                      Text('Attach receipt screenshot'),
                    ],
                  ))
                : PickedImage(file: _receipt!),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.upload),
          label: Text(context.tr('submit')),
        ),
      ],
    );
  }
}
