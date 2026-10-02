# 里々サンプルゴースト ポストと狛犬 ＋ バイブコーディングツールキット（里々/Win版）

- original author : 櫛ヶ浜やぎ（Yagi Kushigahama。里々の作者。サンプルスクリプトとシェルの著作権は放棄されています）
- modernized by : ponapalt and contributors

「ポストと狛犬」は、SHIORI「里々（SATORI）」の作者・櫛ヶ浜やぎ氏が、里々の書き方を見せるために作ったサンプルゴーストです。この版は、いまの環境（UTF-8 の辞書、Unicode 版の `satori.dll`、SSP）で動くように直し、AI コーディングエージェントで開発するための「里々バイブコーディングツールキット」を加えたものです。里々の辞書を書く練習台にも、自分のゴーストの土台にもなります。

原作の説明（元の readme）は [readme.txt](readme.txt) にあります。

# 改造のしかた

ポストと狛犬は、SHIORI「里々」で自分のゴーストを作るための土台（サンプル）です。辞書を手で編集しても、AI コーディングエージェントに手伝ってもらってもかまいません。

## 手で編集する

- 辞書の本体は `ghost/master/` にある `dic*.txt`（`dic01_Base.txt` から `dic09_Timer.txt`）です。文字コードは UTF-8（BOM なし）です。里々は、`dic` で始まり `.txt` で終わるファイルをすべて読み込むので、`dic10_*.txt` のようにファイルを足すだけで増やせます。
- どのファイルに何が書いてあるか（ランダムトーク、起動・終了、マウスへの反応、メニューなど）、キャラクターと使えるサーフェス番号、トークの書き方の決まりは、[GHOST.md](GHOST.md) にまとめてあります。
- 里々の文法の要点とトークでよくある失敗は、[AGENTS.md](AGENTS.md) の「里々辞書の書き方の要点」と「トーク（さくらスクリプト）の書き方」にあります。AI エージェント向けの指示書ですが、人が読んでもわかるように書いてあります。
- 詳しい仕様は、次を見てください。
  - 里々の文法、イベント、関数: 里々の仕様書 satori-docs（https://ukatech.github.io/satori-docs/ ）
  - さくらスクリプト、SHIORI イベント、設定ファイル: UKADOC（https://ssp.shillest.net/ukadoc/manual/ ）
  - 里々のリリースとソース: https://github.com/ukatech/satoriya-shiori
- 辞書の文法にエラーがあっても、里々は起動します（その文が動かなかったり、読み込まれなかったりします）。Windows なら、同梱のスクリプトで辞書をチェックできます（最初の準備は [DEVKIT-GUIDE.md](DEVKIT-GUIDE.md) の「はじめかた」）。

  ```
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/check-dic.ps1 -Run
  ```

- SSP で動かしている間の里々のログ（（ ）が何に展開されたか、どのリクエストに何を返したか）は、`ghost/master/receiver.bat` で開くウインドウで見られます。ゴーストより先に開いておきます（使い方は `ghost/master/receiver.txt`。開発キットが入っているフォルダでだけ動きます）。
- シェル（`shell/master/`）は、辞書と同じく櫛ヶ浜やぎ氏が著作権を放棄したものです。自由に改変・再配布できます。
- 自分のゴーストとして配布するときに変えるところ（名前、作者、インストール先、ネットワーク更新の URL など）は、[docs/agents/standalone.md](docs/agents/standalone.md) と、`GHOST.md` の「テンプレートから独立させるときの追加項目」にチェックリストがあります。

## AI エージェントで開発する (Vibe Coding)

このゴーストには、AI コーディングエージェント（Claude Code、Codex、GitHub Copilot など）で開発するための開発キット「里々バイブコーディングツールキット」が入っています。
リポジトリを clone したフォルダでも、nar を SSP にインストールしたフォルダ（`<SSP>/ghost/POST_and_KOMAINU_V2/`）でも使えます。

開発キットは、Windows と Claude Code の組み合わせで作り、動作を確かめています。おすすめもこの組み合わせです。

- `tools/` のスクリプトの多くは、Windows でしか動きません（辞書やシェルのチェック、SSP での確認など。里々、SSP、チェック用ツールが Windows 用のため）。
- ほかのエージェントでも `AGENTS.md` に沿って使えますが、起動時の診断、仕様調査用のサブエージェントは、Claude Code でしか自動では動きません。

- [DEVKIT-GUIDE.md](DEVKIT-GUIDE.md) : 開発キットの使い方（あらかじめ入れておくもの、mac・Linux で使う場合、はじめかた、キットの更新、配布物にキットを含めるかどうか、別の里々ゴーストへの導入）
- [AGENTS.md](AGENTS.md) : エージェント向けの指示書（作業のルール、里々とさくらスクリプトの要点、依頼の言い回しと手順書の対応）。開発コマンド、構成、独立ゴーストにするときのチェックリスト、作業の手順書は `docs/agents/` にあります
- [GHOST.md](GHOST.md) : このゴーストに固有の情報（キャラクター、サーフェス、ライセンス、辞書の構成）。自分のゴーストを作ったら、その内容に書き直します

まずは [DEVKIT-GUIDE.md](DEVKIT-GUIDE.md) の「あらかじめ入れておくもの」を見て、このフォルダで AI エージェントを起動し、「セットアップして」と頼んでください。

ポストと狛犬を元にしていない、手元の里々ゴーストにも、開発キットだけを入れられます（辞書やシェルには手を加えません）。手順は [DEVKIT-GUIDE.md](DEVKIT-GUIDE.md#別の里々ゴーストに開発キットを入れる) の「別の里々ゴーストに開発キットを入れる」にあります。

# ライセンス

- サンプルスクリプト（辞書 `dic*.txt`、`satori_conf.txt`、`replace*.txt`）とシェル: 櫛ヶ浜やぎ氏が著作権を放棄しています（[readme.txt](readme.txt)）。ご自由にお使いください。
- `ghost/master/satori.dll`、`satorite.exe`: 里々の配布物です。`ghost/master/satori_license.txt` の条件（再配布・改変は自由、ただしライセンス文書を同梱すること、ライセンスを変えないこと、無保証）に従います。辞書、設定ファイル、SAORI、画像などは、このライセンスの対象外です。
- 開発キット（`tools/`、`docs/agents/`、`.claude/` など）: YAYA のテンプレートゴースト「紺野ややめ」（Public Domain / Unlicense）の開発キットを、里々向けに移植したものです。キットも同じく Public Domain（Unlicense）です。

詳しいライセンスの整理は、[GHOST.md](GHOST.md) の「ライセンス」にあります。
