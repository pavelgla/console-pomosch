Name:       consolehelp
Version:    1.4.8
Release:    0
Summary:    Консоль Помощь — удалённая поддержка
License:    AGPL-3.0
URL:        https://helpdesk.console10.ru
Vendor:     Console LLC
Requires:   gtk3 libxcb libXfixes alsa-lib libva pam gstreamer1-plugins-base
Recommends: libayatana-appindicator-gtk3 libxdo
# Бандл flutter несёт свои .so; без этого rpmbuild впишет их в Requires, и dnf не поставит пакет.
AutoReqProv: no

# Ребренд по образцу .deb из build.py: те же пути, юнит и ярлыки. Без /etc/pam.d, startwm.sh
# и xorg.conf — PAM-файл deb завязан на debian-стек (common-auth), на Fedora его нет.
# https://docs.fedoraproject.org/en-US/packaging-guidelines/Scriptlets/

%description
Клиент удалённой поддержки «Консоль Помощь».

%prep
# исходников нет, пакуется готовый бандл

%build
# исходников нет, пакуется готовый бандл

%install
mkdir -p "%{buildroot}/usr/share/consolehelp" && cp -r ${HBB}/flutter/build/linux/x64/release/bundle/* -t "%{buildroot}/usr/share/consolehelp"
install -Dm 644 $HBB/res/consolehelp.service "%{buildroot}/usr/lib/systemd/system/consolehelp.service"
install -Dm 644 $HBB/res/consolehelp.desktop "%{buildroot}/usr/share/applications/consolehelp.desktop"
install -Dm 644 $HBB/res/consolehelp-link.desktop "%{buildroot}/usr/share/applications/consolehelp-link.desktop"
install -Dm 644 $HBB/res/128x128@2x.png "%{buildroot}/usr/share/icons/hicolor/256x256/apps/consolehelp.png"
install -Dm 644 $HBB/res/scalable.svg "%{buildroot}/usr/share/icons/hicolor/scalable/apps/consolehelp.svg"
# ExecStop без абсолютного пути systemd не принимает (то же исправляет postinst deb)
sed -i "s|^ExecStop=pkill|ExecStop=/usr/bin/pkill|" "%{buildroot}/usr/lib/systemd/system/consolehelp.service"

%files
/usr/share/consolehelp/
/usr/lib/systemd/system/consolehelp.service
/usr/share/applications/consolehelp.desktop
/usr/share/applications/consolehelp-link.desktop
/usr/share/icons/hicolor/256x256/apps/consolehelp.png
/usr/share/icons/hicolor/scalable/apps/consolehelp.svg

%changelog
# не ведётся

%pre
# $1: 1 — установка, 2 — обновление
if [ "$1" = "2" ]; then
if [ -d /run/systemd/system ]; then
  systemctl stop consolehelp || true
fi
fi

%post
ln -sf /usr/share/consolehelp/consolehelp /usr/bin/consolehelp
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload || true
  systemctl enable consolehelp || true
  systemctl restart consolehelp || true
fi
update-desktop-database >/dev/null 2>&1 || true

%preun
# $1: 0 — удаление, 1 — обновление (новая версия уже стоит)
if [ "$1" = "0" ]; then
if [ -d /run/systemd/system ]; then
  systemctl stop consolehelp || true
  systemctl disable consolehelp || true
fi
fi

%postun
if [ "$1" = "0" ]; then
  rm -f /usr/bin/consolehelp
  update-desktop-database >/dev/null 2>&1 || true
fi
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload || true
fi
