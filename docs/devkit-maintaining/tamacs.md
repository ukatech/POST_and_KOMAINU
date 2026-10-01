# tamacs と一時コピー、tamacsw

tamacs は、SHIORI の dll を SSP なしで読み込むツール。伺かのログ受信ツール tama のコンソール版 tamac（[YAYA-shiori/tama](https://github.com/YAYA-shiori/tama)）を C# に移したもので、ソース `tools/lib/tamacs.cs` は YAYA 版のキット（konnoyayame）と同じファイル。`tools/check-dic.ps1` と `tools/shiori.ps1` はこれで里々を動かしている。

## ビルド

- `tools/lib/common.ps1` の `Get-DevkitTamacs` が、使うときにビルドする（`tools/setup.ps1` も呼ぶ）。Windows に入っている .NET Framework 4 の `csc.exe` で、`/platform:x86` の exe にする（`satori.dll` は 32bit）。出力は `tools/bin/tamacs-<ソースの SHA256 の先頭 16 桁>.exe` で、ソースが変わると作り直し、古いものを消す。
- C# 5 までしか使えない。ASCII 文字だけで書き、全角の文字は C# の Unicode エスケープ（バックスラッシュ、`u`、16 進 4 桁）で書く。エージェントのツールによっては、書いたエスケープが本物の文字に変わってしまうので、書いたあとで ASCII だけか確かめる。
- ビルドの詳細と tamac との違いは、konnoyayame の `docs/devkit-maintaining/tamacs.md` にある。

## tamacs.exe の使い方（Mc201-10 の `satori.dll` で確認）

- ログは `Set_loghandler` だけで受け取る。里々は Mc201-10 からこれを持つ（YAYA と同じ型。最初に文字コードの通知 `E_UTF8` を送り、行の末尾に LF を付け、id は常に 0）。持っていない `satori.dll` では、`load` を呼ばずに終了コード 3 で終わる。`tools/doctor.ps1` の `satori-loghandler` は、dll のエクスポート名に `Set_loghandler` があるかで見分ける（`Test-DevkitSatoriLogHandler`）。
  - tamac は、メッセージ専用ウィンドウを作って `logsend(hwnd)` で渡し、`WM_COPYDATA` でログを受け取っていた。里々は、`Set_loghandler` が設定されていればウィンドウには送らない。
- `tamacs.exe <satori.dll のフルパス>` だけなら、読み込んで、解放するだけ（ログを出す）。`-r` を付けると、標準入力を EOF まで読んでリクエストにし（改行を CRLF にそろえ、終わりの空行を足し、先頭の BOM を外す）、応答を標準出力に出す。リクエストは UTF-8 で送る。
- **ログの出力先が違う**: `-r` なし → ログは標準出力、標準エラー出力には `[ERROR]` などのログ種別付きの行だけ。`-r` あり → ログはすべて標準エラー出力（`[ERROR]` の行も混ざる）、標準出力は応答だけ。`tools/lib/satori.ps1` の `Invoke-DevkitTamacs` が、どちらも `Log` にまとめて返す。
- dll は絶対パスで渡し、作業フォルダも `ghost/master`（の一時コピー）にする。
- 1 回に送れるリクエストは 1 つだけ。
- 終了コード: 0 / 1（dll が読めない、`load` が失敗した、空のリクエスト、空の応答）/ 2（`[ERROR]` などが 1 つでもあった。応答は出る）/ 3（`Set_loghandler` が無い）。**里々の通常のログの行のエラー（`SAORI読み込み中にエラーが発生…`、`（名前） not found.` など）は終了コードに反映されない**ので、ログを読んで調べる。
- 環境変数 `GITHUB_ACTIONS` があると `--ci` の出力に切り替わる（`::error file=,line=0,…` になり、位置が入らない）。`Invoke-DevkitTamacs` は子プロセスに `GITHUB_ACTIONS` を渡さず、注釈は `check-dic.ps1 -Ci` が自分で作る。
- tamac は毎回 `[tamac] Interface "CI_check_failed" not found` を出していたが、tamacs は `--ci` のときだけ出す。`[tamacs]` で始まる行は、`Get-DevkitSatoriDiagnostics` がエラーとして扱う。
- tamac 1.0.3.25 は、4096 バイトを超えるリクエストで、標準入力の読み取りの区切りにかかった日本語の文字を壊した（1.0.3.26 で直った）。tamacs は標準入力をすべて読んでから変換するので起こらない。`tools/check-dic.ps1 -Run` は、1 回の実行を短く保つため、今も 3800 バイト以内に分けて実行している。

## tamacsw.exe（ログ受信ウインドウ）

- `tamacsw.cs` と `common.ps1` のビルド関数（`Get-DevkitCsTool`、`Get-DevkitTamacsw`）は、tamacs と同じく YAYA 版のキット（konnoyayame）と共用する。起動用の `receiver.*` は里々版（このゴースト）だけに置く。YAYA のゴーストは tama をそのまま使う。
- SSP で動いている里々のログを表示する GUI。旧版の「れしば」の代わりで、ゴーストの `ghost/master/receiver.bat` → `receiver.ps1` から起動する（`receiver.*` はキットではなくゴーストのファイル）。ソースは `tools/lib/tamacsw.cs`、ビルドは `tools/lib/common.ps1` の `Get-DevkitTamacsw`（`/target:winexe`、dll を読まないので `/platform:anycpu`。tamacs と同じく `Get-DevkitCsTool` で `tools/bin/tamacsw-<hash>.exe` にする）。
- 里々（`satoriya/_/Sender.cpp`）は、読み込まれたあと最初にログを送るときに一度だけ、`FindWindow("れしば", "れしば")`、なければ `FindWindow("TamaWndClass", NULL)` で受信ウインドウを探す。見つからなければ、そのロードの間は探し直さない（`＄れしば送信＝有効` で探し直す）。だから、ゴーストより先に開いてもらう。
- `TamaWndClass` には、`dwData` にログ種別（tamacs の `E_*` と同じ値）、`lpData` に UTF-16 の 1 行（末尾に LF。`E_END` 以上は制御用で空）を `WM_COPYDATA` で送る。最初に `E_UTF8` を送る。送り側は `SendMessageTimeout`（5 秒）で待つので、tamacsw はウインドウプロシージャでは行をためるだけにして、100 ミリ秒ごとのタイマーで表示する。`E_END`（アンロード）は区切りの行として表示する。
- `FindWindow` はメッセージ専用ウィンドウを見つけないので、`TamaWndClass` は表示しない普通のトップレベルウィンドウとして作る（`RegisterClassExW` と `CreateWindowExW`）。同じクラスのウィンドウ（tama か別の tamacsw）がすでにあれば、起動しない。
- 表示は `RichTextBox`。**古いログを常に切り詰める**（100 万文字を超えたら、古い行から 75 万文字くらいまで消す。`MaxLength` も最大にしておく）。れしばは、エディットボックスの長さの限界に当たって更新が止まることがよくあった。一時停止中にためる行も 2 万件まで。

## 里々のログの出方（`Sender`）

- 里々のログは 2 種類。通常のログ（`GetSender().sender()`）はそのまま行として送られ、tamacs では種類なし（標準出力／`-r` では標準エラー出力）。エラー用（`GetSender().errsender()`）は `[ERROR]` 付きで送られる（`SenderConst::E_E`）。エラー用のうち、`＠SAORI` の誤り、`式が計算不能です`、辞書のカッコの誤りなどは、ログとは別に `ErrorLevel` / `ErrorDescription` ヘッダとしても返せる（SSP が `NOTIFY capability` で `response.errorlevel` を通知したときだけ。tamacs は通知しない）。`response.errorlevel` に対応していないベースウェアでは、エラーがダイアログボックスで出る（`error_buf::flush`）。
- **Mc201-5 の不具合**: `satori::endl`（エラー用の行末）が、VC6 のストリームで文字として出力されず、数字の `1057598`（`'\n'` の 10 と `0xE0FE` の 57598 を並べたものと読める）になる。このため、エラー用の行は `[ERROR]` として送られるのが遅れ、後ろの本物の改行が来た時点でまとめて 1 行になって出る（`… プラグインが存在しません。1057598bar: 設定ファイルの書式が正しくありません。1057598…`）。改行が来なければ、まったく出ない。`tools/satori.json` の `flushMarkArtifact` で、この文字列で分け直している。**エラー用のメッセージが見えないことがあるので、通常のログの行（`SAORI読み込み中にエラーが発生: …` など）からも拾っている**。
  - satoriya-shiori のソースでは `satori::endl` を `put()` で書くように直した（Mc201-5 の次の版から）。直った版では、エラー用の行がその場で `[ERROR]` として届き、`calc` の計算エラーなどで応答に `ErrorLevel: critical` が付く。tamacs は Mc201-10 以降しか動かさないので、回避のコードはもう効かないが、害はないので残している。
- ログには、辞書を読み込んだあとの `＊OnSatoriLoad` などの実行と、リクエストごとの `--- Request ---` / `--- Operation ---` / `--- Response ---` の区切りが並ぶ。`Get-DevkitSatoriDiagnostics` は、これらの区切りで、読み込み（`load`）と処理中（`operation`）を分ける。

## 一時コピーで動かす理由

- 里々は、アンロードのたびに `satori_savedata.txt`（と 1 世代前の `satori_savebackup.txt`。暗号化が有効なら `.sat`）を、ゴーストのフォルダに書く。ツールが本物のフォルダで動かすと、作者のセーブデータが変わってしまう。YAYA 版は `yaya_variable.cfg` を退避して戻していたが、里々は書くファイルが多く（`.tmp` を経由する）、SAORI が別のファイルを書くこともあるので、`ghost/master` を一時フォルダにコピーして動かし、終わったら消す（`New-DevkitSatoriSandbox`。`.git` と `profile` は写さない）。
- `ShioriEcho`（`Reference0…` を里々の文として展開して `Value` で返すデバッグ ID）は、`＄デバッグ＝有効` かつ `SecurityLevel: local` のときだけ動く（そうでなければ、有効にする方法を書いたメッセージが返る）。`enable_debug` の ID もあるが、1 回の tamacs の実行では 1 リクエストしか送れず、`ShioriEcho` と組み合わせられない。そこで、`-Eval` と `check-dic -Run` は、**一時コピーの `satori_conf.txt` の `＊初期化` の最後の行として `＄デバッグ＝有効` を足す**（`Add-DevkitSatoriInitLines`）。`＊初期化` は読み込みのときに実行され、辞書より前に読まれる。`satori_conf.txt` には `＊初期化` と `＠SAORI` しか使われないが、`＄デバッグ` は変数（システム変数）なので、`＊初期化` に書けば効く。ゴーストの `＊初期化` が後で `＄デバッグ＝無効` にしても、最後の行なので上書きできる。
  - `satori_conf.txt` の文字コード（UTF-8 か Shift_JIS）と BOM、改行（CRLF か LF）は、そのまま保つ（`Read-DevkitTextFileAuto` と `Write-DevkitTextFileAuto`。UTF-8 として厳密に読めれば UTF-8、だめなら Shift_JIS）。里々の判定（`satori_bootconf.txt`、BOM、全体が UTF-8 か）と同じ結果になる。
  - `＊初期化` の文が無ければ、末尾に足す。`satori_conf.txt` が無ければ、UTF-8 で作る。
  - 追加した行の文字は `tools/satori.json` にある（`tools/*.ps1` は ASCII だけで書くため）。
- 一時コピーのパスは、ログには出るので、表示するときに `ghost/master` に読み替え、さらにゴーストのルートからの相対パスにする（`ConvertTo-DevkitGhostText`）。
- 一時コピーの分、動きが遅くなる。ゴーストが数百 MB の音声などを持つときは、`ghost/master` の下に置く場所を見直す。

## 里々に備わっているもの（使わないもの）

- `SatolistEcho`（さとりすと用）、`enable_log`（`Reference0` が 0 以外ならログを有効にする）。`＄Log`、`＄RequestLog`、`＄OperationLog`、`＄ResponseLog` で出す内容を変えられるが、キットは既定のまま読む。
- `satorite.exe`（さとりて）は、里々の文を入力してさくらスクリプトへの変換結果を見る GUI ツール（同じ `ShioriEcho` の仕組み）。エージェントからは使いにくいので、`tools/shiori.ps1 -Eval` がその代わり。

## `.claude/settings.json` の許可

`-Eval` は任意の里々のコード（`load_saori`、`set_property`、SAORI の呼び出しなど）を実行できるが、辞書の関数を試すたびに確認が出ると使われなくなるため、許可リストに入れている。ファイルの書き込みや外部プログラムの実行をする文は中身を読んでから呼ぶことを、`AGENTS.md` と `docs/agents/workflows/check.md` に書く。
