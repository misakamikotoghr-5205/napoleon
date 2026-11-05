# GameJev NPC 大脑适配层（FeaturePort 的 Godot 简化版）
# - 把《德厚当》人物的多维人格、关系、情境编码成 GameJev v0.5 冻结的 96 维状态；
# - 把候选行动编码成 32 维行动属性；
# - 可解释规则效用 + PersonaResidual（原样复用的 v0.5 GDScript 数值核）残差 → softmax → 角色独立随机流抽样。
# 概率与数值只给开发者面板，玩家界面永远不显示（GameJev UX01）。
extends RefCounted

const PersonaResidualScript = preload("res://scripts/persona/PersonaResidual.gd")

const TRAITS = ["openness", "conscientiousness", "sociability", "compassion", "emotional_reactivity", "honesty", "assertiveness", "impulsivity", "patience", "risk_tolerance", "attachment_security", "adaptability"]
const VALUES = ["autonomy", "fairness", "loyalty", "achievement", "security", "benevolence", "order", "novelty"]
const COGN = ["Se", "Si", "Ne", "Ni", "Te", "Ti", "Fe", "Fi"]
const MOTIVES = ["principle", "connection", "recognition", "identity", "mastery", "certainty", "possibility", "agency", "harmony"]
const EMOTIONS = ["anger", "fear", "sadness", "joy", "shame", "guilt", "disgust", "surprise", "hope", "arousal"]
const NEEDS = ["safety", "resources", "rest", "belonging", "status", "control", "information", "meaning"]
const REL = ["trust", "affection", "respect", "fear", "resentment", "indebtedness", "familiarity", "dependence"]
const CONTEXT = ["time_pressure", "publicness", "enforcement", "exit_access", "support", "ambiguity", "norm_pressure", "threat", "stakes", "opportunity"]
const MEMORY = ["positive", "negative", "betrayal", "help", "humiliation", "success", "failure", "recency"]
const GOALS = ["acquire", "avoid_loss", "connect", "understand", "defend_boundary", "repair_relation", "fulfill_duty", "explore"]
const REGUL = ["self_control", "reappraisal", "flexibility", "fatigue"]
const ACTION_FEATURES = ["gain", "safety", "information", "affiliation", "autonomy", "status", "fairness", "care", "order", "novelty", "effort", "delay", "risk", "harm", "deception", "confrontation", "withdrawal", "disclosure", "repair", "commitment", "evidence", "intuition", "planning", "immediacy", "dignity", "resource_cost", "uncertainty", "social_exposure", "reversibility", "norm_violation", "target_benefit", "intensity"]

const STACKS = {
	"ISTJ": ["Si", "Te", "Fi", "Ne"], "ISFJ": ["Si", "Fe", "Ti", "Ne"], "INFJ": ["Ni", "Fe", "Ti", "Se"], "INTJ": ["Ni", "Te", "Fi", "Se"],
	"ISTP": ["Ti", "Se", "Ni", "Fe"], "ISFP": ["Fi", "Se", "Ni", "Te"], "INFP": ["Fi", "Ne", "Si", "Te"], "INTP": ["Ti", "Ne", "Si", "Fe"],
	"ESTP": ["Se", "Ti", "Fe", "Ni"], "ESFP": ["Se", "Fi", "Te", "Ni"], "ENFP": ["Ne", "Fi", "Te", "Si"], "ENTP": ["Ne", "Ti", "Fe", "Si"],
	"ESTJ": ["Te", "Si", "Ne", "Fi"], "ESFJ": ["Fe", "Si", "Ne", "Ti"], "ENFJ": ["Fe", "Ni", "Se", "Ti"], "ENTJ": ["Te", "Ni", "Se", "Fi"],
}

const RESIDUAL_WEIGHT = 0.8
const TEMPERATURE = 0.35

var model = null
var model_ok: bool = false
var world_seed: int = 19380306

func _init(p_seed: int = 19380306) -> void:
	world_seed = p_seed
	model = PersonaResidualScript.new()
	model_ok = model.load_model("res://model/persona_residual.json")
	if not model_ok:
		push_warning("PersonaResidual 模型未加载，NPC 只用规则效用决策")

