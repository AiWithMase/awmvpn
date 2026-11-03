import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The product's server: the `awmvpn-server` plugin on the brand's site. A
/// token bought from the Telegram bot is exchanged here for the Firefox
/// credentials that make an account in the core, and its end date is read
/// from the same answer.
class LicenseApi {
  LicenseApi({
    Uri? base,
    HttpClient? client,
    this.timeout = const Duration(seconds: 25),
  }) : base = base ?? Uri.parse('https://www.aiwithmase.ir/wp-json/awmvpn/v1'),
       _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 15);
  }

  /// The API's root, the same the bot uses.
  final Uri base;
  final Duration timeout;
  final HttpClient _client;

  void close() => _client.close(force: true);

  /// Whether a token is still good, without spending it.
  Future<LicenseCheck> check(String token) async =>
      LicenseCheck.fromJson(await _post('/client/check', token));

  /// The Firefox credentials behind a token. The token is not consumed: the
  /// same value works on the user's other devices until it ends.
  Future<LicenseAccount> redeem(String token) async =>
      LicenseAccount.fromJson(await _post('/client/redeem', token));

  Future<Map<String, Object?>> _post(String path, String token) async {
    final uri = base.replace(
      path: '${base.path}$path',
      query: null,
      fragment: null,
    );
    final keys = _secrets(token);
    try {
      final req = await _client.postUrl(uri).timeout(timeout);
      req.headers.contentType = ContentType.json;
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      // A bot-style user agent: some hosts answer an empty one rudely.
      req.headers.set(HttpHeaders.userAgentHeader, 'awmvpn-client/1.0');
      req.write(jsonEncode({'token': token}));
      final res = await req.close().timeout(timeout);
      final text = await res.transform(utf8.decoder).join().timeout(timeout);
      final decoded = text.isEmpty ? null : jsonDecode(text);
      if (res.statusCode >= 400) throw _error(res.statusCode, decoded, text);
      if (decoded is! Map<String, Object?>) {
        throw const LicenseException(
          LicenseProblem.server,
          'unreadable answer',
        );
      }
      return decoded;
    } on LicenseException catch (e) {
      throw LicenseException(e.problem, _scrub(e.message, keys));
    } on SocketException catch (e) {
      throw LicenseException(LicenseProblem.network, _scrub(e.message, keys));
    } on HandshakeException catch (e) {
      throw LicenseException(LicenseProblem.network, _scrub(e.message, keys));
    } on HttpException catch (e) {
      throw LicenseException(LicenseProblem.network, _scrub(e.message, keys));
    } on TimeoutException {
      throw const LicenseException(LicenseProblem.network, 'timeout');
    } on FormatException {
      throw const LicenseException(LicenseProblem.server, 'unreadable answer');
    }
  }

  /// WordPress' error body: `{"code": "...", "message": "...",
  /// "data": {"status": 403, "reason": "expired"}}`.
  LicenseException _error(int status, Object? decoded, String text) {
    final data = switch (decoded) {
      {'data': final Map<String, Object?> d} => d,
      _ => const <String, Object?>{},
    };
    final reason = switch (data['reason']) {
      final String r when r.isNotEmpty => r,
      _ => '',
    };
    final message = switch (decoded) {
      {'message': final String m} when m.isNotEmpty => m,
      _ => text.length > 200 ? text.substring(0, 200) : text,
    };
    final problem = switch (status) {
      429 => LicenseProblem.throttled,
      >= 500 => LicenseProblem.server,
      _ when reason.isEmpty =>
        status == 404 ? LicenseProblem.unknown : LicenseProblem.server,
      _ => _problemFor(reason),
    };
    return LicenseException(problem, message);
  }

  /// Hides the token from a message the app may show or log.
  static List<String> _secrets(String token) => [
    if (token.length > 8) token,
    if (token.length > 16) token.substring(0, 16),
  ];

  static String _scrub(String text, List<String> secrets) {
    var out = text;
    for (final secret in secrets) {
      out = out.replaceAll(secret, 'awm_…');
    }
    return out;
  }
}

/// Why a token was refused, in the app's own words.
enum LicenseProblem {
  /// No token like it: mistyped, or from another product.
  unknown,

  /// Its end date has passed.
  expired,

  /// The bot's owner ended it (the user asked, or it was refunded).
  revoked,

  /// The Firefox account behind it is gone; support must look.
  accountUnavailable,

