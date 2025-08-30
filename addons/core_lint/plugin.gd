@tool
extends EditorPlugin

var panel: VBoxContainer
var results: RichTextLabel
var cb_flag_walrus: CheckBox
var cb_fix_ternary: CheckBox

func _enter_tree() -> void:
    panel = VBoxContainer.new()
    panel.name = "Core Lint"
    var title = Label.new()
    title.text = "Core Lint (Godot 4.x)"
    panel.add_child(title)
    cb_flag_walrus = CheckBox.new()
    cb_flag_walrus.text = "Flag occurrences of := (walrus)"
    cb_flag_walrus.button_pressed = false
    panel.add_child(cb_flag_walrus)
    cb_fix_ternary = CheckBox.new()
    cb_fix_ternary.text = "Enable auto-fix for simple ternary lines"
    cb_fix_ternary.button_pressed = false
    panel.add_child(cb_fix_ternary)
    var btn = Button.new()
    btn.text = "Run Lint"
    btn.pressed.connect(_on_run_pressed)
    panel.add_child(btn)
    var btn_fix = Button.new()
    btn_fix.text = "Fix Simple Issues"
    btn_fix.pressed.connect(_on_fix_pressed)
    panel.add_child(btn_fix)
    results = RichTextLabel.new()
    results.fit_content = true
    results.scroll_active = true
    results.autowrap_mode = TextServer.AUTOWRAP_WORD
    results.custom_minimum_size = Vector2(0, 240)
    panel.add_child(results)
    add_control_to_bottom_panel(panel, panel.name)
    add_tool_menu_item("Run Core Lint", Callable(self, "_on_run_pressed"))

func _exit_tree() -> void:
    remove_control_from_bottom_panel(panel)
    remove_tool_menu_item("Run Core Lint")

func _on_run_pressed() -> void:
    var issues := _scan_project(cb_flag_walrus.button_pressed)
    results.clear()
    if issues.is_empty():
        results.append_text("✅ No issues found.\n")
    else:
        results.append_text("⚠️ Found %d potential issues:\n\n" % issues.size())
        for i in issues:
            results.append_text("• %s\n" % i)

func _scan_project(flag_walrus: bool) -> Array:
    var issues: Array = []
    _scan_dir("res://", issues, flag_walrus)
    return issues

func _scan_dir(path: String, issues: Array, flag_walrus: bool) -> void:
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
            _scan_dir(full, issues, flag_walrus)
        else:
            if name.get_extension() == "gd":
                _lint_file(full, issues, flag_walrus)
        name = d.get_next()
    d.list_dir_end()

func _lint_file(path: String, issues: Array, flag_walrus: bool) -> void:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return
    var text := f.get_as_text()
    f.close()
    # Rule 1: C-style ternary
    if _has_c_style_ternary(text):
        issues.append("%s: possible C-style ternary use. Use `a if cond else b`." % path)
    # Rule 2: has_variable usage
    if text.find("has_variable(") != -1:
        issues.append("%s: has_variable() used. Prefer has_method() / get_property_list()." % path)
    # Rule 3: connect to non-existing handler
    var missing_methods := _find_missing_connected_methods(text)
    for m in missing_methods:
        issues.append("%s: signal connected to missing method '%s' in this script." % [path, m])
    # Optional: warn about walrus occurrences (:=)
    if flag_walrus and text.find(":=") != -1:
        issues.append("%s: contains walrus (:=). Ensure inference is valid in this context." % path)

func _on_fix_pressed() -> void:
    var fixed_files := 0
    var d := DirAccess.open("res://")
    if d == null:
        results.append_text("Cannot open res:// for fixing.\n")
        return
    fixed_files = _fix_project(cb_flag_walrus.button_pressed, cb_fix_ternary.button_pressed)
    results.append_text("Fix done. Files modified: %d\n" % fixed_files)

func _fix_project(flag_walrus: bool, do_fix_ternary: bool) -> int:
    var count := 0
    count += _fix_dir("res://", flag_walrus, do_fix_ternary)
    return count

