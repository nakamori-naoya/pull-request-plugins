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

`before_modify`、`after_modify`も同じ。required未承認はexit 3。

## 下段skillと公開操作の委譲

```bash
POLICY_ROOT=$(yq -er '.deps["agent-work-policy"].root' "$CFG_FILE")
POLICY_CFG=$(bash "$POLICY_ROOT/scripts/prepare.sh" "$(pwd)") || exit 2
trap 'rm -f "$CFG_FILE" "$POLICY_CFG"' EXIT
COMMIT_MESSAGE=$(yq -er '.playbook.git.commit_message' "$CFG_FILE")
python3 "$POLICY_ROOT/scripts/control.py" commit --config "$POLICY_CFG" \
  --repo "$(pwd)" --paths-file changed-paths.txt --message "$COMMIT_MESSAGE" [--approved]
python3 "$POLICY_ROOT/scripts/control.py" push --config "$POLICY_CFG" \
  --repo "$(pwd)" [--approved]
```

Agent Work Policyがpermission、検証、human gateと公開Git実行を判断する。`waiting_for_human`以外のexit 3を成功へ変換しない。意味判断を伴う工程はplaybook.ymlに指定されたskillへ渡す。`changed-paths.txt`は1行1repository相対path。公開方針はrepository単位で一つであり、呼び出し元scopeで差し替えられないよう、`prepare.sh`へ`--scope`は意図的に渡さない。

## report

`report.enabled: false`なら資料工程をすべてskipする。trueなら`requires`に`write-doc`が必要で、`report.timing`に一致する1工程だけを実行する。資料成果物は直後のgateまたは後続工程の`conditional_needs`で拘束される。
