# Deep Space Command 维护手册

这是基于 LÖVE 11 的太空 RTT。战斗逻辑使用二维世界坐标，`z` 用于高度表现、部分障碍判断与投影，不是真正的三维飞行模拟。当前保留原有指挥方式，重点完善演习任务、角色通讯、技能和后勤。

## 开始维护

1. 运行 `love .`，选择关卡；除训练关外，先选择舰队和阵型，再进入剧情。
2. 阅读本手册，再按工作内容阅读 [剧情编写指南](docs/STORY_AUTHORING.md) 或 [素材映射](docs/ASSETS.md)。
3. 先执行 `python tools/check_lua.py`，再运行 `lovec.exe . --verify`。前者检查 Lua 语法和逻辑，后者增加真实 LÖVE 绘制、输入和素材解码验证。
4. 修改某项行为后，只增加能揭露实际错误的回归场景。例如补给结束是否离舰、剧情是否重复触发、暂停是否消耗技能。

当前交接清单见 [TODO_NEXT.txt](TODO_NEXT.txt)。它同时记录已完成基线、下一阶段优先级和验收条件。接手者应先阅读该文件，再按本手册的模块边界修改代码。

Windows 发布可先运行根目录的 `build_release.bat`，它会生成 `release/game` 并排除调试截图和验证输出；单文件 EXE 仍需使用与项目匹配的 LÖVE 版本完成 `.love` 合并。

当前 Windows 的 LÖVE 位于 `C:/Program Files/LOVE/`。无窗口检查工具默认从这里加载 `lua51.dll`；其他机器需要修改该工具的 DLL 路径。

## 项目结构

| 路径 | 职责 |
| --- | --- |
| `main.lua` | 游戏状态、输入路由、窗口生命周期、渲染顺序、调试截图入口 |
| `core/game.lua` | 单位、弹道、效果、阵营、暂停、增援与整场战斗状态 |
| `core/camera.lua` | 中键平移、滚轮缩放、边缘滚屏、观察跟随 |
| `core/tbl.lua` | 简单 TBL 配置解析 |
| `entities/unit.lua` | 单位状态机、攻击、补给、受击、技能蓄力 |
| `entities/projectile.lua` | 普通弹、导弹、范围弹道、连续碰撞检查 |
| `entities/effect.lua` | 世界空间效果，效果不直接代替伤害结算 |
| `units/<type>/logic.lua` | 机型的行为入口；通用机动复用 `units/shared.lua` |
| `units/<type>/dialogue.lua` | 机型层面的兜底移动和闲聊，不保存关卡剧情 |
| `config/units/*.tbl` | 机体基础数值、武器、技能参数 |
| `config/characters.lua` | 原始角色 ID、中文名、语气规则 |
| `config/squadrons.lua` | 两支演习舰队的角色与机型组合 |
| `config/character_assets.lua` | 角色 ID 到可读立绘文件名的映射 |
| `dialogue/characters/<ID>.lua` | 每个角色的我方、敌方判定对白和闲聊 |
| `dialogue/exchanges.lua` | 两个角色之间的一问一答，适用于日常与跟随 |
| `levels/level_XX.tbl` | 背景、地形、旧关卡单位和波次数据 |
| `levels/scripts/level_XX.lua` | 任务目标、固定开场/中场/胜败剧情、额外支援、训练步骤 |
| `systems/mission_script.lua` | 剧情队列、条件判定、角色查找和剧情显示位置 |
| `systems/objectives.lua` | 护送、限时防守、母舰与全歼任务 |
| `systems/orders.lua` | 玩家命令验证和下发，禁止命令敌舰 |
| `systems/skill.lua` | 技能可用性、目标模式、名称、通用技能结算 |
| `systems/special_attacks.lua` | 蓄力贯穿、连续轰炸、滑步碰撞及任务队列 |
| `systems/cinematic.lua` | 最多三条并行的侧边必杀演出，不改镜头 |
| `systems/skill_visuals.lua` | 屏幕短闪、释放慢动作，不负责技能伤害 |
| `systems/economy.lua` | 资源、建设/招募/研究队列、退款、按槽位的后勤反馈 |
| `systems/minerals.lua` | 矿脉、剩余矿藏、采集站绑定与产出 |
| `systems/preferences.lua` | 跨关卡、跨启动的操作偏好 |
| `systems/audio.lua` | `assets/se` 音效加载缓存、音量、事件冷却、最大并发声音 |
| `ui/` | 单位列表、侧栏、通讯、常驻定位头像、菜单与结果页 |
| `assets/` | 游戏实际运行使用的素材 |
| `png/`、`dump/` | 原始素材仓库；运行代码应优先引用 `assets/` |
| `tools/` | 语法检查、无窗口逻辑检查、LÖVE 回归与截图 |

