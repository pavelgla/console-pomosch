// Сценарий съёмки кадров для карточки RuStore («Консоль Помощь», Android-эмулятор).
// Запускается только воркфлоу android-screenshots.yml; на релизные сборки не влияет.
//
// Сам кадр снимает хост (`adb exec-out screencap`): так в нём настоящий статус-бар и
// системная навигация. Тест печатает строку `SHOT <имя>` и стоит на месте 6 секунд, хост
// по этой строке в логе делает снимок. Секреты приходят через --dart-define и не печатаются.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/main.dart' as app;
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

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
  debugPrint('SHOT $name');
  await _wait(t, 6);
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

  testWidgets('кадры для RuStore', (tester) async {
    app.main(<String>[]);
    expect(
        await _until(
            tester,
            () =>
                globalKey.currentContext != null &&
                find.byType(BottomNavigationBar).evaluate().isNotEmpty,
            180),
        isTrue,
        reason: 'главный экран не поднялся');
    await _wait(tester, 4);

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
    await _wait(tester, 6);
    await _shot(tester, '02-address-book');

    // 04 — «Поделиться экраном» (до любых системных диалогов).
    final nav = find.descendant(
        of: find.byType(BottomNavigationBar), matching: find.byType(InkResponse));
    if (nav.evaluate().length >= 3) {
      await tester.tap(nav.at(2));
      await _wait(tester, 4);
    }
    await _shot(tester, '04-share');
    if (nav.evaluate().isNotEmpty) {
      await tester.tap(nav.at(0));
      await _wait(tester, 3);
    }

    // 03 — живой сеанс к демо-стенду
    debugPrint('VIDEO start');
    await connect(globalKey.currentContext!, _peerId, password: _peerPass);
    final inSession =
        await _until(tester, () => gFFI.ffiModel.pi.displays.isNotEmpty, 90);
    debugPrint('SESSION ${inSession ? "up" : "DOWN"}');
    await _wait(tester, 10);
    await _shot(tester, '03-session');
    await _wait(tester, 12);
    debugPrint('VIDEO stop');
    debugPrint('DONE');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
