# Lost Purr: Emotional Trigger System

Новая data-driven система триггеров живёт поверх текущей Fear/Calm механики и не заменяет существующие PlayerCat, HUD, Cat Vision, Journal и purr по `R`.

## Файлы

- `Scripts/Systems/CatCalmManager.gd` - autoload-фасад для Calm.
- `Scripts/Triggers/LPTrigger.gd` - универсальный Area3D-триггер.
- `Scripts/Triggers/LPSafePoint.gd` - safe point для возврата после паники.
- `Scripts/Triggers/LPFearZone.gd` - красная fear zone, блокирующая вход при недостаточном Calm.

## Calm

Calm считается как `100 - Fear`, чтобы не ломать уже реализованную Fear System.

Состояния:

- `76-100`: `CALM`
- `51-75`: `UNEASY`
- `26-50`: `SCARED`
- `1-25`: `CRITICAL`
- `0`: `PANIC`

Все новые триггеры меняют Calm через:

```gdscript
CatCalmManager.apply_calm_delta(calm_delta, trigger_id, reason, source_node)
```

Manager печатает debug:

```text
Calm changed: old -> new | reason: ... | trigger_id: ...
```

## LPTrigger

Создание:

1. Создать `Area3D`.
2. Добавить `CollisionShape3D`.
3. Повесить `Scripts/Triggers/LPTrigger.gd`.
4. Настроить category, activation, calm_delta, cooldown и requirements.

Основные поля:

```gdscript
trigger_id
trigger_name
trigger_category
activation_type
calm_delta
is_repeatable
cooldown
requires_interaction
requires_cat_vision
requires_purr
journal_entry_id
blocks_movement
creates_fear_zone
safe_point_id
feedback_type
is_periodic
periodic_interval
max_total_delta_per_enter
```

Примеры:

- Lantern: `POSITIVE`, `ON_ENTER_AREA`, `calm_delta = 25`, `is_repeatable = true`, `cooldown = 10`.
- Road: `NEGATIVE`, `ON_ENTER_AREA`, `calm_delta = -15`, `is_repeatable = true`, `cooldown = 10`.
- Water Bowl: `POSITIVE`, `ON_INTERACT_E`, `calm_delta = 10`, `is_repeatable = false`.
- Owner Trace: `NEUTRAL`, `ON_CAT_VISION`, `calm_delta = 0`, `requires_cat_vision = true`, `journal_entry_id = owner_trace_01`.
- Shadow: `NEGATIVE`, `ON_ENTER_AREA`, `calm_delta = -40`, `creates_fear_zone = true`.

## Activation Types

Supported now:

- `ON_ENTER_AREA`
- `ON_EXIT_AREA`
- `ON_INTERACT_E`
- `ON_CAT_VISION`
- `ON_PURR`
- `ON_SCRIPTED_EVENT` via `activate_trigger()`

Other enum values are present for future expansion.

## Periodic Zones

For zones like black puddles or cold wind:

```gdscript
is_periodic = true
periodic_interval = 2.5
calm_delta = -10
max_total_delta_per_enter = -30
```

The total resets when the cat leaves and enters again.

## Safe Point

Use `LPSafePoint.gd` on an `Area3D`.

Fields:

```gdscript
safe_point_id
restore_calm_on_use = 25
restore_on_enter
```

Entering the area sets the last recovery point. Panic return still uses PlayerCat recovery logic and restores only to Calm 25.

## Fear Zone

Use `LPFearZone.gd` when a red blocking radius is needed directly.

Fields:

```gdscript
fear_zone_id
required_calm_to_enter = 100
radius = 3
is_story_required
show_red_radius
```

The existing Trauma/Fear avoidance in PlayerCat is still used for zones created by panic sources.

## Cat Vision

For `requires_cat_vision = true`, LPTrigger checks the current `CatVisionManager`. OtherWorld works because CatVisionManager already forces Cat Vision there.

## Journal

If `journal_entry_id` is set, LPTrigger calls:

```gdscript
JournalManager.collect_entry({"id": journal_entry_id})
```

If JournalManager is unavailable, it prints a safe debug line instead.
