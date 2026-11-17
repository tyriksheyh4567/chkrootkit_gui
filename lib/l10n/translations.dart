// Interface translations. Scanner logs and model responses are preserved.
const english = <String, String>{
  'Изображение': 'Image',
  'без описания': 'no description',
  "Справка": "Help",
  "Руководство": "User guide",
  "Параметры сканеров": "Scanner arguments",
  "Справочник угроз": "Threat reference",
  "Хранение данных": "Data storage",
  "Сборка и релизы": "Build and release",
  "Не удалось открыть справку.": "Could not open help.",
  "Тема": "Theme",
  "Системная тема": "System theme",
  "Светлая тема": "Light theme",
  "Тёмная тема": "Dark theme",
  "Проверка": "Scan",
  "Находки": "Findings",
  "Инструменты": "Tools",
  "Проверка хоста": "Host scan",
  "Запускайте установленные CLI-инструменты из одного окна.":
      "Run installed scanning tools from one window.",
  "Инструмент": "Tool",
  "Каталог сканирования": "Scan directory",
  "Корень проверяемой системы": "Target filesystem root",
  "/ или /mnt/system": "/ or /mnt/system",
  "По умолчанию /. Для смонтированной системы будет передан chkrootkit -r <путь>. Проверки процессов относятся к работающему ядру.": "Defaults to /. For a mounted system, chkrootkit receives -r <path>. Process checks use the running kernel.",
  "Этот инструмент проверяет работающую систему. Выбор другого каталога для него не поддерживается.": "This tool checks the running system. It does not support a different scan directory.",
  "Дополнительные параметры запуска": "Advanced launch options",
  "Проверяю наличие бинарника…": "Looking for the executable…",
  "Не найден в PATH": "Not found in PATH",
  "Найден в PATH": "Found in PATH",
  "Права root через pkexec": "Root access through pkexec",
  "Для полного аудита нужен root; без него аудит ограничен.": "Root access provides a full audit; an unprivileged audit has limited coverage.",
  "Требуется для запуска сканера, в том числе из ~/.local/bin.":
      "Required to run this scanner, including from ~/.local/bin.",
  "pkexec не найден": "pkexec not found",
  "Разрешить запуск без владельца root":
      "Allow a helper owned by a regular user",
  "Опасно: headless-сервис сможет стартовать из пользовательского каталога": "Warning: the privileged service can start from a user-writable directory.",
  "Headless-сервис принимает только системный бинарник; настройка действует при его запуске": "Use a system-installed service. This setting is checked when the service starts.",
  "Оставлять headless-сервис запущенным": "Keep the privileged service running",
  "Выключите, чтобы завершать отдельный сервис после каждой операции":
      "Disable to stop the service after each operation.",
  "Остановить": "Stop",
  "Запустить проверку": "Start scan",
  "Разбор": "Summary",
  "Вывод": "Output",
  "Экспорт .log": "Export .log",
  "Результат сканера требует проверки администратором. Сигнатурные утилиты не гарантируют отсутствие неизвестного rootkit.": "An administrator should review the results. Signature tools may miss an unknown rootkit.",
  "Явных предупреждений по простому разбору не найдено.":
      "No explicit warning markers found.",
  "Показаны первые 30 предупреждений. Откройте «Вывод» для полного вывода.":
      "Showing the first 30 warnings. Open Output for the complete log.",
  "Готово к проверке": "Ready to scan",
  "Проверка выполняется": "Scan in progress",
  "Проверка завершена": "Scan complete",
  "Есть предупреждения": "Warnings found",
  "Ошибка запуска": "Launch error",
  "Рекомендуемый стек": "Complementary tools",
  "Интерфейс GTK работает в сеансе композитора, в том числе с seatd. Запросы прав root обрабатывает агент polkit.": "The GTK interface runs in compositor sessions, including those using seatd. A polkit agent handles root authorization.",
  "Комплементарные локальные проверки сигнатур, бинарников, модулей и файловых признаков.": "Complementary checks of signatures, executables, modules and file indicators.",
  "Сравнение представлений процессов помогает заметить сокрытие. Проверка портов требует отдельной утилиты unhide-tcp.": "Comparing process views helps detect hidden processes. Port checks require the separate unhide-tcp utility.",
  "Для постоянного мониторинга: скрытые процессы, файлы, порты и системные вызовы.": "Continuous monitoring of hidden processes, files, ports and system calls.",
  "Поведенческие правила на eBPF для загрузки модулей, неожиданных exec и сетевых действий.": "eBPF rules for module loading, unexpected executions and network activity.",
  "Аудит защиты и конфигурации системы помогает оценить обнаруженные предупреждения.":
      "Security and configuration audits provide context for scanner warnings.",
  "ClamAV для РФ": "ClamAV in Russia",
  "Для обновления баз используйте зеркало Yandex (clamav-mirror.yandex.ru) или зеркало вашего дистрибутива; задайте его в freshclam.conf и проверьте доступность HTTPS.": "Use the Yandex mirror (clamav-mirror.yandex.ru) or a distribution mirror for database updates. Set it in freshclam.conf and check HTTPS availability.",
  "Установка отсутствующих инструментов": "Install missing tools",
  "Репозиторий": "Repository",
  "Не найден": "Not found",
  "Установить": "Install",
  "Выберите инструмент и запустите проверку.":
      "Select a tool and start a scan.",
  "Сигнатуры, троянские бинарники и аномалии /proc":
      "Signatures, trojaned binaries and /proc anomalies",
  "Известные rootkit, изменённые файлы и подозрительные настройки":
      "Known rootkits, modified files and suspicious settings",
  "Сверка процессов через /proc, ps и системные вызовы":
      "Compare processes using /proc, ps and system calls",
  "Аудит конфигурации и признаков компрометации хоста":
      "Audit configuration and signs of host compromise",
  "Не удалось сохранить оформление.": "Could not save appearance preferences.",
  "Нужны системные утилиты": "Scanning tools are required",
  "Откройте вкладку «Инструменты», чтобы установить пакеты. Для ClamAV в РФ используйте зеркало Yandex или зеркало вашего дистрибутива.": "Open Tools to install packages. For ClamAV in Russia, use a Yandex or distribution mirror.",
  "Позже": "Later",
  "Открыть инструменты": "Open tools",
  "Не удалось сохранить лог. Проверьте каталог, права и отсутствие файла с таким именем.": "Could not save the log. Check the directory, permissions and whether the file already exists.",
  "pkexec не найден. Установите polkit/pkexec и запустите агент аутентификации.": "pkexec not found. Install polkit/pkexec and start an authentication agent.",
  "Проверка превысила лимит 10 минут и была остановлена.":
      "The scan exceeded the 10-minute limit and was stopped.",
  "Проверка остановлена пользователем.": "Scan stopped by the user.",
  "Переменная HOME не задана": "HOME is not set",
  "Поддерживаемый пакетный менеджер не найден.":
      "No supported package manager found.",
  "Для системной установки нужен pkexec/polkit.":
      "System installation requires pkexec/polkit.",
  "Анализ через API": "API analysis",
  "По нажатию весь вывод этой проверки будет отправлен на указанный сервер. Он может содержать имена файлов, пользователей и адреса. Ключ сохраняется на диск только по отдельному выбору.": "Submitting sends this scan's complete output to the specified server. It may contain file names, user names and addresses. Saving the API key to disk is optional.",
  "Открытие баз API": "Opening API databases",
  "Совместимость API": "API compatibility",
  "Base URL или полный endpoint": "Base URL or full endpoint",
  "Модель": "Model",
  "API-ключ GPTunnel (обязательно)": "GPTunnel API key (required)",
  "API-ключ (если требуется)": "API key (if required)",
  "Ключ есть в базе. Нажмите «Загрузить API из базы».":
      "A key is saved. Click Reload API profile.",
  "Ключ отсутствует. Введите API-ключ своего аккаунта.":
      "No key loaded. Enter your account's API key.",
  "Ключ загружен из зашифрованной базы.":
      "Key loaded from the encrypted database.",
  "Ключ введён; в базе также есть сохранённый ключ.":
      "Key entered. A key is also saved in the database.",
  "Ключ введён только для текущего сеанса.":
      "Key entered for this session only.",
  "Скрыть ключ": "Hide key",
  "Показать ключ": "Show key",
  "Сохранять API-ключ в api.db": "Save API key in api.db",
  "Для сохранения ключа включите опцию и нажмите «Сохранить API». Без неё сохраняются только URL, модель и провайдер.": "Enable this option and click Save API to store the key. Otherwise, only the URL, model and provider are saved.",
  "Кэшировать анализ на 7 дней": "Cache analysis for 7 days",
  "Отдельная requests.db: до 100 ответов; исходные логи и ключи не сохраняются в кэше.": "Separate requests.db stores up to 100 responses. Source logs and API keys are excluded from the cache.",
  "Загрузить API из базы": "Reload API profile",
  "Открыть зашифрованные базы": "Open encrypted databases",
  "Удалить обе базы…": "Delete both databases…",
  "Сохранить API": "Save API",
  "Удалить сохранённый API": "Delete saved API profile",
  "Очистить кэш": "Clear cache",
  "Отправить вывод на анализ": "Send output for analysis",
  "Отменить анализ": "Cancel analysis",
  "Анализ выполняется": "Analysis in progress",
  "Ответ из локального кэша; запрос не отправлялся.":
      "Response from the local cache. No request was sent.",
  "Ответ модели — предположение, требующее ручной проверки.":
      "Model responses require manual verification.",
  "В базе нет сохранённого API-профиля. Введите настройки и сохраните их.":
      "No saved API profile. Enter your settings and save them.",
  "Профиль загружен, но API-ключ в нём не сохранён. Введите ключ; для следующих запусков включите сохранение ключа и нажмите «Сохранить API».": "Profile loaded without an API key. Enter the key. To reuse it later, enable key storage and click Save API.",
  "Не удалось расшифровать API-профиль.": "Could not decrypt the API profile.",
  "Базы повреждены или не завершены": "Databases are damaged or incomplete",
  "Закрыть": "Close",
  "Не удалось открыть SQLite-базы. Проверьте права и libsqlite3.":
      "Could not open SQLite databases. Check permissions and libsqlite3.",
  "Введите ключ перед сохранением.": "Enter a key before saving.",
  "Настройки и зашифрованный ключ сохранены в api.db":
      "Settings and the encrypted key were saved in api.db.",
  "Настройки сохранены БЕЗ API-ключа. Ключ останется только в текущем сеансе.": "Settings saved without the API key. The key remains available for this session.",
  "Не удалось сохранить настройки. Проверьте URL и доступ к базе.":
      "Could not save settings. Check the URL and database access.",
  "Не удалось очистить кэш.": "Could not clear the cache.",
  "Не удалось удалить сохранённый профиль.":
      "Could not delete the saved profile.",
  "Не удалось удалить базы полностью. Проверьте права файлов.":
      "Could not fully delete the databases. Check file permissions.",
  "GPTunnel требует API-ключ. Введите его или загрузите сохранённый профиль.":
      "GPTunnel requires an API key. Enter it or reload a saved profile.",
  "Ошибка локального хранилища анализа.": "Analysis storage error.",
  "Экспорт вывода последней проверки": "Export the latest scan output",
  "Полный путь к .log": "Full .log file path",
  "Отмена": "Cancel",
  "Сохранить": "Save",
  "Находки последней проверки": "Latest scan findings",
  "Проверка ещё не завершена. Запустите сканер на вкладке «Проверка».":
      "No completed scan yet. Start a scanner on the Scan tab.",
  "Предупреждения сканера требуют ручной проверки. Учитывайте ошибки запуска и пропущенные тесты.": "Review scanner warnings manually. Consider launch errors and skipped checks.",
  "Строк с известными маркерами предупреждений не найдено. Это не гарантирует отсутствие угроз.":
      "No known warning markers found. Threats may still be present.",
  "Минимум 8 символов": "At least 8 characters",
  "Пароли не совпадают": "Passwords do not match",
  "Зашифровать старые базы": "Encrypt existing databases",
  "Создать пароль баз": "Create a database password",
  "Разблокировать базы": "Unlock databases",
  "Пароль не сохраняется; без него восстановить данные нельзя.":
      "The password is not stored. It is required to recover your data.",
  "Новый пароль": "New password",
  "Пароль": "Password",
  "Повторите пароль": "Repeat password",
  "Создать и открыть": "Create and open",
  "Разблокировать": "Unlock",
  "Системный": "System",
  "Бирюзовый": "Teal",
  "Синий": "Blue",
  "Фиолетовый": "Purple",
  "Оранжевый": "Orange",
  "Зелёный": "Green",
  "Розовый": "Rose",
  "Цвет приложения": "App color",
  "Удалить обе базы?": "Delete both databases?",
  "Будут удалены API-настройки, сохранённый ключ, кэш и параметры шифрования. Восстановление через приложение невозможно. Экспортированные .log останутся.": "API settings, the saved key, cache and encryption metadata will be deleted. This cannot be undone in the app. Exported .log files are kept.",
  "Удалить базы": "Delete databases",
  "Ссылка скопирована": "Link copied",
  "Параметры запуска": "Launch options",
  "Рабочий каталог (cwd)": "Working directory (cwd)",
  "Авто: каталог реального бинарника": "Auto: real executable directory",
  "Пустое поле выбирает каталог реального бинарника. Допустим абсолютный путь или ~/. Для chkrootkit здесь должны находиться вспомогательные бинарники. Каталог сканирования задаётся отдельно.": "Leave blank to use the real executable's directory. Enter an absolute path or ~/. For chkrootkit, this directory must contain its helper binaries. The scan directory is set separately.",
  "Базы ещё не созданы. Задайте новый пароль шифрования.":
      "No databases exist yet. Create a new encryption password.",
  "Есть кэш, но нет базы API с параметрами шифрования. Восстановите api.db из резервной копии либо удалите обе базы с подтверждением.": "A cache exists, but the API database with encryption settings is missing. Restore api.db from a backup or confirm deletion of both databases.",
  "Найден старый незашифрованный профиль. Задайте пароль для его шифрования. Старый кэш будет очищен.": "An old unencrypted profile was found. Create a password to encrypt it. The old cache will be cleared.",
  "Найдены сформированные зашифрованные базы. Введите существующий пароль.":
      "Valid encrypted databases were found. Enter the existing password.",
  "Найдена зашифрованная база API. Введите существующий пароль; отсутствующий кэш будет создан заново.": "An encrypted API database was found. Enter the existing password; the missing cache will be recreated.",
  "Структура баз повреждена или создание не завершено. Данные не изменены. Восстановите базы из копии либо удалите их с подтверждением.": "The databases are damaged or incomplete. Data has not been changed. Restore a backup or confirm deletion.",
  "Пароль должен содержать минимум 8 символов.":
      "The password must contain at least 8 characters.",
  "Не удалось защитить каталог базы":
      "Could not secure the database directory.",
  "Неверный пароль или повреждены данные базы.":
      "Incorrect password or damaged database contents.",
  "Не удалось защитить базу": "Could not secure the database.",
  "Укажите HTTPS URL или HTTP на localhost.":
      "Enter an HTTPS URL, or an HTTP URL on localhost.",
  "Это сайт документации. API GPTunnel: https://gptunnel.ru/v1":
      "This is the documentation site. GPTunnel API: https://gptunnel.ru/v1",
  "GPTunnel требует API-ключ. Ключ не введён или не загружен из базы.":
      "GPTunnel requires an API key. Enter a key or load it from the database.",
  "API-ключ содержит перенос строки. Вставьте ключ заново.":
      "The API key contains a line break. Paste the key again.",
  "Укажите модель.": "Enter a model.",
  "Вывод больше 200 КБ. Экспортируйте .log для отдельного анализа.":
      "Output exceeds 200 KB. Export a .log for separate analysis.",
  "Сервер не ответил за 90 секунд.":
      "The server did not respond within 90 seconds.",
  "Не удалось получить ответ API. Проверьте адрес и подключение.":
      "Could not retrieve an API response. Check the URL and connection.",
  "Ответ API слишком большой.": "The API response is too large.",
  "Ключ отсутствует, недействителен или отозван. Проверьте загрузку ключа и выбранного провайдера; баланс не подтверждает авторизацию.": "The key is missing, invalid or revoked. Check the loaded key and selected provider.",
  "Недостаточно средств или недоступен платёжный баланс для этого ключа.":
      "Insufficient funds or billing is unavailable for this key.",
  "Модель не найдена. Проверьте её ID в списке моделей провайдера.":
      "Model not found. Check its ID in the provider's model list.",
  "Проверьте endpoint (GPTunnel: https://gptunnel.ru/v1/chat/completions) и ID модели.": "Check the endpoint (GPTunnel: https://gptunnel.ru/v1/chat/completions) and model ID.",
  "Проверьте ключ, модель, доступ и баланс.":
      "Check the key, model, access and balance.",
  "API вернул пустой или несовместимый ответ.":
      "The API returned an empty or incompatible response.",
  "Неизвестный формат шифрования": "Unknown encryption format.",
  "Укажите абсолютный путь каталога сканирования.":
      "Enter an absolute scan directory path.",
  "Этот сканер поддерживает только работающую систему.":
      "This scanner supports only the running system.",
  "Не удалось определить домашний каталог. Укажите полный путь.":
      "Could not determine your home directory. Enter a full path.",
  "Рабочий каталог должен быть абсолютным путём или начинаться с ~/":
      "The working directory must be an absolute path or start with ~/.",
  "Сеанс закрыт": "Session closed",
  "Привилегированный сеанс поддерживается только в Linux":
      "Privileged sessions are supported only on Linux.",
  "Запуск сеанса отменён": "Session startup cancelled.",
  "Запрос прав отменён.": "Authorization cancelled.",
  "Не удалось запустить сервис или авторизоваться через polkit. В сеансе Wayland/seatd проверьте агент polkit и D-Bus.": "Could not start the service or authorize through polkit. In a Wayland/seatd session, check the polkit agent and D-Bus.",
  "Привилегированный сеанс завершился": "The privileged session ended.",
  "Headless-сервис не найден рядом с приложением или в /usr/libexec":
      "Privileged service not found alongside the app or in /usr/libexec.",
  "Не удалось запустить привилегированный сеанс":
      "Could not start the privileged session.",
  "Для безопасного запуска установите приложение в системный каталог с владельцем root": "Install the application in a root-owned system directory for secure launching.",
};
const englishFragments = <String, String>{
  'API вернул HTTP ': 'API returned HTTP ',
  ' через pkexec': ' via pkexec',
  'Привилегированный сервис завершился (код ':
      'Privileged service exited (code ',
  "Каталог сканирования: ": "Scan directory: ",
  "Рабочий каталог: ": "Working directory: ",
  "Бинарник: ": "Executable: ",
  "Источник: ": "Source: ",
  "код завершения ": "exit code ",
  "Найден: ": "Found: ",
  "Строк: ": "Lines: ",
  "предупреждений: ": "warnings: ",
  "Команда: ": "Command: ",
  "Лог сохранён: ": "Log saved: ",
  "Установка не выполнена: ": "Installation failed: ",
  "Инструмент завершился без вывода (код ": "Tool exited without output (code ",
  "Запуск ": "Starting ",
  "Проверка может потребовать права root.": "The scan may require root access.",
  "Не удалось запустить ": "Could not start ",
  "Не удалось завершить проверку ": "Could not finish scan ",
  "не найден. Установите его на вкладке «Инструменты».":
      "not found. Install it on the Tools tab.",
  "Установите пакет и повторите.": "Install the package and try again.",
  " установлен через ": " installed using ",
  " установлен из официального релиза в ~/.local/bin.":
      " installed from an official release to ~/.local/bin.",
  "Официальный релиз для ": "Official release for ",
  " не настроен.": " is not configured.",
  "Пакет ": "Package ",
  " есть в репозитории. Выберите системную установку, чтобы получить обновления.": " is available in the repository. Choose system installation to receive updates.",
};
