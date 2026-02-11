# kami-treasure-battle

## 開発環境（Docker Compose）

前提:
- Docker Desktop が起動していること
- 開発用Dockerfileは `Dockerfile.dev`（本番用は直下 `Dockerfile`）

### 起動

```bash
docker compose up
```

初回は以下が自動で実行されます:
- `bundle install`
- `bin/rails db:prepare`
- `bin/rails server -b 0.0.0.0 -p 3000`

ブラウザで `http://localhost:3000` にアクセスしてください。

### 停止

```bash
docker compose down
```

DBも含めて初期化したい場合:

```bash
docker compose down -v
```

### Railsコマンド実行例

```bash
docker compose exec web bin/rails console
docker compose exec web bin/rails routes
docker compose exec web bin/rails db:migrate
```

## 本番用Dockerイメージ（GCPへPushする前提）

本番用Dockerfileは直下 `Dockerfile` です（Railsアプリは `rails/` 配下をビルド時に取り込みます）。

### ローカルでビルド（動作確認用）

```bash
docker build -t kami-treasure-battle:local .
docker run --rm -p 8080:80 -e RAILS_MASTER_KEY=... kami-treasure-battle:local
```

### Artifact RegistryへPush（例）

```bash
PROJECT_ID="$(gcloud config get-value project)"
REGION="asia-northeast1"
REPO="backend"
IMAGE="kami-treasure-battle"
TAG="$(git rev-parse --short HEAD)"

gcloud auth configure-docker "${REGION}-docker.pkg.dev"
docker buildx build --platform linux/amd64 -t "${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/${IMAGE}:${TAG}" --push .
```

## ディレクトリ構成

- `docs/`: 要件・設計ドキュメント
- `rails/`: Railsアプリ本体（コンテナにマウントして開発）