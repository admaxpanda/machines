# 故障机器人 Roguelike 幸存者 - 系统架构

## 架构原则

1. **数据驱动** — 卡牌、充能球、敌人、Buff 等全部用 Godot `Resource` 子类定义，运行时 `.duplicate()` 避免修改主数据
2. **组合优于继承** — 实体通过子节点组件组合（HitboxComponent、HealthComponent、BuffContainer 等），继承只用于共享接口
3. **Autoload 仅用于全局状态** — Events(信号总线)、Game(游戏状态机)、RunState(局内持久数据)、Pool(对象池)、AudioManager
4. **信号总线解耦全局事件，直接调用处理局部通信**
5. **对象池** — 投射物、VFX、经验宝石、敌人全部池化
6. **两套独立 CardEngine 实例** — 攻击卡引擎和技能卡引擎共享基类，但池子/能量完全隔离

---

## 目录结构

> `script/` 按「谁负责什么」组织。每个条目标注 [x] 已实现 / [ ] 未实现。未实现的目录暂不新建，按开发进度逐步创建。

```
res://
├── script/
│   ├── autoload/
│   │   ├── events.gd               [ ] 信号总线（无状态）
│   │   ├── game.gd                 [ ] 游戏生命周期状态机
│   │   ├── run_state.gd            [ ] 局内持久数据（卡组、能力、进度）
│   │   └── pool.gd                 [ ] 对象池管理器
│   │
│   ├── core/
│   │   ├── card/
│   │   │   ├── card_data.gd              [ ] Resource 基类
│   │   │   ├── attack_card_data.gd       [ ] 攻击卡数据
│   │   │   ├── skill_card_data.gd        [ ] 技能卡数据
│   │   │   ├── passive_ability_data.gd   [ ] 被动能力数据
│   │   │   ├── status_card_data.gd       [ ] 状态牌数据
│   │   │   ├── card_effect.gd            [ ] 原子效果枚举+参数
│   │   │   ├── card_instance.gd          [ ] 运行时卡牌包装
│   │   │   ├── card_engine.gd            [ ] 抽/弃/洗/消耗引擎基类
│   │   │   └── card_resolver.gd          [ ] 结算卡牌效果
│   │   ├── orb/
│   │   │   ├── orb_data.gd               [ ] 充能球数据
│   │   │   └── orb_manager.gd            [ ] 球槽管理、被动/激发
│   │   ├── buff/
│   │   │   ├── buff_data.gd              [ ] Buff 数据定义
│   │   │   ├── buff_instance.gd          [ ] 运行时 Buff 实例
│   │   │   └── buff_container.gd         [ ] Buff 容器，统一管理
│   │   ├── combat/
│   │   │   ├── health_component.gd       [ ] HP 追踪、死亡信号
│   │   │   ├── shield_component.gd       [ ] 护盾（按回合过期）
│   │   │   ├── hitbox_component.gd       [ ] 造成伤害区域
│   │   │   └── hurtbox_component.gd      [ ] 接收伤害区域
│   │   ├── movement/
│   │   │   ├── movement_component.gd     [ ] 速度移动
│   │   │   └── chase_component.gd        [ ] AI 追踪行为
│   │   ├── turn/
│   │   │   └── turn_manager.gd           [ ] 回合时序状态机
│   │   ├── wave/
│   │   │   └── wave_data.gd              [x] 波次数据
│   │   └── level/
│   │       └── level_data.gd             [x] 关卡数据
│   │   ├── battle/
│   │   │   ├── battle_manager.gd         [x] 战斗流程：开始→波次→结束
│   │   │   └── battle_rewards.gd         [ ] 战后奖励选择
│   │   ├── card_engine/
│   │   │   ├── attack_card_engine.gd     [ ] CardEngine 子类：攻击卡（DR-2）
│   │   │   └── skill_card_engine.gd      [ ] CardEngine 子类：技能卡（DR-3）
│   │   ├── targeting/
│   │   │   └── targeting_system.gd       [ ] 敌人查询
│   │   ├── upgrade/
│   │   │   └── upgrade_manager.gd        [ ] 升级奖励展示与选择
│   │   └── enemy_spawner.gd              [ ] 从池中生成敌人
│   │
│   ├── entity/
│   │   ├── player/
│   │   │   └── player.gd                 [x]
│   │   ├── enemy/
│   │   │   ├── base_enemy.gd             [ ]
│   │   │   ├── slime.gd                  [x] 史莱姆脚本（两种史莱姆共用）
│   │   │   └── enemies/                  [ ] 各具体敌人脚本
│   │   ├── projectile/
│   │   │   ├── bullet.gd                 [ ]
│   │   │   ├── beam.gd                   [ ]
│   │   │   └── ...                       [ ] 其他投射物
│   │   ├── orb/
│   │   │   └── orb_visual.gd             [ ] 充能球视觉
│   │   ├── xp_gem/
│   │   │   └── xp_gem.gd                [ ]
│   │   ├── deployable/                   [ ] 可部署物（全息影像、引雷针等）
│   │   └── vfx/                          [ ] 特效（冲击波、爆炸、斩击等）
│   │
│   └── ui/
│       ├── hud/
│       │   └── hud.gd                    [ ]
│       ├── card_display/
│       │   ├── attack_hand_ui.gd         [ ]
│       │   └── skill_bar_ui.gd           [ ]
│       ├── orb_display/
│       │   └── orb_display.gd            [ ]
│       ├── rewards/
│       │   └── reward_screen.gd          [ ]
│       ├── level_up/
│       │   └── level_up_screen.gd        [ ]
│       ├── pause/
│       │   └── pause_menu.gd             [ ]
│       └── game_over/
│           └── game_over_screen.gd       [ ]
│
├── sprite/
│   ├── entity/                            [ ] 角色、敌人、充能球
│   ├── ui/                                [ ] UI 元素、卡牌图标
│   ├── vfx/                               [ ] 特效帧
│   ├── tileset/                           [ ] 地图瓦片
│   └── icon/                              [ ] 通用图标
│
├── audio/
│   ├── bgm/                               [ ]
│   └── sfx/                               [ ]
│
├── data/
│   ├── enemy/
│   │   └── enemies.json                     [x] 所有敌人数据
│   └── level/
│       └── levels.json                     [x] 所有关卡数据
│
└── scene/
    ├── player.tscn                        [x]
    ├── enemy/                                 [x] 敌人场景
    │   ├── slime_leaf.tscn                [x]
    │   └── slime_twig.tscn                [x]
    ├── main.tscn                          [x]
    ├── main.gd                            [x]
    ├── ...                                [ ]
```

