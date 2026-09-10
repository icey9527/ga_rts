-- AI 统一入口。
-- 迁移期间复用旧实现，后续可在 battle/ai/ 下拆分敌方策略、我方自动行为和难度配置。
return require("systems.ai")
