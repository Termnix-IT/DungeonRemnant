# リポジトリガイドライン

## プロジェクト構成とモジュール分割

`rogue-like-play/` がGodot 4.7プロジェクトのルートです。ゲームを実行する際は、このディレクトリの `project.godot` を開きます。ゲームプレイコードは責務ごとに分けています。`actors/` はプレイヤーと敵の挙動、`combat/` は攻撃処理、`game/` は拠点・冒険のライフサイクル・セーブ・ターンの調整、`world/` はグリッド・ダンジョン生成・視界・レイアウトを担当します。Inventoryと進行処理は `items/` と `progression/` にあります。調整可能なバランス定義は `data/` 配下のGodot Resourceとして管理します。UIのSceneとScriptは `ui/`、自動テストと目視確認用Scriptは `tests/` に置きます。製品仕様と受け入れ確認は、リポジトリ直下の `docs/` にあります。

## ビルド・テスト・開発コマンド

Godotを `godot` コマンドとして利用できる状態で、`rogue-like-play/` から次のコマンドを実行します。

- `godot --editor --path .`: エディターでプロジェクトを開き、ローカル開発とF5によるプレイテストを行う。
- `godot --headless --path . --editor --import --quit`: アセットをimportし、ScriptとSceneを検証する。
- `python tools/run_tests.py`: `tests/test_*.gd` をすべて並列（既定は4件ずつ）で実行し、スイートごとの成否・所要時間・失敗した検査を表示する。`python tools/run_tests.py hub shop` のように名前を渡すと対象を絞り、`--skip playthrough` で除外できる。Godotは `--godot`、環境変数 `GODOT`、PATH上の `godot` の順に探す。ログは `.godot/test-logs/` に出し、終わらないスイートは `--timeout`（既定180秒）で失敗として打ち切る。
- `godot --headless --path . --log-file .godot/combat-tests.log --script res://tests/test_combat.gd`: 対象を絞ったテストスイートを1つ実行する。
- `godot --headless --path . --log-file .godot/playthrough-tests.log --script res://tests/test_playthrough.gd`: 1Fから10Fまでのゲームループ全体を検証する。
- `godot --headless --path . --log-file .godot/smoke-test.log --quit-after 5`: 短時間の起動確認を行う。

## コーディングスタイルと命名規則

GDScriptはUTF-8で記述し、インデントにはタブを使用します。ファイル、関数、signal、変数には `snake_case`、名前付きclassとResource型には `PascalCase`、定数には `UPPER_SNAKE_CASE` を使用します。Node、Resource、collection、signalの境界が明確になる場合は、型を明示します。調整可能なステータスは `.tres` ファイルに置き、`TurnManager`、`Run`、戦闘ルール、actor、ダンジョン状態という既存の責務分離を維持します。

## UI変更の指針

- UIの仕様・デザイン値・操作要件は `docs/MVP_SPEC.md` のUI記述を参照する。拠点の個別画面（出撃・装備・倉庫・ショップ・強化・設定）を変更するときは、同書の「個別画面のUI文法」に従う。AGENTS.mdには作業上の判断基準を置き、色・文字サイズ・余白の数値を二重管理しない。
- 外観は `rogue-like-play/ui/theme/dungeon_theme.tres` のTheme Type Variation・StyleBox・定数で管理する。画面ごとの色・フォントサイズ・StyleBox overrideや別Themeの追加を避ける。
- 拠点背景の明るさは `rogue-like-play/game/hub/hub.gd` の背景上の暗幕で、パネルの明るさと色相は共通Themeの `MainSurface`・`ItemSurface`・`ListBackground` で調整する。背景の暖かい光と、青みのない石墨色のパネルを分け、選択の金枠と本文の視認性を保つ。
- パネル構造には `HubUI`、アイテム一覧には `ItemCardList`、選択品の表示には `ItemVisual` / `ItemShowcase` / `ItemDetails` を優先して再利用する。ItemListの標準入力・検索・Tooltip・スクロールを維持し、表示を省略する場合も名前の全文を詳細とTooltipに残す。
- 配置はContainerを基本とする。現在の基準解像度は1600×900（16:9）、Stretchは `canvas_items`。1920×1080専用の固定配置を作らず、縮小時も詳細のスクロール・主要操作・Focus表示が収まるようにする。
- `rogue-like-play/参考アート/` を参照する変更では、ファイル名だけでなく画像内容を確認する。情報階層・比率・選択状態を実装へ翻訳し、参考画像をそのまま背景や一枚のUI素材として使用しない。
- UIの外観変更でゲームロジック・セーブ仕様・Item / Stage Dataを変更しない。現行データにないレアリティ・推奨Lv・報酬などを参考画像から捏造せず、空のPlaceholderも追加しない。
- Motionは `UIMotion` に集約する。色・枠線はThemeに残し、Containerの位置や最小サイズをTweenしない。競合するTweenの停止と非表示時のリセットを維持し、演出完了をゲーム処理から待たない。
- 取引・装備・倉庫移動・永久強化の成功演出は、保存まで成功した `Main.preparation_completed` を起点にする。選択と確定を分け、保存失敗時の復元、Disabled状態、マウス・キーボード・ゲームパッド操作を維持する。

