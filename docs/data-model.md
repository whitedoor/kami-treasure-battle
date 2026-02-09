# Firestore データモデル案（MVP）

前提:Firebase Auth + Rails API(Cloud Run) + Firestore + Cloud Storage。

## 設計方針

- **マスタとユーザデータを分離**（`cards` はマスタ、所持はユーザ配下）
- **日次報酬はサーバで原子処理**（多重受取を防ぐ）
- **将来のオンライン対戦**に備え、バトルログは「入力」と「結果」を保持できる形にする

## コレクション一覧

### `users/{uid}`

- `uid`: string（Firebase Auth UID）
- `displayName`: string（任意）
- `characterHand`: `"rock" | "scissors" | "paper"`（作成時選択、後で変更可）
- `createdAt`: timestamp
- `updatedAt`: timestamp

サブコレクション:

#### `users/{uid}/ownedCards/{cardId}`

- `cardId`: string
- `owned`: true（存在=所持にしてもよい）
- `acquiredAt`: timestamp
- `source`: `"daily" | "starter" | "admin" | "other"`

> 将来「複数枚所持」にするなら `count: number` を追加。

#### `users/{uid}/loadout/current`

- `rockCardId`: string
- `scissorsCardId`: string
- `paperCardId`: string
- `totalAttack`: number（保存時にサーバで計算して保持）
- `updatedAt`: timestamp

#### `users/{uid}/dailyClaims/{yyyyMMdd}`

- `date`: string（`yyyyMMdd`、JST基準）
- `claimedAt`: timestamp
- `cardId`: string（付与したカード）
- `idempotencyKey`: string（任意: クライアント再送対策）

> ここを「その日の受取済みフラグ」として使う。存在チェック + トランザクションで多重受取を防ぐ。

### `cards/{cardId}`（カードマスタ）

- `cardId`: string
- `name`: string
- `hand`: `"rock" | "scissors" | "paper"`
- `attack`: number（整数）
- `rarity`: `"common" | "rare" | "epic" | "legendary"`（例）
- `imagePath`: string（Cloud Storageのパス or 公開URL）
- `active`: boolean（日次報酬の母集団に含めるか）
- `createdAt`: timestamp
- `updatedAt`: timestamp

### `battles/{battleId}`（任意: バトルログ）

CPU戦MVPでは保存しなくても成立しますが、分析や将来のオンライン化を見据えて残せる形です。

- `battleId`: string
- `uid`: string（プレイヤー）
- `mode`: `"cpu"`
- `seed`: number（任意: CPUのランダム再現用）
- `loadout`: object
  - `rockCardId`: string
  - `scissorsCardId`: string
  - `paperCardId`: string
- `turns`: array（任意: 入力ログ）
  - `playerHand`: `"rock" | "scissors" | "paper"`
  - `cpuHand`: `"rock" | "scissors" | "paper"`
  - `damageToCpu`: number
  - `damageToPlayer`: number
  - `multiplierApplied`: boolean
  - `ended`: boolean
- `result`: object
  - `winner`: `"player" | "cpu" | "draw"`
  - `playerHpFinal`: number
  - `cpuHpFinal`: number
- `createdAt`: timestamp

## 主要ユースケースと整合性（サーバ処理）

### 日次報酬付与（`POST /daily-claim`）

サーバ側（Rails）が以下を**Firestoreトランザクション**で行う想定:

1. `users/{uid}/dailyClaims/{today}` が存在するか確認（存在なら同じ結果を返す＝冪等）
2. 母集団 `cards(active=true)` から、`ownedCards` に存在しないカードを抽出
3. 付与カードを1枚決定し、`ownedCards/{cardId}` を作成
4. `dailyClaims/{today}` を作成（`cardId` と `claimedAt` を保存）

> 「揃うまで重複なし」は 2 を「未所持優先」にするだけで満たせる。母集団の定義やコンプリート後の扱いは後から差し替え可能。

### ロードアウト更新（`PUT /loadout`）

サーバ側で `cards` を参照して攻撃力合計を再計算し、`totalAttack<=100` を検証して保存。

## 将来のオンライン対戦を見据えた拡張

- `matches/{matchId}`（マッチング/対戦部屋）
- `matches/{matchId}/events/{eventId}`（イベントソーシング）
- 状態管理をFirestoreに置くか、Redis系（Memorystore）に置くかは、リアルタイム要求とコストで決定

