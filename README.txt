======================================================================
               H1Z1 ROTK Russia - Direct UDP Bypass v1.2.1
======================================================================

QUICK START / БЫСТРЫЙ СТАРТ:

[EN]
OPTION A: AUTO MODE (RECOMMENDED - INSTALLED TO PROGRAMDATA)
1. Right-click INSTALL_AUTO.cmd -> "Run as administrator".
2. Copies runtime to %ProgramData%\H1Z1-ROTK-Russia and registers
   a logon background task.
3. You can now safely move or delete the downloaded release folder!
4. The bypass activates automatically when H1Z1 starts,
   and unloads automatically 7 seconds after H1Z1 exits.
5. Check status at any time with STATUS.cmd.
6. To uninstall, run UNINSTALL_AUTO.cmd from here or from
   %ProgramData%\H1Z1-ROTK-Russia\UNINSTALL_AUTO.cmd.

OPTION B: MANUAL MODE (100% PORTABLE)
1. Right-click START.cmd -> "Run as administrator".
2. Runs directly from this folder without installing anything.
3. Launch ROTK normally and play!
4. When finished, press any key in START window or run STOP.cmd.

[RU]
ВАРИАНТ А: АВТОРЕЖИМ (РЕКОМЕНДУЕТСЯ - УСТАНОВКА В PROGRAMDATA)
1. Нажмите правой кнопкой мыши по INSTALL_AUTO.cmd -> "Запуск от имени администратора".
2. Скрипт копирует рантайм в %ProgramData%\H1Z1-ROTK-Russia и регистрирует
   фоновую задачу автозапуска.
3. После этого исходную скачанную папку можно безопасно переместить или удалить!
4. Обход включается автоматически при запуске H1Z1,
   и выключается автоматически через 7 секунд после закрытия игры.
5. Проверить текущее состояние можно через STATUS.cmd.
6. Для удаления запустите UNINSTALL_AUTO.cmd от администратора (из этой папки
   или из %ProgramData%\H1Z1-ROTK-Russia\UNINSTALL_AUTO.cmd).

ВАРИАНТ Б: РУЧНОЙ РЕЖИМ (100% ПОРТАТИВНЫЙ)
1. Нажмите правой кнопкой мыши по START.cmd -> "Запуск от имени администратора".
2. Работает прямо из этой папки без какой-либо установки в систему.
3. Запустите ROTK и играйте!
4. После завершения игры нажмите любую клавишу в окне START или запустите STOP.cmd.

----------------------------------------------------------------------
PROCESS ISOLATION & SAFETY / ИЗОЛЯЦИЯ ПРОЦЕССОВ:
Strict PID and path verification: this project manages ONLY its own winws
instance and will never terminate unrelated winws/zapret processes.

Строгая проверка PID и путей: проект управляет ТОЛЬКО собственным процессом winws
и никогда не завершает чужие процессы zapret или сторонние утилиты.

----------------------------------------------------------------------
NOTE ON LATENCY & TUNNELS:
VLESS was playable and often stayed around roughly 60–80 ms, but the tunneled path
introduced noticeable jitter and occasional latency spikes reaching approximately
140–170 ms on the tested setup. The direct local bypass keeps the native route and
produced a much steadier connection with substantially reduced jitter (~55–61 ms observed).

Через VLESS игра была играбельной: пинг часто находился примерно в диапазоне
60–80 мс. Главной проблемой были нестабильность, джиттер и периодические скачки
задержки примерно до 140–170 мс. Локальный direct-bypass сохраняет прямой маршрут:
на тестовом соединении получена значительно более стабильная задержка, существенно
меньше скачков и стабильные ~55–61 мс во время тестов.

----------------------------------------------------------------------
SECURITY, TRUST & VERIFICATION / БЕЗОПАСНОСТЬ И ПРОВЕРКА:
- Not a cheat or injector: does not touch game memory, files, or BattlEye.
- Game-specific zapret/winws profile with narrow ROTK UDP filter scope.
- Zero telemetry, zero credentials, no remote servers, no hidden web calls.
- Verify archive SHA-256 via PowerShell:
  Get-FileHash .\H1Z1-ROTK-Russia-v1.2.1.zip -Algorithm SHA256

- Не чит и не инжектор: не трогает память, файлы игры и не вмешивается в BattlEye.
- Узкий профиль zapret/winws исключительно для UDP-трафика серверов ROTK.
- Ноль телеметрии, ноль сбора паролей, нет своих серверов или скрытых запросов.
- Проверить хеш архива через PowerShell:
  Get-FileHash .\H1Z1-ROTK-Russia-v1.2.1.zip -Algorithm SHA256

Security & Provenance Docs:
https://github.com/Blaykosik/H1Z1-ROTK-Russia/blob/main/docs/SECURITY_AND_TRUST.md
https://github.com/Blaykosik/H1Z1-ROTK-Russia/blob/main/BINARY_PROVENANCE.md

----------------------------------------------------------------------
Documentation & GitHub:
https://github.com/Blaykosik/H1Z1-ROTK-Russia
======================================================================
