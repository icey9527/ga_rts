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
