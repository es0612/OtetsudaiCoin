#!/usr/bin/env bash
#
# version-bump-check.sh
#
# project.pbxproj の MARKETING_VERSION / CURRENT_PROJECT_VERSION が
# 前回 git tag より増えていることを CI で検証する。
#
# ITMS-90186 / ITMS-90062 (App Store 公開済バージョンと同じバージョン番号で
# 再アップロードして reject される) の再発防止。
#
# 環境変数:
#   PR_TITLE   : Pull Request タイトル (release: / chore: bump で始まると enforce mode)
#   PR_LABELS  : Pull Request labels (JSON 配列。"release" ラベルがあると enforce mode)
#   PBXPROJ    : 検査対象 pbxproj (デフォルト: app/OtetsudaiCoin.xcodeproj/project.pbxproj)
#   BASE_REF   : 比較対象 ref (デフォルト: 直近の tag、無ければ origin/main)
#
# Exit code:
#   0: 問題なし (info / pass)
#   1: enforce mode で違反検出

set -euo pipefail

PBXPROJ="${PBXPROJ:-app/OtetsudaiCoin.xcodeproj/project.pbxproj}"
PR_TITLE="${PR_TITLE:-}"
PR_LABELS="${PR_LABELS:-[]}"

if [[ ! -f "$PBXPROJ" ]]; then
  echo "::error::pbxproj not found: $PBXPROJ"
  exit 1
fi

# ---- extract helpers ----

# 引数で渡された ref の pbxproj から MARKETING_VERSION のユニーク値を出力。
# ref が空の場合は working tree のファイルを読む。
extract_marketing_version() {
  local ref="${1:-}"
  if [[ -z "$ref" ]]; then
    grep -E "^[[:space:]]*MARKETING_VERSION = " "$PBXPROJ"
  else
    git show "${ref}:${PBXPROJ}" | grep -E "^[[:space:]]*MARKETING_VERSION = "
  fi | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/' | sort -u
}

extract_build_version() {
  local ref="${1:-}"
  if [[ -z "$ref" ]]; then
    grep -E "^[[:space:]]*CURRENT_PROJECT_VERSION = " "$PBXPROJ"
  else
    git show "${ref}:${PBXPROJ}" | grep -E "^[[:space:]]*CURRENT_PROJECT_VERSION = "
  fi | sed -E 's/.*CURRENT_PROJECT_VERSION = ([^;]+);.*/\1/' | sort -u
}

# semver-ish greater-than (a > b). sort -V を使った version sort で判定。
semver_gt() {
  local a="$1" b="$2"
  if [[ "$a" == "$b" ]]; then
    return 1
  fi
  local higher
  higher=$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -n 1)
  [[ "$higher" == "$a" ]]
}

# ---- determine base ref ----

if [[ -n "${BASE_REF:-}" ]]; then
  base_ref="$BASE_REF"
elif base_ref=$(git describe --tags --abbrev=0 2>/dev/null); then
  :
else
  base_ref="origin/main"
fi

echo "Comparing against: $base_ref"

# ---- read versions ----

head_mv_list=$(extract_marketing_version "")
head_bv_list=$(extract_build_version "")
base_mv_list=$(extract_marketing_version "$base_ref" || true)
base_bv_list=$(extract_build_version "$base_ref" || true)

# 6 箇所 (本体/Tests/UITests × Debug/Release) で揺れていないか確認
errors=0

head_mv_count=$(echo "$head_mv_list" | wc -l | tr -d ' ')
head_bv_count=$(echo "$head_bv_list" | wc -l | tr -d ' ')

if [[ "$head_mv_count" -ne 1 ]]; then
  echo "::error::project.pbxproj contains inconsistent MARKETING_VERSION values:"
  echo "$head_mv_list" | sed 's/^/  - /'
  errors=$((errors + 1))
fi
if [[ "$head_bv_count" -ne 1 ]]; then
  echo "::error::project.pbxproj contains inconsistent CURRENT_PROJECT_VERSION values:"
  echo "$head_bv_list" | sed 's/^/  - /'
  errors=$((errors + 1))
fi

head_mv=$(echo "$head_mv_list" | head -n 1)
head_bv=$(echo "$head_bv_list" | head -n 1)
base_mv=$(echo "$base_mv_list" | head -n 1)
base_bv=$(echo "$base_bv_list" | head -n 1)

echo "HEAD : MARKETING_VERSION=$head_mv CURRENT_PROJECT_VERSION=$head_bv"
echo "BASE : MARKETING_VERSION=$base_mv CURRENT_PROJECT_VERSION=$base_bv"

# ---- detect release PR ----

is_release_pr=false
if [[ "$PR_TITLE" =~ ^(release:|chore:[[:space:]]*bump|chore:[[:space:]]*bump\ to) ]]; then
  is_release_pr=true
fi
if echo "$PR_LABELS" | grep -qE '"name"[[:space:]]*:[[:space:]]*"release"'; then
  is_release_pr=true
fi

# ---- compare ----

mv_increased=false
bv_increased=false

if [[ -n "$base_mv" ]] && semver_gt "$head_mv" "$base_mv"; then
  mv_increased=true
fi
if [[ -n "$base_bv" ]] && [[ "$head_bv" =~ ^[0-9]+$ ]] && [[ "$base_bv" =~ ^[0-9]+$ ]] && (( head_bv > base_bv )); then
  bv_increased=true
fi

if $is_release_pr; then
  echo "Mode: enforce (release PR detected)"
  if ! $mv_increased; then
    echo "::error::MARKETING_VERSION must be greater than base ($base_mv). Got: $head_mv"
    errors=$((errors + 1))
  fi
  if ! $bv_increased; then
    echo "::error::CURRENT_PROJECT_VERSION must be greater than base ($base_bv). Got: $head_bv"
    errors=$((errors + 1))
  fi
else
  echo "Mode: info (non-release PR)"
  if [[ "$head_mv" != "$base_mv" ]] && ! $mv_increased; then
    echo "::warning::MARKETING_VERSION ($head_mv) is not greater than base ($base_mv). If this is a release, add 'release' label or use 'release:' / 'chore: bump' title prefix."
  fi
  if [[ "$head_bv" != "$base_bv" ]] && ! $bv_increased; then
    echo "::warning::CURRENT_PROJECT_VERSION ($head_bv) is not greater than base ($base_bv). If this is a release, mark the PR as such."
  fi
fi

if (( errors > 0 )); then
  echo "Version bump check failed with $errors error(s)"
  exit 1
fi

echo "Version bump check passed"
