import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/paywall_notifier.dart';
import '../../core/settings/settings_cubit.dart';
import '../../core/widgets/app_logo.dart';
import '../advanced_ai/advanced_ai_screen.dart';
import '../auth/bloc/auth_cubit.dart';
import '../billing/billing_screen.dart';
import '../billing/ui/paywall_popup.dart';
import '../consultant/consultant_screen.dart';
import '../crop_advisor/crop_advisor_screen.dart';
import '../dashboard/ui/dashboard_screen.dart';
import '../leaf_doctor/leaf_doctor_screen.dart';
import '../profile/ui/profile_screen.dart';
import '../report/report_screen.dart';
import '../satellite/satellite_screen.dart';
import '../support/support_screen.dart';
import '../yield_predict/yield_screen.dart';

/// A navigable feature entry in the shell.
class _Feature {
  const _Feature(this.titleKey, this.icon, this.builder, {this.primary = false});
  final String titleKey;
  final IconData icon;
  final WidgetBuilder builder;
  final bool primary; // shown in the bottom navigation bar
}

/// Main authenticated container: a bottom navigation bar for the primary
/// features plus a drawer listing everything, mirroring the web sidebar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  PaywallNotifier? _paywall;
  bool _paywallOpen = false;

  @override
  void initState() {
    super.initState();
    _paywall = context.read<PaywallNotifier>()..addListener(_onPaywall);
  }

  @override
  void dispose() {
    _paywall?.removeListener(_onPaywall);
    super.dispose();
  }

  void _onPaywall() {
    if (_paywallOpen || !mounted) return;
    _paywallOpen = true;
    PaywallPopup.show(
      context,
      onTopUp: () {
        final billing = _features.indexWhere((f) => f.titleKey == 'nav_billing');
        if (billing >= 0) _select(billing);
      },
    ).whenComplete(() {
      _paywallOpen = false;
      // Credits may have changed; refresh the badge.
      if (mounted) context.read<AuthCubit>().refreshCredits();
    });
  }

  // Feature registry. Screens are swapped from PlaceholderScreen to the real
  // implementation as each phase lands.
  late final List<_Feature> _features = [
    _Feature('nav_dashboard', Icons.dashboard_outlined,
        (c) => const DashboardScreen(),
        primary: true),
    _Feature('nav_leaf_doctor', Icons.local_florist_outlined,
        (c) => const LeafDoctorScreen(),
        primary: true),
    _Feature('nav_satellite', Icons.satellite_alt_outlined,
        (c) => const SatelliteScreen(),
        primary: true),
    _Feature('nav_consultant', Icons.smart_toy_outlined,
        (c) => const ConsultantScreen(),
        primary: true),
    _Feature('nav_crop_advisor', Icons.grass_outlined,
        (c) => const CropAdvisorScreen()),
    _Feature('nav_yield', Icons.analytics_outlined,
        (c) => const YieldScreen()),
    _Feature('nav_advanced_ai', Icons.auto_awesome_outlined,
        (c) => const AdvancedAiScreen()),
    _Feature('nav_profile', Icons.person_outline,
        (c) => const ProfileScreen()),
    _Feature('nav_billing', Icons.credit_card_outlined,
        (c) => const BillingScreen()),
    _Feature('nav_report', Icons.picture_as_pdf_outlined,
        (c) => const ReportScreen()),
    _Feature('nav_support', Icons.support_agent_outlined,
        (c) => const SupportScreen()),
  ];

  List<int> get _primaryIndexes => [
        for (var i = 0; i < _features.length; i++)
          if (_features[i].primary) i,
      ];

  void _select(int featureIndex) {
    setState(() => _index = featureIndex);
  }

  @override
  Widget build(BuildContext context) {
    final feature = _features[_index];
    final primaryIdx = _primaryIndexes;
    final selectedBottom = primaryIdx.indexOf(_index);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(feature.titleKey)),
        actions: const [_CreditsBadge(), SizedBox(width: 8)],
      ),
      drawer: _AppDrawer(
        features: _features,
        selected: _index,
        onSelect: (i) {
          Navigator.of(context).pop();
          _select(i);
        },
      ),
      body: IndexedStack(
        index: _index,
        children: [for (final f in _features) Builder(builder: f.builder)],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedBottom < 0 ? 0 : selectedBottom,
        onDestinationSelected: (i) => _select(primaryIdx[i]),
        destinations: [
          for (final i in primaryIdx)
            NavigationDestination(
              icon: Icon(_features[i].icon),
              label: context.tr(_features[i].titleKey),
            ),
        ],
      ),
    );
  }
}

class _CreditsBadge extends StatelessWidget {
  const _CreditsBadge();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (a, b) => a.aiCredits != b.aiCredits,
      builder: (ctx, state) {
        return Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: ActionChip(
              avatar: const Icon(Icons.bolt, size: 18),
              label: Text('${state.aiCredits}'),
              onPressed: () => ctx.read<AuthCubit>().refreshCredits(),
            ),
          ),
        );
      },
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.features,
    required this.selected,
    required this.onSelect,
  });

  final List<_Feature> features;
  final int selected;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: selected,
      onDestinationSelected: onSelect,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const AppLogo(size: 44),
              const SizedBox(width: 12),
              Text(
                context.tr('app_name'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final f in features)
          NavigationDrawerDestination(
            icon: Icon(f.icon),
            label: Text(context.tr(f.titleKey)),
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(context.tr('language')),
                trailing: Text(
                  context.locale.languageCode == 'ar' ? 'العربية' : 'EN',
                ),
                onTap: () => context.read<SettingsCubit>().toggleLocale(),
              ),
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: Text(context.tr('theme')),
                onTap: () => context.read<SettingsCubit>().toggleTheme(),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(context.tr('logout')),
                onTap: () => context.read<AuthCubit>().logout(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
