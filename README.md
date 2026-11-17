# chkrootkit GUI 1.0.0

Графическое приложение для локальных проверок GNU/Linux через **chkrootkit**, **rkhunter**, **unhide** и **Lynis**. Интерфейс на Material 3 доступен на русском и английском языках. Предупреждения требуют ручной проверки; приложение сохраняет полный вывод утилит и не выполняет автоматическое удаление файлов.

## Использование

Откройте **Инструменты**, установите сканеры из репозитория дистрибутива, затем выберите инструмент на вкладке **Проверка**. Для chkrootkit можно задать каталог сканирования: `/` для текущей системы или корень смонтированной системы. Проверки процессов используют работающее ядро. Остальные подключённые инструменты проверяют текущую систему.

Результаты доступны в **Разборе**, **Выводе** и **Находках**, экспорт — в `.log`. Вкладка **Справка** содержит офлайн-руководство, параметры сканеров, справочник угроз, описание хранения данных и сборки. Документы включены в [assets/docs](assets/docs).

Административные операции выполняет отдельный C++17-сервис через `pkexec`. chkrootkit, rkhunter и unhide требуют root независимо от места установки. Для Lynis доступен ограниченный аудит без root. Нужны polkit, сеансовый D-Bus и агент аутентификации. seatd обеспечивает доступ композитора к устройствам; авторизацию обрабатывает polkit.

Сервис можно оставлять запущенным до закрытия приложения либо завершать после каждой операции. Для обычной установки используйте системный каталог с владельцем root. Разрешение запуска сервиса из пользовательского каталога предназначено для разработки.

## Сборка

Проверено с **Flutter 3.47.1 / Dart 3.13.1**. Нужны Linux, C++17-компилятор, CMake, Ninja, pkg-config и библиотеки разработки GTK 3. Сервис можно собирать без Flutter.

```bash
make build                                  # release: приложение + сервис
make service                                # только C++-сервис
make build FLUTTER=/opt/flutter/bin/flutter MODE=debug JOBS=4
make tui                                    # терминальный менеджер сборки
make package FORMAT=deb                     # также rpm, appimage, pkg.tar.zst, all
```

`make tui` и `./build.sh` открывают Textual-менеджер с формой параметров, журналом и отменой процесса. При первом запуске Python 3.10+ с venv/pip создаёт `.venv-tui` и устанавливает Textual **8.2.8**; следующие запуски используют это окружение. Tab переключает фокус, Ctrl+B запускает сборку, Ctrl+K отменяет, Ctrl+Q закрывает менеджер. Дополнительные поля доступны прокруткой формы.

Командная сборка работает без Textual:

```bash
./build.sh --help
./build.sh --target service --mode debug --jobs 4
./build.sh --target app --package all --output-dir dist
./build.sh --bundle-dir build/linux/x64/release/bundle --package pkg.tar.zst
pacman -Qip build/packages/chkrootkit_gui-1.0.0-1-x86_64.pkg.tar.zst
```

Для `.deb` нужен `dpkg-deb`, для `.rpm` — `rpmbuild`, для AppImage — `appimagetool`, для Arch — `bsdtar` и `zstd`. Метаданные проверяются доступными пакетными инструментами; `.PKGINFO` размещается в корне Arch-архива. AppImage использует системные GTK, polkit и SQLite. До распространения проверьте пакеты на целевых дистрибутивах. `debootstrap` подходит для отдельной проверки Debian rootfs и автоматически не запускается.

## API и данные

На вкладке **Находки** доступен дополнительный анализ через GPTunnel или OpenAI-совместимый сервер. Для GPTunnel используется `https://gptunnel.ru/v1`; формат авторизации учитывается отдельно. Статус под полем ключа показывает, загружен ли ключ. HTTP 401 относится к авторизации, 402 — к платёжному балансу.

Весь вывод выбранной проверки отправляется по явному нажатию кнопки. Он может содержать личные сведения. Ответ оформляется как Markdown; внешние изображения не загружаются, ссылки копируются в буфер обмена. Язык нового ответа соответствует выбранному языку интерфейса.

Профиль хранится в `$XDG_CONFIG_HOME/chkrootkit_gui/api.db`, кэш — в `$XDG_CACHE_HOME/chkrootkit_gui/requests.db`. По умолчанию используются `~/.config` и `~/.cache`. На Linux нужна `libsqlite3.so.0`. Содержимое профиля и ответов зашифровано AES-256-GCM с ключом от пароля через PBKDF2-HMAC-SHA256 (210 000 итераций). Структура SQLite и служебные метаданные остаются видимыми. Пароль не сохраняется и не восстанавливается.

Ключ API сохраняется только при отдельном включении опции. Кэш ограничен 100 ответами и семью днями; исходные логи и ключи в него не записываются. При открытии различаются новые, корректные, старые и повреждённые базы. **Удалить обе базы…** требует подтверждения; экспортированные `.log` сохраняются. Удаление файлов не гарантирует стирание резервных копий, снимков и блоков SSD.

Оформление, ручной акцент и язык сохраняются в `appearance.json`. matugen для ручной палитры не нужен. Вывод сканеров и уже полученные ответы сохраняют исходный язык.

## Проверки и релиз

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
python3 -m unittest discover -s tests -p 'test_*.py'
make .venv-tui/.ready
.venv-tui/bin/python -m unittest discover -s tests -p 'test_build_manager.py'
```

[Release workflow](.github/workflows/release.yml) запускается **только вручную**: Actions → Release → Run workflow. Укажите версию из `pubspec.yaml` и [CHANGELOG.md](CHANGELOG.md). По умолчанию workflow сохраняет артефакты; параметр `publish` создаёт GitHub Release, `draft` управляет черновиком. Описание берётся из раздела changelog, к пакетам добавляются SHA256-суммы. Для появления кнопки workflow должен находиться в основной ветке. Выпуск с уже существующим тегом автоматически не перезаписывается.

Описание школьного проекта: [presentation/описание.docx](presentation/описание.docx). Исходные шаблоны сохранены. Дополнительные инструкции для разработки: [docs/CODEX_SETUP.md](docs/CODEX_SETUP.md).

## English

chkrootkit GUI provides a Russian/English Material 3 interface for local GNU/Linux scanning tools. Open **Help** for the complete offline English guide, scanner arguments, storage details and build instructions. Use `make build` for the application, `make service` for the C++ helper, or `make tui` for the interactive Textual build manager. Packaging supports `.deb`, `.rpm`, `.AppImage` and `.pkg.tar.zst`. Releases are triggered manually in GitHub Actions and use the changelog for release notes.
