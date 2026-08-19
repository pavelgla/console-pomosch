# PATCHES.md — правки форка поверх апстрима RustDesk

Реестр по факту диффа, не по намерению. Заведён 16.08.2026 волной `w-full-debrand` — предыдущие
волны ребренда (T6–T71, начиная с 22.06.2026) в реестр задним числом не сведены, история по ним —
в `~/projects/helpdesk/_SUMMARY.md` и коммитах ветки `rebrand`.

## Волна `debrand-full` (16.08.2026) — полная зачистка видимых следов RustDesk

Спека: `~/projects/helpdesk/docs/superpowers/specs/2026-08-16-full-debrand.md`.
План: `~/projects/helpdesk/plans/full-debrand.md`.
Приёмка: `~/projects/helpdesk/tests/t71-debrand.sh` (79 ассертов, все группы ниже).

- **Группа A — Windows exe-метаданные.** `libs/portable/Cargo.toml` (name/description/winres),
  `flutter/windows/runner/Runner.rc` (InternalName/OriginalFilename), `src/platform/windows.rs`
  (заголовок окна вывода — заменён литерал на `crate::get_app_name()`), синхронное
  переименование `RuntimeBroker_rustdesk.exe` → `RuntimeBroker_consolehelp.exe` в
  `libs/portable/src/main.rs`, `res/msi/Package/Components/RustDesk.wxs`,
  `res/msi/CustomActions/CustomActions.cpp`. Побочно задета переименованием crate `name`:
  `Cargo.lock`, `libs/portable/Cargo.lock`, `build.py`, `.github/workflows/flutter-build.yml`
  (имя промежуточного артефакта сборки) — механические правки вслед за rename, не отдельный патч.
- **Группа B — CI.** `.github/workflows/flutter-build.yml`: `build-for-windows-sciter` переведён
  из закомментированного `# if: false` в активный `if: false` — публиковал
  `rustdesk-*-x86-sciter.exe` в релиз, апстримовый sciter-UI (`src/ui/index.tis`) ребрендингу не
  поддаётся. `.github/workflows/fdroid.yml`: job `update-fdroid-version-file` — `if: false`, мы
  не публикуемся в F-Droid.
- **Группа C — Linux.** `flutter/linux/my_application.cc` (GTK-заголовок окна и имя иконки в
  теме — литерал `rustdesk` → `consolehelp`), `res/consolehelp-link.desktop` (Name, TryExec,
  MimeType, StartupWMClass), `res/consolehelp.desktop` (StartupWMClass).
- **Группа D — macOS.** `flutter/macos/Runner/Configs/AppInfo.xcconfig` (PRODUCT_NAME,
  PRODUCT_COPYRIGHT), `flutter/macos/Runner.xcodeproj/project.pbxproj` (три вхождения
  `PRODUCT_BUNDLE_IDENTIFIER` → `ru.console10.consolehelp`, тот же id, что у iOS-сборки),
  `flutter/macos/Runner/Info.plist` (URL-схема → `consolehelp`), `Cargo.toml`
  (`[package.metadata.bundle] identifier`), `build.py`/`flutter-build.yml` (DMG: имя `.app`,
  иконка, volname — синхронно с PRODUCT_NAME). macOS ещё не раздаётся с лендинга (готовится),
  правка сделана заранее, чтобы не разъезжаться с уже отребренженным iOS.
- **Группа E — iOS.** `flutter/ios/Runner/Info.plist`: URL-схема `com.carriez.rustdesk`/
  `rustdesk` → `consolehelp` (согласована с macOS/Linux). **Уже в TestFlight** — требует новой
  сборки и заливки после мержа этой волны, приёмка на устройстве — отдельным циклом.
- **Группа F — Android.** `flutter/android/app/src/main/res/values/strings.xml` (app_name,
  accessibility_service_description — реально видна в Настройки → Спец. возможности), новый
  `values-ru/strings.xml` (RU-перевода этой строки не было вовсе), `AndroidManifest.xml`
  (`android:scheme` → `consolehelp`).
- **Группа G — локализация.** `src/lang/en.rs` и 47 из 51 файлов `src/lang/*.rs` — добавлены
  явные переводы трёх ключей (`About RustDesk`, `Show RustDesk`, `Keep RustDesk background
  service`), у которых раньше не было записи и рантайм (`src/lang.rs::translate_locale`)
  подставлял `get_app_name()` как фолбэк — не утечка бренда, но разнобой (латиница вместо
  согласованного текста). `ru.rs` не трогался (полон с T71), `template.rs` не трогался (штатные
  пустые заглушки для переводчиков).

