# 卡牌版的全部常量：阶段、模式、类型、属性、指令、查询、错误码、钩子、修正项、面板、小游戏、黄历动作、
# 新手指引（FIRSTS / ANCHORS / UI_EVENTS / GUIDE_COND_OPS）、随机数域登记表。主人 W0（Claude），冻结。
# 合同：docs/cards/CARDS_INTERFACES.md §6.3、§7（§7.4、§7.8、§7.10.5、§7.10.10）、§8.1、§9.4。
# 各模块新加的常量放自己目录下的 <模块>_ids.gd，不改本文件（§0 并行规则）。
# 1.3 (2026-10-13): panel presentation, tabs, hotspots, stage constants, extras,
# UI events, and panel_scene()/widget_scene().
# X01-b: every panel and widget has its owner scene; the W0 stubs and the 1.2 anchor aliases are gone.
# Rogue v1 (docs/cards/rogue/ROGUE_V1.md §9): relic/source prefixes, stock.pick, relics/stocktake/legacy.* queries, stocktake/relics panels, curio hotspot, c.stock.offer.
class_name CardIds
extends RefCounted

# ---------------- 阶段与模式（§7.4） ----------------
const PH_BOOT := &"boot"
const PH_MONTH_OPEN := &"month_open"
const PH_MORNING := &"morning"
const PH_DAY := &"day"
const PH_NIGHT := &"night"
const PH_SETTLE := &"settle"
const PH_MONTH_CLOSE := &"month_close"
const PH_YEAR_JUMP := &"year_jump"
const PH_GAME_OVER := &"game_over"
const PH_BRANCH_PICK := &"branch_pick"
const PHASES: Array[StringName] = [&"boot", &"month_open", &"morning", &"day", &"night", &"settle",
	&"month_close", &"year_jump", &"game_over", &"branch_pick"]

const MODE_SHOP := &"shop"
const MODE_STREET := &"street"
const MODES: Array[StringName] = [&"shop", &"street"]

# ---------------- 牌的类型与 id 前缀（§4.2） ----------------
const TYPE_PREFIX := {
	"person": "p", "self": "self", "contact": "ct", "event": "ev", "fate": "fa", "big_fate": "bf",
	"demand": "dm", "life": "lf", "news": "nw", "kept": "kp", "estate": "es", "night": "nt",
	"street": "st", "prison": "pr", "item": "it", "pawn_ticket": "tk", "wheel": "wh",
	"wheel_segment": "ws", "fortune_lot": "lot", "cezi": "cz", "almanac_day": "alm",
	"dossier_page": "dp", "dossier_fragment": "df", "goal": "gl", "guide_step": "gd", "rule_page": "rule",
	"relic": "rl", "source": "ky",
}
const TYPES: Array[StringName] = [&"person", &"self", &"contact", &"event", &"fate", &"big_fate", &"demand",
	&"life", &"news", &"kept", &"estate", &"night", &"street", &"prison", &"item", &"pawn_ticket", &"wheel",
	&"wheel_segment", &"fortune_lot", &"cezi", &"almanac_day", &"dossier_page", &"dossier_fragment", &"goal",
	&"guide_step", &"rule_page"]
# 会进手牌或各区的类型（V16）
const DEALT_TYPES: Array[StringName] = [&"person", &"event", &"fate", &"big_fate", &"demand", &"life", &"news",
	&"kept", &"night", &"street", &"prison", &"pawn_ticket"]
# must_resolve 默认为 true 的类型（§4.7 开头、§7.4.7）。10-13 起含义：“今天要有个了断”——打烊确认后还在手上，
# 就按“没理会”结算（§7.4.7 的表）；不再挡打烊。
const MUST_RESOLVE_TYPES: Array[StringName] = [&"person", &"event", &"fate", &"big_fate", &"street", &"prison"]
const ID_REGEX := "^[a-z][a-z0-9_]*(\\.[a-z0-9_]+)+$"
const SLUG_REGEX := "^[a-z0-9_]+$"

# ---------------- 区（§6.1 core.zones） ----------------
const ZONE_HAND := &"hand"
const ZONE_KEPT := &"kept"
const ZONE_CONTACTS := &"contacts"
const ZONE_DEMANDS := &"demands"
const ZONE_PENDING := &"pending"
const ZONE_DISCARD := &"discard"
const ZONES: Array[StringName] = [&"hand", &"kept", &"contacts", &"demands", &"pending", &"discard"]

