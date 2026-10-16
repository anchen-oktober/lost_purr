# Lost Purr: Fear / Calmness System

Этот документ описывает текущую механику страха котика: как она считается, как влияет на движение, как обновляет HUD и как подключать safe/recovery points.

## Идея

В Lost Purr нет классического HP и смерти. Вместо этого у котика есть `Fear` от `0` до `100`.

- `Fear = 0` означает спокойное состояние.
- `Calmness = 100 - Fear`.
- При испуге `Fear` растет.
- Чем меньше `Calmness`, тем медленнее котик двигается.
- При `Fear >= 100` котик не умирает: управление временно блокируется, включается critical-состояние, затем котик возвращается к последней безопасной точке.

Основная логика живет в:

- `Scripts/Player/player_cat.gd`
- `Scripts/UI/cat_status_hud.gd`
- `Scripts/Interactables/recovery_point.gd`

## PlayerCat

Файл: `Scripts/Player/player_cat.gd`

Основные переменные:

```gdscript
@export var max_fear: float = 100.0
@export var fear_per_scare: float = 25.0
@export var restore_quarter_amount: float = 25.0
@export var purr_restore_amount: float = 10.0
@export var purr_restore_cooldown: float = 3.0
@export var can_purr_restore: bool = true
@export var flee_speed: float = 8.0
@export var hiding_recovery_rate: float = 25.0
@export var minimum_hiding_time: float = 1.0

var fear: float = 0.0
var is_critical_fear: bool = false
var move_speed_multiplier: float = 1.0
var last_recovery_transform: Transform3D
var level_start_transform: Transform3D
var controls_locked: bool = false
```

Публичный метод для ловушек, теней, врагов и scare-trigger объектов:

```gdscript
player.apply_fear_damage(25.0)
```

Метод увеличивает `fear`, обновляет множитель скорости, HUD и запускает critical-состояние, если страх дошел до максимума.

Публичные методы восстановления:

```gdscript
player.restore_fear(25.0)
player.restore_fear_quarter()
player.restore_fear_by_purr()
```

Восстановление всегда уменьшает `Fear` на указанное значение и не опускает его ниже `0`.

`restore_fear_by_purr()` используется для клавиши `R`: котик мурчит и восстанавливает `10` Fear, если не активен cooldown и котик не в critical-состоянии.

## Состояния

Состояния считаются через `Calmness`.

| Calmness | State | Speed | HUD |
|---|---|---:|---|
| 100-76 | `Calm` | 100% | `cats_eye_1` |
| 75-51 | `Uneasy` | 85% | `cats_eye_1`, темнее |
| 50-26 | `Scared` | 70% | `cats_eye_1`, еще темнее, легкое дрожание |
| 25-1 | `Panic` | 55% | `cats_eye_1_1`, красный оттенок, сильнее дрожание |
| 0 | `Critical` | 0% | `cats_eye_3`, возврат к recovery point |

Дрожание HUD-глаз начинается при `Fear >= 50`, то есть при `Calmness <= 50`.

## Движение

Система click-to-move / hold-to-move не переписана. Скорость меняется только через общий множитель:

```gdscript
velocity.x = direction.x * speed * move_speed_multiplier
velocity.z = direction.z * speed * move_speed_multiplier
```

Это важно: если движение будет расширяться дальше, достаточно учитывать `move_speed_multiplier`, не меняя всю механику навигации.

## Critical Fear

При `Fear >= max_fear` существующий PlayerCat выполняет последовательность `Fleeing → Hiding → управление игрока`.

1. Фиксируется мировая позиция кота в момент испуга. Через существующий TraumaRadiusVisual создаётся красная зона с радиусом `trauma_block_radius`.
2. Блокируются ввод движения, взаимодействия и переключение Cat Vision; включается критический HUD.
3. Кот физически бежит к `last_recovery_transform` с `flee_speed`, используя `move_and_slide` и маршрут по проходимым точкам. Телепортации нет. До посещения SafePoint цель совпадает со стартом уровня.
4. После прибытия кот приседает в укрытии. Управление остаётся заблокированным, страх уменьшается с `hiding_recovery_rate` до нуля, но не менее `minimum_hiding_time`.
5. После восстановления возвращаются обычный размер спрайта и управление. Красная зона остаётся в месте испуга и реально останавливает перемещение по всему отрезку физического шага. Цель за кругом не позволяет пересечь его. Следующая паника обновляет круг.

