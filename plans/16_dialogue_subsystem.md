# 计划 16：对话独立子系统（事件驱动，与战斗逻辑解耦）

来源：用户反馈 2026-09-11（"对话判定不要写在战斗逻辑里；可以依赖战斗逻辑
但不要写在一起；单独子文件夹、单独接入，可以考虑独立线程或全局变量桥接"）。

## 现状问题

- 对白触发判断散落在战斗代码里：`game:report_event`（core/game.lua）直通
  `ui/pilots.line`，节流/冷却/优先级逻辑长在战斗状态里；`systems/mission_script`
  的剧情队列、`systems/advisor`/`comms_slots` 的反应逻辑、单位文件里的
  判定对白各自为政。
- 想改一句台词的触发条件，要动战斗代码；战斗重构（06/08）也会反复牵连对白。

## 设计：事件总线 + 独立子系统

```
battle/（及 mission/economy 等一切"玩法"侧）
    └─ 只负责在状态变化点 发布 事件：
       Events.publish("unit_lost", {unit=..., attacker=...})
       Events.publish("hp_low"/"kill"/"skill_ready"/"order_failed"/...)

dialogue/（新顶层目录，与战斗彻底分离）
    bus.lua          事件订阅/发布/帧内排队（单文件，含冷却与优先级仲裁）
    rules.lua        触发规则表：事件 -> 谁在什么条件下说什么（数据，可配）
    presenter.lua    把"要说的台词"投递到现有气泡/通讯槽/立绘 UI
```

- **不是真多线程**：LÖVE 单线程，帧首统一 `bus.flush()` 消费上一帧积累的
  事件；战斗侧发布零阻塞，对话判定完全在 dialogue/ 内。Lua 协程只用于
  多句连播的时序控制（现有 mission_script 已有类似结构，可并入）。
- 战斗侧契约只有一条：**在状态变化点调用 Events.publish**。对白文案、
  触发条件、冷却、优先级全部收进 dialogue/。
- 迁移期 `game:report_event` 改为薄转发（发布事件），现有 UI 不动；
  迁完后 ui/pilots 只做"展示"不再做"判断"。

## 步骤

1. 建 dialogue/bus.lua + 在 core/game.lua 的 report_event 处发布事件
   （双轨期：旧路径照常工作，事件并行记录）。
2. rules.lua 吸收 report_event 现有节流/优先级/角色判定逻辑，
   presenter 对齐现有气泡输出；灰度切换。
3. mission_script 的剧情队列、advisor/comms_slots 反应逐步并入
   （它们本就是"剧情与反应"，归 dialogue/ 或其 presentation 层）。
4. 删除战斗侧的台词字符串与触发判断（defaults 表迁走）。

## 验收

- [ ] 战斗目录（battle/、entities 后继）grep 不到台词字符串与发言冷却逻辑。
- [ ] 对白行为回归：受击/击破/补给/命令失败等既有断言全绿。
- [ ] 新增一条"只改 rules.lua 就能改触发条件"的演示条目。

## 前置

06（entities 拆迁）完成后做，避免双线重构同一批文件。

## 完成后

删除本文件。
