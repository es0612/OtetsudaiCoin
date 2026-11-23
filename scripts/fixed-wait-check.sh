#!/bin/bash
# unit テストの「固定時間の待ち」を検出する (#306 候補 #30 / #313)。
#
# ViewModel が `Task { }` で起こした処理の完了を `Task.sleep(0.1)` や
# `DispatchQueue.main.asyncAfter(0.1)` で待つテストは、CI の遅い runner で間に合わず
# 時々落ちた (#313: 11-15〜11-23 に 5 run)。完了は `waitUntil { 条件 }`
# (app/OtetsudaiCoinTests/Helpers/AsyncTestHelpers.swift) で待つ。
#
# 固定時間で待つ理由がある行 (「起きないこと」の確認、waitUntil 自身のポーリングなど) は、
# 同じ行に `// allow-fixed-wait: <理由>` を書くと許可される。理由が空なら違反のまま。
# コメントの中に書いてあるだけの言及は数えない (`//` より前のコードだけを見る)。
#
# 使い方: bash scripts/fixed-wait-check.sh [検査するディレクトリ ...]
#         (省略時は app/OtetsudaiCoinTests。UI テストの sleep は画面操作の待ちなので対象外)
# 終了コード: 0 = 違反なし / 1 = 違反あり / 2 = 使い方の誤り
# GITHUB_ACTIONS が設定されていると、違反ごとに ::error file=...,line=...:: の注記を出す。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 引数なしのときはリポのルートから相対パスで探す (GitHub の ::error file= はリポからの相対パスで
# PR の行に注記が付くため)。
if [[ $# -eq 0 ]]; then
  cd "$REPO_ROOT"
  set -- app/OtetsudaiCoinTests
fi

for dir in "$@"; do
  if [[ ! -d "$dir" ]]; then
    echo "error: ディレクトリがありません: $dir" >&2
    exit 2
  fi
done

files=()
while IFS= read -r f; do
  files+=("$f")
done < <(find "$@" -type f -name '*.swift' | LC_ALL=C sort)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "固定時間の待ちの検査: 対象の .swift ファイルが 0 件"
  exit 0
fi

# awk は POSIX の範囲だけを使う (CI の ubuntu は mawk、macOS は BSD awk)。
result="$(awk -v gha="${GITHUB_ACTIONS:-}" '
  BEGIN {
    pat = "Task\\.sleep|asyncAfter|Thread\\.sleep|usleep[ \t]*\\(|(^|[^.A-Za-z0-9_])sleep[ \t]*\\("
    violations = 0; allowed = 0
  }
  {
    code = $0
    i = index(code, "//")
    if (i > 0) code = substr(code, 1, i - 1)
    gsub(/func[ \t]+sleep/, "func _", code)  # sleep という名前の関数の宣言は数えない
    if (code !~ pat) next

    comment = (i > 0) ? substr($0, i) : ""
    j = index(comment, "allow-fixed-wait:")
    if (j > 0) {
      reason = substr(comment, j + length("allow-fixed-wait:"))
      gsub(/^[ \t]+|[ \t]+$/, "", reason)
      if (reason != "") { allowed++; next }
    }

    violations++
    text = $0
    gsub(/^[ \t]+/, "", text)
    printf "%s:%d: %s\n", FILENAME, FNR, text
    if (gha != "") {
      printf "::error file=%s,line=%d::固定時間の待ちです。完了は waitUntil { 条件 } で待ってください。固定時間が必要なら同じ行に // allow-fixed-wait: <理由> を書きます (#313)\n", FILENAME, FNR
    }
  }
  END { printf "SUMMARY %d %d\n", violations, allowed }
' "${files[@]}")"

summary="$(printf '%s\n' "$result" | tail -n 1)"
printf '%s\n' "$result" | sed '$d'
read -r _ violations allowed <<<"$summary"

echo "固定時間の待ちの検査: ${#files[@]} ファイル / 違反 ${violations} 件 / 許可 ${allowed} 件 (// allow-fixed-wait:)"
if [[ "$violations" -gt 0 ]]; then
  echo "→ 完了は waitUntil { 条件 } で待つ (Helpers/AsyncTestHelpers.swift)。固定時間が必要な行には // allow-fixed-wait: <理由> を書く"
  exit 1
fi
exit 0