## Сознательно НЕ патчено (известные ограничения, зафиксированы решением Павла 16.08)

- **Принтер-драйвер** (`res/msi/CustomActions/RemotePrinter.cpp`,
  `res/msi/preprocess.py::replace_app_name_in_custom_actions`) — апстрим принудительно откатывает
  имя драйвера на «RustDesk v4 Printer Driver» / `RustDeskPrinterDriver.inf`. Переименование
  требует новой подписи Microsoft WHQL для .inf/каталога — вне объёма ребренда. Виден в
  «Принтеры и сканеры» Windows только тем, кто туда целенаправленно зашёл.
- **`RustDeskTempTopMostWindow.exe`** (`.github/workflows/third-party-RustDeskTempTopMostWindow.yml`)
  — собирается из внешнего репозитория `rustdesk-org/RustDeskTempTopMostWindow` на пине коммита.
  Переименование потребовало бы форка ещё одного апстримового репозитория ради имени процесса,
  видимого только при целенаправленном поиске в Диспетчере задач в момент активной сессии.
- **Прямое подключение по IP не шифруется** (режим 2, редакция «Контур») — решение волны
  «Редакции» 08.08.2026, не относится к этой волне, упоминается для полноты картины ограничений
  форка. Подробности — `deploy/contour/RUNBOOK.md` в `~/projects/helpdesk`.
- **Функциональные ссылки на `rustdesk.com/docs/...`** в подсказках о правах доступа
  (X11/Wayland/macOS) — не бренд-метка, а рабочая документация, аналога которой у нас нет.

## Волна `w-appstore-ios` (19.08.2026) — манифест приватности iOS

Спека: `~/projects/helpdesk/docs/superpowers/specs/2026-08-19-appstore-ios-design.md`.
План: `~/projects/helpdesk/plans/appstore-ios.md`, Task 4.
Приёмка: `~/projects/helpdesk/tests/t72-appstore.sh`.

- **Новый `flutter/ios/Runner/PrivacyInfo.xcprivacy`.** Проверен код iOS-реализаций пяти плагинов,
  закреплённых в `flutter/pubspec.lock` на дату волны: `path_provider_foundation 2.4.1`,
  `package_info_plus 4.2.0`, `device_info_plus 9.1.2`, `sqflite 2.2.0`, `file_picker 5.5.0`.
  Из четырёх категорий required-reason API (`UserDefaults`, `FileTimestamp`, `DiskSpace`,
  `SystemBootTime`) в исходниках этих версий нашлось обращение только к одной: `file_picker`
  (`ios/Classes/FileUtils.m:92`) вызывает `[[NSFileManager defaultManager]
  attributesOfItemAtPath:path error:nil]` — это сигнатура из официального списка File Timestamp
  API. Причина — `C617.1` (метаданные файлов внутри контейнера приложения: `file_picker` читает
  атрибуты уже выбранных пользователем файлов из своей временной директории).
  `NSUserDefaults`, `statfs`/`getattrlist`/`volumeAvailableCapacity` (DiskSpace) и
  `systemUptime`/`mach_absolute_time` (SystemBootTime) в исходниках всех пяти плагинов не
  встретились — эти три категории в манифест не включены. `path_provider_foundation 2.4.1` несёт
  собственный `PrivacyInfo.xcprivacy` с пустым `NSPrivacyAccessedAPITypes` — сверка подтверждает
  вывод независимо. `NSPrivacyCollectedDataTypes` оставлен пустым: ни один из проверенных
  плагинов сам не передаёт данные за пределы устройства. Шаблон из `~/projects/conv42` (три
  категории: `UserDefaults`+`FileTimestamp`+`DiskSpace`) не подошёл — там иной набор пакетов
  (включая `shared_preferences`, которого в этом форке нет) и более новые версии
  `package_info_plus`/`device_info_plus`.
- **`flutter/ios/Runner.xcodeproj/project.pbxproj`.** Файл добавлен в таргет `Runner`: запись в
  `PBXFileReference` (`8D2520E5B200F258E5B7BE57`), в `PBXBuildFile` (`3AB5E0DCBB1D5B8D14BD0825`,
  `in Resources`), в группу `Runner` (`PBXGroup`) и в `PBXResourcesBuildPhase` таргета `Runner`.
  `plutil -lint` недоступен на Linux (нет macOS-инструментов); проверена балансировка скобок
  файла и однократное появление обеих новых записей в ожидаемых секциях — строгий линт переносится
  на CI-прогон сборки (`ios-build.yml`).
