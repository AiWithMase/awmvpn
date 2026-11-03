import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import '../license.dart';
import '../platform.dart';
import 'activate_dialog.dart';
import 'format.dart';
import 'widgets.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key, required this.core});

  final CoreController core;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final list = core.accounts?.accounts ?? const <Account>[];
    final threshold = core.accounts?.thresholdPercent ?? 0;
    return ListView(
      padding: pagePadding(context),
      children: [
        Row(
          children: [
            Expanded(child: PageTitle(l.navAccounts)),
            FilledButton.icon(
              onPressed: () => showActivateDialog(context, core),
              icon: const Icon(Icons.key_rounded),
              label: Text(l.activate),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (core.endedLicense != null) ...[
          _EndedNotice(core: core, license: core.endedLicense!),
          const SizedBox(height: 12),
        ],
        if (core.accounts == null)
          const Center(child: CircularProgressIndicator())
        else if (list.isEmpty)
          _NoSubscription(core: core)
        else
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _AccountCard(
              core: core,
              account: list[i],
              license: core.licenses[list[i].id],
              threshold: threshold,
              first: i == 0,
              last: i == list.length - 1,
            ),
          ],
        // More subscriptions, more data: each has its own month's
        // allowance, and the app moves to the next one by itself.
        if (list.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [
                    l.accountsGuide(_allowance(list)),
                    if (list.length > 1) l.accountsOrderNote(threshold.round()),
                  ].join(' '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MoreSubscriptions(core: core),
        ],
      ],
    );
  }
}

/// Why an account is out of the rotation, in the user's language; the
/// core's English for a reason the app does not know; null for none.
/// [threshold] is the account-switch setting, in percent.
String? accountReason(AppLocalizations l, Account a, double threshold) {
  final time = a.retryAt == null ? null : formatTime(a.retryAt!.toLocal());
  final detail = a.reasonDetail.isEmpty ? null : ltr(a.reasonDetail);
  final known = switch (a.reasonCode) {
    'quota_threshold' => l.reasonQuotaThreshold(
      (threshold > 0 ? threshold : 95).round(),
    ),
    'quota_exhausted' => l.reasonQuotaExhausted,
    'signin_required' => l.reasonTokenNeeded,
    'signin_confirm' => l.reasonSignInConfirm,
    'signin_failed' when detail != null => l.reasonSignInFailed(detail),
    'signin_wait' when time != null => l.reasonSignInWait(time),
    'signin_retry' when detail != null && time != null => l.reasonSignInRetry(
      detail,
      time,
    ),
    'not_entitled' => l.reasonNotEntitled,
    _ => null,
  };
  return known ?? (a.reason.isEmpty ? null : a.reason);
}

/// An account's monthly allowance as the accounts report it (50 GB until
/// one has been read).
String _allowance(List<Account> list) {
  final limit =
      list
          .map((a) => a.usage?.limitBytes ?? 0)
          .where((b) => b > 0)
          .firstOrNull ??
      50 << 30;
  return formatBytes(limit).replaceAll('.0 ', ' ');
}

/// How long a subscription has left, in the user's words.
String licenseRemaining(AppLocalizations l, License license) {
  final left = license.remaining;
  if (left <= Duration.zero) return l.licenseEnded;
  if (left.inDays >= 1) return l.daysLeft(left.inDays);
  if (left.inHours >= 1) return l.hoursLeft(left.inHours);
  final minutes = left.inMinutes < 1 ? 1 : left.inMinutes;
  return l.minutesLeft(minutes);
}

/// Nothing activated yet: where a token comes from and how to use it.
class _NoSubscription extends StatelessWidget {
  const _NoSubscription({required this.core});

  final CoreController core;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 28, 24, 26),
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
              children: [
                Icon(
                  Icons.vpn_key_rounded,
                  size: 46,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(height: 14),
                Text(
                  l.noSubscriptionTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.noSubscriptionBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  onPressed: () => showActivateDialog(context, core),
                  icon: const Icon(Icons.key_rounded),
                  label: Text(l.activate),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => openUrl(tokenBotUrl),
                  icon: const Icon(Icons.telegram_rounded, size: 18),
                  label: Text(l.getTokenFromBot),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The subscription that ended: its account is gone, and a new token is
/// what brings the VPN back.
class _EndedNotice extends StatelessWidget {
  const _EndedNotice({required this.core, required this.license});

  final CoreController core;
  final License license;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: StatusColors.busy.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: StatusColors.busy.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.timer_off_rounded,
                    color: StatusColors.busy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.licenseEndedTitle(license.label),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.licenseEndedBody,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.close,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: core.dismissEndedLicense,
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => showActivateDialog(context, core),
                icon: const Icon(Icons.key_rounded, size: 18),
                label: Text(l.activateNewToken),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A second subscription for the one user: each adds a token's account.
class _MoreSubscriptions extends StatelessWidget {
  const _MoreSubscriptions({required this.core});

  final CoreController core;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l.moreSubscriptions,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () => showActivateDialog(context, core),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(l.activate),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.core,
    required this.account,
    required this.license,
    required this.threshold,
    required this.first,
    required this.last,
  });

  final CoreController core;
  final Account account;
  final License? license;
  final double threshold;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final a = account;
    final busy = core.busyAccounts.contains(a.id);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final usage = a.usage;
    final subscription = license;
    return Opacity(
      opacity: a.enabled ? 1 : 0.6,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: a.active
              ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            // A phone: the controls go under the account.
            final narrow = box.maxWidth < 520;
            // What the account needs now, beside its name on a computer, so
            // every card's bar is as wide and the threshold marks line up.
            final Widget? action = busy
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : a.needsSignIn
                ? FilledButton.tonal(
                    onPressed: () => showActivateDialog(context, core),
                    child: Text(l.activateNewToken),
                  )
                : !a.active && a.enabled && a.status == AccountStatus.ready
                ? OutlinedButton(
                    onPressed: () =>
                        runShowingErrors(context, () => core.activate(a)),
                    child: Text(l.useNow),
                  )
                : null;
            final controls = <Widget>[
              Tooltip(
                message: a.enabled ? l.statusEnabled : l.statusDisabled,
                child: Switch(
                  value: a.enabled,
                  onChanged: busy
                      ? null
                      : (v) => runShowingErrors(
                          context,
                          () => core.setEnabled(a, v),
                        ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: l.more,
                enabled: !busy,
                onSelected: (v) => switch (v) {
                  'refresh' => runShowingErrors(
                    context,
                    () => core.refreshQuota(a),
                  ),
                  'copy' when subscription != null => _copyToken(context),
                  'remove' => _remove(context),
                  _ => null,
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'refresh',
                    child: ListTile(
                      leading: const Icon(Icons.sync_rounded),
                      title: Text(l.refreshQuota),
                    ),
                  ),
                  if (subscription != null)
                    PopupMenuItem(
                      value: 'copy',
                      child: ListTile(
                        leading: const Icon(Icons.content_copy_rounded),
                        title: Text(l.copyToken),
                      ),
                    ),
                  PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline_rounded),
                      title: Text(l.remove),
                    ),
                  ),
                ],
              ),
            ];
            return Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 14, 16, 14),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: l.moveUp,
                        onPressed: first || busy
                            ? null
                            : () => runShowingErrors(
                                context,
                                () => core.move(a, -1),
                              ),
                        icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      ),
                      Text('${a.position}', style: theme.textTheme.titleMedium),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: l.moveDown,
                        onPressed: last || busy
                            ? null
                            : () => runShowingErrors(
                                context,
                                () => core.move(a, 1),
                              ),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // The name takes all the room the button leaves.
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      a.name,
                                      style: theme.textTheme.titleMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _StatusPill(account: a),
                                  if (subscription != null) ...[
                                    const SizedBox(width: 6),
                                    Pill(
                                      licenseRemaining(l, subscription),
                                      icon: Icons.schedule_rounded,
                                      color: licenseRemainingColor(
                                        subscription,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!narrow && action != null) ...[
                              const SizedBox(width: 12),
                              action,
                            ],
                          ],
                        ),
                        if (a.name != a.email && a.email.isNotEmpty)
                          Text(a.email, style: muted),
                        if (subscription != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            l.subscriptionEnds(
                              formatDate(l, subscription.expiresAt),
                            ),
                            style: muted,
                          ),
                        ],
                        if (accountReason(l, a, threshold)
                            case final reason?) ...[
                          const SizedBox(height: 4),
                          Text(reason, style: muted),
                        ],
                        const SizedBox(height: 12),
                        if (usage == null)
                          Text(l.quotaNotRead, style: muted)
                        else if (usage.unlimited)
                          Text(l.unlimitedQuota, style: muted)
                        else ...[
                          QuotaBar(
                            percent: a.usedPercent,
                            threshold: threshold,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            [
                              l.usedOf(
                                formatBytes(usage.usedBytes),
                                formatBytes(usage.limitBytes),
                              ),
                              if (usage.resetAt != null)
                                l.resets(formatDate(l, usage.resetAt!)),
                            ].join(' · '),
                            style: muted,
                          ),
                        ],
                        if (narrow) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (action != null) ...[
                                action,
                                const SizedBox(width: 8),
                              ],
                              ...controls,
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!narrow) ...[const SizedBox(width: 16), ...controls],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _copyToken(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final token = license?.token;
    if (token == null) return;
    await Clipboard.setData(ClipboardData(text: token));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l.tokenCopied)));
    }
  }

  Future<void> _remove(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.removeTitle),
        content: Text(l.removeBody(account.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: StatusColors.bad),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.remove),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await runShowingErrors(context, () => core.remove(account));
    }
  }
}

/// Amber when the end is near, red once it is near enough to matter.
Color licenseRemainingColor(License license) {
  final left = license.remaining;
  if (left <= const Duration(days: 2)) return StatusColors.bad;
  if (left <= const Duration(days: 5)) return StatusColors.busy;
  return StatusColors.good;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final a = account;
    if (!a.enabled) return Pill(l.statusDisabled);
    if (a.active) {
      return Pill(
        l.statusActive,
        color: StatusColors.good,
        icon: Icons.bolt_rounded,
      );
    }
    return switch (a.status) {
      AccountStatus.ready => Pill(
        l.statusReady,
        color: Theme.of(context).colorScheme.primary,
      ),
      AccountStatus.reauthRequired => Pill(
        l.statusTokenNeeded,
        color: StatusColors.bad,
      ),
      AccountStatus.reserved => Pill(
        l.statusReserved,
        color: StatusColors.busy,
      ),
      AccountStatus.unavailable => Pill(
        a.retryAt != null
            ? l.statusUnavailableUntil(formatDate(l, a.retryAt!))
            : l.statusUnavailable,
        color: StatusColors.busy,
      ),
      _ => Pill(a.status),
    };
  }
}