`fear_return_path.gd` строит только маршрут возвращения; значение страха, состояния, восстановление и сигналы остаются в PlayerCat. Сцена не перезагружается и прогресс квестов не сбрасывается. Прямой запуск Village использует ту же инициализацию GameManager, что обычный вход в игру.

## HUD

Файлы:

- `Scripts/UI/cat_status_hud.gd`
- `Scenes/UI/CatStatusHUD.tscn`

HUD слушает сигнал игрока:

```gdscript
signal fear_changed(fear: float, calmness: float, state: String, is_critical: bool)
```

HUD отвечает только за отображение:

- выбор текстуры глаз: `cats_eye_1.png` при Fear <25, `cats_eye_1_1.png` при 25–<50, `cats_eye_2.png` при 50–<100, `cats_eye_3.png` при паническом побеге;
- затемнение обычных глаз;
- дрожание при страхе;
- debug-текст справа сверху.

Cat Vision имеет приоритет над fear-иконкой:

- если Cat Vision включен, HUD показывает `cats_eye_2`;
- когда Cat Vision выключается, HUD возвращается к актуальному состоянию страха;
- critical-состояние показывает `cats_eye_3`.

## Debug UI

Справа сверху временно отображается:

```text
Fear: XX / 100
Calmness: XX%
State: Calm / Uneasy / Scared / Panic / Critical
```

Отключить debug-текст можно в инспекторе у `CatStatusHUD`, сняв `debug_text_visible`.

## Debug Input

Для тестирования есть временная клавиша:

```text
F6: +25 Fear
```

Дополнительная debug-клавиша:

```text
F7: -25 Fear
R: -10 Fear, purr restore
```

`F7` не телепортирует котика и не восстанавливает полностью. Она только вызывает `restore_fear_quarter()`.

`R` использует существующую логику мурчания: feedback и влияние на NPC остаются, а дополнительно вызывается `restore_fear_by_purr()`.

Восстановление от мурчания:

- уменьшает `Fear` на `10`;
- не опускает `Fear` ниже `0`;
- не работает во время critical state;
- имеет cooldown `3.0` секунды;
- не телепортирует котика и не сбрасывает прогресс.

После четырех нажатий `F6` при дефолтных настройках котик войдет в critical-состояние и вернется к recovery point или старту уровня. После прибытия начнётся укрытие: страх постепенно снижается до `0`, затем возвращается управление.

## RecoveryPoint

Файл: `Scripts/Interactables/recovery_point.gd`

Скрипт рассчитан на `Area3D`.

Как добавить safe point:

1. Создать `Area3D` в сцене.
2. Добавить `CollisionShape3D`.
3. Повесить `Scripts/Interactables/recovery_point.gd`.
4. Разместить объект там, где котик должен восстанавливаться: фонарь, добрый NPC, безопасная зона, положительный триггер.

Экспортируемые параметры:

```gdscript
@export var restore_on_enter: bool = true
@export var restore_amount: float = 25.0
@export var can_restore_repeatedly: bool = false
@export var reset_when_player_leaves: bool = true
@export var restore_cooldown: float = 0.0
@export var recovery_marker: Node3D
```

Поведение:

- при входе `PlayerCat` сохраняет позицию recovery point;
- если есть дочерний `Marker3D` с именем `RecoveryMarker`, он используется как точная позиция возврата;
- если `recovery_marker` задан в инспекторе, используется он;
- если marker не задан, используется позиция самого trigger;
- если `restore_on_enter = true`, страх уменьшается на `restore_amount`;
- восстановление происходит один раз при входе, а не каждый кадр.

Примеры:

- Обычная safe-zone: `restore_on_enter = true`, `restore_amount = 25`.
- Только сохранить safe point без восстановления: `restore_on_enter = false`.
- Разрешить повторное восстановление после выхода и входа: `reset_when_player_leaves = true`.
- Добавить задержку между восстановлением: `restore_cooldown = 3.0`.

