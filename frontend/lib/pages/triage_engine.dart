import '../localization.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/triage_chat_service.dart';
import '../theme.dart';
import 'triage_report.dart';

class _ChatMessage {
  final String text;
  final bool fromUser;
  const _ChatMessage(this.text, {required this.fromUser});
}

class TriagePage extends StatefulWidget {
  const TriagePage({super.key});

  @override
  State<TriagePage> createState() => _TriagePageState();
}

class _TriagePageState extends State<TriagePage> {
  /// Selection lists up to this size render as buttons, longer ones as a dropdown.
  static const int _maxButtonOptions = 4;

  final List<_ChatMessage> _messages = [
    // The backend applies the account owner's saved health profile unless told
    // the screening is for someone else. Naming the logged-in user shows whose
    // profile is in use.
    _ChatMessage(_ownerNotice(), fromUser: false),
    const _ChatMessage(
      'Hi, I will ask a few questions to understand your condition. '
      'What is the main problem you are experiencing?',
      fromUser: false,
    ),
  ];
  static String _ownerNotice() {
    final name = (AuthService.currentUser?['name'] as String?)?.trim() ?? '';
    final you = name.isEmpty ? 'you, the account owner' : 'you, $name (the account owner)';
    return 'Please note: this screening is for $you by default, and uses your '
        'saved health profile (such as your age). If you are doing it on behalf '
        'of someone else, please tell me who it is for (for example, "this is '
        'for my mother, she is 70").';
  }

  final TextEditingController _textController = TextEditingController();
  // Optional extra details typed under the answer options.
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _sessionId;
  String? _firstComplaint; // fallback only: the user's first message
  String? _chiefComplaint; // the main problem, as identified by the backend
  String? _mainSymptom; // its short summary, written once there is a result
  String? _lastSent;
  List<String>? _lastSelected;
  String? _lastNote;
  TriageChatReply? _current; // null until the first reply = free-text prompt
  String? _dropdownValue;
  final Set<String> _checked = {}; // ticked options of a multi-select question
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    _noteController.dispose();
    _scrollController.dispose();
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
      if (!mounted) return;
      setState(() {
        _sessionId = reply.sessionId ?? _sessionId;
        _chiefComplaint = reply.chiefComplaint ?? _chiefComplaint;
        _mainSymptom = reply.mainSymptom ?? _mainSymptom;
        _current = reply;
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
      if (!mounted) return;
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        CircleBackButton(onTap: () => Navigator.pop(context)),
                        const SizedBox(width: 14),
                        const BrandWordmark(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: LocalizedText('AI Triage', style: AppText.display),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        for (final m in _messages) _bubble(m),
                        if (_loading) _typingIndicator(),
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

  // ============================================================
  // CHAT BUBBLES
  // ============================================================

  Widget _bubble(_ChatMessage m) {
    return Align(
      alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: m.fromUser
            ? BoxDecoration(
                color: AppColors.darkTeal,
                borderRadius: BorderRadius.circular(18),
              )
            : cardDecoration(radius: 18),
        child: m.fromUser
            ? Text(
                m.text,
                style: AppText.style(14, FontWeight.w500, Colors.white, height: 1.4),
              )
            : Text.rich(TextSpan(style: AppText.body, children: _questionSpans(m.text))),
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
    const bold = TextStyle(fontWeight: FontWeight.w700);
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

  Widget _typingIndicator() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 10, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _error!,
              style: AppText.style(12, FontWeight.w600, AppColors.textDark),
            ),
          ),
          TextButton(
            onPressed: _lastSent == null ? null : _retry,
            child: const Text('Retry'),
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
    final Widget content;
    if (_isSelection) {
      final options = _current!.options;
      final Widget picker;
      if (_current!.multiSelect) {
        picker = _checkboxList(options);
      } else {
        picker = options.length <= _maxButtonOptions
            ? _optionButtons(options)
            : _optionDropdown(options);
      }
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_noteBox(), const SizedBox(height: 10), picker],
      );
    } else {
      content = _textBox();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: AbsorbPointer(absorbing: _loading, child: content),
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

  /// Optional extra details, sent with whichever option is picked.
  Widget _noteBox() {
    return TextField(
      controller: _noteController,
      minLines: 1,
      maxLines: 3,
      style: AppText.style(13, FontWeight.w500, AppColors.textDark),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Anything else to add? (optional)',
        filled: true,
        fillColor: AppColors.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
      ),
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

  Widget _checkboxList(List<String> options) {
    // Keep the screen's option order, not the tap order.
    final picked = [for (final o in options) if (_checked.contains(o)) o];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final o in options)
                CheckboxListTile(
                  value: _checked.contains(o),
                  onChanged: (_) => _toggle(o),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.darkTeal,
                  title: Text(
                    o,
                    style: AppText.style(
                      14,
                      FontWeight.w500,
                      AppColors.darkTeal,
                      height: 1.25,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: picked.isEmpty
              ? null
              : () => _send(picked.join('; '), selected: picked),
          child: const Text('Continue'),
        ),
      ],
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
            hint: const Text('Select an answer'),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.field,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
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
        IconButton.filled(
          onPressed:
              _dropdownValue == null
                  ? null
                  : () => _send(_dropdownValue!, selected: [_dropdownValue!]),
          icon: const Icon(Icons.arrow_forward_rounded),
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
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: _send,
            decoration: InputDecoration(
              hintText: 'Type your answer',
              filled: true,
              fillColor: AppColors.field,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          onPressed: () => _send(_textController.text),
          icon: const Icon(Icons.send_rounded),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(16),
          border: suggested
              ? Border.all(color: AppColors.darkTeal, width: 2)
              : Border.all(color: AppColors.border),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppText.style(
            14,
            FontWeight.w500,
            AppColors.darkTeal,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}
