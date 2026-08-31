from precise_block_parser import lex_luau

with open(r"A:\Potassium\Modular-Roblox-Menu\Loader.luau", "r", encoding="utf-8") as fp:
    c = fp.read()

toks = lex_luau(c)
print(f"Total tokens: {len(toks)}")
for idx in range(max(0, 30), min(len(toks), 60)):
    print(f"{idx}: {toks[idx]}")
