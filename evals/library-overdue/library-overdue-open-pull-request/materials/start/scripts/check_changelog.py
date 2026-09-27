"""CHANGELOG.md の「未リリース」の節に一行以上の記載があるかを確かめる。"""
import sys
from pathlib import Path

text = Path("CHANGELOG.md").read_text(encoding="utf-8")
section = text.split("## 未リリース", 1)[1].split("\n## ", 1)[0]
if not any(line.startswith("- ") for line in section.splitlines()):
    print("CHANGELOG.md の「未リリース」に変更の記載が無い", file=sys.stderr)
    sys.exit(1)
print("CHANGELOG: ok")
