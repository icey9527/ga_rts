# 计划文件夹使用约定

- 这里只存放**进行中的长期计划**，一个计划一个文件，文件名前缀数字代表推荐执行顺序。
- 每个计划文件包含：目标、前置依赖、步骤、验收标准。验收标准全部满足且
  `python tools/check_lua.py`、`lovec.exe . --verify` 全绿后，**删除该计划文件**。
- 总体设计契约见 `docs/battle_redesign_plan.md`（单一更新流程、单一写入者、验收阶段），
  本文件夹的文件是它的执行清单，两者冲突时以设计文档为准并在此修正。
- 开源参考引擎在 `dump/gardens-of-kadesh-master`（Homeworld 源码维护版），
  只移植行为与结构思路；逐行翻译前先确认其许可边界。

## 已完成的计划（文件已删）

- 阶段 0（2026-09-10）：AI 止血（集火滞回、战略/协同生效）、队伍列表缓存、
  热量文档裁决、`retarget_timer` 初始化修复。
- 计划 01 命令层（2026-09-10）：`battle/commands.lua` 成为玩家与自动命令的
  唯一状态写入口；orders、UI 返航/防守、受击反锁、自动行为全部接入；
  命令完成点由状态机清除。
- 计划 03 舰队 AI 分层（2026-09-10）：`systems/ai.lua` 拆分迁入
  `battle/ai/{profiles,strategy,focus,executor,controller}.lua` 并删除旧文件；
  AI 决策全部经命令层下发。
- 计划 02 机型迁移（2026-09-10）：15 种机型全部迁入 `battle/unit/types/`，
  `common.lua` 提炼 GoK Attack.c 的侧移掠袭/直线压迫双引擎；
  删除 `units/*/logic.lua`、`units/shared.lua`、type_loader 回退与
  `entities/unit.lua` 通用环绕兜底（circle_strafing）。
- 计划 04 技能与数值（2026-09-10）：必杀技全部迁入 `battle/skills/`
  （registry 分发，`systems/special_attacks.lua` 已删除，`systems/skill.lua`
  只作门面）；pacing 伤害倍率移入配置加载；buff 增伤改快照显式乘数；
  战斗参数收敛到 `config/gameplay.lua`；SP 改为伤害充能（造成/承受/维修
  三来源，技能弹不回流）；新增 `--fire-profile` 火力剖面诊断。

## 已完成的计划（文件已删）

- 阶段 0 / 计划 01 命令层 / 计划 03 舰队 AI 分层 / 计划 02 机型迁移 /
  计划 04 技能与数值（2026-09-10，详见 git 历史）。
- 计划 05 自动化部分（2026-09-11）：能量角色化、炮击哑弹、SP 命中回充、
  轻型补正、火力剖面双档；剩余人工实机验收保留在 05 文件中。
- 计划 13 编队与增援（2026-09-11）：上阵 7 人 + 阵营选人增援 + 编队存档。
- 计划 15 主界面背景（2026-09-11）：头像俄罗斯方块拼图 + --menu-shot 验收。

## 当前计划

| 文件 | 计划 | 前置 | 状态 |
| --- | --- | --- | --- |
| `05_balance_effects_cleanup.md` | 平衡收尾：只剩人工实机验收 | 无 | **等用户实机** |
| `06_entities_into_battle.md` | entities 拆迁入 battle + 特效按通用/技能专属归类 | 无 | 下一步 |
| `07_weapon_diversification.md` | 武器多元化：伤害/装甲克制、点防御拦截、过热差异化 | 05 | 排队 |
| `08_structure_cleanup.md` | systems 分流（battle/mission/systems 三层）+ 死代码清单（含随机池文件删除） | 06 | 排队 |
| `09_maps_redesign.md` | 关卡改为 maps/ 目录扫描的自描述地图 | 08 | 排队 |
| `11_combat_feel.md` | 战斗手感：技能武器绑定、技能后摇、补给滑行 | 无 | 排队 |
| `12_weapon_facings.md` | 武器方位：侧舷/尾炮接敌、非正面武器自主目标、挂点 | 07 | 排队 |
| `14_dialogue_face_system.md` | face.tbl 编号体系、每句头像、角色覆盖、面板子目录 | 无 | 排队（用户指定随后） |

计划 10（资源目录）已关闭（2026-09-11）：用户确认 `dump/` 是临时目录且
已 git 忽略，无需处理；`assets/` 保留为运行时素材目录。

## 2026-09-10 残留与未实现功能排查结论（写计划时的依据）

已实现未使用（列入 08 删除清单）：`core/json.lua`、`core/event.lua`、
`Effect.unit_death`、legacy 技能 teleport/disable/heal_aoe、`unit.repair_rate`、
gameplay 的 supply_rate/supply_hp_rate。
有设计未实现（保留为后续方向）：主菜单机体预览、第一人称接管/真 3D、
完整战局快照存档、运输船循环采集与敌方经济经营、独立炮塔朝向、
关卡地图化（已立计划 09）。

