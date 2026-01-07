# Magnus Dream – Camp & Craft MVP

## Быстрый старт
- Открой `res://scenes/main.tscn` и запусти сцену. `Main` остаётся контейнером сессии, Player и HUD живут только здесь.
- По умолчанию игра стартует в лесу. Для телепорта используй горячие клавиши:
  - `F5` (`go_camp`) – перейти в лагерь, активировать станок/NPC и разрешить крафтовый UI.
  - `F6` (`go_forest`) – вернуться в лес и снова подписаться на освещение (`torch_properties_changed`).
- Крафтовое меню (`CraftingUI`) открывается кнопкой `C` (`craftmenu`). Проверка включена внутри `Main`: UI доступен только когда активен лагерь, поэтому можно вызывать из любого места сцены, пока включён Camp.

## Сцены и узлы
- `res://scenes/forest/ForestScene.tscn` – обёртка над старым `world/forest.tscn`. Содержит:
  - `LevelRoot` (инстанс оригинальной сцены, включая `WorldLighting.gd`).
  - `ForestSpawn` – маркер привязки игрока.
  - `mobs/GoblinScout` – перенесён из `main.tscn`.
- `res://scenes/camp/CampScene.tscn` – новая локация лагеря:
  - `CampSpawn` – точка появления игрока.
  - `Station` – Area2D под ручной крафт (пока служит маркером; интеракция идёт через глобальный `craftmenu`).
  - `AutoCrafterNPC` – Area2D, на котором «сидит» очередь NPC. Для теста к нему привязан `CampStorageDebugUI`.
  - `CampStorageDebugUI` – CanvasLayer с кнопками «добавить ресурсы», «в очередь» и списком текущих заказов.
- `Main` переключает локации без пересоздания Player/HUD и телепортирует контейнер `$Player` в `CampSpawn`/`ForestSpawn`.

## Data-driven предметы, рецепты и апгрейды
- Новые данные лежат в отдельных директориях:
  - `res://data/items/*.json`
  - `res://data/recipes/*.json`
  - `res://data/experiments/*.json`
  - `res://data/camp_upgrades/*.json`
- `ItemManager` собирает данные из старого `items.json` плюс всех файлов в `data/items`. Формат пример (`wood.json`):
```json
{
  "id": "wood",
  "name": "Сосновая древесина",
  "type": "material",
  "stack_size": 99,
  "tags": ["resource", "organic"]
}
```
- Рецепты (пример `recipes/basic_sword.json`):
```json
{
  "id": "recipe_sword_basic",
  "slot1_id": "wood",
  "slot2_id": "stone",
  "output": {"sword": 1},
  "craft_time_sec": 5.0,
  "workshop_type": "forge"
}
```
- Эксперименты (пример `experiments/wood_stone.json`) задают `core_pair`, набор вероятностей `outcome_pool` и `fallback`. Любой предмет в Slot3 запускает эксперимент. Если подходящего правила нет, выдаётся эфир (fallback).
- Апгрейды лагеря описываются в `data/camp_upgrades`. Пример (`storage_warehouse.json`):
```json
{
  "upgrade_id": "storage_warehouse",
  "category": "storage",
  "max_level": 3,
  "levels": [
    {"level": 1, "cost": {"wood": 10}, "effects": {"storage_capacity_bonus": 50}},
    ...
  ]
}
```
Каждый уровень может иметь `requirements` (по уровню лагеря или другим апгрейдам) и словарь `effects` (`storage_capacity_bonus`, `autocraft_speed_multiplier`, `unlock_station_type`, `camp_defense_level_bonus`, и т.д.).

## Менеджеры автозагрузки
- `ItemManager` – перечитывает легаси-файл и весь каталог `data/items`.
- `CampStorageManager` – ведёт `total/reserved/free`, умеет `add`, `reserve`, `unreserve`, `consume_reserved`, `consume_free`, `get_snapshot`. Теперь учитывает вместимость: базовые 200 ячеек + бонусы `storage_capacity_bonus`. Если на складе нет места, `add` вернёт `false` и отправит `reservation_warning`.
- `CraftManager` – грузит рецепты/эксперименты, реализует `try_manual(slot1, slot2, slot3?)`. Для ручного крафта сразу списывает ингредиенты со склада, но не добавляет результат (это делает UI после `ForgeAnimation`/`on_craft_phase_complete`).
- `AutoCrafterManager` – очередь NPC: `enqueue(recipe_id, count)` резервирует ресурсы через склад, отслеживает статусы (`reserved/in_progress/completed/paused_no_resources/waiting_storage/completed/cancelled`). Учитывает апгрейды: `autocraft_speed_multiplier` уменьшает `craft_time_sec`, `autocraft_queue_slots_bonus` увеличивает длину очереди. Если в момент завершения нет места на складе, заказ остаётся в `waiting_storage` и выдаётся автоматически, как только освободится место.
- `CampUpgradeManager` – загружает `data/camp_upgrades`, хранит текущие уровни апгрейдов, проверяет условия (`can_upgrade`), списывает ресурсы из `CampStorageManager`, агрегирует модификаторы (`get_effective_modifiers`) и рассылает сигнал `upgrades_changed`.

