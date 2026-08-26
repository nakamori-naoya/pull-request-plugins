# 実行契約

## preflight

```bash
python3 "${PLUGIN_ROOT}/scripts/control.py" preflight --config "$CFG_FILE" --repo "$(pwd)"
```

`${.playbook.git.require_clean_start}`がtrueなら、開始時にtracked/untracked変更が1件でもあれば停止する。

## permission

```bash
python3 "${PLUGIN_ROOT}/scripts/control.py" permission --config "$CFG_FILE" --name review_import
python3 "${PLUGIN_ROOT}/scripts/control.py" permission --config "$CFG_FILE" --name modify
```

許可はexit 0、禁止はexit 3。禁止を承認質問で上書きしない。

## gate

```bash
python3 "${PLUGIN_ROOT}/scripts/control.py" gate --config "$CFG_FILE" --name after_assessment
# requiredなら人間へ確認し、明示承認後だけ:
python3 "${PLUGIN_ROOT}/scripts/control.py" gate --config "$CFG_FILE" --name after_assessment --approved
```

`before_modify`、`after_modify`、`before_commit`、`before_push`も同じ。required未承認はexit 3。

## 下段skillと公開

```bash
bash "${PLUGIN_ROOT}/scripts/publish.sh" commit --config "$CFG_FILE" \
  --repo "$(pwd)" --paths-file changed-paths.txt --approved
bash "${PLUGIN_ROOT}/scripts/publish.sh" push --config "$CFG_FILE" \
  --repo "$(pwd)" --approved
```

意味判断を伴う工程はplaybook.ymlに指定されたskillへ渡す。`changed-paths.txt`は1行1repository相対path。

## report

`report.enabled: false`なら資料工程をすべてskipする。trueなら`requires`に`write-doc`が必要で、`report.timing`に一致する1工程だけを実行する。資料成果物は直後のgateまたは後続工程の`conditional_needs`で拘束される。
