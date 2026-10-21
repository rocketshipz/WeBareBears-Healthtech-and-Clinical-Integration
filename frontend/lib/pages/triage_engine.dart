import 'dart:math' as math;

import '../localization.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/triage_chat_service.dart';
import '../theme.dart';
import 'triage_report.dart';

// Screen-local colours. Body text is a touch darker than AppColors.grey so long
// bot messages and option details stay easy to read on white.
const Color _bodyText = Color(0xFF42575A);
const Color _mutedText = Color(0xFF556668);
const Color _hintText = Color(0xFF6F7F81);
const Color _selectedFill = Color(0xFFE8F7F6);
const Color _uncheckedBox = Color(0xFFA5B2B2);
const Color _softBorder = Color(0xFFD3E6E5);

const BorderRadius _botRadius = BorderRadius.only(
  topLeft: Radius.circular(20),
  topRight: Radius.circular(20),
  bottomRight: Radius.circular(20),
  bottomLeft: Radius.circular(6),
);
const BorderRadius _userRadius = BorderRadius.only(
  topLeft: Radius.circular(20),
  topRight: Radius.circular(20),
  bottomLeft: Radius.circular(20),
  bottomRight: Radius.circular(6),
);

class _ChatMessage {
  final String text;
  final bool fromUser;
  final DateTime time;
  _ChatMessage(this.text, {required this.fromUser, DateTime? time})
      : time = time ?? DateTime.now();
}

class TriagePage extends StatefulWidget {
  const TriagePage({super.key});

  @override
  State<TriagePage> createState() => _TriagePageState();
}

class _TriagePageState extends State<TriagePage> {
  /// Selection lists up to this size render as buttons, longer ones as a dropdown.
  static const int _maxButtonOptions = 4;

  /// Step bar: segments shown before the backend's estimate arrives, the most
  /// segments drawn (a longer screening shows one continuous bar), and the
  /// rough time one question takes, for "about N min".
  static const int _defaultSegments = 6;
  static const int _maxSegments = 12;
  static const int _secondsPerQuestion = 20;

  /// Typed in front of the answer when "Change" on the profile card is tapped.
  static const String _someoneElsePrefix = 'This is for my ';

  final List<_ChatMessage> _messages = [_greeting()];

  static _ChatMessage _greeting() => _ChatMessage(
        'Hi, I will ask a few questions to understand your condition. '
        'What is the main problem you are experiencing?',
        fromUser: false,
      );

  /// The backend applies the account owner's saved health profile unless told
  /// the screening is for someone else. The card at the top of the chat names
  /// the logged-in user, so it is clear whose profile is in use.
  static String _ownerName() =>
      (AuthService.currentUser?['name'] as String?)?.trim() ?? '';

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFocus = FocusNode();
  final FocusNode _noteFocus = FocusNode();

  String? _sessionId;
  String? _firstComplaint; // fallback only: the user's first message
  String? _chiefComplaint; // the main problem, as identified by the backend
  String? _mainSymptom; // its short summary, written once there is a result
  String? _lastSent;
  List<String>? _lastSelected;
  String? _lastNote;
  TriageChatReply? _current; // null until the first reply = free-text prompt
  // Step 1 is the opening "main problem" question.
  TriageProgress _progress = const TriageProgress(step: 1);
  String? _dropdownValue;
  final Set<String> _checked = {}; // ticked options of a multi-select question
  bool _loading = false;
  // Options panel slid down to a slim bar, so the chat can use the screen.
  // Starts collapsed for every question; the user taps the bar to answer.
  bool _panelCollapsed = true;
  String? _error;

  /// Bumped on restart so a reply to the old session is ignored.
  int _generation = 0;

