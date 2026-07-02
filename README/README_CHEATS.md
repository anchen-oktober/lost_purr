# Lost Purr: Cheats and Debug Shortcuts

Документ фиксирует все найденные в проекте чит-клавиши, debug-переключатели и кодовые точки, которые могут менять состояние игрока в обход обычного геймплея.

Последняя ручная сверка: 2026-07-02.

## Что считается читом

- Клавиши, которые напрямую меняют страх, уровень, состояние Cat Vision/Danger или физику.
- Debug-режимы, которые помогают тестировать сцену, рендер, UI или перемещение.
- Script API, через которые тестовые объекты могут искусственно менять Fear/Calmness.

Обычные игровые действия вроде прыжка, движения, взаимодействия `E` или штатного включения Cat Vision через `Shift` не считаются читами, если они не дают тестовое преимущество.

## Main Game

### Fear / Calmness

Файл: `Scripts/Player/player_cat.gd`

| Клавиша | Эффект | Детали |
|---|---|---|
| `F6` | Добавить страх | Вызывает `apply_fear_damage(fear_per_scare)`. По умолчанию `fear_per_scare = 25.0`. После четырех нажатий при стандартных настройках котик входит в `Critical`. |
| `F7` | Восстановить страх на четверть шкалы | Вызывает `restore_fear_quarter()`. По умолчанию уменьшает `Fear` на `25.0`, не телепортирует и не делает полный reset. |

Связанные export-настройки:

| Параметр | Значение по умолчанию | Назначение |
|---|---:|---|
| `max_fear` | `100.0` | Верхняя граница шкалы страха. |
| `fear_per_scare` | `25.0` | Сколько страха добавляет `F6`. |
| `restore_quarter_amount` | `25.0` | Сколько страха снимает `F7` и quarter-restore. |
| `purr_restore_amount` | `10.0` | Сколько страха снимает мурчание. |
| `purr_restore_cooldown` | `3.0` | Cooldown восстановления от мурчания. |

### Purr Restore

Файлы:

- `Scripts/Journal/character_journal_manager.gd`
- `Scripts/Triggers/LPTrigger.gd`
- `Scripts/Player/player_cat.gd`

| Клавиша | Эффект | Детали |
|---|---|---|
| `R` | Мурчание / purr restore | Вызов `restore_fear_by_purr()` уменьшает `Fear` на `10.0`, если включен `can_purr_restore`, не активен cooldown и котик не в `Critical`. |

`R` может быть обычной игровой механикой, но для тестов фактически работает как мягкий restore-cheat.

### Quick Travel

Файл: `Scripts/Core/game_manager.gd`

Клавиши работают через `GameManager.QUICK_TRAVEL_LEVELS`, если не идет quick travel и ввод сцены не заблокирован журналом.

| Клавиша | Уровень | Spawn |
|---|---|---|
| `1` / `Numpad 1` | `village` | `SpawnFromVillage` |
| `2` / `Numpad 2` | `park` | `SpawnFromPark` |
| `3` / `Numpad 3` | `city` | `SpawnFromCity` |
| `4` / `Numpad 4` | `metro` | `SpawnFromCity` |
| `5` / `Numpad 5` | `other_world` | `SpawnFromMetro` |

Это полноценный dev-cheat для быстрой навигации между уровнями.

### Cat Vision / Danger Debug

Файл: `Scripts/CatVision/cat_vision_manager.gd`

| Клавиша | Эффект | Детали |
|---|---|---|
| `F1` | Переключить critical/danger-состояние Cat Vision | Вызывает `set_cat_critical(not is_cat_critical)`. Используется для проверки danger-визуала без накопления `Fear`. |

Связанные состояния:

- `NORMAL`
- `CAT_VISION`
- `DANGER`

`Shift` включает/выключает Cat Vision и считается штатным игровым управлением, а не читом. Исключение: в `OtherWorld` Cat Vision форсируется через `set_location()`.

### Camera Debug

Файл: `Scripts/Camera/camera_3d.gd`

| Клавиша / ввод | Эффект | Детали |
|---|---|---|
| `C` | Переключить камеру | Меняет режим между `ISOMETRIC` и `THIRD_PERSON`. |
| Правая кнопка мыши + движение | Повернуть камеру | Вращает `yaw` камеры. |
| Колесо мыши | Zoom | Работает в `ISOMETRIC`. |

