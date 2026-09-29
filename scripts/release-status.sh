#!/bin/bash
#
# release-status.sh
#
# 公開中の version・前回公開からの日数・まだ出していない feat / fix の件数を
# 表示する。daily-issue-triage の Step 0 から呼ぶ (Issue #232)。
#
# 基準は「最新タグ」ではなく「App Store で公開中の version のタグ」。
# v1.1.3 はタグと手順書があったのに提出されておらず、タグを出荷の証拠に
# したせいで 126 日気付けなかった (docs/releases/RELEASE_v1.1.4.md §5)。
#
# 環境変数 (検証用の差し替え):
#   APP_ID            : App Store の app id (デフォルト: 6747692379)
#   GIT_REF           : 未出荷を数える先端 (デフォルト: origin/main、無ければ HEAD)
#   THRESHOLD_DAYS    : この日数を超え、かつ未出荷の feat/fix が 1 件以上なら
#                       リリースを勧める (デフォルト: 30)
#   LOOKUP_JSON_JP    : iTunes Lookup の代わりに読む JSON ファイル (JP)
#   LOOKUP_JSON_US    : 同上 (US)
#   NOW_EPOCH         : 「今」の UNIX 時刻 (デフォルト: date +%s)
#
# Exit code: 常に 0 (表示するだけで triage を止めない)

set -uo pipefail

APP_ID="${APP_ID:-6747692379}"
THRESHOLD_DAYS="${THRESHOLD_DAYS:-30}"
NOW_EPOCH="${NOW_EPOCH:-$(date +%s)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

JQ="$(resolve_jq)" || {
  echo "判定: unknown (動作する jq が見つかりません。brew install jq)"
  exit 0
}

if [[ -z "${GIT_REF:-}" ]]; then
  if git rev-parse --verify -q origin/main >/dev/null; then
    GIT_REF="origin/main"
  else
    GIT_REF="HEAD"
  fi
fi

# country の公開中 version と公開日 (ISO 8601) を "version<TAB>date" で出す。
# 取れなければ何も出さない。
lookup() {
  local country="$1" override="$2" json
  if [[ -n "$override" ]]; then
    json="$(cat "$override" 2>/dev/null)"
  else
    json="$(curl -s --max-time 10 "https://itunes.apple.com/lookup?id=${APP_ID}&country=${country}")"
  fi
  printf '%s' "$json" | "$JQ" -r \
    '.results[0] // empty | "\(.version)\t\(.currentVersionReleaseDate)"' 2>/dev/null
}

# ISO 8601 (UTC, 例 2026-09-27T19:10:11Z) → UNIX 時刻。macOS と GNU date の両対応。
to_epoch() {
  date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null \
    || date -u -d "$1" +%s 2>/dev/null
}

# UTC の公開日時を日本時間の日付で出す (公開日を JST で読むため)。
to_jst_date() {
  local epoch
  epoch="$(to_epoch "$1")" || return 1
  TZ=Asia/Tokyo date -r "$epoch" +%Y-%m-%d 2>/dev/null \
    || TZ=Asia/Tokyo date -d "@$epoch" +%Y-%m-%d
}

jp="$(lookup jp "${LOOKUP_JSON_JP:-}")"
us="$(lookup us "${LOOKUP_JSON_US:-}")"

if [[ -z "$jp" ]]; then
  echo "判定: unknown (App Store の JP lookup に失敗。ネットワークを確認)"
  exit 0
fi

jp_version="${jp%%$'\t'*}"
jp_date="${jp#*$'\t'}"
jp_epoch="$(to_epoch "$jp_date")" || {
  echo "判定: unknown (公開日 '${jp_date}' を日付として読めない)"
  exit 0
}
days=$(( (NOW_EPOCH - jp_epoch) / 86400 ))

if [[ -n "$us" ]]; then
  us_version="${us%%$'\t'*}"
  us_part="US ${us_version} $(to_jst_date "${us#*$'\t'}")"
  if [[ "$us_version" != "$jp_version" ]]; then
    us_part="${us_part} ※JP と不一致 (公開直後は国ごとに反映がずれる)"
  fi
else
  us_part="US 取得失敗"
fi

echo "公開中: ${jp_version} (JP $(to_jst_date "$jp_date") / ${us_part})  前回公開から ${days} 日"

base_tag="v${jp_version}"
latest_tag="$(git tag --list 'v*' --sort=-v:refname | head -1)"
if [[ "$latest_tag" == "$base_tag" ]]; then
  echo "基準タグ: ${base_tag}  最新タグ: ${latest_tag} (一致)"
else
  echo "基準タグ: ${base_tag}  最新タグ: ${latest_tag:-なし}  ⚠ 不一致 (タグは出荷の証拠ではない。未提出のタグがないか ASC で確認)"
fi

if ! git rev-parse --verify -q "${base_tag}^{commit}" >/dev/null; then
  echo "判定: unknown (公開中 version のタグ ${base_tag} がない。承認後にビルド元のコミットへタグを打つ)"
  exit 0
fi

subjects="$(git log --format=%s "${base_tag}..${GIT_REF}")"
count_type() {
  printf '%s\n' "$subjects" | grep -cE "^$1(\([^)]*\))?!?:" || true
}
feat=$(count_type feat)
fix=$(count_type fix)
perf=$(count_type perf)
refactor=$(count_type refactor)
total=$(printf '%s' "$subjects" | grep -c '' || true)
other=$(( total - feat - fix - perf - refactor ))

echo "未出荷 (${base_tag}..${GIT_REF}): feat ${feat} / fix ${fix} / perf ${perf} / refactor ${refactor}  (その他 ${other})"

if (( days > THRESHOLD_DAYS && feat + fix >= 1 )); then
  echo "判定: release-recommended (${THRESHOLD_DAYS} 日超 かつ 未出荷の feat/fix ${feat}+${fix} 件) → triage の表に「リリース issue を切る」を候補として出す"
else
  echo "判定: ok (しきい値: ${THRESHOLD_DAYS} 日超 かつ 未出荷の feat/fix ≥ 1)"
fi
