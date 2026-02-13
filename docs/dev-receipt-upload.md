# 開発環境: レシート写真 → GCSアップロード（まず動くところまで）

目的: ブラウザで撮影/選択した画像を Rails が受け取り、GCS に `<env>/receipts/...` で保存できることを確認する。

## 1. GCSバケット準備

- バケットを作成（例: `ktb-uploads`）
- 作成したバケット名を環境変数 `GCS_BUCKET` に入れる

この実装は **GCSのオブジェクトキーに環境名プレフィックス** を付けます。

- 例（development）: `development/receipts/2026/02/13/<uuid>.jpg`

## 2. 認証（どちらか）

### A. ローカルMacでADC（推奨・簡単）

GCPのCLIでApplication Default Credentialsを作ります。

```bash
gcloud auth application-default login
```

※ `GCP_PROJECT_ID` は未設定でも動くことが多いですが、明示したい場合は設定してください。

### B. サービスアカウントキー（Docker等）

- サービスアカウントに「Storage Object Creator」相当の権限を付与
- JSONキーを作り、ローカルに配置
- `GOOGLE_APPLICATION_CREDENTIALS` にそのパスを設定

## 3. 環境変数

最低限:

```bash
export GCS_BUCKET="ktb-uploads"
```

任意（明示したい場合）:

```bash
export GCP_PROJECT_ID="your-gcp-project-id"
export GOOGLE_APPLICATION_CREDENTIALS="/absolute/path/to/key.json"
```

## 4. Rails起動と動作確認

このリポジトリは開発用に Docker（Ruby 3.4）を使う前提です（macOSのシステムRubyだとRails要件を満たさない可能性があります）。

`docker compose` で起動する場合、ホスト側の環境変数（または `.env`）を `web` コンテナへ渡す必要があります。
このリポジトリの `docker-compose.yml` は `GCS_BUCKET` などを参照するようになっているので、以下のどちらかで設定してください。

- `.env` を使う（おすすめ）:

```bash
cat > .env <<'EOF'
GCS_BUCKET=ktb-uploads
# 任意
# GCP_PROJECT_ID=your-gcp-project-id
# 例: rails/tmp にキーを置く場合（git管理外）
# GOOGLE_APPLICATION_CREDENTIALS=/app/tmp/gcp-key.json
EOF
```

- 端末で `export` してから起動する:

```bash
export GCS_BUCKET="ktb-uploads"
```

まず依存を入れます。

```bash
docker compose run --rm web bundle install
```

起動します（別ターミナル）。

```bash
docker compose up
```

ブラウザで以下を開きます（webが3000を公開）。

- `http://localhost:3000/receipts/new`

「写真を選ぶ / 撮る」から画像を選択（モバイルは撮影）すると自動でアップロードされ、結果の `gs://...` が表示されます。

## 5. うまくいかない時の切り分け

- `ENV['GCS_BUCKET'] is not set` が出る: `GCS_BUCKET` を設定
- `GCS bucket not found` が出る: バケット名/プロジェクトを確認
- 認可エラー: ADCログインやサービスアカウント権限を確認（オブジェクト作成権限が必要）

## 6. Cloud Runへ（手元から）毎回同じ手順でデプロイする

Apple Silicon（M1/M2等）から `linux/amd64` をローカルでビルドすると、QEMU起因で失敗することがあります。
そのため、**ビルドはCloud Buildに任せる**のが安定です。

リポジトリには `rails/bin/deploy_cloud_run` を用意してあります（Cloud Buildでビルド→Cloud Runをimage更新）。

```bash
cd rails
bin/deploy_cloud_run
```

必要に応じて以下の環境変数で上書きできます。

- `PROJECT`（例: `kamitreasurebattle`）
- `REGION`（例: `asia-northeast1`）
- `SERVICE`（例: `kami-treasure-battle`）
- `AR_REPO`（例: `backend`）
- `IMAGE_NAME`（例: `kami-treasure-battle`）

