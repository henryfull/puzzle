@tool
extends EditorScript

# Simple GDScript linter for common pitfalls:
# - C-style ternary operator usage (?:) instead of GDScript's `a if cond else b`
# - Usage of has_variable() (not available on Object) instead of has_method()/get_property_list

func _run() -> void:
    var issues := []
    var dir := DirAccess.open("res://")
    if dir == null:
        push_error("Lint: No se pudo abrir res://")
        return
    _scan_dir("res://", issues)
    if issues.size() == 0:
        print("Lint: Sin problemas detectados ✅")
    else:
        print("Lint: Se detectaron ", issues.size(), " posibles problemas:")
        for i in issues:
            print(" - ", i)

func _scan_dir(path: String, issues: Array) -> void:
    var d := DirAccess.open(path)
    if d == null:
        return
    d.list_dir_begin()
    var name = d.get_next()
    while name != "":
        if name.begins_with("."):
            name = d.get_next()
            continue
        var full = path.rstrip("/") + "/" + name
        if d.current_is_dir():
            _scan_dir(full, issues)
        else:
            if name.get_extension() == "gd":
                _lint_file(full, issues)
        name = d.get_next()
    d.list_dir_end()

func _lint_file(path: String, issues: Array) -> void:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return
    var text := f.get_as_text()
    f.close()
    # Heurística: buscar '? ... :' (C-style ternary)
    if _has_c_style_ternary(text):
        issues.append(path + ": posible uso de operador ternario estilo C. Usa `a if cond else b`.")
    # has_variable(
    if text.find("has_variable(") != -1:
        issues.append(path + ": uso de has_variable(). En su lugar, usa has_method(), get_property_list() o un setter específico.")

func _has_c_style_ternary(s: String) -> bool:
    # Detectar "?" seguido de algo y luego ":" en la misma línea (ignorando comentarios básicos)
    var lines := s.split("\n")
    for line in lines:
        var stripped := line.strip_edges()
        if stripped.begins_with("#"):
            continue
        var qpos = stripped.find_char("?")
        if qpos >= 0:
            var cpos = stripped.find_char(":", qpos)
            if cpos > qpos:
                return true
    return false

