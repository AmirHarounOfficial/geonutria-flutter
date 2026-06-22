import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';

/// Shown when the backend reports out-of-credits (HTTP 402). Mirrors the web
/// PaywallPopup: explains the situation and routes to the billing screen.
class PaywallPopup extends StatelessWidget {
  const PaywallPopup({super.key, required this.onTopUp});

  final VoidCallback onTopUp;

  static Future<void> show(BuildContext context, {required VoidCallback onTopUp}) {
    return showDialog(
      context: context,
      builder: (_) => PaywallPopup(onTopUp: onTopUp),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.bolt, color: Colors.amber, size: 40),
      title: Text(context.tr('paywall_title')),
      content: Text(context.tr('paywall_body')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('close')),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onTopUp();
          },
          child: Text(context.tr('top_up')),
        ),
      ],
    );
  }
}
