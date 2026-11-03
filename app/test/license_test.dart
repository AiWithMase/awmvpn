import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:awmvpn/license.dart';
import 'package:awmvpn/ui/activate_dialog.dart';

void main() {
  group('the token store', () {
    late Directory dir;
    late LicenseStore store;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('awmvpn_licenses_');
      store = LicenseStore(File('${dir.path}/licenses.json'));
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('keeps the tokens across runs', () async {
      final license = License(
        token: 'awm_0123456789abcdef0123456789abcdef01234567',
        accountId: 'a1',
        label: 'AWMVPN',
        expiresAt: DateTime.utc(2026, 12, 3, 10, 11, 12),
      );
      await store.save([license]);

      final saved = await LicenseStore(store.file).load();
      expect(saved.single.token, license.token);
      expect(saved.single.accountId, 'a1');
      expect(saved.single.label, 'AWMVPN');
      expect(
        saved.single.expiresAt.toUtc(),
        DateTime.utc(2026, 12, 3, 10, 11, 12),
      );
    });

    test('a missing file is an empty list', () async {
      expect(await store.load(), isEmpty);
    });

    test('a half-written file does not lose the app', () async {
      await store.file.writeAsString('{"licenses": [');
      expect(await store.load(), isEmpty);
    });

    test('the date decides when a subscription ended', () {
      final live = License(
        token: 't',
        accountId: 'a',
        label: '',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );
      expect(live.expired, isFalse);
      final ended = License(
        token: 't',
        accountId: 'a',
        label: '',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(ended.expired, isTrue);
    });
  });

  group('the pasted token', () {
    test('is taken out of a deeplink, a message, or spaces', () {
      const token = 'awm_0123456789abcdef0123456789abcdef01234567';
      expect(normalizeToken(token), token);
      expect(normalizeToken('  $token  '), token);
      expect(normalizeToken('awmvpn://activate?t=$token'), token);
      expect(normalizeToken('Your token:\n$token\nKeep it safe.'), token);
    });
  });

  test('a server date is read as local time', () {
    final time = licenseTime('2026-12-03 10:11:12');
    expect(time, isNotNull);
    expect(time!.toUtc(), DateTime.utc(2026, 12, 3, 10, 11, 12));
    expect(
      licenseTime('2026-12-03T10:11:12Z')!.toUtc(),
      DateTime.utc(2026, 12, 3, 10, 11, 12),
    );
    expect(licenseTime(''), isNull);
    expect(licenseTime('not a date'), isNull);
  });
}