## TraumaZone / Red Radius

Файлы:

- `Scripts/Trauma/trauma_zone.gd`
- `Scripts/Trauma/trauma_radius_visual.gd`

`TraumaZone` - это страшная зона, которая может довести котика до critical fear и затем стать временно заблокированной зоной.

Как добавить:

1. Создать `Area3D`.
2. Добавить `CollisionShape3D`.
3. Повесить `Scripts/Trauma/trauma_zone.gd`.
4. Настроить `fear_damage` и `trauma_radius`.

Основные параметры:

```gdscript
@export var fear_damage: float = 100.0
@export var trauma_radius: float = 4.0
@export var use_collision_radius: bool = true
@export var damage_on_enter: bool = true
@export var can_damage_repeatedly: bool = false
@export var reset_damage_when_player_leaves: bool = true
```

Когда котик получает critical fear от `TraumaZone`:

- зона сохраняется как `CurrentTraumaZone`;
- включается `HasActiveTraumaAvoidance`;
- на земле появляется полупрозрачный красный радиус;
- пока `Calmness < 100`, котик не хочет идти обратно в эту зону;
- если игрок кликает внутрь заблокированной зоны, движение отменяется, а радиус коротко вспыхивает;
- когда `Calmness` снова становится `100`, avoidance выключается и красный радиус скрывается.

Если critical fear произошёл без конкретной `TraumaZone`, игрок создаёт временный красный радиус вокруг последней позиции испуга. Радиус берётся из `trauma_block_radius` у `PlayerCat`.

Debug text дополнительно показывает:

```text
Trauma Avoidance: ON / OFF
Blocked Zone: zone_name / none
Blocked Zone Radius Visible: true / false
```

## Как вызвать страх из другого объекта

Минимальный пример для scare trigger:

```gdscript
extends Area3D

@export var fear_amount: float = 25.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.name != "PlayerCat":
		return

	if body.has_method("apply_fear_damage"):
		body.call("apply_fear_damage", fear_amount, self)
```

Враги, ловушки и тени не должны менять HUD напрямую. Они только вызывают `apply_fear_damage`.

## Быстрая проверка

1. Запустить любой уровень.
2. Убедиться, что debug-текст показывает `Fear: 0 / 100`, `Calmness: 100%`, `State: Calm`.
3. Нажать `F6`: страх станет `25`, скорость снизится до `85%`.
4. Нажать `F6` второй раз: страх станет `50`, глаза начнут слегка дрожать, скорость снизится до `70%`.
5. Нажать `F6` третий раз: включится panic-глаз `cats_eye_1_1`, дрожание станет сильнее, скорость снизится до `55%`.
6. Нажать `F7`: страх уменьшится на `25`, HUD и скорость обновятся без телепорта.
7. Нажать `R`: котик мурчит, страх уменьшается на `10`, HUD и скорость обновляются.
8. Повторно нажать `R` сразу: восстановление не должно сработать из-за cooldown.
9. Нажать `F6` до critical: включится critical-глаз `cats_eye_3`, котик вернется к recovery point или старту уровня, кот спрячется, постепенно восстановит страх до нуля и вернёт управление.
10. Проверить positive trigger: при входе он сохраняет LastRecoveryPoint и уменьшает страх на `25`.
11. Проверить TraumaZone: после critical должна появиться красная подсветка радиуса зоны.
12. Кликнуть внутрь подсвеченной зоны при `Calmness < 100`: движение должно отмениться, радиус должен вспыхнуть.
13. Восстановить котика до `Calmness 100`: последняя красная зона остаётся видимой и непроходимой. Следующая паника заменяет её новым кругом в новом месте испуга.
14. Проверить Cat Vision: при включенном Cat Vision должен показываться `cats_eye_2`, после выключения HUD должен вернуться к состоянию страха.

## Важные ограничения

- Не использовать эту систему как combat HP.
- Не перезагружать сцену при critical fear.
- Не сбрасывать квесты и собранные воспоминания.
- Не менять HUD напрямую из врагов и триггеров.
- Не добавлять тяжелый UI: страх должен читаться через движение, глаза и атмосферу.
