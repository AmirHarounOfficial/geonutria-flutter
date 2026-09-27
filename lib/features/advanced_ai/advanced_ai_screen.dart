import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/data_uri_image.dart';
import '../../core/widgets/image_pick_sheet.dart';
import '../../core/widgets/picked_image.dart';
import 'advanced_ai_cubit.dart';

/// Free-form streaming AI chat (cloud Nemotron via `/v1/openrouter-chat`).
class AdvancedAiScreen extends StatelessWidget {
  const AdvancedAiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(context.locale.languageCode),
      create: (ctx) => AdvancedAiCubit(ctx.read<ApiClient>()),
      child: const _AdvancedAiView(),
    );
  }
}

class _AdvancedAiView extends StatefulWidget {
  const _AdvancedAiView();
  @override
  State<_AdvancedAiView> createState() => _AdvancedAiViewState();
}

class _AdvancedAiViewState extends State<_AdvancedAiView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  XFile? _attached;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _attach() async {
    final file = await pickImage(context);
    if (file != null) setState(() => _attached = file);
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty && _attached == null) return;
    // The server picks its system prompt — and the language it answers in —
    // from this, so it has to follow the app's locale.
    context.read<AdvancedAiCubit>().send(
      text,
      image: _attached,
      lang: context.locale.languageCode == 'ar' ? 'ar' : 'en',
    );
    _input.clear();
    setState(() => _attached = null);
  }

  void _sendPreset(String text, {String? prefix}) {
    final prompt = prefix != null ? '$prefix\n\n$text' : text;
    context.read<AdvancedAiCubit>().send(
      prompt,
      image: null,
      lang: context.locale.languageCode == 'ar' ? 'ar' : 'en',
    );
  }

  void _showHistorySheet(BuildContext context) {
    final cubit = context.read<AdvancedAiCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bctx) {
        return BlocProvider.value(
          value: cubit,
          child: BlocBuilder<AdvancedAiCubit, AdvancedAiState>(
            builder: (ctx, state) {
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.ui('Conversation History'),
                            style: Theme.of(ctx).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              cubit.newChat();
                              Navigator.pop(bctx);
                            },
                            icon: Icon(Icons.add),
                            label: Text(context.ui('New Chat')),
                          ),
                        ],
                      ),
                      Divider(),
                      if (state.sessions.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              context.ui('No previous conversations yet.'),
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: state.sessions.length,
                            separatorBuilder: (_, _) => Divider(height: 1),
                            itemBuilder: (lctx, i) {
                              final s = state.sessions[i];
                              final isCurrent = s.id == state.currentSessionId;
                              return ListTile(
                                leading: Icon(
                                  Icons.chat_bubble_outline,
                                  color: isCurrent ? Color(0xFFC47A2C) : null,
                                ),
                                title: Text(
                                  s.preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  '${s.updatedAt.month}/${s.updatedAt.day} ${s.updatedAt.hour}:${s.updatedAt.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(fontSize: 11),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete_outline, size: 18),
                                  onPressed: () {
                                    cubit.deleteSession(s.id);
                                  },
                                ),
                                onTap: () {
                                  cubit.selectSession(s.id);
                                  Navigator.pop(bctx);
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = context.locale.languageCode == 'ar';

    return BlocConsumer<AdvancedAiCubit, AdvancedAiState>(
      listener: (ctx, state) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      },
      builder: (context, state) {
        return Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showHistorySheet(context),
                    icon: Icon(Icons.history, size: 18),
                    label: Text(
                      '${context.ui('History')} ${state.sessions.length})',
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 5),
                        Text(
                          isAr ? 'متصل' : 'Online',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => context.read<AdvancedAiCubit>().newChat(),
                    icon: Icon(Icons.add, size: 16),
                    label: Text(isAr ? 'محادثة جديدة' : 'New Chat'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.turns.isEmpty
                  ? _WelcomeHero(onSelectPrompt: _sendPreset)
                  : ListView.builder(
                      controller: _scroll,
                      padding: EdgeInsets.all(16),
                      itemCount: state.turns.length,
                      itemBuilder: (ctx, i) => _Bubble(turn: state.turns[i]),
                    ),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_attached != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                height: 72,
                                width: 72,
                                child: PickedImage(file: _attached!),
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: IconButton(
                                icon: Icon(Icons.cancel, size: 20),
                                onPressed: () =>
                                    setState(() => _attached = null),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: context.ui('Attach image'),
                          onPressed: state.streaming ? null : _attach,
                          icon: Icon(Icons.add_photo_alternate_outlined),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            onSubmitted: (_) =>
                                state.streaming ? null : _send(),
                            decoration: InputDecoration(
                              hintText: isAr
                                  ? 'اسأل المستشار الذكي عن أي محصول…'
                                  : 'Ask the agricultural consultant anything…',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        if (state.streaming)
                          IconButton.filledTonal(
                            tooltip: context.ui('Stop response'),
                            onPressed: () =>
                                context.read<AdvancedAiCubit>().stop(),
                            icon: Icon(Icons.stop_rounded, color: Colors.red),
                          )
                        else
                          FloatingActionButton.small(
                            onPressed: _send,
                            child: Icon(Icons.send),
                          ),
                      ],
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});
  final AiTurn turn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isUser = turn.isUser;

    return Align(
      alignment: isUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // The model's working, above its answer and collapsed by default.
            if (!isUser && turn.hasThinking) _ThinkingPanel(turn: turn),
            Container(
              margin: EdgeInsets.symmetric(vertical: 6),
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: isUser
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (turn.imageDataUrl != null) ...[
                          DataUriImage(
                            dataUri: turn.imageDataUrl!,
                            height: 160,
                          ),
                          if (turn.content.isNotEmpty) SizedBox(height: 6),
                        ],
                        if (turn.content.isNotEmpty)
                          Text(
                            turn.content,
                            style: TextStyle(color: scheme.onPrimary),
                          ),
                      ],
                    )
                  : (turn.content.isEmpty
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                context.ui(
                                  turn.isThinking ? 'Thinking…' : 'Working…',
                                ),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          )
                        : MarkdownBody(
                            data: turn.content,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet.fromTheme(theme)
                                .copyWith(
                                  p: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.5,
                                    color: isUser
                                        ? scheme.onPrimary
                                        : scheme.onSurface,
                                  ),
                                  tableBorder: TableBorder.all(
                                    color: scheme.outlineVariant.withValues(
                                      alpha: 0.5,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  tableHead: theme.textTheme.labelMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: scheme.primary,
                                      ),
                                  tableBody: theme.textTheme.bodySmall
                                      ?.copyWith(height: 1.4),
                                  code: TextStyle(
                                    backgroundColor:
                                        scheme.surfaceContainerHighest,
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                          )),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rich welcome hero with quick agricultural consultation starters.
class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.onSelectPrompt});
  final void Function(String text, {String? prefix}) onSelectPrompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = context.locale.languageCode == 'ar';

    final prompts = [
      (
        icon: Icons.verified_outlined,
        title: isAr ? 'معايير التصدير الأوروبية' : 'European Export Compliance',
        desc: isAr
            ? 'تقييم توافق المحصول ومتبقيات المبيدات مع المعايير الأوروبية.'
            : 'Evaluate crop quality and pesticide MRLs against EU standards.',
        prefix:
            '[SYSTEM INSTRUCTION: Focus response on European Export Compliance standards]',
      ),
      (
        icon: Icons.biotech_outlined,
        title: isAr ? 'تشخيص المحصول المتعمق' : 'Deep-Dive Diagnosis',
        desc: isAr
            ? 'تحليل الأعراض ونقص العناصر والمشاكل الفسيولوجية للنبات.'
            : 'Detailed analysis of plant stress, nutrient deficiency, and pathology.',
        prefix: '[SYSTEM INSTRUCTION: Perform a deep-dive diagnosis]',
      ),
      (
        icon: Icons.science_outlined,
        title: isAr ? 'برنامج التسميد NPK' : 'NPK Fertilization Plan',
        desc: isAr
            ? 'حساب معدلات النيتروجين والفوسفور والبوتاسيوم لمراحل النمو.'
            : 'Calculate NPK rates and micronutrient blends tailored to growth stage.',
        prefix:
            '[SYSTEM INSTRUCTION: Provide a comprehensive NPK and micronutrient schedule]',
      ),
      (
        icon: Icons.water_drop_outlined,
        title: isAr ? 'جدولة الري والاحتياجات' : 'Irrigation Scheduling',
        desc: isAr
            ? 'تحديد المقننات المائية وفترات الري المثلى وفق التربة والطقس.'
            : 'Determine optimal irrigation intervals and water volumes based on soil & weather.',
        prefix:
            '[SYSTEM INSTRUCTION: Formulate a precise irrigation volume and schedule]',
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFC47A2C), Color(0xFF6B8F71)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFC47A2C).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Icon(Icons.eco_rounded, size: 36, color: Colors.white),
          ),
          SizedBox(height: 16),
          Text(
            isAr ? 'مرحبًا بك في GeoNutria AI' : 'Welcome to GeoNutria AI',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            isAr
                ? 'مستشارك الزراعي الذكي المتقدم للإجابة عن استفسارات المحاصيل، التسميد، تشخيص الآفات وجداول الري.'
                : 'Your senior agricultural engineer consultant powered by advanced AI reasoning. Ask about crop nutrition, disease diagnosis, fertilization, or export standards.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          SizedBox(height: 24),
          Align(
            alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              isAr ? 'مقترحات سريعة للبدء' : 'Suggested Consultations',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 10),
          for (final p in prompts)
            Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelectPrompt(p.desc, prefix: p.prefix),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            p.icon,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                p.desc,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          isAr
                              ? Icons.arrow_back_ios_new
                              : Icons.arrow_forward_ios,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Collapsible view of the model's chain of thought.
class _ThinkingPanel extends StatelessWidget {
  const _ThinkingPanel({required this.turn});
  final AiTurn turn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final live = turn.isThinking;

    return Container(
      margin: EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Theme(
        // Hide the divider lines an ExpansionTile draws by default.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: live,
          tilePadding: EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            Icons.psychology_outlined,
            size: 18,
            color: theme.colorScheme.outline,
          ),
          title: Text(
            live ? context.tr('analysis_thinking') : context.tr('reasoning'),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                turn.thinking.trim(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
