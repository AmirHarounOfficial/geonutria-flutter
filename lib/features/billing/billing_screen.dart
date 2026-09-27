import 'package:geonutria_mobile/core/localization/localized_number.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/image_pick_sheet.dart';
import '../../core/widgets/picked_image.dart';
import '../auth/bloc/auth_cubit.dart';

/// Billing: shows the credit balance + complete transfer instructions and lets
/// the user upload a payment receipt for admin approval.
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  String _method = 'Vodafone Cash';
  XFile? _receipt;
  bool _submitting = false;

  static const _phone = '+20 111 611 4118';
  static const _bankName = 'National Bank of Egypt (NBE)';
  // Keep transfer details aligned with the deployed dashboard's PaymentCheckout.
  static const _accountHolder = 'GeoNutria Agricultural Solutions';
  static const _accountNumber = '1234567890123456';
  static const _iban = 'EG12 0003 0004 0000 1234 5678 901';

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.ui('Copied to clipboard'))),
      );
  }

  Future<void> _submit() async {
    final api = context.read<ApiClient>();
    final uid = context.read<AuthCubit>().state.userId;
    final amount = parseLocalizedDouble(_amount.text);
    if (uid == null || amount == null || amount <= 0 || _receipt == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.ui('Enter an amount and attach a receipt image.'),
            ),
          ),
        );
      return;
    }
    setState(() => _submitting = true);
    try {
      final bytes = await _receipt!.readAsBytes();
      await api.upload(
        '/admin/payments/upload',
        query: {
          'user_id': uid,
          'amount': amount,
          'method': _method == 'Bank Transfer'
              ? 'BankTransfer'
              : 'VodafoneCash',
          if (_reference.text.trim().isNotEmpty)
            'reference': _reference.text.trim(),
        },
        files: {
          'file': MultipartFile.fromBytes(bytes, filename: _receipt!.name),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.ui('Receipt submitted. Credits arrive after approval.'),
            ),
          ),
        );
      setState(() {
        _receipt = null;
        _amount.clear();
        _reference.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.errorText('$e'))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            children: [
              Icon(Icons.bolt, color: Colors.amber, size: 36),
              SizedBox(height: 8),
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
        SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: InputDecoration(labelText: context.ui('Payment Method')),
          items: [
            DropdownMenuItem(
              value: 'Vodafone Cash',
              child: Text(context.ui('Vodafone Cash')),
            ),
            DropdownMenuItem(
              value: 'InstaPay',
              child: Text(context.ui('InstaPay')),
            ),
            DropdownMenuItem(
              value: 'Bank Transfer',
              child: Text(context.ui('Bank Transfer')),
            ),
          ],
          onChanged: (v) => setState(() => _method = v ?? 'Vodafone Cash'),
        ),
        SizedBox(height: 12),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.ui('Beneficiary Instructions'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 8),
                if (_method == 'Bank Transfer') ...[
                  Text(
                    '${context.ui('Bank')}: ${context.ui(_bankName)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('${context.ui('Account Name')}: $_accountHolder'),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: SelectableText('IBAN: $_iban')),
                      IconButton(
                        icon: Icon(Icons.copy, size: 18),
                        onPressed: () => _copyToClipboard(_iban, 'IBAN'),
                      ),
                    ],
                  ),
                  Text('${context.ui('Account Number')}: $_accountNumber'),
                  SizedBox(height: 8),
                  Text(
                    context.ui(
                      'Include your account email or reference in the transfer notes.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  Text(
                    '${context.ui(_method)} — ${context.ui('Transfer to')}:',
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _phone,
                          textDirection: TextDirection.ltr,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.copy),
                        onPressed: () =>
                            _copyToClipboard(_phone, 'Phone number'),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    context.ui(
                      'You receive 10 credits per EGP unit once approved by an admin.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.ui('Amount paid'),
            hintText: context.ui('e.g. 100'),
          ),
        ),
        SizedBox(height: 12),
        TextField(
          controller: _reference,
          decoration: InputDecoration(
            labelText: context.ui(
              'Transfer Reference / Transaction ID (optional)',
            ),
            hintText: context.ui('e.g. TXN12345678'),
          ),
        ),
        SizedBox(height: 12),
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
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _receipt == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 36),
                        SizedBox(height: 8),
                        Text(context.ui('Attach receipt screenshot')),
                      ],
                    ),
                  )
                : PickedImage(file: _receipt!),
          ),
        ),
        SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(Icons.upload),
          label: Text(context.tr('submit')),
        ),
      ],
    );
  }
}
