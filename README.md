# wancare

## AdMob IDの切り替え（Debug/Release）

このプロジェクトでは、`xcconfig` ファイルを使ってビルド構成ごとに AdMob ID を切り替えます。

- `WanCare/Config/Debug.xcconfig`: Google公式のテストID
- `WanCare/Config/Release.xcconfig`: ローカル秘密設定を読み込み
- `WanCare/Config/AdMob.Secrets.local.xcconfig`: 本番ID（git管理対象外）

### 初回セットアップ

```bash
cp WanCare/Config/AdMob.Secrets.template.xcconfig WanCare/Config/AdMob.Secrets.local.xcconfig
```

次に、`WanCare/Config/AdMob.Secrets.local.xcconfig` を編集して本番IDを設定します。

- `ADMOB_APP_ID`
- `ADMOB_BANNER_AD_UNIT_ID`

これらは `Info.plist` 側で次のキーとして参照されます。

- `GADApplicationIdentifier = $(ADMOB_APP_ID)`
- `GADBannerAdUnitID = $(ADMOB_BANNER_AD_UNIT_ID)`

### Archive前のチェック（任意）

```bash
./scripts/validate_admob_release_config.sh
```
