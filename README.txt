======================================================================
               H1Z1 ROTK Russia - Direct UDP Bypass v1.2.0
======================================================================

QUICK START / БЫСТРЫЙ СТАРТ:

[EN]
OPTION A: AUTO MODE (RECOMMENDED)
1. Right-click INSTALL_AUTO.cmd -> "Run as administrator".
2. That's it! The bypass activates automatically when H1Z1 starts,
   and unloads automatically 7 seconds after H1Z1 exits.
3. Check status at any time with STATUS.cmd.
4. To uninstall, run UNINSTALL_AUTO.cmd as administrator.

OPTION B: MANUAL MODE
1. Right-click START.cmd -> "Run as administrator".
2. Launch ROTK normally and play!
3. When finished, press any key in START window or run STOP.cmd.

[RU]
ВАРИАНТ А: АВТОРЕЖИМ (РЕКОМЕНДУЕТСЯ)
1. Нажмите правой кнопкой мыши по INSTALL_AUTO.cmd -> "Запуск от имени администратора".
2. Готово! Обход включится автоматически при запуске H1Z1,
   и выключится автоматически через 7 секунд после закрытия игры.
3. Проверить текущее состояние можно через STATUS.cmd.
4. Для удаления авторежима запустите UNINSTALL_AUTO.cmd от администратора.

ВАРИАНТ Б: РУЧНОЙ РЕЖИМ
1. Нажмите правой кнопкой мыши по START.cmd -> "Запуск от имени администратора".
2. Запустите ROTK и играйте!
3. После завершения игры нажмите любую клавишу в окне START или запустите STOP.cmd.

----------------------------------------------------------------------
NOTE ON LATENCY & TUNNELS:
VLESS was playable and often stayed around roughly 60–80 ms, but the tunneled path
introduced noticeable jitter and occasional latency spikes reaching approximately
140–170 ms on the tested setup. The direct local bypass keeps the native route and
produced a much steadier ~55–61 ms connection.

Через VLESS игра была играбельной: пинг часто находился примерно в диапазоне
60–80 мс. Главной проблемой были нестабильность, джиттер и периодические скачки
задержки примерно до 140–170 мс. Локальный direct-bypass сохраняет прямой маршрут
и на тестовом соединении дал значительно более стабильные ~55–61 мс.

----------------------------------------------------------------------
ANTI-CHEAT / АНТИЧИТ:
The project does not inject into H1Z1, modify game memory, patch game files,
or interact with BattlEye. It has been successfully tested in live ROTK gameplay.
Future anti-cheat policy changes cannot be guaranteed.

----------------------------------------------------------------------
Documentation & GitHub:
https://github.com/Blaykosik/H1Z1-ROTK-Russia
======================================================================
