# 计划 17：队伍包结构——指挥官/左右手移出 chara

来源：用户反馈 2026-09-11（"左右手不要当做普通角色，可以不放在 chara，
指挥可能也是——字段和其他角色不一样，容易写重复、容易弄混"）。

## 现状问题

`teams/<队>/chara/<ID>/` 混装三类身份：

| 身份 | 实际字段 | 问题 |
| --- | --- | --- |
| 普通队员 | chara.tbl（name/type/rank/face_*）+ dialogue + 立绘 | 标准结构 ✓ |
| 左右手 | 多了 intro/interlude/left/right 台词、半身立绘 | 字段和队员不一样，塞同一目录靠编号区分，重复且易混 |
| 指挥官 | mothership 驾驶员 + 战前小剧场 + 常不参战 | 同上；混在 chara 列表里还要靠 team.tbl 反向排除 |

## 设计

```
teams/<队>/
    team.tbl          commander/left/right 改为指向 advisor/ 子目录名
    chara/<ID>/       只放可上阵队员（普通结构）
    advisor/<name>/   左右手/指挥官每人一目录：
                        profile.tbl（名字、称呼、语气规则）
                        dialogue/（intro.lua / interlude.lua / panel.lua）
                        chara.png（立绘/半身）
```

- 选人/上阵/增援只扫 `chara/`——指挥官与左右手天然不再混进队员列表，
  `team.tbl` 里"commander 移出 chara 成员列表"的历史补丁可以删掉。
- 左右手对白按计划 14 拆到 `advisor/<name>/dialogue/` 子文件，
  与本计划同一批迁移一次完成。
- `Registry.character`/`ui.pilots` 的查找路径加 advisor 段；
  `systems/advisor`、`comms_slots` 的角色解析改读新结构。

## 迁移

- 脚本化搬移现有两队 + default + 弹丸论破 + baldr_heart 的顾问目录；
  旧路径加载兼容保留一个版本期，之后删除。

## 验收

- [ ] `chara/` 内不再有指挥官/左右手目录；上阵/增援/名册零特判。
- [ ] 顾问通讯、战前小剧场、指挥官立绘全部从新结构加载（回归绿）。
- [ ] MAINTENANCE.md 与 STORY_AUTHORING.md 更新队伍包结构说明。

## 前置

与计划 14（face.tbl/对话编号）同批做最省——同批文件只动一次。

## 完成后

删除本文件。