# ---------------- 属性、来意、各种枚举（§4.4、§4.7） ----------------
const ATTRS: Array[StringName] = [&"eye", &"tongue", &"pull", &"nerve"]
const INTENTS: Array[StringName] = [&"pawn", &"sell", &"buy", &"redeem", &"help", &"ask", &"story"]
const SLOT_ACCEPTS: Array[StringName] = [&"money", &"self", &"contact", &"kept", &"item", &"news"]
const SOURCE_KINDS: Array[StringName] = [&"money", &"self", &"contact", &"kept", &"item", &"news"]
const VALENCES: Array[StringName] = [&"good", &"bad", &"mixed", &"neutral"]
const DEMAND_KINDS: Array[StringName] = [&"money", &"goods", &"people", &"info"]
const DEMAND_MODES: Array[StringName] = [&"pay", &"haggle", &"substitute", &"fabricate", &"send_person", &"inform"]
const NEWS_KINDS: Array[StringName] = [&"price", &"lead", &"rumor", &"letter", &"paper", &"telegram"]
const KEPT_KINDS: Array[StringName] = [&"favor", &"paper", &"hard", &"leverage", &"blank_ticket", &"token"]
const FRAGMENT_KINDS: Array[StringName] = [&"pawn", &"said", &"heard", &"clipping", &"ticket", &"letter", &"year_after"]
const WHEEL_KINDS: Array[StringName] = [&"month", &"big", &"fair", &"gamble"]
const WEATHERS: Array[StringName] = [&"clear", &"rain", &"fog", &"wind", &"snow"]
const PERSON_STATES: Array[StringName] = [&"ok", &"hurt", &"jailed", &"away", &"gone", &"changed"]
const ESTATE_STATES: Array[StringName] = [&"held", &"mortgaged", &"lost"]
const PRICE_TIERS: Array[StringName] = [&"harsh", &"fair", &"kind"]
const REDEEM_MODES: Array[StringName] = [&"by_rule", &"squeeze", &"compensate", &"buy_back"]
const REPLIES: Array[StringName] = [&"accept", &"counter", &"leave"]
const CRISES: Array[StringName] = [&"cash_short", &"arrested", &"heat_max", &"street_long"]
const OPENS_FORTUNE: Array[StringName] = [&"lot", &"cezi", &"both"]
const GOAL_EVAL: Array[StringName] = [&"month_close", &"any_time"]
const LOT_GRADES: Array[int] = [0, 1, 2, 3, 4]
const CARD_LEFT_REASONS: Array[StringName] = [&"resolved", &"refused", &"left", &"expired", &"gold_left", &"seized",
	&"informed"]
const METERS: Array[StringName] = [&"rep", &"heat", &"conscience"]
const TIER_METERS: Array[StringName] = [&"rep", &"heat"]
const CURRENCIES: Array[StringName] = [&"fabi"]

# ---------------- 效果钩子名（§4.4.5；on_short 见 §5.2 pay） ----------------
const EFFECT_HOOKS: Array[StringName] = [&"on_deal", &"on_resolve", &"on_expire", &"on_accept", &"on_refuse",
	&"on_leave", &"on_keep", &"on_play", &"on_read", &"on_inform", &"on_choose", &"on_complete", &"on_done",
	&"on_fail", &"on_short"]

# ---------------- 指令（§7.4；值 = 主人任务号） ----------------
const CMD_GAME_NEW := &"game.new"
const CMD_GAME_SAVE := &"game.save"
const CMD_GAME_LOAD := &"game.load"
const CMD_GAME_RETRY := &"game.retry_stage"
const CMD_MONTH_BEGIN := &"month.begin"
const CMD_DAY_BEGIN := &"day.begin"
const CMD_DAY_END := &"day.end"          # 打烊 · 下一天：{confirm:bool=false}；除 game_over 外任何阶段都能发（§7.4.7）
const CMD_NIGHT_CHOOSE := &"night.choose"
const CMD_SETTLE_NEXT := &"settle.next"
const CMD_MONTH_NEXT := &"month.next"
const CMD_YEAR_NEXT := &"year.next"
const CMD_CARD_KEEP := &"card.keep"
const CMD_CARD_DISCARD := &"card.discard"
const CMD_CARD_READ := &"card.read"
const CMD_CARD_CHOOSE := &"card.choose"
const CMD_SLOT_PLACE := &"slot.place"
const CMD_SLOT_REMOVE := &"slot.remove"
const CMD_SLOT_ROLL := &"slot.roll"
const CMD_DEMAND_SUBMIT := &"demand.submit"
const CMD_DEMAND_DELAY := &"demand.delay"
const CMD_CONTACT_RELEASE := &"contact.release"
const CMD_COUNTER_OPEN := &"counter.open"
const CMD_COUNTER_OFFER := &"counter.offer"
const CMD_COUNTER_ANSWER := &"counter.answer"
const CMD_COUNTER_PICK := &"counter.pick_stock"
const CMD_COUNTER_REDEEM := &"counter.redeem"
const CMD_COUNTER_REFUSE := &"counter.refuse"
const CMD_COUNTER_CLOSE := &"counter.close"
const CMD_MG_REQUEST := &"mg.request"
const CMD_MG_REPORT := &"mg.report"
const CMD_ESTATE_MORTGAGE := &"estate.mortgage"
const CMD_ESTATE_REDEEM := &"estate.redeem"
const CMD_SHORT_RESOLVE := &"short.resolve"
const CMD_STREET_REDEEM := &"street.redeem_shop"
const CMD_WHEEL_OFFER := &"wheel.offer"
const CMD_WHEEL_WITHDRAW := &"wheel.withdraw"
const CMD_WHEEL_STAKE := &"wheel.stake"
const CMD_WHEEL_SPIN := &"wheel.spin"
const CMD_FORTUNE_LOT := &"fortune.lot"
const CMD_FORTUNE_CEZI := &"fortune.cezi"
const CMD_UI_GUIDE := &"ui.guide"
const COMMANDS := {
	&"game.new": "G02", &"game.save": "G02", &"game.load": "G02", &"game.retry_stage": "G02",
	&"month.begin": "G02", &"day.begin": "G02", &"day.end": "G02", &"night.choose": "G02",
	&"settle.next": "G02", &"month.next": "G02", &"year.next": "G02",
	&"card.keep": "G01", &"card.discard": "G01", &"card.read": "G03", &"card.choose": "G03",
	&"slot.place": "G03", &"slot.remove": "G03", &"slot.roll": "G03",
	&"demand.submit": "G03", &"demand.delay": "G03", &"contact.release": "G03",
	&"counter.open": "G04", &"counter.offer": "G04", &"counter.answer": "G04", &"counter.pick_stock": "G04",
	&"counter.redeem": "G04", &"counter.refuse": "G04", &"counter.close": "G04",
	&"mg.request": "G04", &"mg.report": "G04",
	&"estate.mortgage": "G06", &"estate.redeem": "G06", &"short.resolve": "G06", &"street.redeem_shop": "G06",
	&"wheel.offer": "G05", &"wheel.withdraw": "G05", &"wheel.stake": "G05", &"wheel.spin": "G05",
	&"fortune.lot": "G05", &"fortune.cezi": "G05",
	&"ui.guide": "G01",
	&"stock.pick": "RG2",
}

