# library

図書館の貸出を扱う小さな package である。

## 完了判定

変更は、repository の root で次の command を、この順にすべて通したときに完了とする。

1. `python3 -m unittest discover -s tests`
2. `python3 scripts/check_changelog.py`
