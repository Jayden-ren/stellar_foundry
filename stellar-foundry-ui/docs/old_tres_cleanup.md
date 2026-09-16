## 已清理的旧数据文件

当前静态配置已经统一迁移到 `res://data/buildings/building_registry.json`。

以下旧 `.tres` 文件已从运行时数据链路移除，建议在确认 Godot 项目可正常运行后一并删除：

### 建筑
- `data/buildings/mining_drill.tres`
- `data/buildings/smelter.tres`
- `data/buildings/conveyor.tres`
- `data/buildings/storage.tres`
- `data/buildings/trading_post.tres`

### 资源
- `data/resources/iron_ore.tres`
- `data/resources/copper_ore.tres`
- `data/resources/coal.tres`

### 为什么可以清理
- `BuildingRegistry.gd` 已成为唯一加载入口
- `GameWorld.gd` 不再读取 `res://data/buildings/*.tres` 或 `res://data/resources/*.tres`
- 项目 `.gd` / `.tscn` 中未再引用这些旧 `.tres`
- `BuildingData.gd` / `MineralData.gd` 已扩展为可直接从 JSON 生成实例所需的字段

### 保留建议
- 若还想保留本地备份，可先把这两个目录复制到仓库外备份：
  - `data/buildings/`
  - `data/resources/`
- 若你希望我继续，我可以下一条直接给你一份**建议保留/建议删除的文件清单**或**一键删除命令**。
