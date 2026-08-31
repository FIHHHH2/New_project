from exact_lexer import lex_luau

def inspect_ifs(path):
    print(f"=== Inspecting {path} ===")
    with open(path, "r", encoding="utf-8") as fp:
        code = fp.read()
    tokens = lex_luau(code)
    for idx, (ttype, tval) in enumerate(tokens):
        if tval == 'if':
            prev_tok = tokens[idx-1] if idx > 0 else None
            # print surrounding tokens
            context = " ".join([t[1] for t in tokens[max(0, idx-5):min(len(tokens), idx+6)]])
            print(f"if at token {idx}: prev = {prev_tok} | context: {context}")

inspect_ifs(r"A:\Potassium\Modular-Roblox-Menu\UI\Animations.luau")
inspect_ifs(r"A:\Potassium\Modular-Roblox-Menu\UI\PlayerList.luau")
inspect_ifs(r"A:\Potassium\Modular-Roblox-Menu\UI\MusicTracker.luau")
