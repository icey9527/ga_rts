# 对白工作室

打开 `tools/dialogue_editor.html` 即可使用，不需要 Python、8080 端口或额外服务。编辑器使用 Chrome / Edge 的 File System Access API 直接读写本地资源。

## 使用方式

1. 选择项目根目录 `rts_game`，或直接选择 `teams` 目录。
2. 选择队伍、原皮/皮肤和角色。
3. 在左侧选择对白事件，编辑中间的多条台词。
4. 输入后会自动保存到 `teams/<队伍>/chara/<编号>/dialogue.lua`。

皮肤不会复制一份对白文件。选择皮肤时，编辑器使用皮肤头像预览，但台词仍写回该角色的原皮 `dialogue.lua`，与游戏运行时行为一致。

## 头像规则

头像不是固定路径。编辑器会读取当前角色或皮肤目录中的 `chara.tbl` 与 `face/*.png`，并复用游戏 `ui/pilots.lua` 的事件映射：

- `attack`、`skill` 使用 `face_attack` 或攻击表情。
- `hit`、`energy`、`failed`、`lost` 使用 `face_hit` 或受击表情。
- `idle`、`praise` 使用 `face_idle` 或日常表情。
- 其余事件使用 `face_normal` 或文件名回退规则。

如果 `chara.tbl` 显式指定了 `face_attack`、`face_hit` 等文件，编辑器优先使用这些文件；找不到时才按游戏同样的文件名规则回退。

## 支持的事件

角色对白支持 `friendly` 与 `enemy` 下的 `ready`、`interaction`、`command`、`attack`、`hit`、`energy`、`supplied`、`return_battle`、`repair_done`、`failed`、`skill`、`lost`、`idle`、`praise`，以及镜头跟随和编队跟随的三个事件。

每个事件都支持多条字符串台词。编辑器允许添加、删除和调整顺序；保存时会保留字符串中的占位符：`{commander}`、`{player_commander}`、`{enemy_commander}`、`{opponent_commander}`、`%s`。

切换“队伍顾问 / 战前对白”后，编辑器会读写 `teams/<队伍>/advisor/dialogue.lua`。`left/right` 台词按队伍 `team.tbl` 中的左右手角色编号显示头像；`groups` 会分别显示左右手文本，`scenes` 会显示场景内的角色编号与文本。皮肤选择仍只影响头像预览，不会复制顾问台词文件。

## 安全措施

- 自动保存前会检查文件内容是否被其他窗口改过。
- 解析失败或保存冲突会显示错误，不会回退成默认台词。
- 目录句柄只保存在浏览器 IndexedDB 中，不上传任何文件。
