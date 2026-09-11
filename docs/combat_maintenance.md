# 战斗系统维护约定

本轮检查：2026-09-10。

## 数值模型与 SP

`config/pacing.lua` 的伤害倍率（`damage_multiplier`）在 `levels/manager.lua` 加载配置时一次性乘入 `attack_damage`、`weapon.damage` 与 `skill.damage`：**加载后的数值即实际结算数值**，`take_damage` 不再二次缩放，属性面板与平衡调试不需要心算倍率。技能模块里的兜底默认值按 `floor(基础值*倍率)` 书写。

攻击增益（`buffs.attack`）不再改写 `unit.attack_damage` 基础值：`battle/unit/combat.lua` 开火时把 `buffs.attack.multiplier` 显式乘入武器伤害快照；快照生成后连发延迟弹药不再读取单位属性。

SP 的来源是实际战斗效果（不再按开火次数）：普通弹药命中/溅射按 `pacing.sp_per_damage_dealt` 给施放者回充并附加 `sp_per_hit` 命中小额（0.4/发，防止高频低伤武器充能过慢；光束类即时结算同理由 spawn 回充）；承受伤害按 `pacing.sp_per_damage_taken` 给受击方回充，重甲高受击单位自然更快充能；维修机按实际修复量以 `pacing.sp_per_repair` 回充。基准充能时间：拦截机曳光约 26 秒、狙击约 14 秒充满。必杀技弹药带 `no_sp` 标记，必杀伤害不回充施放者 SP，防止自充循环。

武器能量按角色显式配置：快射压制武器（机枪类 1-2）、常规火炮（3-4）、重炮/导弹（4-6），单位缺省回落到 `config/gameplay.lua` 的每周期 5 点。被动回复 1.8/秒意味着高能耗组合仍会枯竭并需要返航补给——这是设计，不是 bug；调平衡时先用 `--fire-profile` 看实际开火率。

artillery 类型武器在 `weapons.normalize` 有 60 缺省溅射：炮击弹没有目标引用、完全靠落点溅射结算，缺省防止配置遗漏造出命中不结算的哑弹（2026-09-11 修复：重型主炮曾因此全程零命中）。

慢速炮击弹（`artillery` 类型）使用全量前置与更小散布（`pacing.artillery_lead_fraction/artillery_spread_factor`）：重火力的命中靠预测而非弹速，目标变向仍可规避，但匀速直线飞行不再无限戏耍重装单位。`--fire-profile` 输出静止/机动双档 DPS，是平衡调整的对照基准（当前梯度：缠斗 7-11 < 重装 16-23 < 狙击，详见 plans/05）。

## 武器与弹道

`config/units/*.tbl` 是机体和武器配置，`battle/unit/weapons.lua` 为每个单位复制独立的冷却、热量状态。不要向缓存的配置表写入运行时状态。

`battle/unit/combat.lua` 生成开火参数快照，立即发射和延迟连发都交给 `battle/unit/projectile.lua`。伤害、弹速、射程、攻击方向与视觉类型随快照保存；不能临时修改单位属性再用单位属性发出后续弹药。

目前 `damage` 表示每轮齐射的总伤害，除以 `count` 后分配给每发；`burst_count` 是齐射轮数。因此总伤害约为 `damage * burst_count`，存在整数取整。攻击强化进入武器伤害快照。

每门武器一个完整连发周期的 `energy_cost` 默认取全局攻击消耗（`config/gameplay.lua`），除以 `count * burst_count`，仅在每发成功生成时结算；未发出的弹药不扣能量、不积热。热量逐发按 `heat_per_shot` 累积；目标失效、射界不足、过热、能量不足时取消本周期剩余弹药。多门武器分别结算，避免同帧合并开火获得不一致的成本。冷却从首次发射开始，队列结束前不重叠启动新的周期。手动命令和返航等清理必须调用 `Combat.cancel_bursts`，同时解除武器的队列占用。

类型加载只认 `battle/unit/types/<type>.lua`（详见下文验证节）。普通航行与技能突进互斥。

普通炮弹、导弹与必杀技弹药需要携带 `source`，供受击反锁使用。慢速弹药寿命必须覆盖到目标点的飞行时间；高速弹药使用线段碰撞检测。

## 移动、索敌与技能

`battle/unit/movement.lua` 负责速度变化和按秒计算转向。开火判定不能再次修改朝向。绕行点根据实际机体位置计算，超出射程一定距离恢复追击，保留缓冲区以减少反复切换。航线受阻播报按单位有 2 秒冷却。