# ---------------- 查询（§7.4；值 = 主人任务号） ----------------
const QUERIES := {
	&"card": "G02", &"actions": "G02", &"slots": "G03", &"counter": "G04", &"stock": "G04", &"tickets": "G04",
	&"estates": "G06", &"short": "G06", &"wheel": "G05", &"fortune": "G05", &"almanac": "G05",
	&"dossier": "G03", &"settle_report": "G02", &"month_report": "G02", &"year_report": "G02",
	&"firsts": "G01", &"guide_data": "G01", &"guide_progress": "G01", &"guide_conds": "G01",
	&"day.end_preview": "G02",
	&"relics": "RG1", &"stocktake": "RG2", &"legacy.harvest": "RG5", &"legacy.old_ink": "RG5",
}
const Q_DAY_END_PREVIEW := &"day.end_preview"   # 打烊确认要列的清单（§7.4.7）

# ---------------- 打烊 · 下一天（§7.4.7；主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”） ----------------
# day.end 在各阶段做的那一步（预览和结果里的 step）
const END_STEPS: Array[StringName] = [&"end_day", &"skip_night", &"next_day", &"open_day", &"begin_month", &"month_next",
	&"year_next"]
# 清单每一行的 kind：没处理的东西打烊后会怎样
const END_KINDS: Array[StringName] = [&"leave", &"gold_leave", &"ignore", &"pass", &"void", &"stay", &"fail", &"wait",
	&"discard", &"release", &"short", &"auto_spin", &"skip_night"]
# 这些 kind 的行不需要确认（没有损失：明天接着算、机会过去了、今晚不选夜牌）；别的只要有一行就要确认
const END_NO_CONFIRM_KINDS: Array[StringName] = [&"wait", &"pass", &"skip_night"]
# 这些 kind 的行算“必须了断的牌没处理”（第一次出现时记 first must_resolve；gold_leave 另记 gold_leave）
const END_MUST_KINDS: Array[StringName] = [&"leave", &"ignore", &"void", &"stay", &"fail"]
# 从任何不是 game_over 的状态，连续 day.end {confirm:true} 最多这么多次，abs_day 一定变大或进 game_over（§7.4.7 不卡死）
const END_MAX_STEPS_TO_NEXT_DAY := 8

# ---------------- 错误码（§7.2） ----------------
const ERR_NONE := ""
const ERR_BAD_PHASE := "bad_phase"
const ERR_BAD_ARGS := "bad_args"
const ERR_UNKNOWN_UID := "unknown_uid"
const ERR_UNKNOWN_DEF := "unknown_def"
const ERR_NOT_ALLOWED := "not_allowed"
const ERR_COND_FAILED := "cond_failed"
const ERR_INSUFFICIENT_MONEY := "insufficient_money"
const ERR_SLOT_FULL := "slot_full"
const ERR_SLOT_REJECT := "slot_reject"
const ERR_SLOT_REQUIRED := "slot_required"
const ERR_PERSON_BUSY := "person_busy"
const ERR_KEPT_FULL := "kept_full"
const ERR_NOT_KEEPABLE := "not_keepable"
const ERR_MUST_RESOLVE := "must_resolve_pending"   # 10-13 起：day.end {confirm:false} 时还有要了断的东西，结果带清单，等确认
const ERR_GOLD_PENDING := "gold_pending"           # 10-13 起不再返回（金色牌并进上面那张清单）；保留常量，不复用
const ERR_WHEEL_PENDING := "wheel_pending"
const ERR_ALREADY_RESOLVED := "already_resolved"
const ERR_NO_SUCH_CHOICE := "no_such_choice"
const ERR_STOCK_EMPTY := "stock_empty"
const ERR_ESTATE_STATE := "estate_state"
const ERR_STAKE_REQUIRED := "stake_required"
const ERR_NO_MINIGAME := "no_minigame"
const ERR_OVERFLOW_PENDING := "overflow_pending"
const ERR_SAVE_NEWER := "save_newer"
const ERR_BUSY := "busy"
const ERR_NOT_IMPLEMENTED := "not_implemented"
const ERRORS: Array[String] = ["", "bad_phase", "bad_args", "unknown_uid", "unknown_def", "not_allowed",
	"cond_failed", "insufficient_money", "slot_full", "slot_reject", "slot_required", "person_busy", "kept_full",
	"not_keepable", "must_resolve_pending", "gold_pending", "wheel_pending", "already_resolved", "no_such_choice",
	"stock_empty", "estate_state", "stake_required", "no_minigame", "overflow_pending", "save_newer", "busy",
	"not_implemented"]

