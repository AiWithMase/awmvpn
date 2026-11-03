import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../app_settings.dart';
import '../core/core_api.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'about_page.dart';
import 'accounts_page.dart';
import 'format.dart';
import 'logs_page.dart';
import 'mobile_shell.dart';
import 'overview_page.dart';
import 'port_dialog.dart';
import 'servers_page.dart';
import 'settings_page.dart';
import 'welcome_page.dart';
import 'widgets.dart';

/// The brand's colors: the deep navy and violet of the home page, with the
/// mint accent, dark first. The light theme is the same family on paper.
abstract final class Brand {
  static const night = Color(0xFF070A18);
  static const nightRaised = Color(0xFF0F1430);
  static const nightHigh = Color(0xFF161D40);
  static const nightHighest = Color(0xFF1D2552);
  static const violet = Color(0xFF7C83FF);
  static const mint = Color(0xFF10D9A0);
  static const ink = Color(0xFF141B3D);
  static const indigo = Color(0xFF4B54D6);
  static const mintDeep = Color(0xFF0A9E76);
  static const paper = Color(0xFFF4F5FC);
}

ThemeData _theme(Brightness brightness, Locale locale) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Brand.violet,
        brightness: brightness,
      ).copyWith(
        primary: dark ? Brand.violet : Brand.indigo,
        onPrimary: dark ? const Color(0xFF090D1F) : Colors.white,
        primaryContainer: dark
            ? const Color(0xFF2A3170)
            : const Color(0xFFDDE0FF),
        onPrimaryContainer: dark
            ? const Color(0xFFE6E8FF)
            : const Color(0xFF11164A),
        secondary: dark ? const Color(0xFFA8AFDA) : const Color(0xFF5A6193),
        secondaryContainer: dark
            ? const Color(0xFF232B58)
            : const Color(0xFFE4E7FA),
        onSecondaryContainer: dark
            ? const Color(0xFFDDE2FF)
            : const Color(0xFF171D45),
        tertiary: dark ? Brand.mint : Brand.mintDeep,
        onTertiary: dark ? const Color(0xFF04231A) : Colors.white,
        tertiaryContainer: dark
            ? const Color(0xFF0B3A2C)
            : const Color(0xFFC8F7E6),
        onTertiaryContainer: dark
            ? const Color(0xFFC7FFEC)
            : const Color(0xFF04321F),
        error: dark ? const Color(0xFFFF6B85) : const Color(0xFFC0324B),
        surface: dark ? Brand.night : Brand.paper,
        onSurface: dark ? const Color(0xFFE9ECFF) : Brand.ink,
        onSurfaceVariant: dark
            ? const Color(0xFF9AA3C7)
            : const Color(0xFF565E85),
        surfaceContainerLowest: dark ? const Color(0xFF050813) : Colors.white,
        surfaceContainerLow: dark ? Brand.nightRaised : const Color(0xFFEDEFFA),
        surfaceContainer: dark ? Brand.nightHigh : Colors.white,
        surfaceContainerHigh: dark
            ? Brand.nightHighest
            : const Color(0xFFE7EAFA),
        surfaceContainerHighest: dark
            ? const Color(0xFF232C5E)
            : const Color(0xFFDCE0F3),
        outline: dark ? const Color(0xFF3A4370) : const Color(0xFFB9BFDC),
        outlineVariant: dark
            ? const Color(0xFF252C52)
            : const Color(0xFFD5D9EE),
        inverseSurface: dark ? const Color(0xFFE9ECFF) : Brand.ink,
        onInverseSurface: dark
            ? const Color(0xFF0A0E20)
            : const Color(0xFFE9ECFF),
      );
  // Vazirmatn for Persian and Arabic; the system font (Segoe UI)
  // otherwise. Styles set here name it too, or they would fall back to the
  // system font.
  final font = languageFont(locale.languageCode);
  final radius = BorderRadius.circular(14);
  return ThemeData(
    colorScheme: scheme,
    fontFamily: font,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? Brand.nightHigh : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.9)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? Brand.nightRaised : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: TextStyle(
          fontFamily: font,
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.7)),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: TextStyle(
          fontFamily: font,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: TextStyle(
          fontFamily: font,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? Brand.nightRaised : Colors.white,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? Brand.nightHighest : Brand.ink,
      contentTextStyle: TextStyle(fontFamily: font, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    popupMenuTheme: PopupMenuThemeData(
      color: dark ? Brand.nightHigh : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: dark ? Brand.nightRaised : const Color(0xFFEDEFFA),
      indicatorColor: scheme.primary.withValues(alpha: dark ? 0.22 : 0.14),
      // The menu's names semi-bold, the open page's bold.
      selectedLabelTextStyle: TextStyle(
        fontFamily: font,
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: font,
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
      selectedIconTheme: IconThemeData(size: 24, color: scheme.primary),
      unselectedIconTheme: IconThemeData(
        size: 24,
        color: scheme.onSurfaceVariant,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? Brand.nightRaised : const Color(0xFFEDEFFA),
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: dark ? 0.22 : 0.14),
    ),
  );
}

class VpnApp extends StatelessWidget {
  const VpnApp({
    super.key,
    required this.core,
    required this.settings,
    this.navigatorKey,
  });

  final CoreController core;
  final AppSettings settings;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => MaterialApp(
      navigatorKey: navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (locales, _) =>
          AppSettings.localeOf(AppSettings.languageForList(locales)),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // The theme depends on the resolved language for its font.
      builder: (context, child) {
        final locale = Localizations.localeOf(context);
        final dark = switch (settings.themeMode) {
          ThemeMode.dark => true,
          ThemeMode.light => false,
          ThemeMode.system =>
            MediaQuery.platformBrightnessOf(context) == Brightness.dark,
        };
        return Theme(
          data: _theme(dark ? Brightness.dark : Brightness.light, locale),
          child: child!,
        );
      },
      home: Shell(core: core, settings: settings),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.core, required this.settings});

  final CoreController core;
  final AppSettings settings;

  @override
  State<Shell> createState() => _ShellState();
}

enum _Page { overview, servers, accounts, settings, logs, about }

class _ShellState extends State<Shell> {
  _Page _page = _Page.overview;

  /// The settings section the home page opened (Connection), until another
  /// page is chosen.
  SettingsSection? _settingsOpening;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.core,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final core = widget.core;
      final status = core.status;
      final needsAttention = (core.accounts?.accounts ?? const [])
          .where((a) => a.enabled && a.needsSignIn)
          .length;
      if (widget.settings.firstRun && status != null) {
        return WelcomePage(core: core, settings: widget.settings);
      }
      final pages = [
        _Page.overview,
        _Page.servers,
        _Page.accounts,
        _Page.settings,
        _Page.logs,
        _Page.about,
      ];
      final page = pages.contains(_page) ? _page : _Page.overview;
      Widget accountsIcon(IconData icon) => Badge(
        isLabelVisible: needsAttention > 0,
        label: Text('$needsAttention'),
        child: Icon(icon),
      );
      // Each page's icons and name, for the side menu and the bottom bar.
      final items = [
        for (final page in pages)
          switch (page) {
            _Page.overview => (
              const Icon(Icons.dashboard_outlined),
              const Icon(Icons.dashboard_rounded),
              l.navOverview,
            ),
            _Page.servers => (
              const Icon(Icons.public_outlined),
              const Icon(Icons.public_rounded),
              l.navServers,
            ),
            _Page.accounts => (
              accountsIcon(Icons.people_outline_rounded),
              accountsIcon(Icons.people_rounded),
              l.navAccounts,
            ),
            _Page.settings => (
              const Icon(Icons.settings_outlined),
              const Icon(Icons.settings_rounded),
              l.navSettings,
            ),
            _Page.logs => (
              const Icon(Icons.receipt_long_outlined),
              const Icon(Icons.receipt_long_rounded),
              l.navLogs,
            ),
            _Page.about => (
              const Icon(Icons.info_outline_rounded),
              const Icon(Icons.info_rounded),
              l.navAbout,
            ),
          },
      ];
      final content = Column(
        children: [
          if (core.unavailable != null && status != null) const _LostBanner(),
          Expanded(
            child: status == null
                ? _NoCore(core: core)
                : switch (page) {
                    // Its cards open the pages beside it.
                    _Page.overview => OverviewPage(
                      core: core,
                      settings: widget.settings,
                      onOpenServers: () =>
                          setState(() => _page = _Page.servers),
                      onOpenAccounts: () =>
                          setState(() => _page = _Page.accounts),
                      onOpenConnection: () => setState(() {
                        _page = _Page.settings;
                        _settingsOpening = SettingsSection.connection;
                      }),
                    ),
                    _Page.servers => ServersPage(
                      core: core,
                      settings: widget.settings,
                    ),
                    _Page.accounts => AccountsPage(core: core),
                    _Page.settings => SettingsPage(
                      key: ValueKey(_settingsOpening),
                      core: core,
                      settings: widget.settings,
                      opening: _settingsOpening,
                    ),
                    _Page.logs => LogsPage(
                      core: core,
                      settings: widget.settings,
                    ),
                    _Page.about => AboutPage(core: core),
                  },
          ),
        ],
      );
      void select(int i) => setState(() {
        _page = pages[i];
        _settingsOpening = null;
      });
      // Android (a phone, or a tablet in either orientation) and a narrow
      // window: the phone layout, Home and Settings. The computer layout
      // offers computer-only choices, such as Windows' system proxy.
      if (Platform.isAndroid || MediaQuery.sizeOf(context).width < 640) {
        return MobileShell(
          core: core,
          settings: widget.settings,
          banner: core.unavailable != null && status != null
              ? const _LostBanner()
              : null,
          noCore: status == null ? _NoCore(core: core) : null,
        );
      }
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: pages.indexOf(page),
              onDestinationSelected: select,
              // Icons with their names beside them.
              extended: true,
              minExtendedWidth: 190,
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Row(
                  children: [
                    const AppLogo(size: 34),
                    const SizedBox(width: 10),
                    Text(
                      l.appTitle,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              destinations: [
                for (final (icon, selected, label) in items)
                  NavigationRailDestination(
                    icon: icon,
                    selectedIcon: selected,
                    label: Text(label),
                  ),
              ],
              // The traffic at the bottom of the menu; in a short window the
              // pages above it scroll rather than run under it.
              trailing: _TrafficPanel(traffic: status?.traffic),
              trailingAtBottom: true,
              scrollable: true,
            ),
            // A maximized window: the pages stay as wide as reads well; the
            // home page, centered by itself, keeps its colors to the edges.
            Expanded(
              child: page == _Page.overview || status == null
                  ? content
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: content,
                      ),
                    ),
            ),
          ],
        ),
      );
    },
  );
}