`core/game.lua` 的 `get_units_by_team`、`get_enemy_units`、`get_all_friendly_units`、`get_mothership` 使用按队伍缓存：返回的是共享列表，调用方只读遍历，禁止 insert/remove/sort。增援入队、单位死亡（take_damage）和 reset 自动失效缓存；脚本直接改 `alive` 模拟死亡时必须手动调用 `game:invalidate_team_cache()`。

舰队 AI 已分层迁入 `battle/ai/`：`profiles.lua`（人格/难度/战略数据）、`strategy.lua`（力量对比审查与权重修正）、`focus.lua`（集火目标，带 150 分滞回，等分目标不翻转）、`executor.lua`（单舰效用评分与命令下发）、`controller.lua`（节拍组装，对外 `Controller.new/update`）。`systems/ai.lua` 已删除。集火服从度由难度 `coordination` 决定；所有 AI 决策通过 `battle/commands.lua` 命令层下发，不直接改写单位状态。

命令层 `battle/commands.lua` 是玩家命令与自动命令（AI、机体自动行为、受击反锁）设置战斗状态的唯一入口：玩家命令优先，玩家命令在位期间自动命令被拒绝；自动命令间后者覆盖前者；补给流程只接受重复返航。命令完成点（移动到达、目标死亡转空闲、跟随/维修结束、补给离舰、失能解除）由 `entities/unit.lua` 状态机调用 `Commands.finish` 清除。同命令重复下发幂等，不会打断连发。

有有效攻击目标时，受击不会抢锁；目标不存在或已死亡时锁定攻击者。采集站排除战斗 AI 和受击反锁。狙击行为只修改攻击/绕行状态，不能覆盖返航和手动移动。

必杀技取消时清除瞄准快照和指定目标，并退还 SP。技能弹道需要保留施放者。

## 已知后续工作

推进方向现在跟随机头，转弯时降低航速；武器受机体正面射界限制。狙击机使用短距离射击航线和固定交战中心，超出机动半径后转回，防止互相规避造成整体漂移。仍未实现独立炮塔、完整六自由度飞行。必杀技实现已全部迁入 `battle/skills/`（注册表分发），`systems/skill.lua` 只作门面；`systems/special_attacks.lua` 已删除。

拦截机采用高速白色曳光弹，虎式使用双联重炮与压制弹幕。多用途战机当前为主炮和机枪，后续重做时再设计导弹定位。整体平衡与视觉观感仍需要实机试玩。

## 验证

全部 15 种机型已迁入 `battle/unit/types/`：sniper、fighter、interceptor 各自独立；light、scout 共用 `common.lua` 的侧移掠袭引擎（对应 GoK `attackSideStep`）；heavy、tiger、gunship、carrier、missile_frigate、artillery、bomber、repair 共用直线压迫引擎（对应 GoK `attackStraightForward`：突进→火力距离边逼近边打→`too_close` 内刹车原地射击）；mothership、collector 为无机动脚本。`units/<type>/logic.lua`、`units/shared.lua` 与 type_loader 旧模块回退已删除，`units/` 目录只剩机型对白。`entities/unit.lua` 的通用环绕状态（circle_strafing）、kite 意图和高速接敌特判已移除；无 fly 的机型（母舰、采集站）走通用逼近路径。

各机型战术参数在 `config/units/<type>.tbl` 的 `[behavior]`：侧移系 `break_distance/reposition_distance/reposition_angle/reposition_time/approach_boost`，直线系 `too_close/approach_boost`。回归覆盖每种机型实际开火且位移有界、单次积分断言、`too_close` 内零积分刹车。

狙击近身策略由 `config/units/sniper.tbl` 的 `[behavior]` 配置：650 内触发加速脱离，950 外结束脱离，倍率约 1.7，规避分为外侧脱离、反向切线、回转占位三段。检测身边敌人，不要求其为当前锁定对象；保留原攻击目标。狙击枪 `min_range=600` 同时用于初始开火和延迟弹药检查。脱离期间优先飞行，不执行普通攻击；返航等命令清除脱离状态。

狙击当前加载后冷却 4.8 秒（基础 3 秒 × 全局冷却倍率），普通伤害 506（加载时已含伤害倍率），对基础多用途战机 1500 血量约为 33.7%；必杀伤害 825。弹速加载后 3420。以上为无护盾无强化、命中时的基准，不代表必然命中或所有目标按百分比扣血。SP 充能按伤害结算后，狙击约 4 发命中充满，与高频低伤武器的击杀充能速度对齐。

执行 `python tools/check_lua.py`，扫描包含 `battle/` 的 Lua 文件，并运行 `tools/verify_combat.lua`：覆盖武器独立状态、连发快照、强化、反锁、高速命中、慢弹寿命、敌我狙击移动开火和实际到达判定。
