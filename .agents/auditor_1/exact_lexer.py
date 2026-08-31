import os
import glob

ROOT = r"A:\Potassium\Modular-Roblox-Menu"

def lex_luau(code):
    n = len(code)
    i = 0
    tokens = []
    
    while i < n:
        # Comments
        if i + 1 < n and code[i:i+2] == '--':
            i += 2
            if i < n and code[i] == '[':
                eq_count = 0
                j = i + 1
                while j < n and code[j] == '=':
                    eq_count += 1
                    j += 1
                if j < n and code[j] == '[':
                    close_tag = ']' + ('=' * eq_count) + ']'
                    close_pos = code.find(close_tag, j + 1)
                    if close_pos != -1:
                        i = close_pos + len(close_tag)
                        continue
                    else:
                        i = n
                        continue
            end_nl = code.find('\n', i)
            if end_nl != -1:
                i = end_nl + 1
            else:
                i = n
            continue
            
        # Long strings
        if code[i] == '[':
            eq_count = 0
            j = i + 1
            while j < n and code[j] == '=':
                eq_count += 1
                j += 1
            if j < n and code[j] == '[':
                close_tag = ']' + ('=' * eq_count) + ']'
                close_pos = code.find(close_tag, j + 1)
                if close_pos != -1:
                    tokens.append(('STRING', code[i:close_pos+len(close_tag)]))
                    i = close_pos + len(close_tag)
                    continue
                else:
                    tokens.append(('STRING', code[i:]))
                    i = n
                    continue

        # Quoted strings
        if code[i] in ("'", '"', '`'):
            quote = code[i]
            j = i + 1
            while j < n:
                if code[j] == '\\':
                    j += 2
                    continue
                if code[j] == quote:
                    j += 1
                    break
                j += 1
            tokens.append(('STRING', code[i:j]))
            i = j
            continue

        # Identifiers and keywords
        if code[i].isalpha() or code[i] == '_':
            j = i + 1
            while j < n and (code[j].isalnum() or code[j] == '_'):
                j += 1
            tokens.append(('IDENT', code[i:j]))
            i = j
            continue

        # Numbers
        if code[i].isdigit():
            j = i + 1
            while j < n and (code[j].isalnum() or code[j] in '._xX'):
                j += 1
            tokens.append(('NUMBER', code[i:j]))
            i = j
            continue

        ch = code[i]
        if ch in '()[]{}':
            tokens.append(('PUNCT', ch))
        elif ch in '=+-*/%^#<>~:,.;':
            tokens.append(('OP', ch))
        i += 1
        
    return tokens