> 注：
> - .tscn 场景文件统一放在 `scene/` 目录，引用 `script/` 和 `sprite/` 下的资源。
> - `data/` 目录存放所有非硬编码的数据文件（JSON 格式），后续卡牌、敌人、充能球等数据也放在这里。

---

## 场景树结构（game_scene.tscn）

```
GameScene (Node2D)
 ├── Arena（竞技场背景）
 ├── Camera2D（跟随玩家）
 ├── YSort（深度排序）
 │    ├── Player
 │    │    ├── CollisionShape2D, Sprite2D
 │    │    ├── HitboxComponent, HurtboxComponent
 │    │    ├── HealthComponent, ShieldComponent
 │    │    ├── MovementComponent, BuffContainer
 │    │    └── OrbManager（充能球视觉节点）
 │    ├── Enemies/（动态填充）
 │    ├── Projectiles/（玩家投射物）
 │    ├── EnemyProjectiles/
 │    ├── Deployables/
 │    ├── XPGems/
 │    └── VFX/
 ├── BattleManager
 │    ├── TurnManager
 │    ├── AttackCardEngine
 │    ├── SkillCardEngine
 │    └── BattleRewards
 ├── WaveManager, EnemySpawner, TargetingSystem, UpgradeManager
 └── UILayer (CanvasLayer)
      ├── HUD
      ├── RewardScreen / LevelUpScreen / PauseMenu / GameOverScreen
```

---

## 核心类设计

### CardEngine（抽/弃/洗/消耗引擎）

基类，AttackCardEngine 和 SkillCardEngine 各一个实例：

```
draw_pile / hand / discard_pile / exhaust_pile
current_energy / energy_per_turn / energy_cap
```

方法：`start_turn()` / `draw_cards()` / `can_play_card()` / `play_card()` / `end_turn()`

| 配置项 | 攻击卡引擎 | 技能卡引擎 |
|--------|-----------|-----------|
| 手牌上限 | 10 | 5 |
| 每回合抽牌 | 5 | 1 |
| 每回合能量 | 3 | 1 |
| 能量上限 | 99 | 无上限 |
| 出牌方式 | 自动（0.1s间隔） | 手动（按键1-5） |

### TurnManager（回合时序状态机）

```
PRE_TURN → CARD_PLAY → ORB_PASSIVE → POST_TURN → BETWEEN_TURNS → (循环)
```

- **PRE_TURN**: 攻击卡抽牌+能量、技能卡抽牌+能量、Buff回合开始触发
- **CARD_PLAY**: 每 0.1s 自动打出一张攻击牌（能量不足跳过但耗0.1s）
- **ORB_PASSIVE**: 每 0.02s 触发一个充能球被动效果
- **POST_TURN**: 虚无牌→消耗；Buff/护盾回合倒计时
- **BETWEEN_TURNS**: 等待至 1.0s（若前面超出则无等待）→ 下一回合

### CardResolver（卡牌效果结算）

两层设计：
1. **数据驱动** — `CardEffect` 枚举（DEAL_DAMAGE, GAIN_BLOCK, APPLY_BUFF, CHANNEL_ORB, EVOKE_ORB, DRAW_CARDS, GAIN_ENERGY, ADD_STATUS, SPECIAL_SCRIPTED 等），大部分卡牌只需填 .tres
2. **脚本化** — 复杂卡牌通过 `effect_script` 实现 `static func execute(card, source, context)`