# ---------------- 生命周期钩子（§7.3） ----------------
const HOOK_STAGE_START := &"stage_start"
const HOOK_MONTH_OPEN := &"month_open"
const HOOK_DAY_START := &"day_start"
const HOOK_DEAL_COMPOSED := &"deal_composed"
const HOOK_CARD_RESOLVED := &"card_resolved"
const HOOK_DAY_END := &"day_end"
const HOOK_NIGHT_CHOSEN := &"night_chosen"
const HOOK_SETTLE := &"settle"
const HOOK_MONTH_CLOSE := &"month_close"
const HOOK_YEAR_JUMP := &"year_jump"
const HOOK_MONEY_SHORT := &"money_short"
const HOOK_ARRESTED := &"arrested"
const HOOKS: Array[StringName] = [&"stage_start", &"month_open", &"day_start", &"deal_composed",
	&"card_resolved", &"day_end", &"night_chosen", &"settle", &"month_close", &"year_jump", &"money_short",
	&"arrested"]

# ---------------- 修正项 kind（§7.3） ----------------
const MODS: Array[StringName] = [&"deal_count", &"pool_rows", &"scheduled_cards", &"pinned_cards", &"fate_due",
	&"pool_pct", &"cap", &"intake_blocked", &"price_pct", &"coins", &"patience_pct", &"appraise_pct", &"hand_sub",
	&"view_section", &"card_view_part", &"end_rows", &"unscripted_day"]

# ---------------- 牌池（发牌用，§6.3 c.deal.<pool>） ----------------
const POOLS: Array[StringName] = [&"person", &"event", &"news", &"fate", &"life", &"big_fate", &"night", &"street"]

# ---------------- 面板（§7.8；kind → 场景） ----------------
const PANEL_SCENES := {
	&"counter": "res://scenes/cards/counter/CounterPanel.tscn",
	&"slots": "res://scenes/cards/slots/SlotPanel.tscn",
	&"demand": "res://scenes/cards/demand/DemandPanel.tscn",
	&"wheel": "res://scenes/cards/wheel/WheelPanel.tscn",
	&"fortune": "res://scenes/cards/fortune/FortunePanel.tscn",
	&"end_day": "res://scenes/cards/night/EndDayConfirm.tscn",
	&"night": "res://scenes/cards/night/NightPanel.tscn",
	&"settle": "res://scenes/cards/night/SettlePanel.tscn",
	&"month_open": "res://scenes/cards/month/MonthOpen.tscn",
	&"month_close": "res://scenes/cards/month/MonthClose.tscn",
	&"year_jump": "res://scenes/cards/month/YearJump.tscn",
	&"game_over": "res://scenes/cards/month/GameOver.tscn",
	&"dossier": "res://scenes/cards/dossier/DossierBook.tscn",
	&"estates": "res://scenes/cards/ladder/EstatePanel.tscn",
	&"short": "res://scenes/cards/ladder/ShortPanel.tscn",
	&"prison": "res://scenes/cards/ladder/PrisonPanel.tscn",
	&"read": "res://scenes/cards/slots/SlotPanel.tscn",
	&"contacts_full": "res://scenes/cards/slots/ContactsFull.tscn",
	&"kept_full": "res://scenes/cards/slots/KeptFull.tscn",
	&"help": "res://scenes/cards/dossier/HelpPanel.tscn",
	&"pause": "res://scenes/cards/shell/CardPause.tscn",
	&"settings": "res://scenes/cards/shell/CardSettings.tscn",
	&"contacts": "res://scenes/cards/slots/ContactsDrawer.tscn",
	&"demands": "res://scenes/cards/demand/DemandsDrawer.tscn",
	&"shelf": "res://scenes/cards/counter/ShelfDrawer.tscn",
	&"tickets": "res://scenes/cards/counter/TicketsDrawer.tscn",
	&"almanac": "res://scenes/cards/fortune/AlmanacDrawer.tscn",
	&"stocktake": "res://scenes/cards/rogue/StocktakePanel.tscn",
	&"relics": "res://scenes/cards/rogue/RelicsDrawer.tscn",
}
const PANELS: Array[StringName] = [&"counter", &"slots", &"demand", &"wheel", &"fortune", &"end_day", &"night",
	&"settle", &"month_open", &"month_close", &"year_jump", &"game_over", &"dossier", &"estates", &"short", &"prison",
	&"read", &"contacts_full", &"kept_full", &"help", &"pause", &"settings",
	&"contacts", &"demands", &"shelf", &"tickets", &"almanac", &"minigame", &"stocktake", &"relics"]
