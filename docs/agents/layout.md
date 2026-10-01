# ディレクトリ構成

サンプルゴースト（ポストと狛犬）から作ったゴーストの標準的な構成。このゴーストで違うところは `GHOST.md` に書く。

| パス | 内容 |
|---|---|
| `GHOST.md` | **このゴーストに固有の情報**（キャラクター、サーフェス、ライセンス、辞書の構成） |
| `readme.txt` | 原作者（櫛ヶ浜やぎ）の readme。元の文面のまま残す（配布物に入る） |
| `ghost/master/descript.txt` | ゴーストの基本情報（名前、作者、`shiori,satori.dll`、`charset,UTF-8`） |
| `ghost/master/satori_conf.txt` | 里々の初期設定。**`＊初期化`（システム変数の初期値）と `＠SAORI`（SAORI の登録）だけが有効** |
| `ghost/master/dic*.txt` | **ゴーストの辞書本体。主に編集するのはここ**。`dic` で始まり `.txt` で終わるファイルがファイル名の順にすべて読まれる（`dic01_Base.txt` … `dic10_SAORI_test.txt`。新しい `dic11_*.txt` も自動で読まれる） |
| `ghost/master/another/` | 別のキャラクターの辞書。`＄辞書フォルダ` で指定したときだけ読まれる |
| `ghost/master/replace.txt` / `replace_after.txt` | 辞書の読み込み時の置換 / 応答を返す直前の置換（`置換前<タブ>置換後`） |
| `ghost/master/satori.dll` | SHIORI 本体（Unicode 版で、ssu を内蔵している）。`tools/update-satori.ps1` 以外で差し替えない。旧版のゴーストには `saori/ssu.dll` が残っていることもある（`docs/agents/workflows/update-satori.md`） |
| `ghost/master/satori_license.txt` | `satori.dll` のライセンス。`satori.dll` を同梱する限り残す |
| `ghost/master/satorite.exe` `れしば.exe` ほか | 里々の補助ツール（さとりて、ログ受信ツール）と説明文書。**編集しない**。`satorite.exe` の更新は `tools/update-satori.ps1` で行う |
| `ghost/master/saori/` | SAORI の DLL（`＠SAORI` で登録する）。ssu は内蔵なので要らない |
| `shell/master/surfaces.txt` | サーフェス（表情、アニメーション、当たり判定）の定義 |
| `shell/master/descript.txt` | シェルの情報、メニューや吹き出し位置の設定 |
| `install.txt` | インストール設定（名前、インストール先フォルダ名、`refreshundeletemask`） |
| `.narignore` / `.updateignore` | nar / ネットワーク更新から除外するファイル。書き方は `.gitignore` と同じで、`include:ファイル名` で別のファイルを取り込める（パスはその行を書いたファイルのフォルダからの相対。取り込んだ先でも `include:` を書け、3 段まで）。キット用の除外は `tools/devkit.narignore` を取り込んでいる。SSP が使い（`tools/build-nar.ps1` も SSP に作らせる。`-ListOnly` と `-Builtin` では `.narignore` を SSP と同じように自分で解釈する）、どちらもルートに置いたものだけを読む（サブフォルダに置いても効かない）。古い形式の `developer_options.txt` は、併用すると両方が処理されて紛らわしいので作らない |
| `delete.txt` | ネットワーク更新のときに削除するファイル（あるとき） |
| `tools/` | 開発用スクリプト（一覧は `docs/agents/commands.md`） |
| `DEVKIT-GUIDE.md` | 開発キットの使い方（作者向け）。キットについて作者に説明するときは、ここを案内する |
| `docs/agents/` | エージェント向けの資料（一覧は `AGENTS.md` の「資料」）と、`workflows/` の作業手順書 |
| `CLAUDE.md`, `.claude/`, `.mcp.json` | Claude Code 用の設定（編集後の自動チェックと起動時の診断、調査用サブエージェント、仕様検索 MCP） |
| `.github/workflows/auto_check.yml` | push ごとに辞書チェック（tamacs）する |

実行時に作られるもの（編集もコミットもしない）: `ghost/master/satori_savedata.txt` と `satori_savebackup.txt`（変数の保存先。ゴーストの終了時に里々が書く。暗号化を有効にしたときは `.sat`）、`ghost/master/profile/`、`shell/master/profile/`、`tools/bin/`（ビルドした tamacs.exe と、ダウンロードしたツール）、`tools/local.json`（各自の設定）、`build/`。

`tools/check-dic.ps1` と `tools/shiori.ps1` は、`ghost/master` の一時コピーで里々を動かすので、実行してもこのフォルダに `satori_savedata.txt` などは残らない。