# ---------- 创建人格（GameJev P01/P02：MBTI/九型只做初始化预设） ----------
static func make_persona(def: Dictionary) -> Dictionary:
	var p := {}
	p["traits"] = def.get("traits", {}).duplicate()
	p["values"] = def.get("values", {}).duplicate()
	var cog := {}
	for c in COGN:
		cog[c] = 0.36
	var stack: Array = STACKS.get(def.get("mbti", "ISFJ"), STACKS["ISFJ"])
	var lv := [0.745, 0.605, 0.465, 0.325]
	for i in range(4):
		cog[stack[i]] = lv[i]
	p["cognition"] = cog
	var mot := {}
	for m in MOTIVES:
		mot[m] = 0.35
	var en: Array = def.get("ennea", [9, 1])
	mot[MOTIVES[int(en[0]) - 1]] = 0.7
	mot[MOTIVES[int(en[1]) - 1]] = 0.525
	p["motives"] = mot
	var ins: Array = def.get("instincts", [0.6, 0.5, 0.4])
	p["instincts"] = {"preservation": ins[0], "social": ins[1], "intensity": ins[2]}
	var emo := {}
	for e in EMOTIONS:
		emo[e] = 0.08
	emo["joy"] = 0.25
	emo["hope"] = 0.4
	emo["arousal"] = 0.15
	for k in def.get("emotions", {}):
		emo[k] = def["emotions"][k]
	p["emotions"] = emo
	var needs := {}
	for n in NEEDS:
		needs[n] = 0.25
	for k in def.get("needs", {}):
		needs[k] = def["needs"][k]
	p["needs"] = needs
	var mem := {}
	for m in MEMORY:
		mem[m] = 0.0
	p["memory"] = mem
	var goals := {}
	for g in GOALS:
		goals[g] = 0.3
	for k in def.get("goals", {}):
		goals[k] = def["goals"][k]
	p["goals"] = goals
	p["regulation"] = {"self_control": 0.65, "reappraisal": 0.5, "flexibility": 0.5, "fatigue": 0.15}
	return p

static func fresh_rel() -> Dictionary:
	return {"trust": 0.4, "affection": 0.3, "respect": 0.4, "fear": 0.1, "resentment": 0.0, "indebtedness": 0.0, "familiarity": 0.0, "dependence": 0.1}

# ---------- FeaturePort：编码 96 维（只用该角色能感知的信号） ----------
func encode(npc: Dictionary, ctx: Dictionary) -> Array:
	var p: Dictionary = npc["persona"]
	var rel: Dictionary = npc["rel"].get(ctx.get("target", "player"), fresh_rel())
	var v: Array = []
	for k in TRAITS: v.append(_c(p["traits"].get(k, 0.5)))
	for k in VALUES: v.append(_c(p["values"].get(k, 0.5)))
	for k in COGN: v.append(_c(p["cognition"].get(k, 0.36)))
	for k in MOTIVES: v.append(_c(p["motives"].get(k, 0.35)))
	for k in ["preservation", "social", "intensity"]: v.append(_c(p["instincts"].get(k, 0.5)))
	for k in EMOTIONS: v.append(_c(p["emotions"].get(k, 0.08)))
	for k in NEEDS: v.append(_c(p["needs"].get(k, 0.25)))
	for k in REL: v.append(_c(rel.get(k, 0.0)))
	var cx: Dictionary = {"time_pressure": 0.2, "publicness": 0.3, "enforcement": 0.4, "exit_access": 0.8, "support": 0.3, "ambiguity": 0.4, "norm_pressure": 0.3, "threat": 0.1, "stakes": 0.3, "opportunity": 0.3}
	for k in ctx.get("context", {}): cx[k] = ctx["context"][k]
	for k in CONTEXT: v.append(_c(cx[k]))
	for k in MEMORY: v.append(_c(p["memory"].get(k, 0.0)))
	for k in GOALS: v.append(_c(p["goals"].get(k, 0.3)))
	for k in REGUL: v.append(_c(p["regulation"].get(k, 0.5)))
	return v

static func action_vec(attrs: Dictionary) -> Array:
	var a: Array = []
	for k in ACTION_FEATURES:
		a.append(_c(attrs.get(k, 0.0)))
	return a