# ---------------- Panel presentation (7.8, 1.3) ----------------
const SHOW_STAGE := &"stage"
const SHOW_DRAWER_L := &"drawer_l"
const SHOW_DRAWER_R := &"drawer_r"
const SHOW_OVERLAY := &"overlay"
const SHOW_HOST := &"host"
const PANEL_SHOW := {
	&"counter": &"stage", &"slots": &"stage", &"read": &"stage", &"demand": &"stage", &"fortune": &"stage",
	&"prison": &"stage", &"night": &"stage", &"settle": &"stage",
	&"contacts": &"drawer_l", &"demands": &"drawer_l", &"dossier": &"drawer_l",
	&"shelf": &"drawer_r", &"tickets": &"drawer_r", &"estates": &"drawer_r", &"almanac": &"drawer_r", &"settings": &"drawer_r",
	&"wheel": &"overlay", &"end_day": &"overlay", &"month_open": &"overlay", &"month_close": &"overlay",
	&"year_jump": &"overlay", &"game_over": &"overlay", &"short": &"overlay", &"contacts_full": &"overlay",
	&"kept_full": &"overlay", &"help": &"overlay", &"pause": &"overlay", &"minigame": &"host",
	&"stocktake": &"overlay", &"relics": &"drawer_r",
}

# CardView.panel 的取值（§7.4.3、§7.5）
const CARD_PANELS: Array[StringName] = [&"counter", &"slots", &"demand", &"wheel", &"fortune", &"prison", &"read",
	&"none"]

# 嵌在牌桌上的控件（§7.8 第二张表）
const WIDGET_SCENES := {
	&"card": "res://scenes/cards/card/CardWidget.tscn",
	&"slot": "res://scenes/cards/slots/SlotWidget.tscn",
	&"coin_toss": "res://scenes/cards/slots/CoinToss.tscn",
	&"demand_board": "res://scenes/cards/demand/DemandBoard.tscn",
	&"almanac_strip": "res://scenes/cards/fortune/AlmanacStrip.tscn",
	&"street_overlay": "res://scenes/cards/ladder/StreetOverlay.tscn",
	&"title": "res://scenes/cards/shell/CardTitle.tscn",
	&"guide": "res://scenes/cards/shell/GuideOverlay.tscn",
	&"stage": "res://scenes/cards/table/CardStage.tscn",
	&"dialog": "res://scenes/cards/counter/DialogBox.tscn",
	&"hand_fan": "res://scenes/cards/card/HandFan.tscn",
	&"hero_bar": "res://scenes/cards/card/HeroBar.tscn",
	&"checks": "res://scenes/cards/slots/CounterChecks.tscn",
}
const ROOT_SCENE := "res://scenes/cards/CardGame.tscn"

# ---------------- Tabs and hotspots (7.11) ----------------
const TABS_L: Array[StringName] = [&"contacts", &"demands", &"dossier", &"rules"]
const TABS_R: Array[StringName] = [&"shelf", &"tickets", &"estates", &"settings"]
const TAB_PANELS := {&"contacts": [&"contacts", {}], &"demands": [&"demands", {}], &"dossier": [&"dossier", {}],
	&"rules": [&"dossier", {"tab": "rules"}], &"shelf": [&"shelf", {}], &"tickets": [&"tickets", {}],
	&"estates": [&"estates", {}], &"settings": [&"settings", {}]}
const HOTSPOTS: Array[StringName] = [&"magnifier", &"abacus", &"cashbox", &"ledger", &"notebook", &"calendar",
	&"notice", &"notewall", &"lamp", &"curio"]
const HOTSPOT_PANELS := {&"abacus": [&"dossier", {"tab": "rules"}], &"cashbox": [&"estates", {}],
	&"ledger": [&"tickets", {}], &"notebook": [&"dossier", {}], &"calendar": [&"almanac", {}], &"notewall": [&"demands", {}],
	&"curio": [&"relics", {}]}

# ---------------- Stage data (4.7.24) ----------------
const STAGE_SETS: Array[StringName] = [&"counter", &"candle", &"street", &"prison", &"temple", &"dock", &"market",
	&"teahouse", &"ricehall", &"pharmacy", &"post", &"baogong"]
const STAGE_TIMES: Array[StringName] = [&"day", &"dusk", &"night"]
const STAGE_SPOTS: Array[StringName] = [&"customer", &"companion", &"door", &"door_l", &"door_r", &"street"]
const CAST_LOOKS: Array[StringName] = [&"stand", &"walk", &"shadow"]
const PROP_SPOTS: Array[StringName] = [&"counter_left", &"counter_mid", &"counter_right", &"door_side", &"door_notice",
	&"wall_right"]
const STAGE_FX: Array[StringName] = [&"rain", &"fire", &"smoke", &"predawn", &"dim", &"cold", &"warm", &"drip", &"shake",
	&"seal"]