func _fix_dir(path: String, flag_walrus: bool, do_fix_ternary: bool) -> int:
    var c := 0
    var d := DirAccess.open(path)
    if d == null:
        return 0
    d.list_dir_begin()
    var name = d.get_next()
    while name != "":
        if name.begins_with("."):
            name = d.get_next()
            continue
        var full = path.rstrip("/") + "/" + name
        if d.current_is_dir():
            c += _fix_dir(full, flag_walrus, do_fix_ternary)
        elif name.get_extension() == "gd":
            if _fix_file(full, flag_walrus, do_fix_ternary):
                c += 1
        name = d.get_next()
    d.list_dir_end()
    return c

func _fix_file(path: String, flag_walrus: bool, do_fix_ternary: bool) -> bool:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return false
    var text := f.get_as_text()
    f.close()
    var changed := false
    if do_fix_ternary and _has_c_style_ternary(text):
        var new_text := _auto_fix_c_style_ternary(text)
        if new_text != text:
            var w := FileAccess.open(path, FileAccess.WRITE)
            if w:
                w.store_string(new_text)
                w.close()
                changed = true
    return changed

func _auto_fix_c_style_ternary(text: String) -> String:
    var out_lines: Array[String] = []
    for line in text.split("\n"):
        var fixed_line := line
        var s := line.strip_edges()
        if s.begins_with("#"):
            out_lines.append(line)
            continue
        var qpos = line.find_char("?")
        if qpos >= 0:
            var cpos = line.find_char(":", qpos)
            if cpos > qpos:
                # Heurística: soportar patrones simples "return C ? T : F" y "X = C ? T : F"
                var leading = line.substr(0, qpos)
                var cond_start := -1
                var prefix := ""
                if leading.find("return ") != -1:
                    var rp = leading.rfind("return ")
                    prefix = leading.substr(0, rp)
                    var cond = leading.substr(rp + 7, qpos - (rp + 7)).strip_edges()
                    var true_expr = line.substr(qpos + 1, cpos - (qpos + 1)).strip_edges()
                    var false_expr = line.substr(cpos + 1).strip_edges()
                    fixed_line = "%sreturn %s if %s else %s" % [prefix, true_expr, cond, false_expr]
                elif leading.find("=") != -1:
                    var ep = leading.rfind("=")
                    prefix = leading.substr(0, ep + 1)
                    var cond2 = leading.substr(ep + 1, qpos - (ep + 1)).strip_edges()
                    var t2 = line.substr(qpos + 1, cpos - (qpos + 1)).strip_edges()
                    var f2 = line.substr(cpos + 1).strip_edges()
                    fixed_line = "%s %s if %s else %s" % [prefix.strip_edges(), t2, cond2, f2]
        out_lines.append(fixed_line)
    return "\n".join(out_lines)

func _has_c_style_ternary(s: String) -> bool:
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

func _find_missing_connected_methods(text: String) -> Array:
    var missing: Array = []
    var lines := text.split("\n")
    var methods: Array = _collect_defined_methods(text)
    for line in lines:
        var l := line.strip_edges()
        if l.find(".connect(") != -1:
            # Pattern A: signal.connect(_on_something)
            var start = l.find("connect(") + 8
            var inside = l.substr(start, l.length() - start)
            # Remove trailing ) and spaces
            inside = inside.trim_suffix(")").strip_edges()
            # Pattern B: connect( Callable(self, "method") )
            if inside.begins_with("Callable("):
                var q1 = inside.find("\"")
                if q1 != -1:
                    var q2 = inside.find("\"", q1+1)
                    if q2 != -1:
                        var mname = inside.substr(q1+1, q2 - (q1+1))
                        if not methods.has(mname):
                            missing.append(mname)
            else:
                # Try to extract identifier like _on_name
                var token = inside.split(",")[0].strip_edges()
                # remove & casts if present
                token = token.strip_edges()
                # Expect an identifier starting with _
                if token.begins_with("_"):
                    var mname2 = token
                    if not methods.has(mname2):
                        missing.append(mname2)
    return missing

func _collect_defined_methods(text: String) -> Array:
    var names: Array = []
    var lines := text.split("\n")
    for line in lines:
        var s := line.strip_edges()
        if s.begins_with("func "):
            var rest = s.substr(5, s.length() - 5)
            var par = rest.find("(")
            if par > 0:
                var name = rest.substr(0, par).strip_edges()
                names.append(name)
    return names