# ---------- 决策：规则效用 + 神经残差 → 分布 → 角色独立随机流 ----------
# cands: [{id, attrs:{32维中的若干}, utility:float}]；不可行候选应在调用前按知识条件过滤（如“没钱就不能足额还”）
func decide(npc: Dictionary, cands: Array, ctx: Dictionary, semantic_key: String) -> Dictionary:
	if cands.is_empty():
		return {"id": "", "probs": {}}
	var s: Array = encode(npc, ctx)
	var states: Array = []
	var actions: Array = []
	for c in cands:
		states.append(s)
		actions.append(action_vec(c.get("attrs", {})))
	var residuals: Array = []
	if model_ok:
		var r: Dictionary = model.score_pairs(states, actions)
		if r.has("residuals"):
			residuals = r["residuals"]
	var scores: Array = []
	for i in range(cands.size()):
		var res := float(residuals[i]) if i < residuals.size() else 0.0
		scores.append(float(cands[i].get("utility", 0.0)) + RESIDUAL_WEIGHT * res)
	var top: float = scores.max()
	var ex: Array = []
	var tot := 0.0
	for sc in scores:
		var e := exp((float(sc) - top) / TEMPERATURE)
		ex.append(e)
		tot += e
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(world_seed) + "|" + str(npc["id"]) + "|" + semantic_key)
	var roll := rng.randf() * tot
	var pick := cands.size() - 1
	var acc := 0.0
	for i in range(ex.size()):
		acc += ex[i]
		if roll <= acc:
			pick = i
			break
	var probs := {}
	for i in range(cands.size()):
		probs[cands[i]["id"]] = snappedf(ex[i] / tot, 0.001)
	var out := {"id": cands[pick]["id"], "probs": probs, "residuals": residuals, "key": semantic_key}
	npc["last_decision"] = out
	return out

# ---------- 情绪 / 记忆 / 关系更新（态度与行动分离，GameJev P06） ----------
static func feel(npc: Dictionary, deltas: Dictionary) -> void:
	var p: Dictionary = npc["persona"]
	for k in deltas:
		for grp in ["emotions", "memory", "needs", "goals"]:
			if p[grp].has(k):
				p[grp][k] = _c(float(p[grp][k]) + float(deltas[k]))

static func relate(npc: Dictionary, target: String, deltas: Dictionary) -> void:
	if not npc["rel"].has(target):
		npc["rel"][target] = fresh_rel()
	var r: Dictionary = npc["rel"][target]
	for k in deltas:
		r[k] = _c(float(r.get(k, 0.0)) + float(deltas[k]))
	r["familiarity"] = _c(float(r["familiarity"]) + 0.05)

# 外显态度：给表现层选台词/动作用；不是心理答案
static func expression(npc: Dictionary) -> String:
	var e: Dictionary = npc["persona"]["emotions"]
	var t: Dictionary = npc["persona"]["traits"]
	var r: Dictionary = npc["rel"].get("player", fresh_rel())
	if float(e["anger"]) > 0.3 and float(t.get("emotional_reactivity", 0.5)) > 0.45:
		return "（脸色沉下来）"
	if float(e["anger"]) > 0.3:
		return "（没说话，手指在柜台上敲了两下）"
	if float(e["shame"]) > 0.3:
		return "（低着头）"
	if float(e["fear"]) > 0.35:
		return "（往门外瞟了一眼）"
	if float(e["joy"]) > 0.4 or float(r["affection"]) > 0.6:
		return "（笑了笑）"
	if float(e["sadness"]) > 0.35:
		return "（叹了口气）"
	if float(t.get("assertiveness", 0.5)) > 0.7 and float(t.get("patience", 0.5)) < 0.45:
		return "（不耐烦地）"
	return ""

# 每到一个时段，情绪向基线回落；关系怨恨与关键记忆不会因此删除（GameJev 4.5）
static func decay(npc: Dictionary) -> void:
	var e: Dictionary = npc["persona"]["emotions"]
	for k in e:
		var base := 0.08
		if k == "joy": base = 0.25
		elif k == "hope": base = 0.4
		elif k == "arousal": base = 0.15
		e[k] = float(e[k]) + (base - float(e[k])) * 0.25
	npc["persona"]["memory"]["recency"] = float(npc["persona"]["memory"]["recency"]) * 0.7

static func _c(x) -> float:
	return clampf(float(x), 0.0, 1.0)