const STAGE_WALKS: Array[StringName] = [&"crowd", &"patrol", &"troops", &"refugees", &"hu2_men", &"none"]
const STAGE_AFTER_KEYS: Array[StringName] = [&"accept", &"counter", &"leave", &"refused", &"impatient", &"look",
	&"success", &"fail", &"read", &"keep", &"delay", &"lot", &"cezi", &"pass", &"done"]
const STAGE_TYPES: Array[StringName] = [&"person", &"event", &"fate", &"big_fate", &"life", &"news", &"street",
	&"prison", &"demand", &"night", &"pawn_ticket"]
const STAGE_KEYS: Array[String] = ["set", "cast", "props", "fx", "walk", "intro", "after", "brief"]
const STAGE_REF_REGEX := "^(body|lines\\.[a-z0-9_]+|outcomes\\.[a-z0-9_]+|choices\\.[a-z0-9_]+)$"
const STAGE_LIMITS := {"cast": 3, "props": 4, "fx": 3, "intro": 12, "after": 8}
const EXTRAS: Array[String] = ["ex_patrol", "ex_soldier", "ex_newsboy", "ex_girl", "ex_shopboy", "ex_oldman",
	"ex_porter", "ex_student", "ex_hu2_man"]
const HAND_PLAY_HOWS: Array[StringName] = [&"drag", &"button", &"key", &"auto"]

# ---------------- 小游戏（§8.1） ----------------
const MINIGAMES: Array[StringName] = [&"spot", &"coin_ring", &"weigh", &"fragments", &"decode"]
const MINIGAMES_RESERVED: Array[StringName] = [&"seal", &"sniff"]
const MINIGAME_SCENES := {
	&"spot": "res://scenes/cards/minigames/spot/SpotGame.tscn",
	&"coin_ring": "res://scenes/cards/minigames/coin_ring/CoinRingGame.tscn",
	&"weigh": "res://scenes/cards/minigames/weigh/WeighGame.tscn",
	&"fragments": "res://scenes/cards/minigames/fragments/FragmentsGame.tscn",
	&"decode": "res://scenes/cards/minigames/decode/DecodeGame.tscn",
}
## "any" = recorded at every clarity band; an entry may also carry "hedge": {"partial": key, "vague": key} (DESIGN 3.2, 10-25).
const OBS_FIDELITY: Array[StringName] = [&"clear", &"partial", &"vague", &"any"]
const VERDICT_WORDS: Array[String] = ["fake", "real", "genuine", "forged", "true", "false", "authentic"]

# ---------------- 黄历动作（§9.4） ----------------
const ALMANAC_ACTIONS: Array[StringName] = [&"pawn_in", &"buy_in", &"sell_out", &"redeem", &"trade", &"meet",
	&"travel", &"pray", &"repair", &"rest", &"lend", &"wed"]

# ---------------- 新手指引：机制（§7.10.10；值 = 发出者任务号；共 70 个，含两个预留；1.4 office + K18 pet + K18 apprentice + scare） ----------------
const FIRSTS := {
	&"month_open": "G02", &"month_wheel": "G05", &"incense": "G05", &"notice": "G02", &"deal": "G01",
	&"person": "G01", &"counter": "G04", &"mg.spot": "G04", &"ticket": "G04", &"shelf": "G04", &"buyer": "G04",
	&"night": "G02", &"settle": "G02", &"gold": "G02", &"choice": "G03", &"keep": "G01", &"slots": "G03",
	&"coins": "G03", &"almanac": "G05", &"lot": "G05", &"cezi": "G05", &"news": "G01", &"dossier": "G03",
	&"contact": "G03", &"tier_rep": "G03", &"tier_heat": "G03", &"demand": "G03", &"demand_delay": "G03",
	&"demand_people_return": "G03", &"demand_inform": "G03", &"demand_fabricate": "G03", &"demand_fail": "G03",
	&"shop_closed": "G04", &"must_resolve": "G02", &"gold_leave": "G02", &"fate": "G05", &"life": "G01",
	&"kept_expire": "G01", &"kept_full": "G01", &"kept_risk": "G03", &"contacts_full": "G03",
	&"person_state": "G03", &"redeem": "G04", &"mg.coin_ring": "G04", &"mg.weigh": "G04",
	&"mg.fragments": "G04", &"mg.decode": "G04", &"market_day": "G05", &"weather": "G05",
	&"money_short": "G06", &"mortgage": "G06", &"big_wheel": "G05", &"fair_wheel": "G05", &"wheel_stake": "G05",
	&"gamble_wheel": "G05", &"street": "G06", &"prison": "G06", &"game_over": "G02", &"retry": "G02",
	&"resume": "G02", &"month_close": "G02", &"year_jump": "G02", &"year_after": "G03", &"dossier_gap": "G03",
	&"currency": "G04", &"branch_pick": "G02", &"pet": "G03", &"apprentice": "K18",
	&"office": "G03",  # 1.4（§九.7 官场开头）：带 office 标签的牌第一次发到手上
	&"scare": "G03",
}
const FIRSTS_RESERVED: Array[StringName] = [&"currency", &"branch_pick"]

