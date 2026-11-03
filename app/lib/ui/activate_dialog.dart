import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/core_api.dart';
import '../core/core_controller.dart';
import '../l10n/app_localizations.dart';
import '../license.dart';
import '../platform.dart';
import 'widgets.dart';

/// Where a token comes from: the Telegram bot.
const tokenBotUrl = 'https://t.me/awmvpn_bot';

/// Asks for a token and turns it into an account. True when one was added.
Future<bool> showActivateDialog(
  BuildContext context,
  CoreController core,
) async {
  final done = await showDialog<bool>(
    context: context,
    barrierDismissible: !core.activating,
    builder: (_) => _ActivateDialog(core: core),
  );
  return done == true;
}

/// The token in what the user pasted: the bare value, a copied deeplink
/// (`awmvpn://activate?t=…`), or the whole message around it.
String normalizeToken(String raw) {
  var text = raw.trim();
  final scheme = text.indexOf('://');
  if (scheme >= 0 && text.substring(0, scheme).toLowerCase() == 'awmvpn') {
    final at = text.indexOf(RegExp(r'[?&]t='));
    if (at >= 0) text = text.substring(at + 3);
  }
  text = text.replaceAll(RegExp(r'\s'), '');
  // A token is `awm_` and 40 hexadecimal characters; the words around it in
  // a bot message are dropped.
  final match = RegExp(r'awm_[0-9a-fA-F]{40}').firstMatch(text);
  if (match != null) return match.group(0)!.toLowerCase();
  final start = text.indexOf('awm_');
  return start > 0 ? text.substring(start) : text;
}

/// The message for a refused token, in the user's language.
String licenseProblemText(AppLocalizations l, LicenseProblem problem) =>
    switch (problem) {
      LicenseProblem.unknown => l.licenseUnknown,
      LicenseProblem.expired => l.licenseExpired,
      LicenseProblem.revoked => l.licenseRevoked,
      LicenseProblem.accountUnavailable => l.licenseAccountUnavailable,
      LicenseProblem.throttled => l.licenseThrottled,
      LicenseProblem.network => l.licenseNetwork,
      LicenseProblem.server => l.licenseServer,
    };

class _ActivateDialog extends StatefulWidget {
  const _ActivateDialog({required this.core});

  final CoreController core;

  @override
  State<_ActivateDialog> createState() => _ActivateDialogState();
}

class _ActivateDialogState extends State<_ActivateDialog> {
  final _field = TextEditingController();
  final _focus = FocusNode();

  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = normalizeToken(data?.text ?? '');
    if (text.isEmpty || !mounted) return;
    setState(() {
      _field.text = text;
      _field.selection = TextSelection.collapsed(offset: text.length);
      _error = null;
    });
    _focus.requestFocus();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final token = normalizeToken(_field.text);
    if (token.isEmpty) {
      setState(() => _error = l.tokenMissing);
      _focus.requestFocus();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.core.activateLicense(token);
      if (mounted) Navigator.of(context).pop(true);
    } on LicenseException catch (e) {
      if (mounted) {
        setState(() => _error = licenseProblemText(l, e.problem));
      }
    } on CoreUnavailable catch (e) {
      if (mounted) {
        setState(() => _error = describeProblem(l, e));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is CoreApiException ? e.message : e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      contentPadding: EdgeInsets.zero,
      titlePadding: EdgeInsets.zero,
      // A banner in the theme's own light, the key at its center.
      title: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primaryContainer,
              Color.alphaBlend(
                scheme.tertiaryContainer.withValues(alpha: 0.7),
                scheme.primaryContainer,
              ),
            ],
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.vpn_key_rounded, color: scheme.onPrimaryContainer),
            const SizedBox(height: 12),
            Text(
              l.activateTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.activateIntro, style: muted),
              const SizedBox(height: 18),
              TextField(
                controller: _field,
                focusNode: _focus,
                autofocus: true,
                enabled: !_busy,
                // Tokens are Latin and read left to right in any language.
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.start,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                  letterSpacing: 0.4,
                ),
                decoration: InputDecoration(
                  labelText: l.tokenFieldLabel,
                  hintText: l.tokenFieldHint,
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    tooltip: l.paste,
                    onPressed: _busy ? null : _paste,
                    icon: const Icon(Icons.content_paste_rounded),
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
              const SizedBox(height: 10),
              Text(
                l.activateWhere,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  onPressed: () => openUrl(tokenBotUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(l.getTokenFromBot),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: StatusColors.bad.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: StatusColors.bad,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!, style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(_busy ? l.activating : l.activate),
        ),
      ],
    );
  }
}
