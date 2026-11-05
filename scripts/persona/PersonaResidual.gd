# GameJev Persona v0.3 numerical scorer ONLY; not the complete Python host.
# Ported from the project scorer; retains upstream Jevlike attribution (MIT).
extends RefCounted
class_name PersonaResidual

const DIMS = [12, 8, 8, 9, 3, 10, 8, 8, 10, 8, 8, 4]
var p: Dictionary = {}
var ready: bool = false

func load_model(path: String) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var data = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(data) != TYPE_DICTIONARY or data.get("format") != "gamejev-persona-0.3":
        return false
    if int(data.get("width", 0)) != 16 or int(data.get("rank", 0)) != 8:
        return false
    if data.get("state_features", []).size() != 96 or data.get("action_features", []).size() != 32:
        return false
    p = data.get("parameters", {})
    ready = not p.is_empty()
    return ready

func score_pairs(states: Array, actions: Array) -> Dictionary:
    if not ready or states.size() != actions.size() or states.is_empty() or states.size() > 256:
        return {"error": "invalid_model_or_dimensions"}
    for i in range(states.size()):
        if states[i].size() != 96 or actions[i].size() != 32:
            return {"error": "invalid_dimensions"}
        for v in states[i] + actions[i]:
            if (typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT) or is_nan(float(v)) or is_inf(float(v)) or float(v)<0 or float(v)>1:
                return {"error": "invalid_numeric_input"}
    var output: Array = []
    for row in range(states.size()):
        var s: Array = states[row]
        var a: Array = actions[row]
        var keys: Array = []
        var values: Array = []
        var offset: int = 0
        for g in range(DIMS.size()):
            var name: String = "group_proj." + str(g)
            var token: Array = _norm(_linear(s.slice(offset, offset+DIMS[g]), name), "context_norm")
            keys.append(_linear(token, "key"))
            values.append(_linear(token, "value"))
            offset += DIMS[g]
        var query: Array = _linear(_norm(_linear(a,"option_projection"),"option_norm"),"query")
        var logits: Array = []
        for k in keys:
            logits.append(_dot(query,k)/sqrt(8.0))
        var weights: Array = _softmax(logits)
        var attended: Array = []
        for j in range(8):
            var total: float = 0.0
            for g in range(12):
                total += float(weights[g])*float(values[g][j])
            attended.append(total)
        var score: float = _dot(query,attended)/sqrt(8.0)+_dot(a,p["option_bias.weight"][0])+float(p["option_bias.bias"][0])
        output.append(tanh(score))
    return {"residuals":output}

func _dot(a: Array,b: Array) -> float:
    var x: float = 0.0
    for i in range(a.size()):
        x+=float(a[i])*float(b[i])
    return x

func _linear(x: Array,name: String) -> Array:
    var rows: Array = p[name+".weight"]
    var bias: Array = p.get(name+".bias",[])
    var y: Array = []
    for j in range(rows.size()):
        y.append(_dot(rows[j],x)+(float(bias[j]) if not bias.is_empty() else 0.0))
    return y

func _norm(x: Array,name: String) -> Array:
    var mean: float = 0.0
    for v in x: mean+=float(v)/float(x.size())
    var variance: float = 0.0
    for v in x: variance+=pow(float(v)-mean,2.0)/float(x.size())
    var y: Array = []
    for j in range(x.size()):
        y.append((float(x[j])-mean)/sqrt(variance+0.00001)*float(p[name+".weight"][j])+float(p[name+".bias"][j]))
    return y

func _softmax(x: Array) -> Array:
    var top: float = float(x.max())
    var total: float = 0.0
    var y: Array = []
    for v in x:
        y.append(exp(float(v)-top))
        total+=float(y[-1])
    for j in range(y.size()): y[j]=float(y[j])/total
    return y
