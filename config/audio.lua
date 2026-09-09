return {
    -- 混音策略：主音量默认 0.9；高频战斗音压低（0.35/0.45），关键提示拉满（0.85-1.0）。
    confirm={file="ui-confirm",volume=0.4,cooldown=0.12},
    open={file="ui-open",volume=0.35,cooldown=0.4},
    shot={file="weapon-release",volume=0.16,cooldown=0.18},
    main_gun={file="weapon-main",volume=0.28,cooldown=0.15},
    machine_gun={file="weapon-machine",volume=0.12,cooldown=0.06},
    missile={file="weapon-missile",volume=0.30,cooldown=0.20},
    artillery={file="weapon-artillery",volume=0.38,cooldown=0.25},
    beam={file="weapon-beam",volume=0.32,cooldown=0.30},
    impact={file="impact",volume=0.2,cooldown=0.15},
    skill={file="skill-charge",volume=0.25,cooldown=0.6},
    -- 以下映射来自 dump 数字素材，试听后在 file 字段直接换名即可。
    destroyed={file="explosion",volume=0.4,cooldown=0.3},
    warning={file="warning",volume=0.45,cooldown=4},
    build={file="build",volume=0.32,cooldown=1},
    reinforce={file="reinforce",volume=0.32,cooldown=2},
    error={file="error",volume=0.4,cooldown=0.4},
    victory={file="victory",volume=0.5,cooldown=8},
    defeat={file="defeat",volume=0.5,cooldown=8},
}
