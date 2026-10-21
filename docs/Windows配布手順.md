# Windows配布手順

## 対象

Godot 4.7系で、このMVPを64ビット版Windows向けに書き出す手順です。ゲーム仕様、セーブ形式、ゲーム内データは変更しません。

登録済みの `Windows Desktop` プリセットは次の構成です。

- 出力先: `rogue-like-play/build/windows/RogueLike_play.exe`
- CPUアーキテクチャ: `x86_64`
- リソース: プロジェクトで利用する全リソース
- PCK: 実行ファイルへ埋め込まず、`RogueLike_play.pck` として分離
- コンソールウィンドウ: 表示しない
- コード署名: 無効

## 書き出し前の準備

1. Godot 4.7系で `rogue-like-play/project.godot` を開きます。
2. `Editor > Manage Export Templates...` を開き、使用中のGodotと同じバージョンの Export Templates をインストールします。
3. `Project > Export...` を開き、`Windows Desktop` プリセットが表示され、エラーがないことを確認します。
4. 書き出し前の確認として、F5で起動し、拠点画面が表示されることを確認します。

## Godotエディターから書き出す

1. `Project > Export...` を開きます。
2. 左側で `Windows Desktop` を選びます。
3. `Export Project` を選びます。
4. `Export With Debug` をオフにし、`build/windows/RogueLike_play.exe` へ書き出します。
5. `build/windows/` に最低限、次の2ファイルが生成されたことを確認します。

   - `RogueLike_play.exe`
   - `RogueLike_play.pck`

## コマンドラインから書き出す

Godotのエディター実行ファイルが `godot` として `PATH` に登録され、Export Templatesがインストール済みであることを前提にします。`rogue-like-play/` で次を実行します。

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --export-release "Windows Desktop" "build/windows/RogueLike_play.exe"
```

1つ目のコマンドはアセットのインポートとスクリプト・シーンの読み込み確認、2つ目はRelease実行ファイルの書き出しです。成功時は終了コードが `0` になり、`build/windows/` に `.exe` と `.pck` が生成されます。

## ライセンス通知を用意する

Windows版へ同梱する通知文書を、`rogue-like-play/`から次のコマンドで用意します。Godotを更新した場合は、`GODOT_COPYRIGHT.txt`のURLを使用するEngineバージョンと同じタグへ変更します。

```powershell
Copy-Item ..\THIRD_PARTY_NOTICES.md build\windows\THIRD_PARTY_NOTICES.md
Copy-Item ui\fonts\OFL.txt build\windows\SHIPPORI_MINCHO_OFL.txt
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/COPYRIGHT.txt" -OutFile "build\windows\GODOT_COPYRIGHT.txt"
```

`THIRD_PARTY_NOTICES.md`にはGodot EngineのMIT License、既定アイコンのCC BY 4.0表記と、見出しに使う書体しっぽり明朝の表記、`SHIPPORI_MINCHO_OFL.txt`には書体に同梱が義務づけられているSIL Open Font Licenseの全文、`GODOT_COPYRIGHT.txt`にはGodot Engineが含む第三者コンポーネントの著作権・ライセンス情報が記載されています。

## 配布物

`build/windows/` の次の5ファイルを同じフォルダーに置いたまま配布します。

- `RogueLike_play.exe`
- `RogueLike_play.pck`
- `THIRD_PARTY_NOTICES.md`
- `GODOT_COPYRIGHT.txt`
- `SHIPPORI_MINCHO_OFL.txt`

`.exe`と`.pck`の片方だけでは起動できません。配布時は5ファイルをZIPにまとめ、展開後に `RogueLike_play.exe` を起動してもらいます。`progress.json` などの保存データは配布物に含めません。

このMVP用プリセットはコード署名を行いません。そのため、別のPCではWindowsの警告やセキュリティ製品の確認が表示されることがあります。不特定多数への公開前には、配布元を明示し、必要に応じて正規のコード署名証明書を使う別のリリース工程を用意してください。署名用パスワードや証明書は `export_presets.cfg` に保存・コミットしません。

## 保存データの保存先

ゲームはGodotの `user://progress.json` を使用します。既定のWindows環境では次の場所です。

