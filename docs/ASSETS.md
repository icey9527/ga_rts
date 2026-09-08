# 运行素材与来源

`png` 和 `dump` 是原始素材仓库；`assets` 是运行时素材。实际使用的立绘、音效和效果允许改为可读名字，原始文件不用重命名。新增图片后更新映射，不要在绘制代码里猜编号。

## 必杀立绘

运行代码通过 `config/character_assets.lua` 查表。已有的原游戏大头像和表情不替换。新增立绘按原比例绘制，侧边特写会裁切身体下部，不拉伸成人为宽高。

| ID | 运行文件 | 原始来源 |
| --- | --- | --- |
| 000 卡兹亚 | `assets/characters/kazuya.png` | `if_omk_cha006.agi.png` |
| 001 阿普莉可特 | `assets/characters/apricot.png` | `if_omk_cha001.agi.png` |
| 002 卡露娅 | `assets/characters/kahlua.png` | `if_omk_cha002.agi.png` |
| 003 娜诺娜诺 | `assets/characters/nano.png` | `if_omk_cha003.agi.png` |
| 004 莉莉 | `assets/characters/lily.png` | `if_omk_cha004.agi.png` |
| 005 阿妮丝 | `assets/characters/anise.png` | `if_omk_cha005.agi.png` |
| 006 枣 | `assets/characters/natsume.png` | `if_omk_cha000.agi.png` |
| 007 罗塞尔 | `assets/characters/roselle.png` | `png/fac/cha007_0000.png` |
| 008 塔琪拉 | `assets/characters/tequila.png` | `png/fac/cha008_0000.png` |
| 010 梅尔优 | `assets/characters/milfeulle.png` | `png/fac/cha010_0000.png` |
| 011 兰花 | `assets/characters/ranpha.png` | `png/fac/cha011_0000.png` |
| 012 薄荷 | `assets/characters/mint.png` | `png/fac/cha012_0000.png` |
| 013 佛特 | `assets/characters/forte.png` | `png/fac/cha013_0000.png` |
| 014 香草 | `assets/characters/vanilla.png` | `png/fac/cha014_0000.png` |
| 015 千岁 | `assets/characters/chitose.png` | `png/fac/cha015_0000.png` |
| 020 塔克特 | `assets/characters/tact.png` | `png/fac/cha020_0000.png` |
| 021 雷斯特 | `assets/characters/lester.png` | `png/fac/cha021_0000.png` |
| 022 诺阿 | `assets/characters/noah.png` | 用户指定的 `cha022_0000.png` |
| 025 可可 | `assets/characters/instructor.png` | 用户指定的教官立绘 |
| 026 阿尔茉 | `assets/characters/almo.png` | `png/fac/cha026_0000.png` |

卡兹亚和枣这一对已实际看图核对，不要再按数字相等映射回去。其余现有 001 至 005 保持原映射。

## 表情与地图头像

`assets/portraits/facNNN_XXXX...png` 保存表情。角色 `NNN` 与角色目录编号对应。当前表情选择优先寻找 `0000` 普通、`0001` 攻击、`0002` 日常/表扬、`0008` 受击/失能。没有指定差分时回退到该角色第一张可用图；其他原始变体编号尚未完整语义标注。

地图头像使用圆形裁切和单层边框；列表与通讯使用圆角裁切。红边来自阵营，不要烘焙进图片。技能就绪发光也是动态效果，不应生成另一套头像文件。

## 特效纹理

| 运行文件 | 来源 | 用法 |
| --- | --- | --- |
| `charge-glint.png` | `png/effects/si_est_0000.agi.png` | 蓄力星芒 |
| `repair-sparks.png` | `png/effects/si_est_0200.agi.png` | 修复粒子 |
| `dash-streak.png` | `png/effects/si_est_0500.agi.png` | 突进速度纹理 |
| `impact-flash.png` | 已有运行素材 | 命中和爆炸亮核 |
| `beaml.bmp.png`、`beams.bmp.png` | 已有运行素材 | 弹道烟迹、闪光 |

黑底亮纹理使用加色混合，不能当普通不透明图片覆盖战场。不是所有 `png/effects` 图片都是单张效果，有些是图集，必须先辨认分块再建立 Quad。不要直接把一整张图集当护盾覆盖。

## 音效

现有原始 OGG 可由 LÖVE 解码，不需要生成替代声音。当前是少量事件映射，可继续按试听结果替换 `config/audio.lua`，无需改战斗逻辑。

| 事件 | 运行文件 | 原始文件 |
| --- | --- | --- |
| `confirm` | `ui-confirm.ogg` | `dump/se_sys/0001.ogg` |
| `open` | `ui-open.ogg` | `dump/se_sys/0002.ogg` |
| `shot` | `weapon-release.ogg` | `dump/se_slg01/0005.ogg` |
| `impact` | `impact.ogg` | `dump/se_slg01/0008.ogg` |
| `skill` | `skill-charge.ogg` | `dump/se_slg01/0001.ogg` |

这些映射已验证解码和时长，但源文件只有数字名，尚未逐项完成听感分类。实际混音可在这里继续调整；不要将它们当成原游戏的官方语义标签。

`config/audio.lua` 的 `volume` 为事件相对音量，`cooldown` 为事件最短触发间隔。总音量在用户偏好中保存。最多并发 12 个声音，超出时停止最早的声音。回归模式关闭播放，但仍检查解码成功。
