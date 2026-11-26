# 既存リソースの取り込み

既存リソースの移行は急がない。新しいプロジェクトは最初から platform 経由で作り、既存のものは少しずつ寄せる。

## 最初にやること: 既存トークンの権限の洗い出し

既存プロジェクトのトークンの中に、トークンを作れる権限を持つものがないか確認する。あれば、その役割を platform に移してからトークンを作り直す（理由は [decisions](decisions.md#10-プロジェクト同士の-r2-の分離は諦める)）。

探す権限:

- `API Tokens Edit`（User）、`Account API Tokens Edit`: トークンを作れる
- メンバー管理、アカウント設定の編集: 権限を広げる抜け道になる
- `Workers R2 Storage Write` / `Read`: R2 の Admin 権限。持っていてもよいが、どのプロジェクトが持っているかは把握しておく

一覧は、`API Tokens Read` だけを持つ読み取り専用トークンで、トークン一覧の API（`/user/tokens` と `/accounts/{account_id}/tokens`）を呼べばポリシーごと取得できる。

## 優先順位

1. 各プロジェクトの tfstate 用バケット（今は手動で作ったもの）
2. プロジェクト用のトークン
3. GitHub リポジトリ
4. ゾーン・DNS、Access の共有部分

## ケース別の手順

### 手動で作ったリソース（Terraform 管理外）

例: 各プロジェクトの tfstate 用バケット、手動で作ったトークン

1. platform に `import` ブロックを書く
2. `terraform plan -generate-config-out=generated.tf` で HCL の下書きを作る
3. 下書きを整理してモジュールに組み込み、plan が「No changes」になるまで合わせる

トークンは import しても値が取れないことがあるので、platform で作り直して古いものを手動で削除する方が早い場合もある。

### すでにプロジェクト側の Terraform で管理しているリソース

state をまたいで移すので、2つの PR に分けて行う。

1. **platform 側**: `import` ブロックで取り込む PR を作り、plan が「No changes」であることを確認してマージする
2. **プロジェクト側**: 該当リソースを `removed` ブロックで state から外す（削除はしない）

```hcl
removed {
  from = cloudflare_r2_bucket.example
  lifecycle {
    destroy = false
  }
}
```

順番を逆にすると、どちらの管理下にもない期間ができる。順番を守れば、一時的に両方で管理している状態になるだけで、実害はない。

### 既存の GitHub リポジトリ

`import` ブロックにリポジトリ名を書いて取り込む。設定の差分が plan に出るので、それを見ながらコードを合わせる。`archive_on_destroy = true` と `prevent_destroy` は取り込んだ時点で付ける。
