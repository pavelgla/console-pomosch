// Сценарий съёмки кадров для карточки App Store («Консоль Помощь», iOS-симулятор).
// Запускается только воркфлоу ios-screenshots.yml; на релизные сборки не влияет.
//
// Сам кадр снимает хост (`xcrun simctl io screenshot`): так в него попадает настоящий
// статус-бар симулятора. Тест просит кадр файлом `req_<имя>` в каталоге SHOT_DIR и ждёт,
// пока хост положит рядом `ack_<имя>`.
//
// Секреты приходят через --dart-define (SHOTS_USER, SHOTS_PASS, SHOTS_PEER_PASS) и
// нигде не печатаются.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/main.dart' as app;
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _shotDir = String.fromEnvironment('SHOT_DIR', defaultValue: '/tmp/shots');
const _user = String.fromEnvironment('SHOTS_USER');
const _pass = String.fromEnvironment('SHOTS_PASS');
const _peerId = String.fromEnvironment('SHOTS_PEER_ID', defaultValue: '361107164');
const _peerPass = String.fromEnvironment('SHOTS_PEER_PASS');

Future<void> _wait(WidgetTester t, int seconds) async {
  for (var i = 0; i < seconds * 4; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _shot(WidgetTester t, String name) async {
  await _wait(t, 2);
  Directory(_shotDir).createSync(recursive: true);
  File('$_shotDir/req_$name').writeAsStringSync('1');
  final ack = File('$_shotDir/ack_$name');
  for (var i = 0; i < 80 && !ack.existsSync(); i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
  debugPrint('SHOT $name ${ack.existsSync() ? "ok" : "TIMEOUT"}');
}

Future<bool> _until(WidgetTester t, bool Function() cond, int seconds) async {
  for (var i = 0; i < seconds * 4; i++) {
    if (cond()) return true;
    await t.pump(const Duration(milliseconds: 250));
  }
  return cond();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('кадры для App Store', (tester) async {
    app.main(<String>[]);
    expect(await _until(tester, () => globalKey.currentContext != null &&
        find.byIcon(Icons.arrow_forward).evaluate().isNotEmpty, 120), isTrue,
        reason: 'главный экран не поднялся');
    await _wait(tester, 3);

    // 01 — главный экран
    await _shot(tester, '01-main');

    // 02 — адресная книга под демо-учёткой
    final resp = await gFFI.userModel.login(LoginRequest(
        username: _user,
        password: _pass,
        id: await bind.mainGetMyId(),
        uuid: await bind.mainGetUuid(),
        autoLogin: true,
        type: HttpType.kAuthReqTypeAccount));
    expect(resp.access_token, isNotNull, reason: 'вход демо-учёткой не удался');
    await bind.mainSetLocalOption(key: 'access_token', value: resp.access_token!);
    await bind.mainSetLocalOption(
        key: 'user_info', value: jsonEncode(resp.user ?? {}));
    gFFI.userModel.refreshCurrentUser();
    await _wait(tester, 4);
    final abTip = gFFI.peerTabModel.tabTooltip(PeerTabIndex.ab.index);
    final abTab = find.byWidgetPredicate((w) => w is Tooltip && w.message == abTip);
    if (abTab.evaluate().isNotEmpty) {
      await tester.tap(abTab.first);
    } else {
      gFFI.peerTabModel.setCurrentTab(PeerTabIndex.ab.index);
    }
    await _wait(tester, 5);
    await _shot(tester, '02-address-book');

    // 03 — живой сеанс к демо-стенду
    var inSession = false;
    for (var attempt = 1; attempt <= 3 && !inSession; attempt++) {
      await connect(globalKey.currentContext!, _peerId, password: _peerPass);
      inSession = await _until(
          tester, () => gFFI.ffiModel.pi.displays.isNotEmpty, 60);
      debugPrint('ATTEMPT $attempt ${inSession ? "up" : "failed"}');
      if (!inSession) {
        // закрыть окно с ошибкой и вернуться на главный экран перед повтором
        gFFI.dialogManager.dismissAll();
        await _wait(tester, 2);
        final nav = Navigator.of(globalKey.currentContext!);
        while (nav.canPop()) {
          nav.pop();
          await _wait(tester, 1);
        }
      }
    }
    debugPrint('SESSION ${inSession ? "up" : "DOWN"}');
    await _wait(tester, 8);
    await _shot(tester, '03-session');

    // 04 — панель жестов поверх сеанса
    final touch = find.byIcon(Icons.touch_app);
    final mouse = find.byIcon(Icons.mouse);
    if (touch.evaluate().isEmpty && mouse.evaluate().isEmpty) {
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) await tester.tap(fab.first);
      await _wait(tester, 2);
    }
    final btn = touch.evaluate().isNotEmpty ? touch : mouse;
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn.first);
      await _wait(tester, 3);
    }
    await _shot(tester, '04-gestures');
    File('$_shotDir/done').writeAsStringSync('1');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
