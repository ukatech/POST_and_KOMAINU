# tamac と一時コピー

tamac は、伺かの SHIORI のログ受信ツール tama のコンソール版（[YAYA-shiori/tama](https://github.com/YAYA-shiori/tama)）。YAYA 用に作られているが、里々（`satori.dll`）も同じ仕組み（`logsend` エクスポートで渡されたウィンドウへ `WM_COPYDATA` でログを送る）に対応していて、`tools/check-dic.ps1` と `tools/shiori.ps1` はこれで里々を動かしている。

## tamac.exe の使い方（Mc201-5 の `satori.dll` で確認）

- `tamac.exe <satori.dll のフルパス>` だけなら、読み込んで、解放するだけ（ログを出す）。`-r` を付けると、標準入力を EOF まで読んでリクエストにし（改行を CRLF にそろえ、終わりの空行を足し、先頭の BOM を外す）、応答を標準出力に出す。
- **ログの出力先が違う**: `-r` なし → ログは標準出力、標準エラー出力には `[ERROR]` などのログ種別付きの行だけ。`-r` あり → ログはすべて標準エラー出力（`[ERROR]` の行も混ざる）、標準出力は応答だけ。`tools/lib/satori.ps1` の `Invoke-DevkitTamac` が、どちらも `Log` にまとめて返す。
- dll は絶対パスで渡し、作業フォルダも `ghost/master`（の一時コピー）にする。
- 1 回に送れるリクエストは 1 つだけ（2 つ目は無視される）。
- 終了コード: 0 / 1（dll が読めない、空のリクエスト、空の応答）/ 2（`[ERROR]` などが 1 つでもあった。応答は出る）。**里々の通常のログの行のエラー（`SAORI読み込み中にエラーが発生…`、`（名前） not found.` など）は終了コードに反映されない**ので、ログを読んで調べる。
- 環境変数 `GITHUB_ACTIONS` があると `--ci` の出力に切り替わる（`::error file=,line=0,…` になり、位置が入らない）。`Invoke-DevkitTamac` は子プロセスに `GITHUB_ACTIONS` を渡さず、注釈は `check-dic.ps1 -Ci` が自分で作る。
- 毎回 `[tamac] Interface "CI_check_failed" not found` が出る。YAYA 用のインターフェースが無いだけで、無視してよい（`Get-DevkitSatoriDiagnostics` が読み飛ばす）。
- **4096 バイトを超えるリクエストは、標準入力の読み取りの区切りで日本語の文字が壊れる**（`Reference` の中の文字が `U+FFFD` になる。3000 バイト台までは壊れず、4186 バイトで壊れることを確認）。tamac 1.0.3.26 で直った（標準入力をすべて読んでから、まとめて UTF-8 から変換する）。`tools/tools.json` の `minimumVersion` を 1.0.3.26 にしたので、`tools/shiori.ps1` の警告は外した。`tools/check-dic.ps1 -Run` は、リクエストを小さく保つため、今も 3800 バイト以内に分けて実行している。

## 里々のログの出方（`Sender`）

- 里々のログは 2 種類。通常のログ（`GetSender().sender()`）はそのまま行として送られ、tamac では種類なし（標準出力／`-r` では標準エラー出力）。エラー用（`GetSender().errsender()`）は `[ERROR]` 付きで送られる（`SenderConst::E_E`）。エラー用のうち、`＠SAORI` の誤り、`式が計算不能です`、辞書のカッコの誤りなどは、ログとは別に `ErrorLevel` / `ErrorDescription` ヘッダとしても返せる（SSP が `NOTIFY capability` で `response.errorlevel` を通知したときだけ。`tamac` は通知しない）。`response.errorlevel` に対応していないベースウェアでは、エラーがダイアログボックスで出る（`error_buf::flush`）。
- **Mc201-5 の不具合**: `satori::endl`（エラー用の行末）が、VC6 のストリームで文字として出力されず、数字の `1057598`（`'\n'` の 10 と `0xE0FE` の 57598 を並べたものと読める）になる。このため、エラー用の行は `[ERROR]` として送られるのが遅れ、後ろの本物の改行が来た時点でまとめて 1 行になって出る（`… プラグインが存在しません。1057598bar: 設定ファイルの書式が正しくありません。1057598…`）。改行が来なければ、まったく出ない。`tools/satori.json` の `flushMarkArtifact` で、この文字列で分け直している。里々が直ったら（`satoriya-shiori` の `Sender.h` の `satori::endl`）、その値は空にしてよい。**エラー用のメッセージが見えないことがあるので、通常のログの行（`SAORI読み込み中にエラーが発生: …` など）からも拾っている**。
  - satoriya-shiori のソースでは `satori::endl` を `put()` で書くように直した（Mc201-5 の次の版から）。直った版では、エラー用の行がその場で `[ERROR]` として届き、`calc` の計算エラーなどで応答に `ErrorLevel: critical` が付く。回避のコードは、Mc201-5 以前の版のために残しておく。
- ログには、辞書を読み込んだあとの `＊OnSatoriLoad` などの実行と、リクエストごとの `--- Request ---` / `--- Operation ---` / `--- Response ---` の区切りが並ぶ。`Get-DevkitSatoriDiagnostics` は、これらの区切りで、読み込み（`load`）と処理中（`operation`）を分ける。

## 一時コピーで動かす理由

- 里々は、アンロードのたびに `satori_savedata.txt`（と 1 世代前の `satori_savebackup.txt`。暗号化が有効なら `.sat`）を、ゴーストのフォルダに書く。ツールが本物のフォルダで動かすと、作者のセーブデータが変わってしまう。YAYA 版は `yaya_variable.cfg` を退避して戻していたが、里々は書くファイルが多く（`.tmp` を経由する）、SAORI が別のファイルを書くこともあるので、`ghost/master` を一時フォルダにコピーして動かし、終わったら消す（`New-DevkitSatoriSandbox`。`.git` と `profile` は写さない）。
- `ShioriEcho`（`Reference0…` を里々の文として展開して `Value` で返すデバッグ ID）は、`＄デバッグ＝有効` かつ `SecurityLevel: local` のときだけ動く（そうでなければ、有効にする方法を書いたメッセージが返る）。`enable_debug` の ID もあるが、1 回の tamac の実行では 1 リクエストしか送れず、`ShioriEcho` と組み合わせられない。そこで、`-Eval` と `check-dic -Run` は、**一時コピーの `satori_conf.txt` の `＊初期化` の最後の行として `＄デバッグ＝有効` を足す**（`Add-DevkitSatoriInitLines`）。`＊初期化` は読み込みのときに実行され、辞書より前に読まれる。`satori_conf.txt` には `＊初期化` と `＠SAORI` しか使われないが、`＄デバッグ` は変数（システム変数）なので、`＊初期化` に書けば効く。ゴーストの `＊初期化` が後で `＄デバッグ＝無効` にしても、最後の行なので上書きできる。
  - `satori_conf.txt` の文字コード（UTF-8 か Shift_JIS）と BOM、改行（CRLF か LF）は、そのまま保つ（`Read-DevkitTextFileAuto`。UTF-8 として厳密に読めれば UTF-8、だめなら Shift_JIS）。里々の判定（`satori_bootconf.txt`、BOM、全体が UTF-8 か）と同じ結果になる。
  - `＊初期化` の文が無ければ、末尾に足す。`satori_conf.txt` が無ければ、UTF-8 で作る。
  - 追加した行の文字は `tools/satori.json` にある（`tools/*.ps1` は ASCII だけで書くため）。
- 一時コピーのパスは、ログには出るので、表示するときに `ghost/master` に読み替え、さらにゴーストのルートからの相対パスにする（`ConvertTo-DevkitGhostText`）。
- 一時コピーの分、動きが遅くなる。ゴーストが数百 MB の音声などを持つときは、`ghost/master` の下に置く場所を見直す。

## 里々に備わっているもの（使わないもの）

- `SatolistEcho`（さとりすと用）、`enable_log`（`Reference0` が 0 以外ならログを有効にする）。`＄Log`、`＄RequestLog`、`＄OperationLog`、`＄ResponseLog` で出す内容を変えられるが、キットは既定のまま読む。
- `satorite.exe`（さとりて）は、里々の文を入力してさくらスクリプトへの変換結果を見る GUI ツール（同じ `ShioriEcho` の仕組み）。エージェントからは使いにくいので、`tools/shiori.ps1 -Eval` がその代わり。

## `.claude/settings.json` の許可

`-Eval` は任意の里々のコード（`load_saori`、`set_property`、SAORI の呼び出しなど）を実行できるが、辞書の関数を試すたびに確認が出ると使われなくなるため、許可リストに入れている。ファイルの書き込みや外部プログラムの実行をする文は中身を読んでから呼ぶことを、`AGENTS.md` と `docs/agents/workflows/check.md` に書く。
