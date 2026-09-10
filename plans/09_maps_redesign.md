# 计划 09：关卡改为可扫描的地图系统

## 目标

取消"关卡 = 编号脚本"的旧模式，改为 **maps/ 目录下的自描述地图**：
菜单扫描文件夹逐张识别，地图元数据（名字、背景、尺寸、胜利条件、队伍）
随图走，新增地图 = 新增文件夹，不改任何代码。

## 现状问题

- `levels/manager.lua` 用硬编码正则 `level_%d+%.tbl` 扫描，11 张图按编号排列，
  菜单显示编号而非名字。
- 图的元数据（背景/地形/波次）与任务脚本（levels/scripts/level_XX.lua）分离，
  但绑定靠编号约定，改号即断。
- 教学关 level_00 靠 meta.tutorial 特判。

## 目录设计

```
maps/
  <map_id>/              -- 文件夹名即地图 ID（英文短名）
    map.tbl              -- [meta] name(显示名)/background/size/tutorial
                           [victory] [defeat] 条件
                           [ai] difficulty/personality
    spawns.tbl           -- 双方出生、地形、矿脉、波次（原 level tbl 主体）
    script.lua           -- 可选：剧情队列/额外触发（原 levels/scripts）
```

- 扫描器：`maps/scanner.lua` 列出全部含 map.tbl 的子目录，读 [meta].name
  排序展示；tutorial=true 的图排最前并标记。
- 存档/最高分按 map_id 记录（替代按文件名）。
- 旧 11 张图机械迁移：level_XX.tbl + scripts/level_XX.lua → maps/<id>/，
  名字取各图 meta；`levels/` 目录删除。

## 兼容与验收

- [ ] 菜单列出全部地图（含中文名），任选可开战，教学图标记正确。
- [ ] 新增一个空地图文件夹（无 script）可直接进图开战——"加图不改代码"成立。
- [ ] 最高分、验证脚本（verify/verify_missions 十图循环）按 map_id 全绿。
- [ ] MAINTENANCE.md 与 STORY_AUTHORING.md 更新为地图编写指南。

## 前置

建议在 08（目录重组）之后做，`levels/manager` 的继任者直接落在新结构里。

## 完成后

删除本文件。