  /// Too many tries from this address or with this token.
  throttled,

  /// The app could not reach the server.
  network,

  /// The server answered with an error of its own.
  server,
}

class LicenseException implements Exception {
  const LicenseException(this.problem, [this.message = '']);

  final LicenseProblem problem;
  final String message;

  @override
  String toString() => message.isEmpty ? problem.name : message;
}

LicenseProblem _problemFor(String reason) => switch (reason) {
  'expired' => LicenseProblem.expired,
  'revoked' => LicenseProblem.revoked,
  'account_unavailable' ||
  'account_broken' => LicenseProblem.accountUnavailable,
  'unknown' => LicenseProblem.unknown,
  _ => LicenseProblem.server,
};

/// A token read: whether it works and when it ends.
class LicenseCheck {
  LicenseCheck.fromJson(Map<String, Object?> j)
    : valid = j['valid'] == true,
      reason = _string(j['reason']),
      expiresAt = licenseTime(j['expires_at']),
      secondsLeft = _seconds(j['seconds_left']);

  final bool valid;
  final String reason;
  final DateTime? expiresAt;
  final int secondsLeft;
}

/// The Firefox credentials behind a token, as the server hands them over.
class LicenseAccount {
  LicenseAccount.fromJson(Map<String, Object?> j)
    : label = _string(j['label']),
      email = _string(j['email']),
      refreshToken = _string(j['refresh_token']),
      accessToken = _string(j['access_token']),
      scope = _string(j['scope']),
      expiresIn = _seconds(j['expires_in']),
      expiresAt = licenseTime(j['expires_at']);

  final String label;
  final String email;
  final String refreshToken;
  final String accessToken;
  final String scope;
  final int expiresIn;
  final DateTime? expiresAt;
}

/// A token this app activated: the token itself (so the user can see it
/// again), the core account it made, and when the subscription ends.
class License {
  License({
    required this.token,
    required this.accountId,
    required this.label,
    required this.expiresAt,
  });

  factory License.fromJson(Map<String, Object?> j) => License(
    token: _string(j['token']),
    accountId: _string(j['account_id']),
    label: _string(j['label']),
    expiresAt:
        licenseTime(j['expires_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
  );

  final String token;
  final String accountId;
  final String label;
  final DateTime expiresAt;

  Duration get remaining => expiresAt.difference(DateTime.now());

  bool get expired => !expiresAt.isAfter(DateTime.now());

  Map<String, Object?> toJson() => {
    'token': token,
    'account_id': accountId,
    'label': label,
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };
}

/// The activated tokens, kept in `licenses.json` in the app's data folder
/// beside the core's files. A token is the user's receipt: losing the phone
/// loses the account, but the token itself can be entered again.
class LicenseStore {
  LicenseStore(this.file);

  /// The store in [dataDir], the folder the core's files are in.
  factory LicenseStore.inDataDir(String dataDir) =>
      LicenseStore(File('$dataDir${Platform.pathSeparator}licenses.json'));

  final File file;

  Future<List<License>> load() async {
    String text;
    try {
      text = await file.readAsString();
    } on FileSystemException {
      return const [];
    }
    try {
      final j = jsonDecode(text);
      final rows = switch (j) {
        {'licenses': final List<Object?> rows} => rows,
        _ => const <Object?>[],
      };
      return [
        for (final row in rows)
          if (row is Map<String, Object?>) License.fromJson(row),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> save(Iterable<License> licenses) async {
    await file.parent.create(recursive: true);
    final text = const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'licenses': [for (final l in licenses) l.toJson()],
    });
    // Written beside and moved over, so a crash mid-write cannot leave a
    // half file that loses every token.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(text, flush: true);
    await temp.rename(file.path);
  }
}

/// A server time (`2026-12-03 10:11:12`, UTC) as local time; null when the
/// value is empty or unreadable.
DateTime? licenseTime(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  final text = value.trim();
  final iso = text.contains('T') ? text : text.replaceFirst(' ', 'T');
  final ended = iso.endsWith('Z') || iso.contains('+');
  return DateTime.tryParse(ended ? iso : '${iso}Z')?.toLocal();
}

String _string(Object? v) => v is String ? v : '';

int _seconds(Object? v) => switch (v) {
  final int i => i,
  final double d => d.round(),
  final String s => int.tryParse(s) ?? 0,
  _ => 0,
};