## Ручной крафт + эксперимент
1. Добавь ресурсы в склад (кнопка `Add wood+stone` в лагере или вызови `CampStorageManager.add` из кода).
2. В лагере нажми `C`, заполни Slot1 и Slot2 (достаточно `wood` + `stone`) и оставь Slot3 пустым — это рецептный крафт.
3. Нажми `Запустить`. `CraftingUI` обратится к `CraftManager.try_manual`, тот проверит `CampStorageManager`, спишет ингредиенты и вернёт `CraftResult`. После проигрывания `ForgeAnimation` вызывается `on_craft_phase_complete()` и результат (`sword`) кладётся в склад.
4. Для эксперимента укажи любой item-id в Slot3. Все три слота сгорят, результат выберется из `outcome_pool` или fallback `ether`.

## Улучшения лагеря
- UI: `CampUpgradeUI` расположен в `res://scenes/camp/ui/CampUpgradeUI.tscn`, подключён к лагерю как CanvasLayer. Открывается горячей клавишей `U` (`campupgrade`) только когда активна локация Camp. Дополнительно на сцене есть маркер `Upgrade Board`.
- Панель показывает все апгрейды (`storage_warehouse`, `stations_forge`, `defense_fence`), текущие уровни, стоимость следующего уровня и требования. Кнопка `Upgrade` активна только при выполнении условий и наличии ресурсов в `CampStorageManager`.
- При успешном апгрейде `CampUpgradeManager` агрегирует эффекты и рассылает модификаторы:
  - `storage_capacity_bonus` / `storage_max_stacks_bonus` → влияют на склад.
  - `autocraft_speed_multiplier` и `autocraft_queue_slots_bonus` → NPC крафт.
  - `unlock_station_type`, `station_level_bonus` → подготовлено под будущие станки/мастерские.
  - `camp_defense_level_bonus`, `unlock_fence_visual` → данные для будущих визуальных апдейтов защиты.
- Прогресс пока хранится в памяти, но `CampUpgradeManager` изолирован и готов к интеграции с системой сохранений.

## Автокрафт через NPC
1. В лагере открой `CampStorageDebugUI`.
2. Поле `recipe_sword_basic` + `Count` → кнопка «В очередь». Менеджер резервирует ресурсы (`CampStorageManager.reserve`) и переводит заказ в `reserved`.
3. NPC обрабатывает очередь последовательно. Во время `in_progress` резерв снять нельзя (`cancel_order` вернёт false).
4. Можно уйти в лес (NPC продолжит работу). После `craft_time_sec * count` результат вернётся в `CampStorageManager`, статус заказа поменяется на `completed`.
5. Кнопка «Очистить очередь» снимает резервы у всех заказов, кроме тех, что в статусе `in_progress`.

## Работа с резервами
- `CampStorageManager` хранит реальные остатки (`total`) и резерв (`reserved`). Свободный остаток = `total - reserved`, именно он используется для ручного крафта.
- При недостатке свободных ресурсов `reserve` вернёт `missing_items`, UI может предложить либо уменьшить запрос, либо снять резерв (через `unreserve`). Снимать резервы в приоритете «с конца очереди».
- После запуска NPC (`status = in_progress`) используется `consume_reserved` – ресурсы переходят из резервов в расход и unreserve для таких заказов блокируется.

## Как добавить новые данные
1. Создай JSON в нужной директории (`data/items`, `data/recipes`, `data/experiments`), укажи уникальный `id`.
2. При необходимости перезагрузи `ItemManager`/`CraftManager` (например, сменой сцены или добавлением временной кнопки Reload) – они перечитывают каталоги на старте.
3. Для новых апгрейдов создавай JSON в `data/camp_upgrades`, указывая `upgrade_id`, `levels`, `cost`, `requirements` и `effects`. `CampUpgradeManager` автоматически подхватит данные при следующем запуске.
4. Убедись, что все id используются в рецептах/экспериментах и что склад знает про новые предметы (простое добавление через `CampStorageManager.add({"new_item": N})`).

