# 只做清理与忽略配置（不建仓、不提交）

## 1. 删除根目录临时文件
`rm` 掉前人留下的验证输出：`verification*.png`（18 张）、`verification.txt`、`verification-error.txt`、`mission-pacing.txt`、`pacing-results.txt`。
不碰代码、文档、`dump/`、`png/`、`assets/`。

## 2. 新建 `rts_game/.gitignore`
```
# 原始素材仓库（保留在本地，不入库）
dump/

# 验证/调试临时输出
verification*.png
verification.txt
verification-error.txt
mission-pacing.txt
pacing-results.txt

# 发布产物
release/
*.love
```

## 不做
- 不执行 `git init`、不提交、不配 remote——仓库由你自己创建。
- 不动背景素材。

## 验收
- 根目录无 verification*/pacing 临时文件。
- `.gitignore` 就位，你 `git init` 后 `dump/` 与验证输出自动被忽略。