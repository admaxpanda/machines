# 能力卡（Power Cards）总览

> 图片来源：sprite/ability_card/（21 张）
> 数据来源：PLAN.md + REFERENCE.md + 会话记录修正

## 已实现 ✅（17/21）

| # | id | 名称 | 原名 | 稀有度 | 本游戏效果 | 叠加规则 | 状态 |
|---|-----|------|------|--------|-----------|---------|------|
| 1 | machine_learning | 机器学习 | Machine Learning | Common | 每回合开始额外抽一张攻击牌 | 每张 +1 抽牌 | ✅ |
| 2 | defragment | 碎片整理 | Defragment | Rare | 获得1集中 | 每张 +1 集中 | ✅ |
| 3 | loop | 循环 | Loop | Common | 回合开始时激发最右侧充能球 | — | ✅ |
| 4 | capacitor | 扩容 | Capacitor | Common | 获得2个充能球栏位 | 每张 +2 栏位 | ✅ |
| 5 | coolant | 冷却剂 | Coolant | Uncommon | 每回合开始时，每有一种不同类型的充能球获得2格挡 | — | ✅ |
| 6 | biased_cognition | 偏差认知 | Biased Cognition | Rare | 获得4集中，每场战斗结束减少1集中（最低为0，最多4场后失效） | 每张独立追踪 | ✅ |
| 7 | bulk_up | 暴涨 | — | — | 失去1个充能球栏位（最少保留1），获得2力量和2敏捷 | 每张独立生效 | ✅ |
| 8 | storm | 雷暴 | Storm | Rare | 回合开始获得一个闪电充能球；使用一张技能卡后，额外获得一个闪电充能球 | — | ✅ |
| 9 | creative_ai | 创造性AI | Creative AI | Rare | 每关结束时获得一个额外的能力卡奖励（无论是否升级） | 每张 +1 额外奖励 | ✅ |
| 10 | feral | 野性 | Feral | Common | 每回合前 N 张0费卡回到手牌末尾 | N = 装备数 | ✅ |
| 11 | echo_form | 回响形态 | Echo Form | Rare | 每回合前 N 张攻击牌额外执行一次 | N = 装备数 | ✅ |
| 12 | buffer | 缓冲 | Buffer | Common | 每场战斗前 N 次伤害无效化 | N = 装备数 | ✅ |
| 13 | spinner | 旋转工艺 | Spinner | Common | 回合开始获得一个玻璃充能球；玻璃球被动额外发射 N 次 | N = 装备数 | ✅ |
| 14 | hailstorm | 冰雹风暴 | Hailstorm | Uncommon | 回合开始获得一个冰霜充能球；回合结束时有冰霜球则释放冰雹（fall→aoe_detect，6伤害） | N = 装备数，每次独立释放 | ✅ |
| 15 | thunder | 雷霆 | Thunder | Rare | 激发闪电充能球时额外执行 N 次 | N = 装备数，lightning evoke 改为 multi_release | ✅ |
| 16 | consuming_shadow | 吞噬暗影 | Consuming Shadow | Uncommon | 回合开始获得一个暗黑充能球；回合结束激发最左侧充能球；击杀敌人时触发所有暗黑球被动 | N = 装备数，每张独立激发最左球 | ✅ |
| 17 | subroutine | 子程序 | Subroutine | Rare | 获得一架无人机；打出任意卡牌后 20% 概率再次触发 + 返还 1 能量 | 可重复选择，每架无人机独立视觉 | ✅ |

## 待实现 ❌（3/21）

| # | id | 名称 | 原名 | 稀有度 | STS2 原始效果 | 本游戏效果 | 备注 |
|---|-----|------|------|--------|---------------|-----------|------|
| 18 | iteration | 迭代 | Iteration | Common | 每回合首次抽到状态牌时，额外抽2张牌。 | 每次从攻击抽牌堆抽到状态牌时额外抽2张牌；每次从技能抽牌堆抽到技能牌时额外抽1张牌 | 依赖状态牌系统 |
| 19 | smokestack | 烟囱 | Smokestack | Common | 每当你创建状态牌时，对所有敌人造成5伤害。 | 每抽取一张状态牌释放一道冲击波，造成伤害并击退 | 依赖状态牌系统 |
| 20 | trash_to_treasure | 化废为宝 | Trash to Treasure | Rare | 每当你创建状态牌时，引导1个随机球。 | 每次生成状态牌都会随机生成一个充能球 | 依赖状态牌系统 |

## 未收录

| # | id | 名称 | 备注 |
|---|-----|------|------|
| 21 | hello_world | — | PLAN.md 和 REFERENCE.md 均无描述，需确认 |

## 依赖关系备注

- **iteration / smokestack / trash_to_treasure**：依赖状态牌（Status Cards）系统，当前游戏尚未实现状态牌
