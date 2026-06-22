import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/status_views.dart';
import '../auth/bloc/auth_cubit.dart';
import '../dashboard/bloc/history_cubit.dart' show LoadState;
import 'consultant_cubit.dart';
import 'data/consultant_models.dart';
import 'data/consultant_repository.dart';

/// Conversational AI consultant that analyzes selected farm data.
class ConsultantScreen extends StatelessWidget {
  const ConsultantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ConsultantCubit(
        ConsultantRepository(ctx.read<ApiClient>()),
        ctx.read<AuthCubit>(),
      )..loadOptions(),
      child: const _ConsultantView(),
    );
  }
}

class _ConsultantView extends StatefulWidget {
  const _ConsultantView();
  @override
  State<_ConsultantView> createState() => _ConsultantViewState();
}

class _ConsultantViewState extends State<_ConsultantView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    context.read<ConsultantCubit>().send(text);
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConsultantCubit, ConsultantState>(
      listenWhen: (a, b) => a.error != b.error && b.error != null,
      listener: (ctx, state) {
        ScaffoldMessenger.of(ctx)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.error!)));
      },
      builder: (context, state) {
        return Column(
          children: [
            _ContextPanel(state: state),
            Expanded(
              child: state.messages.isEmpty
                  ? EmptyView(
                      message:
                          'Attach farm data above, then ask the AI consultant a question.',
                      icon: Icons.smart_toy_outlined,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: state.messages.length + (state.sending ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i >= state.messages.length) {
                          return const _TypingBubble();
                        }
                        return _MessageBubble(message: state.messages[i]);
                      },
                    ),
            ),
            _InputBar(
              controller: _input,
              sending: state.sending,
              onSend: _send,
            ),
          ],
        );
      },
    );
  }
}

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({required this.state});
  final ConsultantState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ConsultantCubit>();
    final sel = cubit.selection;
    final opts = state.options;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: ExpansionTile(
        leading: const Icon(Icons.tune),
        title: const Text('Analysis context'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (state.optionsState == LoadState.loading)
            const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
          else ...[
            StatefulBuilder(
              builder: (ctx, setLocal) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include my profile'),
                    value: sel.includeUserInfo,
                    onChanged: (v) => setLocal(() => sel.includeUserInfo = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include macro weather'),
                    value: sel.includeMacroWeather,
                    onChanged: (v) => setLocal(() => sel.includeMacroWeather = v),
                  ),
                  _ChipGroup(label: 'Devices', items: opts.devices, selected: sel.deviceIds, onToggle: setLocal),
                  _ChipGroup(label: 'Leaf scans', items: opts.leafScans, selected: sel.leafScans, onToggle: setLocal),
                  _ChipGroup(label: 'Soil scans', items: opts.soilScans, selected: sel.soilScans, onToggle: setLocal),
                  _ChipGroup(label: 'Crop recs', items: opts.cropRecs, selected: sel.cropRecs, onToggle: setLocal),
                  _ChipGroup(label: 'Yield', items: opts.yieldPreds, selected: sel.yieldPreds, onToggle: setLocal),
                  _ChipGroup(label: 'Satellite', items: opts.satellites, selected: sel.satellites, onToggle: setLocal),
                  _ChipGroup(label: 'Aerial palms', items: opts.aerialPalms, selected: sel.aerialPalms, onToggle: setLocal),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.label,
    required this.items,
    required this.selected,
    required this.onToggle,
  });

  final String label;
  final List<OptionItem> items;
  final Set<int> selected;
  final void Function(VoidCallback) onToggle;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final item in items)
                FilterChip(
                  label: Text(item.name, overflow: TextOverflow.ellipsis),
                  selected: selected.contains(item.id),
                  onSelected: (v) => onToggle(() {
                    if (v) {
                      selected.add(item.id);
                    } else {
                      selected.remove(item.id);
                    }
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: isUser ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: isUser
            ? Text(message.content,
                style: TextStyle(color: scheme.onPrimary))
            : MarkdownBody(data: message.content),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 24,
          height: 16,
          child: Center(
            child: SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => sending ? null : onSend(),
                decoration: InputDecoration(
                  hintText: 'Ask about your farm…',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: sending ? null : onSend,
              child: sending
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