Это не cheat состояния игрока, но debug/dev shortcut для проверки вида и навигации.

## Script-Level Test Hooks

Эти методы не привязаны к консоли, но используются как точки для тестовых триггеров, зон и safe points.

Файл: `Scripts/Player/player_cat.gd`

| Метод | Эффект |
|---|---|
| `apply_fear_damage(amount, source_node = null)` | Увеличивает `Fear`, может запустить `Critical` и trauma avoidance. |
| `restore_fear(amount)` | Уменьшает `Fear` на указанное значение. |
| `restore_fear_quarter()` | Уменьшает `Fear` на `restore_quarter_amount`. |
| `restore_fear_by_purr()` | Уменьшает `Fear` на `purr_restore_amount` с cooldown и проверками. |
| `recover_from_fear(amount = -1.0)` | При `amount < 0` восстанавливает на `max_fear`, иначе на указанное значение. |
| `set_recovery_point(recovery_transform, restore_now = false)` | Меняет точку восстановления; опционально делает quarter-restore. |

Файл: `Scripts/Systems/CatCalmManager.gd`

| Метод | Эффект |
|---|---|
| `apply_calm_delta(calm_delta, source_id = "", reason = "", source_node = null)` | Положительный delta уменьшает страх, отрицательный delta добавляет страх. |

Файл: `Scripts/Triggers/LPTrigger.gd`

`LPTrigger` может менять состояние через `calm_delta`, `trigger_category`, `activation_type`, `requires_purr`, `requires_cat_vision`, `is_periodic` и `creates_fear_zone`. Это data-driven способ создавать тестовые позитивные/негативные зоны без новой логики в игроке.

## Demo-Only Cheats

Эти клавиши находятся в `demo/` и относятся к Terrain3D/demo-сценам, а не к основной игре Lost Purr.

### Demo Player

Файл: `demo/src/Player.gd`

| Клавиша / ввод | Эффект |
|---|---|
| `Shift` | Удвоить скорость движения, пока клавиша нажата. |
| `+` / `Numpad +` | Постепенно увеличить `MOVE_SPEED`. |
| `-` / `Numpad -` | Постепенно уменьшить `MOVE_SPEED`. |
| Колесо вверх | Увеличить `MOVE_SPEED` на `5`. |
| Колесо вниз | Уменьшить `MOVE_SPEED` на `5`. |
| `V` | Переключить first-person режим. |
| `G` | Включить/выключить gravity. |
| `C` | Включить/выключить collision. |
| `Q` / `E` / `Space` | Вертикальное движение demo-игрока. |

### Demo UI / Render Debug

Файл: `demo/src/UI.gd`

| Клавиша | Эффект |
|---|---|
| `F8` | Закрыть demo (`get_tree().quit()`). |
| `F9` | Переключить видимость demo UI. |
| `F10` | Переключить `viewport.debug_draw` по режимам `0..5`. |
| `F11` | Переключить fullscreen/windowed. |
| `Escape` / `F12` | Переключить захват мыши. |

При инициализации demo UI также вызывает `RenderingServer.set_debug_generate_wireframes(true)`.

## Editor / Build Debug

Файл: `Scripts/World/grid_overlay.gd`

| Контекст | Эффект |
|---|---|
| `G` в editor hint | Переключает видимость grid overlay в редакторе. |
| `start_visible_in_debug` | Может показать grid overlay при runtime, если `editor_only = false`. |

По умолчанию `editor_only = true`, поэтому grid отключается вне редактора.

## Не найдено

На момент сверки не найдено:

- встроенной cheat-консоли;
- текстовых console commands;
- noclip/godmode в основной игре;
- сохраненных action mappings для читов в `project.godot`;
- сетевых или внешних debug-команд.

## Как дополнять этот README

При добавлении нового чита или debug-shortcut:

1. Добавить клавишу, источник и эффект в подходящий раздел.
2. Указать файл, где реализована логика.
3. Отметить, относится ли это к основной игре, demo или editor-only.
4. Если чит меняет баланс или progression, явно подписать его как `dev-cheat`.
5. Обновить дату ручной сверки вверху документа.

Быстрая команда для проверки новых кандидатов:

```powershell
rg -n -i "cheat|debug|god|noclip|console|is_action|Input\\.is_key|KEY_F|KEY_[0-9]|apply_fear|restore_fear|quick_travel" Scripts Scenes demo project.godot README
```
