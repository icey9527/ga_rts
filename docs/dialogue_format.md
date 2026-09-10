# 队伍对白格式

对白统一写在 `teams/<队伍>/advisor/dialogue.lua`，不要在关卡脚本或系统 Lua 中写角色专属台词。

## 基本结构

```lua
return {
  panel = {"%s，下命令吧。"},
  groups = {
    {left = "左手台词", right = "右手台词"},
  },
  scenes = {
    {
      {id = 21, text = "{commander}，准备接战。"},
      {id = 26, text = "收到，马上行动！"},
    },
  },
  economy = {
    no_credits = "资源不足。",
    energy = "%s能量不足，建议脱离火线。",
  },
}
```

## 可用变量

- `{commander}`：当前发言方所属队伍的指挥官
- `{player_commander}`：我方实际指挥官
- `{enemy_commander}`：敌方实际指挥官
- `{opponent_commander}`：当前发言方的对手指挥官
- `%s`：由系统传入当前机体名称；只建议放在句中，不要单独占一行

`groups` 用于战斗中左右手对白；同一组的 `left` 和 `right` 会使用相同组号。`scenes` 用于战前小剧场，按数组顺序交替播放。没有配置的段落不会自动回退到关卡文本。

## 机体驾驶员台词

机体受损、能量不足、攻击、必杀技等台词属于机体驾驶员本人，写在该角色自己的 `chara.tbl` 或 `dialogue.lua` 中，不写进左右手的 `groups`。

常用事件键：

- `hit`：机体受损，例如“机体受损，请求修理。”
- `energy`：能量不足、准备返航补给
- `supplied`：补给瞬间完成
- `return_battle`：脱离母舰、重返战场
- `attack`：进入射程并开始攻击
- `command`：接受移动或攻击指令
- `failed`：指令无法执行
- `ready`：必杀技充能完成
- `skill`：释放必杀技
- `lost`：机体被击毁
- `camera_follow_start`：镜头切换到该机体时触发
- `camera_follow_continue`：镜头持续跟随时按冷却播报（不会每帧触发）
- `camera_follow_end`：镜头停止跟随或切换到另一台机体时触发
- `formation_follow_start` / `formation_follow_continue` / `formation_follow_end`：机体跟随命令的三个事件

发言间隔配置在 `config/comms.lua`：`report_interval` 是同一机体连续两句通讯的最短间隔，`formation_follow_continue_interval` 控制机体跟随持续播报，`camera_follow_continue_delay` 要求镜头单独跟随某台机体至少 10 秒后才允许第一次持续闲聊，`camera_follow_continue_interval` 控制该机体后续持续闲聊间隔，`camera_follow_start_interval` 控制玩家快速切换镜头时的全局 CD，`camera_follow_end_enabled` 控制是否显示脱离镜头跟随对白，`camera_follow_end_min_duration` 要求镜头单独跟随该机体至少 10 秒才允许触发结束对白。每台机体保存自己的开始时间和持续闲聊时间，不共用计时字段。`follow_priority_window` 控制跟随角色抢话时的短暂优先窗口。优先级只影响窗口内的并发播报，不会长期压制敌方；跟随结束后立即回收优先状态。

跟随台词兼容两种位置：旧格式可写在 `friendly.follow` / `friendly.follow_reply`；新的 `follow_start`、`follow_continue`、`follow_end` 可以直接写在对白表顶层。读取器会优先读取 `friendly` 下的同名字段，再读取顶层字段。

两类跟随完全不同：`camera_follow_*` 是玩家主视角锁定机体时，由镜头绑定的机体说话；`formation_follow_*` 是一台机体执行跟随另一台机体的命令，由执行命令的机体说话。镜头跟随对白不读取 `follow_target`，机体跟随对白也不会因为玩家切换镜头而触发。所有事件都使用运行时对象，不使用上一次指令缓存。

## 两套跟随事件示例

下面的示例可以直接写进角色的 `dialogue.lua`。每个事件都只描述一种明确场景：

```lua
return {
  -- 玩家把镜头切到这台机体后，这台机体说话。
  camera_follow_start = {"镜头切过来了？我会保持航向。"},

  -- 玩家持续看着这台机体一段时间后，这台机体偶尔说话。
  camera_follow_continue = {"还在观察吗？前方航路没有异常。"},

  -- 玩家停止镜头跟随或切换到别的机体后，这台机体说话。
  camera_follow_end = {"镜头移开了，我继续执行当前任务。"},

  -- 这台机体收到“跟随另一台我方机体”的命令后说话。
  formation_follow_start = {"收到跟随命令，我跟在你的右侧。"},

  -- 这台机体实际跟着另一台机体飞行时，按冷却偶尔说话。
  formation_follow_continue = {"编队间距正常，继续保持。"},

  -- 被跟随目标死亡、命令取消或改接其他命令后，这台机体说话。
  formation_follow_end = {"跟随结束，准备接收新的指令。"},
}
```

注意：`camera_follow_*` 的“跟随对象”是玩家当前观看的机体；`formation_follow_*` 的“跟随对象”才是运行时字段 `unit.follow_target` 指向的另一台机体。两者不能互换，也不要用 `follow_target` 来判断镜头是否正在跟随。

当前拆分边界：`core/` 放游戏状态、镜头和输入基础；`ui/` 放界面、选择、指令和战术箭头；`systems/` 放订单、顾问和任务流程；`entities/` 放单位运行时行为；`battle/ai/` 放 AI 入口及后续 AI 策略；`config/` 放可调参数。迁移继续按完整功能块进行，避免只移动文件而改变调用行为。

低血量和低能量由系统按冷却自动触发，分别使用 `hit` 和 `energy`。建议驾驶员台词使用明确动作，例如“装甲告急，请求返航补给”或“能源不足，申请回去补给”；系统会在可返航时自动执行。采集站没有驾驶员，不触发这些台词，也不接受普通战斗指挥。

## 机体类型的多武器

武器属于 `config/units/<type>` 的机体类型，不属于角色。运行时支持：

```lua
weapons = {
  {id="main", range=900, damage=60, cooldown=2.4, count=1},
  {id="machine_gun", range=300, damage=8, cooldown=0.18, count=4},
}
```

没有配置 `weapons` 的机体会自动使用原有的单门主炮参数。角色只改变驾驶员资料、立绘和对白，不改变机体武器。
