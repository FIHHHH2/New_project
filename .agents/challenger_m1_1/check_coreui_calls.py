"""
Scan for CoreUI calls
"""
import os
import re

for dirpath, _, filenames in os.walk("."):
    if ".git" in dirpath or ".agents" in dirpath:
        continue
    for f in filenames:
        if f.endswith(".luau"):
            path = os.path.join(dirpath, f)
            with open(path, "r", encoding="utf-8") as file:
                lines = file.readlines()
            for idx, line in enumerate(lines):
                if re.search(r"\b(Toggle|Open|Close|SetVisible|CreateTab|CreateSubTabs|AddSection|AddToggle|AddSlider|AddButton|AddTextBox|Notify)\b", line):
                    # check if called as method
                    if ":" in line:
                        pass
