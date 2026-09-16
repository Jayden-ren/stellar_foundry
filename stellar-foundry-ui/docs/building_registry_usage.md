## 建筑/资源数据单一配置源

### 目标
- `data/buildings/building_registry.json` 作为建筑、资源和分类的唯一静态配置源。
- 运行时不再直接从 `res://data/buildings/*.tres` 或 `res://data/resources/*.tres` 读配置。
- `BuildingRegistry` 负责加载、校验和暴露给 UI/玩法逻辑。

### 使用方式

#### 1. 分类
```gdscript
var categories = BuildingRegistry.get_categories()
var label = BuildingRegistry.get_category_label("mining")
```

#### 2. 资源
```gdscript
var iron = BuildingRegistry.get_resource("iron_ore")
var all_resources = BuildingRegistry.get_all_resources()
```

#### 3. 建筑
```gdscript
var smelter = BuildingRegistry.get_building("smelter")
var category_items = BuildingRegistry.get_buildings_by_category("processing")
var world_items = BuildingRegistry.get_game_world_buildings()
```

#### 4. 额外字段
`icon`、`desc`、`req_tech`、`enabled` 这类尚未进入 `BuildingData` / `MineralData` 脚本类的字段，可从 raw 数据读取：

```gdscript
var raw = BuildingRegistry.get_raw_building("smelter")
var desc = str(raw.get("desc", ""))
var icon = str(raw.get("icon", ""))
var req_tech = str(raw.get("req_tech", ""))
```

### 校验
启动时会自动检查：
- `buildings` / `resources` 数组类型是否正确
- `id` 是否存在
- `id` 是否重复
- 建筑 `category` 是否存在于 `categories`

### 后续清理
当前代码已不再引用旧的 `.tres` 建筑/资源定义。
确认游戏运行正常后，可以将以下目录作为历史数据保留或删除：
- `data/buildings/*.tres`
- `data/resources/*.tres`
