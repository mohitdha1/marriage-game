import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/avatar_look.dart';
import '../../data/name_rules.dart';
import '../home/player_avatar.dart';
import 'name_rules_provider.dart';

/// Picks a display name and an avatar: the chosen avatar large beside the
/// name, the twenty looks to choose from, and a button that saves both
/// once the name passes the [NameRules]. Shared by the first-launch screen
/// and the profile.
class ProfileEditor extends ConsumerStatefulWidget {
  const ProfileEditor({
    super.key,
    required this.name,
    required this.look,
    required this.saveLabel,
    required this.onSave,
    this.footer,
  });

  /// The name and look it starts with.
  final String name;
  final int look;

  /// What the save button says: "Continue", or "Save".
  final String saveLabel;
  final void Function(String name, int look) onSave;

  /// Shown under the save button, such as the player's record.
  final Widget? footer;

  @override
  ConsumerState<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<ProfileEditor> {
  late final _name = TextEditingController(text: widget.name);
  late int _look = widget.look;

  /// Whether to say what's wrong with the name: once it's been changed, or
  /// saving was tried.
  var _checking = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  NameRules get _rules =>
      ref.read(nameRulesProvider).value ?? NameRules(const []);

  void _save() {
    if (_rules.problemWith(_name.text) != null) {
      setState(() => _checking = true);
      return;
    }
    widget.onSave(NameRules.tidy(_name.text), _look);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilt once the blocked words have loaded.
    ref.watch(nameRulesProvider);
    final problem = _checking ? _rules.problemWith(_name.text) : null;

    final details = SizedBox(
      width: 250,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerAvatar(
            key: const Key('profile-preview'),
            name: _name.text,
            look: _look,
            radius: 34,
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('profile-name'),
            controller: _name,
            maxLength: NameRules.maxLength,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Name',
              errorText: problem,
              errorMaxLines: 2,
            ),
            onChanged: (_) => setState(() => _checking = true),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 4),
          FilledButton(
            key: const Key('profile-save'),
            onPressed: _save,
            child: Text(widget.saveLabel),
          ),
          if (widget.footer case final footer?) ...[
            const SizedBox(height: 8),
            footer,
          ],
        ],
      ),
    );

    // Five looks a row, four rows: each choice is its avatar with a ring.
    const perRow = 5;
    const choice = _LookChoice.size;
    const gap = 4.0;
    final looks = SizedBox(
      width: perRow * choice + (perRow - 1) * gap,
      child: Wrap(
        key: const Key('profile-looks'),
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < AvatarLook.presets.length; i++)
            _LookChoice(
              key: Key('look-$i'),
              look: i,
              chosen: i == _look,
              onTap: () => setState(() => _look = i),
            ),
        ],
      ),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 16,
      children: [details, looks],
    );
  }
}

/// One look to choose, ringed when it's the one chosen.
class _LookChoice extends StatelessWidget {
  /// The width and height of a choice, ring included.
  static const size = 2 * 20.0 + 2 * (2 + 3);

  const _LookChoice({
    super.key,
    required this.look,
    required this.chosen,
    required this.onTap,
  });

  final int look;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: chosen,
    label: 'Avatar ${look + 1}',
    excludeSemantics: true,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: chosen
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: PlayerAvatar(name: '', look: look, radius: 20),
      ),
    ),
  );
}
