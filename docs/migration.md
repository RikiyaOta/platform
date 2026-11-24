# 既存リソースの取り込み

既存リソースの移行は急がない。新しいプロジェクトは最初から platform 経由で作り、既存のものは少しずつ寄せる。

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
