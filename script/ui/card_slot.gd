extends TextureRect

## 单张卡牌槽位：显示封面（50% 缩放）

const CARD_SIZE := Vector2(120, 90)

func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func setup(card: AttackCardData) -> void:
	if card.cover != "":
		texture = load(card.cover)