## 第三者素材の採用

無料アセットなど、他者が権利を持つ画像・音声・フォントを採用するときは、次の基準をすべて満たすものに限る。このリポジトリは公開されており、素材ファイルを置くことは素材そのものの再配布になる。また、将来の販売の可能性を残しているため、後から差し替えが必要になる素材は最初から入れない。

- 受け入れるライセンスは、CC0、CC BY（3.0・4.0）、OGA-BY、CC BY-SA（3.0・4.0）とする。非商用（NC）、改変禁止（ND）、GPL・LGPLなどのソフトウェア向けコピーレフト、作者独自の利用規約、「個人利用のみ」、ライセンスの記載がないもの、出どころの分からないもの（市販ゲームから抜き出した素材など）は採用しない。
- ライセンスは、まとめサイトの表示ではなく、作者自身の配布ページの記載で確認する。素材パックの中でファイルごとにライセンスが異なる場合は、使うファイルごとに確認する。
- 素材は自作素材と混ぜず、画像・フォントは `rogue-like-play/art/third_party/<素材名>/`、音声は `rogue-like-play/audio/third_party/<素材名>/` に置く。同じフォルダーに、入手元URL・作者・ライセンス名とそのURL・入手日を書いた `SOURCE.txt` と、配布されていればライセンス文を置く。
- 色・大きさ・音量などを `tools/` のスクリプトで整えた加工品も、元素材と同じフォルダーに置き、元素材のライセンスに従う。CC BY-SAの素材の加工品は、CC BY-SAで公開する義務がある。
- 採用した素材は `THIRD_PARTY_NOTICES.md` に、使用ファイル、作者、入手元URL、ライセンス名とそのURL、改変の有無と内容を追記する。このファイルは配布物に同梱されるため（`docs/Windows配布手順.md`）、CC BYとCC BY-SAが求める表記を満たす。
- 絵の素材は、ドットの細かさ・視点・輪郭線・色調が既存の絵（48pxタイル、16px相当のドット絵の3倍）とそろうものを優先する。そろわないものは、加工スクリプトで整えるか、作画の参考にとどめる。

## テスト指針

テストは `test_<area>.gd` という名前の独立した `SceneTree` Scriptです。挙動を変更するたびに対象機能のテストを更新し、その後に関連する回帰テストを実行します。`capture_<area>.gd` は、目視確認用の証跡が必要な場合に描画可能な環境でのみ使用します。ログは、Git管理対象外の `.godot/` 内に出力します。拠点から冒険を始めるテストは `main.run_seed` を固定し、ダンジョンの生成と死亡時に失うアイテムを毎回同じにします。乱数で結果が変わる検査は、実行ごとに成否が揺れて本当の回帰と見分けられなくなるため、シードを固定するか乱数に依存しない条件で書きます。数値としてのカバレッジ目標は設けていないため、ルール、状態遷移、失敗経路、ターン順序の回帰を直接検証します。

- UI変更時は `tests/test_ui_theme.gd`、`tests/test_ui_layout.gd`、`tests/test_ui_motion.gd`、`tests/test_upgrade_ui.gd` を実行し、変更対象に応じて `tests/test_shop.gd`、`tests/test_preparation.gd`、`tests/test_save.gd` などを加える。以下のパス・コマンドはGodotプロジェクトルートを基準とする。
- 一覧や選択面の外観を変えた場合は `tests/test_ui_selection.gd` を実行し、描画可能な環境で `tests/capture_ui_selection.gd` のショップ・装備・倉庫の選択状態を確認する。
- 7画面の実描画・配置は `godot --path . --rendering-method gl_compatibility --log-file .godot/art-direction.log --script res://tests/capture_art_direction.gd` で確認する。1600×900・1280×720・1920×1080の画像を実際に見て、情報階層・選択状態・主要操作・文字切れを確認する。Headlessでの成功だけを見た目の検証としない。
- 入力やMotionを変更した場合は `tests/capture_ui_motion.gd`、その他は該当画面の `capture_*.gd` を描画可能な環境で実行する。実行できない検証は未確認として報告する。テストの操作手順を新UIへ合わせる際も、取引結果・状態復元などの検証を弱めない。

## CommitとPull Requestの指針

履歴では、`feat: rebalance weapons and enemy encounters` のような簡潔なConventional Commit形式の件名を使用します。1つのcommitには、まとまりのある1つの変更だけを含めます。Pull Requestにはプレイヤーから見た変更内容と検証コマンドを記載し、関連issueがあればリンクします。UIや描画を変更した場合はスクリーンショットも添付します。`.godot/`、ローカルセーブデータ、認証情報、テストで生成した画像はcommitしません。

作業が完了し、変更内容に応じた必要なテストが成功した場合は、依頼の都度確認せずに、作業用ブランチでのstage・commitから、デフォルトブランチの更新とpushまで進めてよい。必要なテストが失敗した、または実行できなかった場合は、その結果と理由を示してcommit前に確認する。変更前から失敗しているテストは、変更前のコミットでも同じ失敗になることを確かめたうえで報告に明記する。stageの際は対象の差分を確認し、既存の未追跡素材や他の作業者の変更、無関係な変更を含めない。
