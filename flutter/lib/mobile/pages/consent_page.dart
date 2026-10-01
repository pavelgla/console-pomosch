import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

const kConsentPrivacyUrl = 'https://console10.ru/helpdesk/privacy';
const kConsentTermsUrl = 'https://console10.ru/helpdesk/oferta';
// Флаг хранится в локальных опциях клиента (main.dart), на сервер не уходит.
const kConsentOptionKey = 'consent-accepted';

Future<void> _launch(String url) async {
  await launchUrlString(url, mode: LaunchMode.externalApplication);
}

/// Пока пользователь не принял политику и условия, показывает экран согласия
/// вместо [child] (главного экрана). Хранилище и открытие ссылок подменяются в тестах.
class ConsentGate extends StatefulWidget {
  final Widget child;
  final bool Function() isAccepted;
  final Future<void> Function() onAccept;
  final Future<void> Function(String url) openUrl;

  /// Хранилище передаётся снаружи (main.dart): экран не зависит от FFI-моста.
  ConsentGate({
    Key? key,
    required this.child,
    required this.isAccepted,
    required this.onAccept,
    Future<void> Function(String url)? openUrl,
  })  : openUrl = openUrl ?? _launch,
        super(key: key);

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  late bool _accepted = widget.isAccepted();

  Future<void> _accept() async {
    await widget.onAccept();
    if (mounted) setState(() => _accepted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted) return widget.child;
    final link = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
      fontSize: 16,
    );
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text('Консоль Помощь',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                'Приложение даёт удалённый доступ к устройству: специалист видит '
                'экран и может им управлять только пока вы разрешаете подключение. '
                'Чтобы продолжить, ознакомьтесь с документами и примите их.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: () => widget.openUrl(kConsentPrivacyUrl),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Политика конфиденциальности', style: link),
                ),
              ),
              InkWell(
                onTap: () => widget.openUrl(kConsentTermsUrl),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Условия использования', style: link),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _accept,
                  child: const Text('Принимаю'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