  @override
  void dispose() {
    _textController.dispose();
    _noteController.dispose();
    _scrollController.dispose();
    _textFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  bool get _isSelection => _current?.isSelection ?? false;

  /// [selected]: the option(s) picked from the current selection, sent so the
  /// backend can record them exactly. [note]: extra details typed under the
  /// options (defaults to the note box when options were picked).
  Future<void> _send(String message, {List<String>? selected, String? note}) async {
    final text = message.trim();
    if (text.isEmpty || _loading) return;
    note = (note ?? (selected != null ? _noteController.text : '')).trim();
    final generation = _generation;

    setState(() {
      _messages.add(
        _ChatMessage(note!.isEmpty ? text : '$text\n$note', fromUser: true),
      );
      _firstComplaint ??= text;
      _lastSent = text;
      _lastSelected = selected;
      _lastNote = note;
      _textController.clear();
      _noteController.clear();
      _dropdownValue = null;
      _checked.clear();
      _panelCollapsed = true;
      _loading = true;
      _error = null;
    });
    _scrollToEnd();

    try {
      final reply = await TriageChatService.sendMessage(
        text,
        sessionId: _sessionId,
        selectedOptions: selected,
        note: note.isEmpty ? null : note,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _sessionId = reply.sessionId ?? _sessionId;
        _chiefComplaint = reply.chiefComplaint ?? _chiefComplaint;
        _mainSymptom = reply.mainSymptom ?? _mainSymptom;
        _current = reply;
        _panelCollapsed = true; // a new question starts hidden until tapped
        _progress = reply.progress ?? _progress;
        _loading = false;
        _messages.add(_ChatMessage(reply.text, fromUser: false));
        // Pre-select what the user already mentioned; they still confirm it.
        final suggested = reply.suggestedOptions
            .where(reply.options.contains)
            .toList();
        if (reply.multiSelect) {
          _checked.addAll(suggested);
        } else if (suggested.isNotEmpty &&
            reply.options.length > _maxButtonOptions) {
          _dropdownValue = suggested.first;
        }
      });
      _scrollToEnd();
      if (reply.assessment != null) _openReport(reply);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the triage service. Please try again.';
      });
    }
  }

  void _openReport(TriageChatReply reply) {
    final a = reply.assessment!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TriageReportPage(
          storedReportId: reply.reportId,
          forSomeoneElse: reply.subject == 'other',
          report: TriageReportData(
            symptom: _mainSymptom ?? _chiefComplaint ?? _firstComplaint,
            severity: a.urgencyDescription,
            duration: null,
            dangerSigns: a.primaryConcerns,
            levelOverride: a.level,
            recommendationOverride:
                a.immediateActions.isEmpty ? null : a.immediateActions.join(' '),
          ),
        ),
      ),
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // RESTART / SOMEONE ELSE
  // ============================================================

  Future<void> _confirmRestart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: LocalizedText('Restart screening?', style: AppText.heading),
        content: LocalizedText(
          'Your answers so far will be cleared and the screening will start again.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: LocalizedText(
              'Cancel',
              style: AppText.style(14, FontWeight.w600, AppColors.grey),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.darkTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: LocalizedText(
              'Restart',
              style: AppText.style(14, FontWeight.w700, Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _restart();
  }

  void _restart() {
    setState(() {
      _generation++;
      _messages
        ..clear()
        ..add(_greeting());
      _sessionId = null;
      _firstComplaint = null;
      _chiefComplaint = null;
      _mainSymptom = null;
      _lastSent = null;
      _lastSelected = null;
      _lastNote = null;
      _current = null;
      _panelCollapsed = true;
      _progress = const TriageProgress(step: 1);
      _dropdownValue = null;
      _checked.clear();
      _loading = false;
      _error = null;
      _textController.clear();
      _noteController.clear();
    });
  }

  /// Starts the answer with "This is for my " so the user can say who the
  /// screening is for.
  void _forSomeoneElse() {
    if (_loading) return;
    final useNote = _isSelection;
    final controller = useNote ? _noteController : _textController;
    final focus = useNote ? _noteFocus : _textFocus;
    final prefix = tr(_someoneElsePrefix);
    if (!controller.text.startsWith(prefix)) {
      controller.text = prefix + controller.text;
    }
    controller.selection =
        TextSelection.collapsed(offset: controller.text.length);
    focus.requestFocus();
    setState(() {});
  }

  // ============================================================
  // PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                children: [
                  _header(),
                  _titleRow(),
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      children: [
                        _ownerCard(),
                        const SizedBox(height: 18),
                        for (final m in _messages)
                          FadeSlideIn(key: ObjectKey(m), child: _bubble(m)),
                        if (_loading) const _TypingBubble(),
                        if (_error != null) _errorBanner(),
                      ],
                    ),
                  ),
                  _answerPanel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final canRestart = _messages.length > 1 || _sessionId != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          CircleBackButton(onTap: () => Navigator.pop(context)),
          const SizedBox(width: 14),
          const BrandWordmark(),
          const Spacer(),
          if (canRestart)
            Semantics(
              button: true,
              child: Pressable(
                onTap: _confirmRestart,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _softBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.restart_alt_rounded,
                        size: 17,
                        color: AppColors.darkTeal,
                      ),
                      const SizedBox(width: 6),
                      LocalizedText(
                        'Restart',
                        style: AppText.style(
                          13,
                          FontWeight.w600,
                          AppColors.darkTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Title, "Step N of M" and the segmented step bar. M is the backend's
  /// estimate if nothing else turns up, so it can change as answers come in.
  Widget _titleRow() {
    final p = _progress;
    final total = p.total;
    final String subtitle;
    if (p.done) {
      subtitle = 'Screening complete';
    } else if (total == null) {
      subtitle = 'A few quick questions';
    } else {
      final left = math.max(1, total - p.step + 1);
      final minutes = math.max(1, (left * _secondsPerQuestion / 60).ceil());
      subtitle = 'A few quick questions · about $minutes min';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocalizedText('AI Triage', style: AppText.display),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: LocalizedText(
                  subtitle,
                  style: AppText.style(13, FontWeight.w400, _mutedText),
                ),
              ),
              const SizedBox(width: 12),
              LocalizedText(
                total == null ? 'Step ${p.step}' : 'Step ${p.step} of $total',
                style: AppText.style(12, FontWeight.w700, AppColors.darkTeal),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _stepBar(),
        ],
      ),
    );
  }

  /// Done steps dark teal, the current step teal, the rest grey.
  Widget _stepBar() {
    final p = _progress;
    final count = p.done ? p.step : math.max(p.step, p.total ?? _defaultSegments);
    if (count > _maxSegments) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: p.done ? 1 : (p.step - 0.5) / count),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: 4,
            color: AppColors.darkTeal,
            backgroundColor: AppColors.border,
          ),
        ),
      );
    }
    return Semantics(
      label: tr(p.total == null ? 'Step ${p.step}' : 'Step ${p.step} of ${p.total}'),
      child: Row(
        children: [
          for (var i = 1; i <= count; i++) ...[
            if (i > 1) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: p.done || i < p.step
                      ? AppColors.darkTeal
                      : i == p.step
                          ? AppColors.teal
                          : AppColors.border,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Whose profile the screening uses, with a shortcut to say it is for
  /// someone else.
  Widget _ownerCard() {
    final name = _ownerName();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gradientTop),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.paleTeal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: AppColors.darkTeal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LocalizedText(
                        name.isEmpty
                            ? 'Screening for you (the account owner)'
                            : 'Screening for $name',
                        style: AppText.style(
                          14,
                          FontWeight.w700,
                          AppColors.textDark,
                          height: 1.3,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _forSomeoneElse,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.darkTeal,
                        minimumSize: const Size(44, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: LocalizedText(
                        'Change',
                        style: AppText.style(
                          12,
                          FontWeight.w700,
                          AppColors.darkTeal,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: LocalizedText(
                    'This uses your saved health profile (such as your age). '
                    'Doing this for someone else? Just tell me who it is for, '
                    'for example "this is for my mother, she is 70".',
                    style: AppText.style(
                      12.5,
                      FontWeight.w400,
                      _mutedText,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHAT BUBBLES
  // ============================================================

  String _clock(DateTime t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(t));

  Widget _bubble(_ChatMessage m) {
    final time = _clock(m.time);
    final timeStyle = AppText.style(11, FontWeight.w400, _mutedText);

    if (m.fromUser) {
      final failed = _error != null && identical(m, _messages.last);
      return Padding(
        padding: const EdgeInsets.only(bottom: 14, left: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.darkTeal,
                borderRadius: _userRadius,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.darkTeal.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                m.text,
                style: AppText.style(14, FontWeight.w500, Colors.white, height: 1.45),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time, style: timeStyle),
                  const SizedBox(width: 4),
                  Icon(
                    failed ? Icons.error_outline_rounded : Icons.check_rounded,
                    size: 14,
                    color: failed ? AppColors.red : AppColors.teal,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14, right: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const _BotAvatar(),
              const SizedBox(width: 10),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: _botRadius,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.darkTeal.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text.rich(
                    TextSpan(
                      style: AppText.style(14, FontWeight.w400, _bodyText, height: 1.5),
                      children: _questionSpans(m.text),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Text(time, style: timeStyle),
          ),
        ],
      ),
    );
  }

  /// Answer instructions ("Tick all that apply.", "About the injury: tick all
  /// that apply.", Malay "Tandakan ..." / "Pilih ...").
  static final _instruction = RegExp(
    r'^(tick|choose|select|pick|tandakan|pilih)\b|tick all that apply|choose one',
    caseSensitive: false,
  );

  /// Bot text with every question and answer instruction in bold, so they stand
  /// out from the conversational text around them.
  static List<TextSpan> _questionSpans(String text) {
    const bold = TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark);
    final spans = <TextSpan>[];
    for (final sentence in _sentences(text)) {
      final body = sentence.trimRight();
      final trailing = sentence.substring(body.length);
      if (body.endsWith('?') || _instruction.hasMatch(body.trimLeft())) {
        spans.add(TextSpan(text: body, style: bold));
        if (trailing.isNotEmpty) spans.add(TextSpan(text: trailing));
      } else {
        spans.add(TextSpan(text: sentence));
      }
    }
    return spans;
  }

  /// Splits text into sentences, each keeping its trailing whitespace. A sentence
  /// ends at a line break, or at . ! ? followed by whitespace and a capital letter,
  /// digit or bracket/quote (so "e.g. a finger" stays in one sentence).
  static List<String> _sentences(String text) {
    final sentences = <String>[];
    final startOfNext = RegExp(r'''[A-Z0-9("'“]''');
    var start = 0;
    var i = 0;
    while (i < text.length) {
      final c = text[i];
      var end = -1;
      if (c == '\n') {
        end = i + 1;
      } else if ('.!?'.contains(c)) {
        var j = i + 1;
        while (j < text.length && text[j] == ' ') {
          j++;
        }
        if (j == text.length || text[j] == '\n') {
          end = j;
        } else if (j > i + 1 && startOfNext.hasMatch(text[j])) {
          end = j;
        }
      }
      if (end != -1) {
        while (end < text.length && text[end] == '\n') {
          end++;
        }
        sentences.add(text.substring(start, end));
        start = i = end;
      } else {
        i++;
      }
    }
    if (start < text.length) sentences.add(text.substring(start));
    return sentences;
  }

  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: AppText.style(12, FontWeight.w600, AppColors.textDark),
            ),
          ),
          TextButton(
            onPressed: _lastSent == null ? null : _retry,
            style: TextButton.styleFrom(foregroundColor: AppColors.darkTeal),
            child: LocalizedText(
              'Retry',
              style: AppText.style(13, FontWeight.w700, AppColors.darkTeal),
            ),
          ),
        ],
      ),
    );
  }

  void _retry() {
    // Drop the failed user bubble; _send adds it back.
    final last = _lastSent;
    if (last == null) return;
    setState(() {
      if (_messages.isNotEmpty && _messages.last.fromUser) {
        _messages.removeLast();
      }
    });
    _send(last, selected: _lastSelected, note: _lastNote);
  }

  // ============================================================
  // ANSWER PANEL: checkboxes, option buttons, dropdown or text box
  // ============================================================

  Widget _answerPanel() {
    final selection = _isSelection;
    final Widget content;
    if (selection && _panelCollapsed) {
      content = _collapsedBar();
    } else if (selection) {
      final options = _current!.options;
      if (_current!.multiSelect) {
        content = _checkboxList(options);
      } else {
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _panelHeading('Choose one'),
            const SizedBox(height: 10),
            options.length <= _maxButtonOptions
                ? _optionButtons(options)
                : _optionDropdown(options),
            const SizedBox(height: 12),
            _noteBox(),
          ],
        );
      }
    } else {
      content = _textBox();
    }

    final panel = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, selection ? 6 : 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            selection ? const BorderRadius.vertical(top: Radius.circular(28)) : null,
        border: selection ? null : const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkTeal.withValues(alpha: selection ? 0.08 : 0.03),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: AbsorbPointer(
          absorbing: _loading,
          child: AnimatedOpacity(
            opacity: _loading ? 0.55 : 1,
            duration: const Duration(milliseconds: 200),
            child: selection
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [_panelHandle(), content],
                  )
                : content,
          ),
        ),
      ),
    );
    if (!selection) return panel;
    // Swipe down to hide the options, up to bring them back. The option list
    // keeps its own scrolling.
    return GestureDetector(
      onVerticalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() < 200) return;
        _setPanelCollapsed(v > 0);
      },
      child: panel,
    );
  }

  void _setPanelCollapsed(bool collapsed) {
    if (collapsed == _panelCollapsed) return;
    FocusScope.of(context).unfocus();
    setState(() => _panelCollapsed = collapsed);
    if (collapsed) _scrollToEnd();
  }

  /// Grab handle with a Hide / Show toggle at the top of the options panel.
  Widget _panelHandle() {
    final collapsed = _panelCollapsed;
    return Semantics(
      button: true,
      label: tr(collapsed ? 'Show options' : 'Hide options'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setPanelCollapsed(!collapsed),
        child: SizedBox(
          height: 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LocalizedText(
                      collapsed ? 'Show' : 'Hide',
                      style: AppText.style(12, FontWeight.w700, AppColors.darkTeal),
                    ),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: collapsed ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.darkTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// What the hidden panel shows: the kind of answer and what is picked so
  /// far. Tapping it brings the options back.
  Widget _collapsedBar() {
    final current = _current!;
    final picked = _picked;
    final String summary;
    if (picked.isNotEmpty) {
      summary = current.multiSelect ? '${picked.length} selected' : picked.first;
    } else {
      summary = 'Tap to answer';
    }
    return Pressable(
      scale: 0.98,
      onTap: () => _setPanelCollapsed(false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.checklist_rounded, size: 18, color: AppColors.darkTeal),
            const SizedBox(width: 10),
            Expanded(
              child: LocalizedText(
                current.multiSelect ? 'Tick all that apply' : 'Choose one',
                style: AppText.style(13, FontWeight.w700, AppColors.textDark),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: LocalizedText(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.style(12, FontWeight.w600, _mutedText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelHeading(String label, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: LocalizedText(
              label,
              style: AppText.style(13, FontWeight.w700, AppColors.textDark),
            ),
          ),
          if (trailing != null)
            LocalizedText(
              trailing,
              style: AppText.style(12, FontWeight.w600, _mutedText),
            ),
        ],
      ),
    );
  }

  Widget _optionButtons(List<String> options) {
    final suggested = _current?.suggestedOptions ?? const <String>[];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final o in options)
          _option(
            text: o,
            suggested: suggested.contains(o),
            onTap: () => _send(o, selected: [o]),
          ),
      ],
    );
  }

  /// The options ticked or chosen in the dropdown, in the screen's order.
  List<String> get _picked {
    final current = _current;
    if (current == null) return const [];
    if (current.multiSelect) {
      return [for (final o in current.options) if (_checked.contains(o)) o];
    }
    return _dropdownValue == null ? const [] : [_dropdownValue!];
  }

  bool get _canSubmit =>
      _picked.isNotEmpty || _noteController.text.trim().isNotEmpty;

  /// Sends the picked option(s) with the typed text as extra details, or the
  /// typed text on its own as the answer (read against the question on screen).
  void _submit() {
    final picked = _picked;
    if (picked.isNotEmpty) {
      _send(picked.join('; '), selected: picked);
    } else {
      _send(_noteController.text);
    }
  }

  InputDecoration _fieldDecoration({
    String? hint,
    IconData? icon,
    double radius = 16,
  }) {
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: AppText.style(13.5, FontWeight.w400, _hintText),
      filled: true,
      fillColor: AppColors.field,
      prefixIcon: icon == null ? null : Icon(icon, size: 18, color: _mutedText),
      prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 20),
      contentPadding: EdgeInsets.fromLTRB(icon == null ? 18 : 0, 14, 16, 14),
      border: outline(AppColors.border),
      enabledBorder: outline(AppColors.border),
      focusedBorder: outline(AppColors.teal, 1.5),
    );
  }

  /// Answer in your own words, or add details to the option you pick.
  Widget _noteBox() {
    // Multi-select and dropdown answers have their own send button.
    final ownSend =
        !_current!.multiSelect && _current!.options.length <= _maxButtonOptions;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _noteController,
            focusNode: _noteFocus,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_canSubmit) _submit();
            },
            style: AppText.style(13.5, FontWeight.w500, AppColors.textDark),
            decoration: _fieldDecoration(
              hint: tr('Or type your answer in your own words'),
              icon: Icons.edit_outlined,
            ),
          ),
        ),
        if (ownSend) ...[
          const SizedBox(width: 10),
          _SendButton(
            onPressed: _noteController.text.trim().isEmpty ? null : _submit,
          ),
        ],
      ],
    );
  }

  /// Tick-all-that-apply list. Exclusive options ("None of these", "Not sure")
  /// clear every other tick, and ticking anything else clears them.
  void _toggle(String option) {
    final exclusive = _current?.exclusiveOptions ?? const <String>[];
    setState(() {
      if (_checked.contains(option)) {
        _checked.remove(option);
      } else if (exclusive.contains(option)) {
        _checked
          ..clear()
          ..add(option);
      } else {
        _checked
          ..removeAll(exclusive)
          ..add(option);
      }
    });
  }

  /// "Trouble breathing - breathless, wheezing ..." → bold title + details.
  static (String, String?) _splitOption(String option) {
    final m = RegExp(r'\s+[-–—]\s+').firstMatch(option);
    if (m == null || m.start == 0) return (option, null);
    final title = option.substring(0, m.start).trim();
    final detail = option.substring(m.end).trim();
    if (detail.isEmpty) return (option, null);
    return (title, detail[0].toUpperCase() + detail.substring(1));
  }

  Widget _checkboxList(List<String> options) {
    final exclusive = _current?.exclusiveOptions ?? const <String>[];
    final regular = [for (final o in options) if (!exclusive.contains(o)) o];
    final only = [for (final o in options) if (exclusive.contains(o)) o];
    final count = _checked.length;
    final maxListHeight = math.max(180.0, MediaQuery.sizeOf(context).height * 0.36);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panelHeading(
          'Tick all that apply',
          trailing: count == 0 ? 'None selected' : '$count selected',
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxListHeight),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final o in regular)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _checkCard(o),
                ),
              if (only.isNotEmpty) ...[
                if (regular.isNotEmpty) _orDivider(),
                _exclusiveChips(only),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _noteBox(),
        const SizedBox(height: 12),
        _continueButton(),
      ],
    );
  }

  Widget _checkCard(String option) {
    final on = _checked.contains(option);
    final (title, detail) = _splitOption(option);
    return Semantics(
      checked: on,
      child: Pressable(
        scale: 0.98,
        onTap: () => _toggle(option),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: on ? _selectedFill : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: on ? AppColors.darkTeal : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              _checkBox(on),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.style(
                        14,
                        FontWeight.w700,
                        AppColors.textDark,
                        height: 1.3,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: AppText.style(
                          12,
                          FontWeight.w400,
                          _mutedText,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkBox(bool on) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: on ? AppColors.darkTeal : Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: on ? AppColors.darkTeal : _uncheckedBox,
          width: 2,
        ),
      ),
      child: on
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
    );
  }

  Widget _orDivider() {
    const line = Expanded(
      child: Divider(height: 1, thickness: 1, color: AppColors.border),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: LocalizedText(
              'OR',
              style: AppText.style(11, FontWeight.w700, _mutedText)
                  .copyWith(letterSpacing: 0.6),
            ),
          ),
          line,
        ],
      ),
    );
  }

  /// "None of these" / "Not sure": side by side when they fit, else wrapped.
  Widget _exclusiveChips(List<String> only) {
    Widget chip(String o) => _choiceChip(
          o,
          selected: _checked.contains(o),
          onTap: () => _toggle(o),
        );
    if (only.length <= 2) {
      return Row(
        children: [
          for (var i = 0; i < only.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: chip(only[i])),
          ],
        ],
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: [for (final o in only) chip(o)]);
  }

  Widget _choiceChip(String text, {required bool selected, required VoidCallback onTap}) {
    return Semantics(
      checked: selected,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.darkTeal : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppColors.darkTeal : _softBorder,
              width: 1.5,
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppText.style(
              13.5,
              FontWeight.w700,
              selected ? Colors.white : AppColors.darkTeal,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _continueButton() {
    final enabled = _canSubmit;
    final color = enabled ? Colors.white : _mutedText;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Pressable(
        onTap: enabled ? _submit : null,
        scale: enabled ? 0.96 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? AppColors.darkTeal : AppColors.border,
            borderRadius: BorderRadius.circular(26),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.darkTeal.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LocalizedText(
                'Continue',
                style: AppText.style(15, FontWeight.w700, color),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionDropdown(List<String> options) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _dropdownValue,
            isExpanded: true,
            borderRadius: BorderRadius.circular(16),
            dropdownColor: Colors.white,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.darkTeal,
            ),
            hint: LocalizedText(
              'Select an answer',
              style: AppText.style(13.5, FontWeight.w400, _hintText),
            ),
            style: AppText.style(14, FontWeight.w500, AppColors.textDark),
            decoration: _fieldDecoration(),
            items: [
              for (final o in options)
                DropdownMenuItem(
                  value: o,
                  child: Text(o, overflow: TextOverflow.ellipsis, maxLines: 2),
                ),
            ],
            onChanged: (v) => setState(() => _dropdownValue = v),
          ),
        ),
        const SizedBox(width: 10),
        _SendButton(
          onPressed: _canSubmit ? _submit : null,
          icon: Icons.arrow_forward_rounded,
          label: 'Continue',
        ),
      ],
    );
  }

  Widget _textBox() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            focusNode: _textFocus,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: _send,
            style: AppText.input,
            decoration: _fieldDecoration(hint: tr('Type your answer'), radius: 26),
          ),
        ),
        const SizedBox(width: 10),
        _SendButton(onPressed: () => _send(_textController.text)),
      ],
    );
  }

  // ============================================================
  // SINGLE-SELECT OPTION BUTTON (sized to its label)
  // ============================================================

  /// [suggested]: matches what the user already mentioned, so it is shown
  /// highlighted for a one-tap confirmation.
  Widget _option({
    required String text,
    required VoidCallback onTap,
    bool suggested = false,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: suggested ? _selectedFill : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: suggested ? AppColors.darkTeal : AppColors.border,
            width: suggested ? 2 : 1.5,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppText.style(
            14,
            FontWeight.w600,
            AppColors.darkTeal,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SMALL WIDGETS
// ============================================================

class _BotAvatar extends StatelessWidget {
  const _BotAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: AppColors.darkTeal,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.monitor_heart_outlined,
        size: 16,
        color: Colors.white,
      ),
    );
  }
}

/// Round dark-teal send button; greyed out when [onPressed] is null.
class _SendButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  const _SendButton({
    required this.onPressed,
    this.icon = Icons.arrow_upward_rounded,
    this.label = 'Send',
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tr(label),
      child: Pressable(
        onTap: onPressed,
        scale: enabled ? 0.92 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: enabled ? AppColors.darkTeal : AppColors.border,
            shape: BoxShape.circle,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.darkTeal.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? Colors.white : _mutedText,
          ),
        ),
      ),
    );
  }
}

/// Three bouncing dots in a bot bubble while the reply is on its way.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _bounce(int i) {
    final t = (_controller.value - i * 0.18) % 1.0;
    return t < 0.4 ? math.sin(t / 0.4 * math.pi) : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr('Assistant is typing'),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const _BotAvatar(),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: _botRadius,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.darkTeal.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: Transform.translate(
                          offset: Offset(0, -3 * _bounce(i)),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: AppColors.teal.withValues(
                                alpha: 0.4 + 0.6 * _bounce(i),
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
