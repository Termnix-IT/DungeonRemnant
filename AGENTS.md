# リポジトリガイドライン

## プロジェクト構成とモジュール分割

`rogue-like-play/` がGodot 4.6プロジェクトのルートです。ゲームを実行する際は、このディレクトリの `project.godot` を開きます。ゲームプレイコードは責務ごとに分けています。`actors/` はプレイヤーと敵の挙動、`combat/` は攻撃処理、`game/` は拠点・冒険のライフサイクル・セーブ・ターンの調整、`world/` はグリッド・ダンジョン生成・視界・レイアウトを担当します。Inventoryと進行処理は `items/` と `progression/` にあります。調整可能なバランス定義は `data/` 配下のGodot Resourceとして管理します。UIのSceneとScriptは `ui/`、自動テストと目視確認用Scriptは `tests/` に置きます。製品仕様と受け入れ確認は、リポジトリ直下の `docs/` にあります。

## ビルド・テスト・開発コマンド

Godotを `godot` コマンドとして利用できる状態で、`rogue-like-play/` から次のコマンドを実行します。

- `godot --editor --path .`: エディターでプロジェクトを開き、ローカル開発とF5によるプレイテストを行う。
- `godot --headless --path . --editor --import --quit`: アセットをimportし、ScriptとSceneを検証する。
- `godot --headless --path . --log-file .godot/combat-tests.log --script res://tests/test_combat.gd`: 対象を絞ったテストスイートを1つ実行する。
- `godot --headless --path . --log-file .godot/playthrough-tests.log --script res://tests/test_playthrough.gd`: 1Fから10Fまでのゲームループ全体を検証する。
- `godot --headless --path . --log-file .godot/smoke-test.log --quit-after 5`: 短時間の起動確認を行う。

## コーディングスタイルと命名規則

GDScriptはUTF-8で記述し、インデントにはタブを使用します。ファイル、関数、signal、変数には `snake_case`、名前付きclassとResource型には `PascalCase`、定数には `UPPER_SNAKE_CASE` を使用します。Node、Resource、collection、signalの境界が明確になる場合は、型を明示します。調整可能なステータスは `.tres` ファイルに置き、`TurnManager`、`Run`、戦闘ルール、actor、ダンジョン状態という既存の責務分離を維持します。

## UI変更の指針

- UIの仕様・デザイン値・操作要件は `docs/MVP_SPEC.md` のUI記述を参照する。AGENTS.mdには作業上の判断基準を置き、色・文字サイズ・余白の数値を二重管理しない。
- 外観は `rogue-like-play/ui/theme/dungeon_theme.tres` のTheme Type Variation・StyleBox・定数で管理する。画面ごとの色・フォントサイズ・StyleBox overrideや別Themeの追加を避ける。
- 拠点背景の明るさは `rogue-like-play/game/hub/hub.gd` の背景上の暗幕で、パネルの明るさと色相は共通Themeの `MainSurface`・`ItemSurface`・`ListBackground` で調整する。背景の暖かい光と、青みのない石墨色のパネルを分け、選択の金枠と本文の視認性を保つ。
- パネル構造には `HubUI`、アイテム一覧には `ItemCardList`、選択品の表示には `ItemVisual` / `ItemShowcase` / `ItemDetails` を優先して再利用する。ItemListの標準入力・検索・Tooltip・スクロールを維持し、表示を省略する場合も名前の全文を詳細とTooltipに残す。
- 配置はContainerを基本とする。現在の基準解像度は1440×900、Stretchは `canvas_items`。1920×1080専用の固定配置を作らず、縮小時も詳細のスクロール・主要操作・Focus表示が収まるようにする。
- `rogue-like-play/参考アート/` を参照する変更では、ファイル名だけでなく画像内容を確認する。情報階層・比率・選択状態を実装へ翻訳し、参考画像をそのまま背景や一枚のUI素材として使用しない。
- UIの外観変更でゲームロジック・セーブ仕様・Item / Stage Dataを変更しない。現行データにないレアリティ・推奨Lv・報酬などを参考画像から捏造せず、空のPlaceholderも追加しない。
- Motionは `UIMotion` に集約する。色・枠線はThemeに残し、Containerの位置や最小サイズをTweenしない。競合するTweenの停止と非表示時のリセットを維持し、演出完了をゲーム処理から待たない。
- 取引・装備・倉庫移動・永久強化の成功演出は、保存まで成功した `Main.preparation_completed` を起点にする。選択と確定を分け、保存失敗時の復元、Disabled状態、マウス・キーボード・ゲームパッド操作を維持する。

## テスト指針

テストは `test_<area>.gd` という名前の独立した `SceneTree` Scriptです。挙動を変更するたびに対象機能のテストを更新し、その後に関連する回帰テストを実行します。`capture_<area>.gd` は、目視確認用の証跡が必要な場合に描画可能な環境でのみ使用します。ログは、Git管理対象外の `.godot/` 内に出力します。数値としてのカバレッジ目標は設けていないため、ルール、状態遷移、失敗経路、ターン順序の回帰を直接検証します。

- UI変更時は `tests/test_ui_theme.gd`、`tests/test_ui_layout.gd`、`tests/test_ui_motion.gd`、`tests/test_upgrade_ui.gd` を実行し、変更対象に応じて `tests/test_shop.gd`、`tests/test_preparation.gd`、`tests/test_save.gd` などを加える。以下のパス・コマンドはGodotプロジェクトルートを基準とする。
- 一覧や選択面の外観を変えた場合は `tests/test_ui_selection.gd` を実行し、描画可能な環境で `tests/capture_ui_selection.gd` のショップ・装備・倉庫の選択状態を確認する。
- 7画面の実描画・配置は `godot --path . --rendering-method gl_compatibility --log-file .godot/art-direction.log --script res://tests/capture_art_direction.gd` で確認する。1440×900・1152×720・1920×1080の画像を実際に見て、情報階層・選択状態・主要操作・文字切れを確認する。Headlessでの成功だけを見た目の検証としない。
- 入力やMotionを変更した場合は `tests/capture_ui_motion.gd`、その他は該当画面の `capture_*.gd` を描画可能な環境で実行する。実行できない検証は未確認として報告する。テストの操作手順を新UIへ合わせる際も、取引結果・状態復元などの検証を弱めない。

## CommitとPull Requestの指針

履歴では、`feat: rebalance weapons and enemy encounters` のような簡潔なConventional Commit形式の件名を使用します。1つのcommitには、まとまりのある1つの変更だけを含めます。Pull Requestにはプレイヤーから見た変更内容と検証コマンドを記載し、関連issueがあればリンクします。UIや描画を変更した場合はスクリーンショットも添付します。`.godot/`、ローカルセーブデータ、認証情報、テストで生成した画像はcommitしません。

ユーザーから明示的に依頼されない限り、stage・commit・pushは行わない。依頼された場合も対象の差分を確認し、既存の未追跡素材や無関係な変更を一括で含めない。
