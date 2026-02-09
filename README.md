# kami-treasure-battle

## 開発環境（Docker Compose）

前提:
- Docker Desktop が起動していること

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

## ディレクトリ構成

- `docs/`: 要件・設計ドキュメント
- `rails/`: Railsアプリ本体（コンテナにマウントして開発）