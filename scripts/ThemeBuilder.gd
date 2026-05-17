extends Node

# ── Paleta ──────────────────────────────────────────────────
const C_PANEL:          Color = Color(0.06, 0.06, 0.10, 0.96)
const C_BTN:            Color = Color(0.18, 0.34, 0.75, 1.0)
const C_BTN_HOV:        Color = Color(0.23, 0.42, 0.83, 1.0)
const C_BTN_PRESS:      Color = Color(0.12, 0.24, 0.56, 1.0)
const C_BTN_DIS:        Color = Color(0.22, 0.22, 0.28, 1.0)
const C_TEXT:           Color = Color(0.94, 0.95, 0.98, 1.0)
const C_TEXT_DIS:       Color = Color(0.50, 0.50, 0.55, 1.0)
const C_BORDER_FOCUS:   Color = Color(0.40, 0.65, 1.00, 0.80)

const C_EASY:           Color = Color(0.12, 0.42, 0.24, 1.0)
const C_EASY_HOV:       Color = Color(0.16, 0.53, 0.30, 1.0)
const C_EASY_PRESS:     Color = Color(0.08, 0.28, 0.16, 1.0)
const C_NORMAL:         Color = Color(0.61, 0.48, 0.00, 1.0)
const C_NORMAL_HOV:     Color = Color(0.76, 0.60, 0.00, 1.0)
const C_NORMAL_PRESS:   Color = Color(0.40, 0.32, 0.00, 1.0)
const C_HARD:           Color = Color(0.55, 0.10, 0.10, 1.0)
const C_HARD_HOV:       Color = Color(0.69, 0.13, 0.13, 1.0)
const C_HARD_PRESS:     Color = Color(0.37, 0.06, 0.06, 1.0)
const C_ADAPTIVE:       Color = Color(0.10, 0.29, 0.48, 1.0)
const C_ADAPTIVE_HOV:   Color = Color(0.15, 0.36, 0.62, 1.0)
const C_ADAPTIVE_PRESS: Color = Color(0.06, 0.19, 0.32, 1.0)

var theme: Theme

func _ready() -> void:
	theme = Theme.new()
	_apply_button(theme)
	_apply_label(theme)
	_apply_panel(theme)
	_apply_variations(theme)
	get_tree().root.theme = theme

func _btn_sb(bg: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.content_margin_left   = 14.0
	sb.content_margin_right  = 14.0
	sb.content_margin_top    = 8.0
	sb.content_margin_bottom = 8.0
	if border.a > 0.0:
		sb.set_border_width_all(2)
		sb.border_color = border
	return sb

func _apply_button(theme: Theme) -> void:
	theme.set_stylebox("normal",   "Button", _btn_sb(C_BTN))
	theme.set_stylebox("hover",    "Button", _btn_sb(C_BTN_HOV, C_BORDER_FOCUS))
	theme.set_stylebox("pressed",  "Button", _btn_sb(C_BTN_PRESS))
	theme.set_stylebox("disabled", "Button", _btn_sb(C_BTN_DIS))

	var sb_focus := StyleBoxFlat.new()
	sb_focus.bg_color    = Color.TRANSPARENT
	sb_focus.draw_center = false
	sb_focus.set_border_width_all(2)
	sb_focus.border_color = C_BORDER_FOCUS
	sb_focus.set_corner_radius_all(8)
	theme.set_stylebox("focus", "Button", sb_focus)

	theme.set_color("font_color",          "Button", C_TEXT)
	theme.set_color("font_hover_color",    "Button", C_TEXT)
	theme.set_color("font_pressed_color",  "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", C_TEXT_DIS)
	theme.set_font_size("font_size",       "Button", 20)

func _apply_label(theme: Theme) -> void:
	theme.set_color("font_color",         "Label", C_TEXT)
	theme.set_color("font_shadow_color",  "Label", Color(0.0, 0.0, 0.0, 0.4))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_font_size("font_size",      "Label", 18)

func _apply_panel(theme: Theme) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color      = C_PANEL
	sb.border_color  = Color(0.30, 0.30, 0.45, 0.50)
	sb.shadow_color  = Color(0.0, 0.0, 0.0, 0.50)
	sb.shadow_size   = 10
	sb.shadow_offset = Vector2(0.0, 3.0)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.content_margin_left   = 14.0
	sb.content_margin_right  = 14.0
	sb.content_margin_top    = 14.0
	sb.content_margin_bottom = 14.0
	theme.set_stylebox("panel", "Panel",          sb)
	theme.set_stylebox("panel", "PanelContainer", sb)

func _apply_variations(theme: Theme) -> void:
	var variants: Array = [
		{"name": "ButtonEasy",     "n": C_EASY,     "h": C_EASY_HOV,     "p": C_EASY_PRESS},
		{"name": "ButtonNormal",   "n": C_NORMAL,   "h": C_NORMAL_HOV,   "p": C_NORMAL_PRESS},
		{"name": "ButtonHard",     "n": C_HARD,     "h": C_HARD_HOV,     "p": C_HARD_PRESS},
		{"name": "ButtonAdaptive", "n": C_ADAPTIVE, "h": C_ADAPTIVE_HOV, "p": C_ADAPTIVE_PRESS},
	]
	for v in variants:
		var vn: String = v["name"]
		theme.set_type_variation(vn, "Button")
		theme.set_stylebox("normal",   vn, _btn_sb(v["n"]))
		theme.set_stylebox("hover",    vn, _btn_sb(v["h"], C_BORDER_FOCUS))
		theme.set_stylebox("pressed",  vn, _btn_sb(v["p"]))
		theme.set_stylebox("disabled", vn, _btn_sb(C_BTN_DIS))
