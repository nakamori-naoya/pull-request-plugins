# assessment.json

```json
{
  "schema": 1,
  "repository": "owner/repo",
  "pull_request": 123,
  "head_sha": "...",
  "comments": [
    {
      "id": "review-comment-id",
      "author": "name",
      "body": "original comment",
      "path": "src/file.ts",
      "line": 10,
      "decision": "accept",
      "intent": "変更と周辺sourceから復元した意図",
      "reason": "採否の根拠",
      "proposed_change": "採用時の修正、非採用時は空文字",
      "verification": ["実行する検証"]
    }
  ]
}
```

`decision`は`accept` / `reject` / `defer`だけを許す。判断不能を`reject`へ丸めない。
