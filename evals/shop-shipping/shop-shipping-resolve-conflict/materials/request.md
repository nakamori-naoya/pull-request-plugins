# 実行の担当に渡したもの

実行の担当には、作業場所の `out/shop/` に置いた手元だけの git repository と、依頼の文だけを渡した。repository の remote は、作業場所の外にある手元の bare repository だけで、GitHub にはつながらない。PR の本文と review は、この環境からは取得できない。

repository には三つの commit がある。版と commit の本文は、このディレクトリの `commits.md`、`ancestor/`、`base/`、`head/` にある。作業 branch は `feature/free-shipping`、base は `main` である。repository の完了判定は、`AGENTS.md` の `python3 -m unittest discover -s tests` である。

依頼は、作業 branch を base と競合なく統合できる状態にすることで、push と PR の作成は頼んでいない。
