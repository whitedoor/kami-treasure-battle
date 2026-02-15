# Railsアプリ（`rails/`）開発メモ

このリポジトリは、**開発はDocker Composeで起動**する想定です（Ruby/DBをローカルに入れなくても動くようにしています）。

## 起動（推奨: Docker Compose）

リポジトリ直下で:

```bash
docker compose up
```

初回は `web` コンテナ内で自動的に以下が実行されます:

- `bundle install`
- `bin/rails db:prepare`
- `bin/rails server -b 0.0.0.0 -p 3000`

ブラウザで `http://localhost:3000` を開いてください。

## 停止 / リセット

```bash
docker compose down
```

DB含めて初期化:

```bash
docker compose down -v
```

## Railsコマンド（例）

```bash
docker compose exec web bin/rails console
docker compose exec web bin/rails routes
docker compose exec web bin/rails db:migrate
```

## 任意: レシートアップロード（GCS）+ Gemini抽出

Railsの起動自体には不要ですが、`/receipts/new` を使う場合は環境変数が必要です。

- 例: `.env` を使う（リポジトリ直下）

```bash
cp .env.example .env
```

必要な値（`GCS_BUCKET` / `GEMINI_API_KEY` など）だけ埋めてから `docker compose up` してください。

## 任意: デフォルトじゃんけん画像（GCSへアップロード）

スターターカード（`gu/choki/pa`）のデフォルト画像は、GCS上の `<env>/card_defaults/janken/{gu,choki,pa}.png` を参照します。

ローカル（Docker Compose）でアップロードする例:

```bash
docker compose exec web bin/rails gcs:upload_janken_defaults
```

既に存在する場合も上書きしたいとき:

```bash
docker compose exec web env OVERWRITE=1 bin/rails gcs:upload_janken_defaults
```

既存ユーザーのスターターカードへ参照を付け直す（必要な場合）:

```bash
docker compose exec web bin/rails card:backfill_default_janken_artworks
```
