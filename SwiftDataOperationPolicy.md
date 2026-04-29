# SwiftData運用ルール

## 前提

MeMoは外部DBを持たず、SwiftDataとDocuments配下のファイル保存でユーザーデータを保持する。
そのため、アプリのアップデート時にユーザーデータを損失しないよう、保存モデルの変更は慎重に行う。

現在はリリース前のため、保存プロパティ名とアプリ上の意味がずれている箇所は、今のうちに整理する。
今回の方針では、`walletKcal` は `walletSteps` に変更し、保存名とアプリ上の意味を統一する。

## リリース前に実施してよい整理

- 保存プロパティ名を、今後も使い続ける正式名称に整える
- `kcal` など古い仕様由来の名称を、現在の仕様に合わせて `steps` へ修正する
- 互換性維持のためだけに残していた computed property やコメントを削除する
- 今後の運用ルールをコメントとして明文化する

## リリース後の禁止事項

リリース後、以下は原則禁止する。

- `@Model` の既存プロパティ名を変更する
- `@Model` の既存プロパティを削除する
- `@Model` の既存プロパティの型を変更する
- `.modelContainer(for:)` から既存モデルを外す
- Documents配下の保存ディレクトリ名やファイル名ルールを移行なしで変更する
- `Data` に保存しているJSON構造を、旧データが読めない形に変更する

## リリース後に許可される変更

比較的安全な変更は以下。

- Optionalプロパティの追加
- デフォルト値付きプロパティの追加
- computed property の追加
- helper method の追加
- 新規 `@Model` の追加

ただし、新規 `@Model` を追加する場合も、既存モデルは `.modelContainer(for:)` に残す。

## 命名変更したい場合の原則

リリース後に仕様上の名称を変えたい場合、保存プロパティ名は変更しない。
新しい意味・表示名は computed property や helper method で吸収する。

例：

```swift
// リリース後は保存プロパティ名を変えない
var savedOldName: Int

// 新しい意味は computed property で扱う
var newDisplayName: Int {
    get { savedOldName }
    set { savedOldName = newValue }
}
```

## Documents保存の注意

`TodayPhotoEntry` は SwiftData に `fileName` を保存し、実画像は `Documents/memories/` 配下に保存する。
そのため、以下を移行なしで変更しない。

- `memories` ディレクトリ名
- `fileName` の命名ルール
- 画像保存形式

保存先を変更する場合は、旧パスから新パスへコピーする移行処理を用意する。

## `Data` / JSON保存の注意

`ownedFoodCountsData`、`toiletPoopsData`、`stepEnjoyLogsData`、`routeData` など、`Data` にJSONを保存している箇所は、内部構造の変更にも注意する。

構造を変える場合は、以下のいずれかを行う。

- `version` を持たせて移行できるようにする
- `decodeIfPresent` を使い、古いデータでも読み込めるようにする
- 旧データを新データへ変換する移行処理を用意する

## リリース前チェックリスト

- [ ] `@Model` の保存プロパティ名が今後も使える名称になっている
- [ ] 不要な旧仕様名のコメントが残っていない
- [ ] `.modelContainer(for:)` の登録モデルが確定している
- [ ] Documents保存のディレクトリ名が確定している
- [ ] JSON保存している `Data` の構造が今後の拡張を考慮している
- [ ] リリース後に変更禁止の箇所へコメントが入っている
