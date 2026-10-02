# ゴーストの一括チェック

## 使うとき

作者が「チェックして」「エラーが出ていないか見て」「おかしくない？」「辞書のエラーを直して」「コミットする前に確認して」と言ったとき。辞書やシェルをまとめて変更した後、コミットや nar 作成の前にも、自分から行ってよい。

## 手順

1. `powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1` を実行する。
   - `skipped (tool not available)` と出た項目は、ツールが入っていないか SSP が見つからない。`tools/setup.ps1` はダウンロードを伴うので、作者に一言断ってから実行する。SSP の場所は `tools/local.json` か環境変数 `SSP_PATH` で指定してもらう。
2. 結果は次の優先順で扱う。
   1. **check-dic の error**: 辞書が正しく読み込まれていない。最優先で直す。里々のログから拾うもの（パターンは `tools/satori.json`）は次のとおり。
      - `カッコの対応関係が正しくない部分があります。` / `辞書は正しく読み込まれていません。`（その前の行に、対象の辞書ファイルのパスが出る）: 閉じていない `（` がある。カッコを文字として使うときは `φ（` と書く。全角の `（` `）` の数と、`）` の閉じ忘れを、表示されたファイルから探す。
      - `SAORI読み込み中にエラーが発生: <行>`: `satori_conf.txt` の `＠SAORI` の行の誤り（`呼び出し名,相対パス` の形か、重複した呼び出し名か、DLL が無いか）。`saori/` のファイルの有無も見る。`SakuraDLLClient::load '…' ...failed.` は、SAORI の DLL が読み込めなかった（中身が SAORI でない、依存するライブラリが無いなど）。
      - `loading dic…txt... failed.` / `no dictionary file (dic*.txt) was loaded`: 辞書が読めない、または 1 つも無い。辞書は `ghost/master` の直下の `dic*.txt` だけが読まれる（`＄辞書フォルダ` で変えていなければ、`another/` などの下のファイルは読まれない）。
      - `loading satori_conf...failed`（warning）: `satori_conf.txt` が無いので、`＊初期化` と `＠SAORI` が読まれない。
      - `-Run` のとき（展開中）: `（名前、引数） not found.`（引数付きなので関数呼び出しとみなす。関数名の打ち間違いか、`＠SAORI` に登録していない SAORI）、`式が計算不能です。`（式のカッコの数、演算子、0 での除算を確かめる）、`引数が足りません。` などの引数の誤り、`※　＄による変数代入文には…　※`（`＄` の行に、タブか `＝` が無い）、`呼び出し回数超過`（循環呼び出し）、`ジャンプ回数超過`、`括弧展開サイズ超過`。
      - `（名前） not found.`（warning）: 引数の無い呼び出しの名前違い、または一度も代入していない変数を読んでいる。変数を意図して読んでいるのなら問題ない（`＊初期化` で初期値を入れる書き方がある）ので、打ち間違いでないかだけ確かめる。存在しないジャンプ先（`＞名前 not found.`）は、辞書が意図して使うことが多いので、表示しない（`tools/shiori.ps1` では `[note]` で出る）。
      - タイマや入力ボックスから呼ばれる文（そのときだけある変数を読む文）は、名前で直接実行すると意味のない警告が出る。その文の `＊` の行のすぐ上に、`check-dic: no-run` を含むコメント行（`＃check-dic: no-run（理由）`）を書くと、`-Run` で実行しない。実行しなかった数は、最後の行に `(N marked no-run)` と出る。同じ名前の文が複数あるときは、1 つに書けば、その名前はすべて実行しない。
      - 里々は、辞書を読み込むときに文法をほとんど検査しない（文を実行するときに解釈する）。読み込みで通っても、`-Run` を付けるか、`tools/shiori.ps1` で実際に呼ばないと、実行時のエラーは見つからない。
   2. **check-shell の Error / Warning**: 直す。`[SERIKO] shell/master/surfaces.txt:Line=123:Surface=10 ...` のように定義位置が出るので、そのファイルと行を直す。二重定義のエラーには、先に定義された側の位置も ` (ファイル名:Line=n)` として付く。位置が出ない（位置の無い種類の Notice）ときは、`Surface=` の番号から探す。Notice（使われていないサーフェスなど）は報告だけにする。シェルの画像そのものは、`GHOST.md` でライセンスを確かめるまで編集しない（改変を禁じているシェルがある。編集の手順は `docs/agents/workflows/edit-shell-image.md`）。`surfaces.txt` の重ね合わせ（`element` など）を直したときは、チェックが通っても位置のずれやパーツの抜けは見つからないので、画像を読めるなら `tools/dump-surface.ps1 -Surface <番号>` で仕上がりを見る。当たり判定（`collision` など）を直したときは `-Collision` を付けて、枠の位置と名前を見る。
3. 直したら 1 をもう一度実行し、error がなくなるまで繰り返す。
   - 辞書のトークを直したときは、`powershell -NoProfile -ExecutionPolicy Bypass -File tools/shiori.ps1 -Eval '（トークの名前）' -Plain` や、`-Event <イベントID>` で呼び出して、展開結果とエラーを見る（使い方は `docs/agents/commands.md` の「里々の文を試す」）。実行時のエラーは、辞書の読み込みのチェックだけでは見つからない。終了コード 2 なら、表示されたエラーの内容（`[in ＊名前]` が、そのとき実行していた文）から直す。SAORI の呼び出しや外部プログラムの実行をする文は本当に動くので、中身を読んでから呼ぶ。
   - 名前のない文（ランダムトーク）は `-Event OnTalk` で 1 つ実行される（選ばれるのはランダムなので、何度か実行する）。
4. SSP でこのゴーストを動かしている場合は、`powershell -NoProfile -ExecutionPolicy Bypass -File tools/ssp-log.ps1` で実行時のエラーログも見る（終了コード 3 なら SSP が起動していないので飛ばす）。古いエラーも残っているので、直したものは `tools/sstp.ps1 -Reload ghost` で読み込ませ、新しいエラーが出ないことを確かめる。
5. 最後に、直したことと残っている警告を短くまとめて報告する。

## 補足

- チェックは `ghost/master` の一時コピーで行う。里々が終了時に書く `satori_savedata.txt` / `satori_savebackup.txt` を、本物のフォルダに残さないため。
- `satori.dll` は、ビルドによっては `[ERROR]` の通知が遅れたり、まとめて出たりする（Mc201-5 で確認）。ログの通常の行からも拾っているので、表示は変わらない。
- チェックに使う tamacs.exe は、YAYA と里々の両方のログを `Set_loghandler` で受け取る。`Set_loghandler` は里々 Mc201-10 から入ったので、それより古い `satori.dll` では、チェックが SKIPPED（終了コード 3）になる。`docs/agents/workflows/update-satori.md` の手順で更新する。
- `-Run` は、SAORI を使う文も本当に実行する（`＠SAORI` に登録した SAORI は動く）。画面や PC に影響する SAORI を使うときは、その文の中身を読んでから実行する。

## 関連

- コマンドと終了コードの一覧: `docs/agents/commands.md`
- 里々のエラーメッセージ: https://ukatech.github.io/satori-docs/other/error-messages/
- 実機で確かめる: `docs/agents/workflows/try-in-ssp.md`