### BuffContainer（统一 Buff 系统）

管理所有 Buff/Debuff，包括：
- 力量、敏捷、集中（永久/持续型叠加 Buff）
- 易伤、虚弱（持续型，叠加只延时长不叠倍率）
- 临时护盾（按回合倒计时）
- 被动能力效果（永久 Buff + 触发回调）

查询接口：`get_strength()`, `get_dexterity()`, `get_focus()`, `is_vulnerable()`, `is_weak()`, `get_damage_multiplier_outgoing()`, `get_damage_multiplier_incoming()`

### OrbManager（充能球管理）

- `orb_instances: Array[OrbRuntime]` — 数据与视觉分离（OrbRuntime = RefCounted 数据，视觉节点挂 Player 下）
- `channel_orb()` — 满槽时先激发最老的球
- `evoke_orb()` — 执行激发脚本
- `trigger_all_passives()` — 回合结束时由 TurnManager 调用
- `trigger_specific_passives(orb_id)` — 卡牌指定触发特定类型球

---

## 数据格式（Resource .tres）

| 数据类型 | Resource 子类 | 关键字段 |
|---------|-------------|---------|
| 攻击卡 | AttackCardData | cost, base_damage, aoe_radius, hit_count, target_type, projectile_type, effects[] |
| 技能卡 | SkillCardData | cost, base_block, effect_script, effect_params |
| 被动能力 | PassiveAbilityData | buff_to_apply, trigger_event |
| 状态牌 | StatusCardData | is_playable, on_draw_effect, on_exhaust_effect |
| 充能球 | OrbData | passive/evoke_value, passive/evoke_focus_scaling, passive/evoke_effect_script |
| Buff | BuffData | duration_type(TURNS/TIMED/PERMANENT), stacking_rule, modifier_type, modifier_value |
| 敌人 | EnemyData | base_hp, speed, damage, xp_value, enemy_type, attack_patterns[] |
| 关卡 | LevelData | scene_index, waves[], elite/boss timing |
| 波次 | WaveData | spawn_entries[], duration_seconds |

---

## 信号通信

关键全局信号（Events 总线）：

| 类别 | 信号 |
|------|------|
| 战斗 | `battle_started`, `battle_ended`, `turn_started`, `turn_ended` |
| 攻击卡 | `attack_card_drawn`, `attack_card_played`, `attack_card_exhausted`, `attack_energy_changed`, `attack_hand_changed` |
| 技能卡 | `skill_card_drawn`, `skill_card_played`, `skill_card_exhausted`, `skill_energy_changed`, `skill_hand_changed` |
| 充能球 | `orb_channeled`, `orb_passive_triggered`, `orb_evoked` |
| 战斗 | `enemy_spawned`, `enemy_died`, `enemy_damaged`, `player_damaged`, `shield_gained` |
| Buff | `buff_applied`, `buff_removed` |
| 经验/等级 | `xp_gained`, `level_up` |

---

## 战斗流程（单回合序列）

1. **PRE_TURN**: 攻击卡抽5张+3能量；技能卡抽1张+1能量；Buff回合开始触发
2. **CARD_PLAY**: 每0.1s自动打出攻击手牌（能量不足跳过但耗0.1s）
3. **ORB_PASSIVE**: 每0.02s触发充能球被动效果
4. **POST_TURN**: 虚无牌检查→消耗；Buff/护盾回合倒计时
5. **BETWEEN_TURNS**: 等待至1.0s（若超出则无等待）→ 下一回合

---

## 对象池策略

| 池 | 场景 | 初始数量 |
|----|------|---------|
| 普通敌人 | base_enemy.tscn | 80 |
| 精英 | base_enemy.tscn | 5 |
| Boss | base_enemy.tscn | 2 |
| 子弹 | bullet.tscn | 50 |
| 经验宝石 | xp_gem.tscn | 200 |
| 爆炸VFX | explosion.tscn | 30 |
| 冲击波VFX | shockwave.tscn | 20 |
| 斩击VFX | slash_effect.tscn | 20 |
| 伤害数字 | damage_number.tscn | 50 |

---

## 可扩展性：添加新内容

**新攻击卡**：
1. 创建 `data/cards/attack/new_card.tres`
2. 标准效果填 effects 数组；复杂效果用 SPECIAL_SCRIPTED + effect_script
3. 需要新投射物类型时创建对应场景

**新充能球**：
1. 创建 `data/orbs/new_orb.tres` (OrbData)
2. 写 passive_effect_script 和 evoke_effect_script

**新敌人**：
1. 创建 `data/enemies/.../new_enemy.tres` (EnemyData)
2. 标准行为复用 base_enemy.tscn；独特 AI 新建子类

**新被动能力**：
1. 创建 BuffData .tres 定义效果
2. 创建 PassiveAbilityData .tres 引用该 Buff
3. 简单数值修改无需写代码