# ---------------- 新手指引：锚点目录（§7.10.5；值 = 主人任务号；带 @ 的按 @ 前面查） ----------------
const ANCHORS := {
	&"a.hand": "C02", &"a.hand.gold": "C02", &"a.top.date": "C01", &"a.top.weather": "C01",
	&"a.top.money": "C01", &"a.top.rep": "C01", &"a.top.heat": "C01", &"a.btn.close_day": "C01",
	&"a.card": "C02", &"a.card.keep": "C02", &"a.card.days": "C02", &"a.card.gold": "C02",
	&"a.slots.first": "C03", &"a.slots.coins": "C03", &"a.slots.roll": "C03", &"a.slots.money": "C03",
	&"a.slots.choices": "C03", &"a.slots.release": "C03", &"a.slots.discard": "C03",
	&"a.counter.item": "C04", &"a.counter.look": "C04", &"a.counter.tier.harsh": "C04",
	&"a.counter.tier.fair": "C04", &"a.counter.tier.kind": "C04", &"a.counter.reply": "C04",
	&"a.counter.stock": "C04", &"a.counter.redeem": "C04",
	&"a.demand.board": "C05", &"a.demand.days": "C05", &"a.demand.tier": "C05", &"a.demand.modes": "C05",
	&"a.demand.delay": "C05",
	&"a.wheel.face": "C06", &"a.wheel.incense": "C06", &"a.wheel.cost": "C06", &"a.wheel.spin": "C06",
	&"a.almanac": "C07", &"a.fortune.lot": "C07", &"a.fortune.cezi": "C07", &"a.fortune.chars": "C07",
	&"a.endday.blocked": "C08", &"a.endday.gold_leave": "C08", &"a.night.offers": "C08", &"a.settle.lines": "C08",
	&"a.month.goals": "C09", &"a.mclose.accounts": "C09", &"a.year.forfeit": "C09", &"a.year.after": "C09",
	&"a.over.retry": "C09",
	&"a.dossier.page": "C10", &"a.dossier.gap": "C10", &"a.dossier.rules_tab": "C10", &"a.help.rules": "C10",
	&"a.estate.list": "C11", &"a.estate.mortgage": "C11", &"a.short.options": "C11", &"a.street.redeem": "C11",
	&"a.prison.slots": "C11",
	&"a.mg.spot.main": "C12", &"a.mg.spot.atlas": "C12", &"a.mg.spot.lens": "C12",
	&"a.mg.coin_ring.main": "C13", &"a.mg.coin_ring.blow": "C13", &"a.mg.coin_ring.ear": "C13",
	&"a.mg.weigh.main": "C14", &"a.mg.weigh.weights": "C14", &"a.mg.weigh.beam": "C14",
	&"a.mg.fragments.main": "C15", &"a.mg.fragments.board": "C15", &"a.mg.fragments.seal": "C15",
	&"a.mg.decode.main": "C15", &"a.mg.decode.book": "C15",
	&"a.mg.spot.tag": "C12", &"a.mg.coin_ring.samples": "C13", &"a.mg.weigh.call": "C14",
	&"a.mg.fragments.seam": "C15", &"a.mg.decode.sheet": "C15",
	&"a.settings.guide_toggle": "C16", &"a.pause.help": "C16",
	&"a.branch.list": "reserved",
	&"a.scene": "C01", &"a.scene.customer": "C01", &"a.scene.notice": "C01",
	&"a.scene.ledger": "C01", &"a.scene.notebook": "C01", &"a.scene.calendar": "C01",
	&"a.scene.cashbox": "C01", &"a.scene.magnifier": "C01", &"a.scene.notewall": "C01",
	&"a.tab.contacts": "C01", &"a.tab.demands": "C01", &"a.tab.dossier": "C01",
	&"a.tab.rules": "C01", &"a.tab.shelf": "C01", &"a.tab.tickets": "C01",
	&"a.tab.estates": "C01", &"a.tab.settings": "C01",
	&"a.hero": "C02", &"a.contacts": "C02", &"a.hand.kept": "C02",
	&"a.pet": "C02",
	&"a.hand.preview": "C02",
	&"a.dialog": "C04", &"a.dialog.next": "C04", &"a.shelf.list": "C04",
	&"a.tickets.list": "C04",
	&"a.scene.curio": "RG4", &"a.stock.offers": "RG4", &"a.relics.list": "RG4",
}
# 带 @<uid> 的锚点（每张牌一个）
const CARD_ANCHORS: Array[StringName] = [&"a.card", &"a.card.keep", &"a.card.days", &"a.card.gold"]

# ---------------- 新手指引：界面事件（§7.10.5；值 = 谁发） ----------------
const UI_EVENTS := {
	&"panel_opened": "C01",
	&"panel_closed": "C01",
	&"drawer_opened": "C01",
	&"drawer_closed": "C01",
	&"hotspot_pressed": "C01",
	&"hand_selected": "C02",
	&"hand_played": "C02",
	&"card_zoomed": "C02",
	&"card_drag_started": "C02",
	&"slot_drop": "C03",
	&"dialog_advanced": "C04",
	&"dialog_skipped": "C04",
	&"reply_chosen": "C04",
	&"mg_tool": "C12-C15",
	&"guide_shown": "C16",
	&"guide_done": "C16",
}