```text
%APPDATA%\Godot\app_userdata\RogueLike_play\progress.json
```

エクスプローラーのアドレス欄または `Win + R` に次を入力すると、保存フォルダーを直接開けます。

```text
%APPDATA%\Godot\app_userdata\RogueLike_play
```

同じフォルダーに次の関連ファイルが作られる場合があります。

- `progress.json`: 現在の保存データ
- `progress.json.bak`: 直前の正常な保存データ
- `progress.json.tmp`: 保存処理中の一時ファイル。通常は処理完了後に残りません
- `progress.json.unreadable-*`: 読み込めなかった保存データの退避ファイル
- `progress.json.v4`: ターン制版（保存形式version 1〜4）の保存データを読み込んだときに残す元のファイル。ゲームはこのファイルを読まないため、旧版に戻す場合の控えとして残ります
- `settings.cfg`: 音量・画面モード・画面の揺れ・操作の案内の設定

保存対象は、残響、永続強化の段階、挑んだラン数と踏破数、最深到達の層、出会った敵です（保存形式version 5）。ラン中のレベル、経験値、強化、HPは保存されません。保存するのは拠点での強化の購入、出撃の直前、ランの終了時だけで、ランの途中で終了した場合は、最後に保存した拠点の状態から再開します。

## 初回起動時の確認項目

配布用ZIPを新しいフォルダーへ展開し、可能なら開発に使っていないWindowsユーザーまたは別PCで確認します。

- [ ] `RogueLike_play.exe`、`RogueLike_play.pck`、`THIRD_PARTY_NOTICES.md`、`GODOT_COPYRIGHT.txt`が同じフォルダーにある
- [ ] `RogueLike_play.exe` をダブルクリックすると、余分なコンソール画面を出さずに起動する
- [ ] 1600×900のウィンドウで拠点のロビーが表示される
- [ ] 拠点下部に新規開始を示す保存メッセージが表示される
- [ ] 「出撃」から分岐マップへ進み、エリアを選んで戦闘を始められる
- [ ] WASDまたは矢印キーで移動し、左クリックで攻撃、Spaceで回避できる
- [ ] Escでメニューを開き、「ランを中断する」を確定すると、結果画面から拠点へ戻れる
- [ ] 結果画面または拠点下部に保存成功のメッセージが表示される
- [ ] ゲームを終了して再起動しても、確定済みの残響・永続強化・図鑑の記録が復元される
- [ ] `%APPDATA%\Godot\app_userdata\RogueLike_play\progress.json` が作成される
- [ ] `.exe` と `.pck` がある配布フォルダー内には保存データが作成されない

## 初回状態で再確認する方法

既存の進行状況を失わないよう、ゲームを終了してから保存フォルダー全体を任意のバックアップ先へコピーします。その後、元の `RogueLike_play` 保存フォルダーを一時的に別名へ変更して起動すると、新規状態を確認できます。

確認後はゲームを終了し、新しく作られた保存フォルダーを削除してから、退避したフォルダー名を `RogueLike_play` に戻します。破損調査時は `progress.json` だけを削除せず、まずフォルダー全体をバックアップしてください。

## リリース前の最終確認

- [ ] `Export With Debug` をオフにしたRelease書き出しである
- [ ] 書き出した`.exe`と`.pck`、ライセンス通知2ファイルを新しいフォルダーへコピーして起動できる
- [ ] `THIRD_PARTY_NOTICES.md`と、使用したGodotバージョンに対応する`GODOT_COPYRIGHT.txt`を確認できる
- [ ] 初回起動と再起動後の保存復元を確認した
- [ ] ZIP内に `.godot/`、テスト用ログ、テスト用JSON、個人の保存データが含まれていない
- [ ] 配布するZIPをWindows Defenderなどでスキャンした
- [ ] 公開範囲に応じて、未署名実行ファイルであることの案内またはコード署名を検討した
