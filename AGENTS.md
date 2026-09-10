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

## テスト指針

テストは `test_<area>.gd` という名前の独立した `SceneTree` Scriptです。挙動を変更するたびに対象機能のテストを更新し、その後に関連する回帰テストを実行します。`capture_<area>.gd` は、目視確認用の証跡が必要な場合に描画可能な環境でのみ使用します。ログは、Git管理対象外の `.godot/` 内に出力します。数値としてのカバレッジ目標は設けていないため、ルール、状態遷移、失敗経路、ターン順序の回帰を直接検証します。

## CommitとPull Requestの指針

履歴では、`feat: rebalance weapons and enemy encounters` のような簡潔なConventional Commit形式の件名を使用します。1つのcommitには、まとまりのある1つの変更だけを含めます。Pull Requestにはプレイヤーから見た変更内容と検証コマンドを記載し、関連issueがあればリンクします。UIや描画を変更した場合はスクリーンショットも添付します。`.godot/`、ローカルセーブデータ、認証情報、テストで生成した画像はcommitしません。
