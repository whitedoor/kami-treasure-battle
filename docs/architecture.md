# アーキテクチャ（MVP + 将来オンライン拡張）

## MVP構成（CPU戦 + コレクション + 日次報酬）

ポイント:
- **フロント/バックはRailsに統一**（ERB + Hotwire/Turboを基本にする）
- **バトル進行はクライアント中心**（CPU戦なので低レイテンシで完結。必要な整合性はサーバ側で検証）
- **所持カード・日次報酬はサーバで管理**（不正/多重受取対策）
- **認証はDevise**（MVPはEmail/Password等。将来はOAuth追加可）

```mermaid
flowchart TB
  user[User] --> rails[Rails Web App]

  subgraph gcp [GCP]
    run[Rails on Cloud Run]
    db[(PostgreSQL / Cloud SQL)]
    gcs[Cloud Storage]
    sm[Secret Manager]
    log[Cloud Logging]
  end

  rails --> run
  run --> db
  run --> gcs
  run --> sm
  run --> log
```

## 主要データフロー

### サインイン〜プロフィール取得

```mermaid
sequenceDiagram
  participant Web as Browser
  participant Rails as Rails(Devise)
  participant DB as PostgreSQL

  Web->>Rails: Sign in (email/password)
  Rails->>DB: Create/read user session
  Rails->>DB: Read users (profile)
  Rails-->>Web: 200 (HTML/Turbo Stream)
```

### 日次報酬（揃うまで重複なし）

```mermaid
sequenceDiagram
  participant Web as Browser
  participant Rails as Rails
  participant DB as PostgreSQL

  Web->>Rails: POST /daily-claim
  Rails->>DB: BEGIN
  Rails->>DB: SELECT daily_claims(today) FOR UPDATE/unique
  alt alreadyClaimed
    Rails->>DB: SELECT existing claim
    Rails->>DB: COMMIT
    Rails-->>Web: 200 (claimed card)
  else notClaimed
    Rails->>DB: SELECT cards(active=true) EXCEPT owned_cards
    Rails->>DB: INSERT owned_cards(card_id, source=daily)
    Rails->>DB: INSERT daily_claims(today, card_id)
    Rails->>DB: COMMIT
    Rails-->>Web: 200 (new card)
  end
```

## 将来: オンライン対戦（リアルタイム）拡張案

オンライン化すると「ルーム状態の同期」「不正対策（サーバ権威）」「切断/再接続」が必要になります。
最初のMVP構成を壊さず足せる拡張として以下を想定します。

```mermaid
flowchart TB
  subgraph gcp [GCP]
    web[Rails Web App]
    battle[Battle Service]
    match[Matchmaking]
    db[(PostgreSQL / Cloud SQL)]
    redis[Memorystore(Redis)]
  end

  web -->|websocket/sse| battle
  web -->|api| match
  match --> db
  battle --> redis
  battle --> db
```

オンライン拡張で増える設計論点:
- **通信方式**: WebSocket / SSE / WebRTC（要件次第）
- **状態置き場**: DB（永続） + Redis（リアルタイム状態/ロック）
- **権威性**: サーバで手を受け取り、勝敗/ダメージ計算をサーバで確定

## 構成の補足（推奨のデプロイ形）

- **Rails（Web + API）**
  - **Cloud Run（コンテナ）** + Secret Manager + Cloud Logging
  - DBは **Cloud SQL(PostgreSQL)** を推奨
  - 画像は **Active Storage + Cloud Storage**（将来CDN追加も容易）