# ---------------- 新手指引：步骤里能用的条件 op（V35；组合 all/any/not 也可以） ----------------
const GUIDE_COND_OPS: Array[StringName] = [&"flag", &"story", &"day_gte", &"abs_day_gte", &"stage_gte", &"mode",
	&"phase", &"has_contact", &"has_kept", &"demand_open", &"money_gte", &"money_lt", &"estate_status",
	&"weather", &"market_day"]
const GUIDE_COMBINATORS: Array[StringName] = [&"all", &"any", &"not"]
# 指引里“教的人”里不是人物的（§3.5）
const GUIDE_TEACHER_OBJECTS: Array[String] = ["obj.notice", "obj.almanac", "obj.brother_ledger"]
# done_when 的 token 前缀（§4.7.21）
const GUIDE_DONE_PREFIXES: Array[String] = ["cmd:", "ui:", "first:", "panel:"]
const GUIDE_TRIGGER_KEYS: Array[String] = ["first", "phase", "mode", "stage_gte", "stage_day_gte", "abs_day_gte",
	"after", "panel", "hand_clear", "cond"]

# ---------------- 随机数域登记表（§6.3；[精确串或正则, 主人, 是否正则]） ----------------
const RNG_DOMAINS: Array = [
	["^c\\.deal\\.(person|event|news|fate|life|big_fate|night|street)$", "G01", true],
	["c.deal.n.person", "G01", false], ["c.deal.n.news", "G01", false], ["c.deal.sub", "G01", false],
	["c.sched.life.n", "G02", false], ["c.sched.life.day", "G02", false], ["c.sched.life.pick", "G02", false],
	["c.goal.pick", "G02", false], ["^c\\.year\\.[a-z0-9_]+$", "G02", true],
	["c.coin", "G03", false], ["c.demand.kind", "G03", false], ["c.demand.pick", "G03", false],
	["c.demand.amt", "G03", false], ["c.pet.wander", "G03", false],
	["c.cust.asking", "G04", false], ["c.cust.floor", "G04", false], ["c.cust.patience", "G04", false],
	["c.cust.want", "G04", false], ["c.cust.reply", "G04", false], ["c.redeem.come", "G04", false],
	["c.mg.pick", "G04", false], ["c.mg.param", "G04", false], ["^item_[a-z0-9_]+$", "G04", true],
	["^c\\.street\\.[a-z0-9_]+$", "G06", true], ["^c\\.prison\\.[a-z0-9_]+$", "G06", true],
	["^pressure:c_[a-z0-9_]+$", "G05", true], ["wheel:c_climate", "G05", false], ["c.fate.due", "G05", false],
	["^c\\.wheel\\.wh\\.[a-z0-9_]+$", "G05", true], ["c.lot.pick", "G05", false], ["c.lot.verse", "G05", false],
	["c.cezi.offer", "G05", false], ["c.almanac", "G05", false],
	["^c\\.ai\\.[a-z0-9_]+$", "G06", true],
	["c.mg.spot.layout", "C12", false], ["c.mg.coin_ring.layout", "C13", false], ["c.mg.weigh.layout", "C14", false],
	["c.mg.fragments.layout", "C15", false], ["c.mg.decode.layout", "C15", false],
	["^c\\.qa\\.[a-z0-9_.]+$", "K14", true],
	["c.stock.offer", "RG2", false], ["m.run.seed", "RG2", false], ["m.run.seed_text", "RG2", false],
	["c.mock", "W0", false],
]


# 随机数域的主人；没登记返回 ""（CardCtx.draw 在开发版里据此 push_error）
static func rng_owner(domain: String) -> String:
	for row in RNG_DOMAINS:
		if bool(row[2]):
			var re := RegEx.create_from_string(str(row[0]))
			if re.search(domain) != null:
				return str(row[1])
		elif str(row[0]) == domain:
			return str(row[1])
	return ""


# 锚点 id 的目录键：a.card@c0007 → a.card；a.card@{uid} → a.card
static func anchor_base(anchor_id: String) -> String:
	var at := anchor_id.find("@")
	return anchor_id if at < 0 else anchor_id.substr(0, at)


static func is_known_anchor(anchor_id: String) -> bool:
	var base := anchor_base(anchor_id)
	if not ANCHORS.has(StringName(base)):
		return false
	var has_at := anchor_id.find("@") >= 0
	return has_at == CARD_ANCHORS.has(StringName(base))


# 牌的 id 是否合 §4.2 的正则
static func is_valid_id(id: String) -> bool:
	return RegEx.create_from_string(ID_REGEX).search(id) != null


# The owner scene of a panel kind; "" for minigame (its own host) and for kinds not in PANEL_SCENES.
static func panel_scene(kind: StringName) -> String:
	if kind == &"minigame":
		return ""
	return str(PANEL_SCENES.get(kind, ""))


# The owner scene of a table widget; "" for names not in WIDGET_SCENES.
static func widget_scene(name: StringName) -> String:
	return str(WIDGET_SCENES.get(name, ""))
