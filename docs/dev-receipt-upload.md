# 開発環境: レシート写真 → GCSアップロード → Gemini APIで抽出（まず動くところまで）

目的: ブラウザで撮影/選択した画像を Rails が受け取り、GCS に `<env>/receipts/...` で保存し、さらに Gemini API へ画像を送って抽出結果（JSON）を受け取れることを確認する。

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

Docker Compose を使う場合:
- `docker-compose.yml` は `~/.config/gcloud` を `web` コンテナへ read-only でマウントするため、ADCを作っておくとそのままコンテナ内からVertex AIを呼べます。
- もし過去に「ADCファイルがディレクトリとして作られてしまった」場合は、`~/.config/gcloud/application_default_credentials.json` が **ファイル** になっているか確認してください。

### B. サービスアカウントキー（Docker等）

- サービスアカウントに「Storage Object Creator」相当の権限を付与
- JSONキーを作り、ローカルに配置
- `GOOGLE_APPLICATION_CREDENTIALS` にそのパスを設定

## 3. 環境変数

最低限:

```bash
export GCS_BUCKET="ktb-uploads"
export GEMINI_API_KEY="your-gemini-api-key"
```

任意（明示したい場合）:

```bash
export GCP_PROJECT_ID="your-gcp-project-id"
export GOOGLE_APPLICATION_CREDENTIALS="/absolute/path/to/key.json"
# 任意（モデルを変えたい場合）
# export GEMINI_MODEL="gemini-2.0-flash-001"
```

## 3.1 Gemini APIの有効化（GCP側で未設定なら）

GCP側でまだ有効化していない場合、以下を行ってください（どちらか）。

- **A. Google Cloud で Gemini API（Generative Language API）を有効化してAPIキー発行**
  - Cloud Console で対象プロジェクトを選択
  - 「APIとサービス」から **Gemini API / Generative Language API** を有効化
  - 「認証情報」→ **APIキー** を作成し、`GEMINI_API_KEY` に設定
  - 可能ならAPIキーに **アプリ制限/キー制限**（参照元やAPI制限）を設定

- **B. Google AI StudioでAPIキー発行（同じキーで動くことが多い）**
  - Gemini API のAPIキーを発行し、`GEMINI_API_KEY` に設定

※ どちらの経路でも、最終的にサーバから `https://generativelanguage.googleapis.com/` へ到達できれば動きます（Cloud Runは通常OK）。

## 4. Rails起動と動作確認

このリポジトリは開発用に Docker（Ruby 3.4）を使う前提です（macOSのシステムRubyだとRails要件を満たさない可能性があります）。

`docker compose` で起動する場合、ホスト側の環境変数（または `.env`）を `web` コンテナへ渡す必要があります。
このリポジトリの `docker-compose.yml` は `GCS_BUCKET` などを参照するようになっているので、以下のどちらかで設定してください。

- `.env` を使う（おすすめ）:

```bash
cp .env.example .env
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

「写真を選ぶ / 撮る」から画像を選択（モバイルは撮影）し「アップロード開始」を押すと、GCSへ保存 → Gemini APIで抽出が走り、結果（アップロード情報 + 抽出JSON）が画面に表示されます。

## 5. うまくいかない時の切り分け

- `ENV['GCS_BUCKET'] is not set` が出る: `GCS_BUCKET` を設定
- `ENV['GEMINI_API_KEY'] is not set` が出る: `GEMINI_API_KEY` を設定
- `GCS bucket not found` が出る: バケット名/プロジェクトを確認
- 認可エラー: ADCログインやサービスアカウント権限を確認（オブジェクト作成権限が必要）
- Gemini APIの 4xx/5xx: APIの有効化、APIキー、ネットワーク到達性、モデル名（`GEMINI_MODEL`）を確認

## 6. Cloud Runへ（手元から）毎回同じ手順でデプロイする

Apple Silicon（M1/M2等）から `linux/amd64` をローカルでビルドすると、QEMU起因で失敗することがあります。
そのため、**ビルドはCloud Buildに任せる**のが安定です。

リポジトリには `rails/bin/deploy_cloud_run` を用意してあります（Cloud Buildでビルド→Cloud Runをimage更新）。
Cloud Build側では `cloudbuild.yaml` で `--cache-from` を使ってレイヤーキャッシュを効かせているため、2回目以降が速くなります。

```bash
./rails/bin/deploy_cloud_run
```

重要: Cloud Runでも `GCS_BUCKET` は必須です（レシートアップロード先）。

```bash
export GCS_BUCKET="your-bucket-name"
./rails/bin/deploy_cloud_run
```

このスクリプトは本番向けに以下も自動で行います:

- Gemini API / Secret Manager / API Keys API の **有効化**
- Gemini APIの **APIキー発行**（`GEMINI_API_KEY` が未指定の場合）
- APIキーを **Secret Managerに保存**し、Cloud Runへ **Secretとして注入**
- `GEMINI_MODEL` をCloud Runの環境変数に設定

任意で上書きしたい場合:

```bash
# 既存のAPIキーを使う（自動発行しない）
export GEMINI_API_KEY="your-existing-key"

# モデル名を指定
export GEMINI_MODEL="gemini-2.0-flash"

# Secret名を変える（デフォルト: ${SERVICE}-gemini-api-key）
export GEMINI_API_KEY_SECRET="kami-treasure-battle-gemini-api-key"
```

必要に応じて以下の環境変数で上書きできます。

- `PROJECT`（例: `kamitreasurebattle`）
- `REGION`（例: `asia-northeast1`）
- `SERVICE`（例: `kami-treasure-battle`）
- `AR_REPO`（例: `backend`）
- `IMAGE_NAME`（例: `kami-treasure-battle`）