/// The side menu's traffic: the speed now and the total since the core
/// started, through Mozilla, up and down.
class _TrafficPanel extends StatelessWidget {
  const _TrafficPanel({required this.traffic});

  final Traffic? traffic;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = traffic;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: SizedBox(
        width: 166,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TrafficCard(
              title: l.liveTraffic,
              up: formatRate(t?.upRate ?? 0),
              down: formatRate(t?.downRate ?? 0),
            ),
            const SizedBox(height: 8),
            _TrafficCard(
              title: l.totalTraffic,
              up: formatBytes(t?.up ?? 0),
              down: formatBytes(t?.down ?? 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficCard extends StatelessWidget {
  const _TrafficCard({
    required this.title,
    required this.up,
    required this.down,
  });

  final String title;
  final String up;
  final String down;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget line(IconData icon, Color color, String text) => Row(
      children: [
        Icon(icon, size: 14, color: color),
        const Spacer(),
        Text(text, style: value),
      ],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          line(Icons.arrow_upward_rounded, StatusColors.good, up),
          line(Icons.arrow_downward_rounded, theme.colorScheme.primary, down),
        ],
      ),
    );
  }
}

class _LostBanner extends StatelessWidget {
  const _LostBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: StatusColors.bad.withValues(alpha: 0.14),
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
    child: Row(
      children: [
        const Icon(Icons.link_off_rounded, size: 18, color: StatusColors.bad),
        const SizedBox(width: 10),
        Expanded(child: Text(AppLocalizations.of(context).coreLost)),
      ],
    ),
  );
}

class _NoCore extends StatelessWidget {
  const _NoCore({required this.core});

  final CoreController core;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final problem = core.unavailable;
    final portTaken =
        problem != null &&
        (problem.problem == CoreProblem.portInUse ||
            problem.problem == CoreProblem.refused);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (problem == null || problem.problem == CoreProblem.starting) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l.startingCore, style: theme.textTheme.titleMedium),
            ] else ...[
              Icon(
                Icons.power_off_rounded,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(l.cantReachCore, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                describeProblem(l, problem),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (portTaken && core.moveStoppedCore != null)
                    FilledButton.icon(
                      onPressed: () async {
                        final port = await showPortDialog(
                          context,
                          taken: problem.detail,
                        );
                        if (port != null && context.mounted) {
                          await runShowingErrors(
                            context,
                            () => core.setAppPort(port),
                          );
                        }
                      },
                      icon: const Icon(Icons.settings_ethernet_rounded),
                      label: Text(l.changePort),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: core.retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l.retry),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
