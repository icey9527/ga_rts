# 计划 08：目录重组、存档系统重置与残留清理

## 目标

`systems/` 按"跨场服务"分层归位（可多层子目录，但不造小文件）；
存档系统重置为统一结构；删除全部确认的死代码。
前置：06（entities 拆迁）完成后执行，避免二次搬移。

## 已确认的死代码清单（2026-09-10 排查，删除项）

| 位置 | 说明 |
| --- | --- |
| `core/json.lua` | 全仓零引用 |
| `core/event.lua` | 全仓零引用 |
| `entities/effect.lua` 的 `Effect.unit_death` | 零调用（死亡走 explosion） |
| `battle/skills/legacy.lua` 的 teleport/disable/heal_aoe | 实现存在，无任何配置/关卡引用（damage_aoe 有 gunship 在用，保留） |
| `unit.repair_rate` 字段 | 读入后从未使用（维修是即时满血） |
| `config/gameplay.lua` 的 supply_rate/supply_hp_rate | 无读取方（补给即时满）——补给若改渐进式则启用，否则删 |

## systems/ 分流方案（用户反馈 2026-09-11：要分类、可多层子目录、别太多小文件）

```
battle/（战斗运行时，随 06 一并归位）
  navigation.lua、terrain.lua、space_scene.lua
  presentation/cinematic.lua、presentation/skill_visuals.lua、ship_renderer.lua

mission/（任务与编排）
  mission_script.lua、objectives.lua、simulation.lua（部署）、battle_flow.lua、
  economy.lua、minerals.lua、random_roster.lua

systems/（跨场服务，允许二级子目录归类）
  audio/（audio、bgm）      persist/（preferences、score、loadout）
  comms/（advisor、comms_slots）   teams/（pack_registry）
  orders（玩家命令入口，命令写入仍经 battle/commands）
```

原则：只按运行职责分层；同层文件少于三个的不再拆子目录（避免碎片化）。

## 存档系统重置（用户反馈 2026-09-11）

现状散落：`saves/preferences.tbl`（偏好）、`saves/loadout.tbl`（编队）、
根目录 `high_scores.tbl`/`high_scores.json`（计分）、无战局快照。

目标结构（一次重置，旧文件迁移后删除）：

```
saves/
  profile.tbl     偏好 + 上次敌我队伍 + 音量等（合并 preferences）
  loadout.tbl     编队（[player.队]/[enemy.队]，members={编号}）
  scores.tbl      最高分（按 map/level id）
```

- 读写统一走 `systems/persist/` 一个门面：启动时读、变更即写、
  校验与默认值集中一处；`high_scores.*` 从根目录迁入并清理双格式并存。
- 战局快照（单位/弹道/波次/剧情游标）不在本计划——需要时单独立项。

## 步骤

1. 先删死代码清单（含 legacy 三技能及其 registry 映射、AI executor 对
   heal_aoe/disable 的判断分支同步清理）。
2. 逐组搬迁 + 全量改 require（battle/presentation、mission/ 两组）。
3. `levels/` 目录随计划 09 处理，此处不动。
4. MAINTENANCE.md 结构表重写为最终目录树。

## 验收

- [ ] 死代码清单全部删除；`grep` 零残留引用。
- [ ] `systems/` 只剩服务模块；根目录无 entities/。
- [ ] 全量 verify 绿。

## 完成后

删除本文件。
