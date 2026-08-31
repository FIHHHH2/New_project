from exact_lexer import lex_luau
import re

with open(r"A:\Potassium\Modular-Roblox-Menu\Core\Main.luau", "r", encoding="utf-8") as fp:
    code = fp.read()

tokens = lex_luau(code)

counts = {}
for ttype, tval in tokens:
    if ttype == 'IDENT':
        counts[tval] = counts.get(tval, 0) + 1

num_func = counts.get('function', 0)
num_do = counts.get('do', 0)
num_if = counts.get('if', 0)
num_end = counts.get('end', 0)

print(f"Main.luau exact tokens:")
print(f"  function: {num_func}")
print(f"  do: {num_do}")
print(f"  if: {num_if}")
print(f"  end: {num_end}")

# Let's count ternary if in tokens:
# An 'if' token preceded by '=', '(', '{', '[', ',', '+', '-', '*', '/', 'and', 'or', 'not', 'return', ':'
ternary_if_count = 0
for idx, (ttype, tval) in enumerate(tokens):
    if ttype == 'IDENT' and tval == 'if':
        prev_tok = tokens[idx-1] if idx > 0 else None
        if prev_tok and prev_tok[1] in ('=', '(', '{', '[', ',', '+', '-', '*', '/', 'and', 'or', 'not', 'return', 'then', 'else'):
            ternary_if_count += 1
            print(f"  Ternary if at index {idx}, prev token: {prev_tok}")

stmt_if = num_if - ternary_if_count
expected_end = num_func + num_do + stmt_if
print(f"  Ternary if count: {ternary_if_count}")
print(f"  Statement if count: {stmt_if}")
print(f"  Expected ends (func + do + stmt_if): {expected_end}")
print(f"  Actual ends: {num_end}")
print(f"  Difference: {expected_end - num_end}")
