extends CanvasLayer

@onready var mana_bar:      ProgressBar = $MarginContainer/VBoxContainer/ManaRow/ManaBar
@onready var mana_label:    Label       = $MarginContainer/VBoxContainer/ManaRow/ManaBar/ManaText
@onready var hp_bar:        ProgressBar = $MarginContainer/VBoxContainer/HPRow/HPBar
@onready var hp_label:      Label       = $MarginContainer/VBoxContainer/HPRow/HPBar/HPText
@onready var stamina_bar:   ProgressBar = $MarginContainer/VBoxContainer/StaminaRow/StaminaBar
@onready var stamina_label: Label       = $MarginContainer/VBoxContainer/StaminaRow/StaminaBar/StaminaText
@onready var xp_bar:        ProgressBar = $MarginContainer/VBoxContainer/XPRow/XPBar
@onready var xp_label:      Label       = $MarginContainer/VBoxContainer/XPRow/XPBar/XPText
@onready var lv_label:      Label       = $MarginContainer/VBoxContainer/XPRow/LvLabel

@onready var skill_panels = {
	"q": $SkillBar/SkillQ,
	"w": $SkillBar/SkillW,
	"e": $SkillBar/SkillE,
}

const SKILL_COLORS = {
	"q": Color(0.9, 0.6, 0.1),
	"w": Color(0.1, 0.5, 0.9),
	"e": Color(0.2, 0.8, 0.4),
}

const READY_COLOR    = Color(0.15, 0.15, 0.15)
const COOLDOWN_COLOR = Color(0.08, 0.08, 0.08)

func _ready():
	_style_bar(mana_bar, Color(0.15, 0.35, 0.9))
	_style_bar(hp_bar, Color(0.85, 0.1, 0.1))
	_style_bar(stamina_bar, Color(0.1, 0.75, 0.2))
	_style_bar(xp_bar, Color(1.0, 0.78, 0.0))
	for label in [mana_label, hp_label, stamina_label, xp_label]:
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	for key in skill_panels:
		_style_skill(key)

func _style_bar(bar: ProgressBar, color: Color):
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.15)
	bar.add_theme_stylebox_override("background", bg)

func _style_skill(key: String):
	var panel = skill_panels[key]
	var style = StyleBoxFlat.new()
	style.bg_color = READY_COLOR
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = SKILL_COLORS[key]
	panel.add_theme_stylebox_override("panel", style)

	var cd_bar: ProgressBar = panel.get_node("VBox/CDBar")
	_style_bar(cd_bar, SKILL_COLORS[key])

func setup(player: CharacterBody3D):
	player.mana_changed.connect(_on_mana_changed)
	player.hp_changed.connect(_on_hp_changed)
	player.stamina_changed.connect(_on_stamina_changed)
	player.xp_changed.connect(_on_xp_changed)
	player.leveled_up.connect(_on_leveled_up)
	_on_mana_changed(player.current_mana, player.stats.max_mana)
	_on_hp_changed(player.current_hp, player.stats.max_hp)
	_on_stamina_changed(player.current_stamina, player.stats.max_stamina)
	_on_xp_changed(player.stats.experience, player.stats.xp_to_next_level())
	lv_label.text = "Lv %d" % player.stats.level

func on_skill_changed(skill: String, cd_remaining: float, cd_max: float):
	if not skill in skill_panels:
		return
	var panel    = skill_panels[skill]
	var cd_label: Label       = panel.get_node("VBox/CDLabel")
	var cd_bar:   ProgressBar = panel.get_node("VBox/CDBar")
	var style    = StyleBoxFlat.new()

	if cd_remaining > 0.0:
		style.bg_color = COOLDOWN_COLOR
		cd_label.text  = "%.1f" % cd_remaining
		cd_bar.value   = cd_remaining / cd_max
	else:
		style.bg_color = READY_COLOR
		cd_label.text  = ""
		cd_bar.value   = 0.0

	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = SKILL_COLORS[skill]
	panel.add_theme_stylebox_override("panel", style)

func on_skill_charged(skill: String, is_charged: bool):
	if not skill in skill_panels:
		return
	var panel = skill_panels[skill]
	var style = StyleBoxFlat.new()
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	if is_charged:
		style.bg_color     = Color(0.5, 0.35, 0.0)
		style.border_color = Color(1.0, 0.85, 0.0)
	else:
		style.bg_color     = COOLDOWN_COLOR
		style.border_color = SKILL_COLORS[skill]
	panel.add_theme_stylebox_override("panel", style)

func _on_mana_changed(current: float, maximum: float):
	mana_bar.max_value = maximum
	mana_bar.value     = current
	mana_label.text    = "%.0f/%.0f" % [current, maximum]

func _on_hp_changed(current: float, maximum: float):
	hp_bar.max_value = maximum
	hp_bar.value     = current
	hp_label.text    = "%.0f/%.0f" % [current, maximum]

func _on_stamina_changed(current: float, maximum: float):
	stamina_bar.max_value = maximum
	stamina_bar.value     = current
	stamina_label.text    = "%.0f/%.0f" % [current, maximum]

func _on_xp_changed(current: int, maximum: int):
	xp_bar.max_value = maximum
	xp_bar.value     = current
	xp_label.text    = "%d/%d" % [current, maximum]

func _on_leveled_up(new_level: int):
	lv_label.text = "Lv %d" % new_level