## 设计原则

### 身份、机型和图片分别管理

`unit.character_id` 是驾驶员身份，`unit.unit_type` 是机型。`unit.name` 在加入游戏时设为角色名，`unit.type_name` 保留中文机型名称。不要从单位显示名推断类型，不要从立绘文件序号推断角色身份。

例如卡兹亚和枣的原必杀立绘文件编号与角色 ID 不一致。当前运行素材已改名为 `kazuya.png` 和 `natsume.png`，由显式映射加载。头像表情继续按原 `facNNN_XXXX` 编号查找。

角色可以更换机型，但语气、个人偏好和立绘仍属于角色。新增一台机体时，应先确定它的机型，再指定或分配驾驶员。

### 三种对白分别维护

- 剧情对白：只放在关卡脚本，包括开场、中场、教学、胜败；有确定的角色、条件和顺序。
- 判定对白：放在角色文件，包括接令、攻击、受击、失能、技能就绪、命令失败和表现评价。
- 随机对白：角色日常对白与双人对话。跟随关系增加对应组合的权重，不将整场闲聊提高到连续刷屏。

不要把“这一关发生了什么”写成角色的通用台词。否则角色会在其他关卡、随机移动或开火时反复念剧情。

当前普通闲聊间隔为 65 秒，有跟随关系时为 40 秒；同一双人组合 120 秒内不重复。剧情和必杀特写期间，随机闲聊暂停。连续互动四次可触发角色反馈，同一角色的该反馈冷却为 60 秒。

### 逻辑与演出分开

技能的伤害、修复和机动必须能在不绘图时测试。粒子、光束、立绘框和短闪只能表现结果，不能通过 `draw()` 改动伤害或移动位置。

世界时间在必杀释放期间放慢，蓄力单位和突进动作允许按实时时间推进。普通单位、普通弹道、AI、增援和经济按战斗时间更新。实时效果通过 `effect.realtime` 标记。暂停时不推进战斗，也不消耗蓄力。

必杀不拉动镜头，不改变缩放。用户仍能维持当前观察位置。立绘在侧边展示，最多同时保留三条；第四条会替换最早的演出，技能本身照常执行。

## 指挥与补给

- 地图上单击我方机体或头像：选中并跟随；单击敌方：观察并跟随，保留原我方选择，不下攻击指令。
- 右键敌方目标：有我方选择时执行攻击。命令菜单中的目标模式只接受合适阵营。
- 中键拖动取消观察跟随；命令箭头到边缘时可继续滚屏。
- 定位头像对所有存活舰船常驻。箭头在头像下沿，尖端朝机体；敌方头像红边。
- 友舰“跟随”命令和“镜头跟随敌舰”是不同功能。前者控制队形，后者只控制视角。
- 补给状态为 `returning -> supplying -> undocking -> idle`。补满后清空旧攻击、跟随和修理目标，按单位 ID 选择离舰点。母舰移出补给范围时重新返航。
- 护送目标自动走任务航线，玩家通过其他舰船跟随和清敌保护它，不能把它改派去追击。

当前一轮 180 秒自动模拟覆盖十关：护送关约 62 至 78 秒结束，限时关按设定时长结束，部分全歼或母舰战仍在继续。这个样本主要验证无卡死和任务时序，不代表玩家主动指挥后的难度。

## 技能扩展

`Skill.target_mode(unit)` 返回 `self`、`ally` 或 `enemy`，输入层据此决定直接释放或选择目标。`Skill.label(unit)` 返回演出短标题。

| 技能 | 行为 | 关键参数 |
| --- | --- | --- |
| `charge_beam` | 蓄力时锁定方向，释放后沿整段贯穿；目标可以移出火线 | `windup`, `range`, `damage`, `width` |
| `sweep_bombardment` | 在预定范围内连续发射范围弹，命中按实际位置计算 | `range`, `radius`, `count`, `damage` |
| `dash_strike` | 短距突进，路径采样避开障碍，敌人每次最多命中一次 | `range`, `damage`, `windup` |
| `orbital_bombardment` | 指定敌人周围的范围打击 | `range`, `radius`, `damage` |
| `shield` | 吸收伤害并显示跟随机体的屏障动画 | `shield_amount`, `duration` |
| `fleet_heal` | 全场友军回复 35% 最大生命 | 无目标 |
| `repair_tool` | 指定 600 距离内受损友舰，回复 70% 最大生命 | `range` |

普通技能点击后直接执行或进入目标选择。维修机拥有两种技能，因此只为它保留一层选择。自动技能开关按驾驶员 ID 保存；维修机默认自动使用全舰修复，手动选择工具后本关会沿用该技能类型。

技能就绪时列表头像和地图头像发光，并有角色报告。不要只显示立绘而漏掉实际释放效果。增加一种新技能至少覆盖合法目标、无效目标、目标失能、蓄力中断、暂停和伤害只结算一次。

## 资源与招募

初始资源 650，母舰基础收入每战斗秒 3。三个矿脉各有 1800 储量，采集站每战斗秒采集 4；枯竭停止收入。建设会自动占用一个空闲且未枯竭的矿脉，不加入运输微操。采集站被击毁后，剩余矿藏可以重新建设。

随机增援 120，指定战机 180，指定维修机 220。随机机型包括轻快、狙击、炮击、虎式、普通战机、维修。驾驶员从存在本地头像的候选角色里选取。研究和生产最多排四项，取消退还该项资源；母舰失能停止后勤并退还未完成项目。

目前没有运输船循环、敌方经济经营或跨关卡养成。需要扩展时，在矿脉和队列模块中完成，不要向 UI 按钮里塞采集逻辑。

## 偏好与存档

当前用户实际保存位置：`C:/Users/Administrator/AppData/Roaming/LOVE/rts_game/saves/preferences.tbl`。其他机器用 `love.filesystem.getSaveDirectory()` 获取，不要硬编码用户路径。

```ini
[preferences]
auto_skill_4 = true
auto_skill_6 = false
dock_open = true
volume = 0.65
```

`volume` 范围为 0 到 1，面板标题处提供音效开关。缺失或类型错误的偏好采用默认值。偏好保存保留其他角色的配置，不因本关未出场而删除。最高分仍使用原有的 `high_scores.tbl`。

这里保存的是操作习惯和最高分，尚不是能恢复任意战斗时刻的完整存档。完整战局快照需要另外保存单位引用关系、弹道、波次、剧情游标和随机状态。

## 后勤槽位与未来菜单

后勤提示必须写入 `game.logistics` 的明确槽位，不要直接从按钮绘制文字。当前四个槽位全部接入独立 FIFO 队列（`systems/comms_slots.lua`）：`player`（诺阿，右下立绘）、`tact`（雷斯特，正式指导与批评）、`almo`（阿尔茉，元气鼓励）、`enemy`（索尔贝，红色气泡与红边头像，按战损阈值反应）。`game.researcher` 仍指向 `game.logistics.player`。可可的教官通讯走 `game.advisor` 的独立队列；右侧通讯列按雷斯特、阿尔茉、索尔贝（红底）顺序堆叠，均只画头像和对白。槽位 unit 必须携带 `game` 引用与 `team`，头像红边与台词阵营都按此判定。教学关的诺阿步骤会完全隐藏可可面板，指引在该步骤完成前保持可见。

主菜单的机体预览暂只保留设计，不改变正式战局。预览应创建独立的演示状态：高生命并持续回血的木偶、只读机体配置、点击技能显示描述并循环释放视觉效果；退出预览时不得污染偏好、任务、经济或单位列表。

音效运行目录统一为 `assets/se`，配置仍由 `config/audio.lua` 管理事件名和相对音量。LÖVE 11 可直接解码当前 OGG；只有目标环境确认无法播放时才考虑转 WAV，不要在代码中同时维护两套资源路径。

第一人称和真 3D 仍是后续设计项。接管模式应共享现有 `Game`、`Unit`、`Projectile`、`Skill` 接口，先完成二维平面接管，再单独评估自由空间三维碰撞与渲染。

## 验证与已知边界

```powershell
python tools/check_lua.py
& 'C:/Program Files/LOVE/lovec.exe' . --verify
& 'C:/Program Files/LOVE/lovec.exe' . --verify --exercise-check
& 'C:/Program Files/LOVE/lovec.exe' . --verify --compact --cutins-shot
& 'C:/Program Files/LOVE/lovec.exe' . --verify --logistics-shot
& 'C:/Program Files/LOVE/lovec.exe' . --verify --compact --economy-shot --story-shot
& 'C:/Program Files/LOVE/lovec.exe' . --verify --release-shot
& 'C:/Program Files/LOVE/lovec.exe' . --verify --pacing
```

输出截图和 `verification.txt` 在项目根目录。`--verify` 不改用户偏好且不播放音效，但验证 OGG 可以解码。无窗口工具不证明画面正确，必须结合真实 LÖVE 截图。两种测试覆盖两支舰队、全部任务结束条件、技能命中/闪避、补给离舰、矿藏、输入、暂停和剧情生命周期。

当前是伪 3D RTT；第一人称自由飞行已按用户决定延后。模拟战两队可互换，玩家身份仍是卡兹亚，通过所选队伍指挥演习。现有剧情是可替换的原创演习脚本，后续作者可以逐关扩写。数值已经降低瞬间失能，但自动化样本不能代替完整人工平衡测试。
