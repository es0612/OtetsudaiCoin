#!/bin/bash
# release-doc-check.sh — リリース手順書 (docs/releases/RELEASE_vX.Y.Z.md) の § 3 の空欄を検査する (#306)
#
# 何を見るか:
#   § 3 (`## 3.` から `### 提出` の手前まで) の「空欄」を数える。空欄とは:
#     - 未チェックの項目 `- [ ] ...`
#     - 中身の無い証拠欄 `証拠:` (チェック済み・未チェックを問わない)
#   ただし、項目の行に `未実施: <理由>` と書いた項目は空欄として数えない (その下の空の証拠欄も)。
#   後から黙ってチェックを付けるのではなく、やらなかった理由を残すための抜け道。
#   `証拠:` の行が空でも、次の行がより深い字下げ (入れ子のリスト・コードフェンス) なら中身ありとみなす。
#   コロンは半角 (:)・全角 (：) のどちらでもよい。
#
# いつ失敗するか:
#   `### 提出` に `- [x]` がある (= 提出したと記録している) のに § 3 に空欄がある → exit 1
#   まだ提出していない手順書の空欄は、下書きとして正常なので警告だけ (exit 0)
#   `## 3.` か `### 提出` の見出しが無い手順書も exit 1 (検査できないのに 0 件と区別できないため)
#
# 対象外:
#   - v1.1.6 以前 (この検査より前に提出済み。空欄を後から埋めない。GRANDFATHER_MAX で変更可)
#   - ファイル名が RELEASE_vX.Y.Z.md でないもの (RELEASE_TEMPLATE.md / *_ASC_EN.md など)
#
# 使い方:
#   /bin/bash scripts/release-doc-check.sh                      # docs/releases/RELEASE_v*.md を全部
#   /bin/bash scripts/release-doc-check.sh docs/releases/RELEASE_v1.1.7.md
#
# 終了コード: 0 = 問題なし / 1 = 提出済みなのに空欄あり、または見出しが無い

set -uo pipefail

GRANDFATHER_MAX="${GRANDFATHER_MAX:-1.1.6}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# GitHub Actions のときだけ ::error:: / ::warning:: の注記を出す
annotate() { # level file line message
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::$1 file=$2,line=$3::$4"
  fi
}

# $1 <= $2 なら 0 (X.Y.Z の数値比較)
version_le() {
  local IFS=.
  local -a a=($1) b=($2)
  local i
  for i in 0 1 2; do
    if (( 10#${a[i]:-0} < 10#${b[i]:-0} )); then return 0; fi  # 10#: 0 埋め (08) を 8 進数と読まない
    if (( 10#${a[i]:-0} > 10#${b[i]:-0} )); then return 1; fi
  done
  return 0
}

if [[ $# -gt 0 ]]; then
  files=("$@")
else
  files=("$REPO_ROOT"/docs/releases/RELEASE_v*.md)
fi

status=0
for file in "${files[@]}"; do
  name="$(basename "$file")"
  rel="${file#"$REPO_ROOT"/}"

  if [[ ! "$name" =~ ^RELEASE_v([0-9]+\.[0-9]+\.[0-9]+)\.md$ ]]; then
    echo "skip: $rel (RELEASE_vX.Y.Z.md の形ではない)"
    continue
  fi
  version="${BASH_REMATCH[1]}"
  if version_le "$version" "$GRANDFATHER_MAX"; then
    echo "skip: $rel (v$GRANDFATHER_MAX 以前は対象外)"
    continue
  fi

  # 出力: 1 行目 "HEADINGS <有無 § 3> <有無 提出>" / 2 行目 "SUBMITTED <0|1>" / 以降 "BLANK <行番号>\t<行>"
  # コロンは半角・全角の両方を受ける。[:：] と書くと mawk がバイト単位で読んで壊れるので alternation で書く
  result="$(awk '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    function indent(s) { match(s, /^[[:space:]]*/); return RLENGTH }
    function flush() { if (pend != "") { blanks[++n] = pend; pend = "" } }
    # 空に見える証拠欄は保留し、次の行がより深い字下げ (入れ子のリスト・コードフェンス) なら中身ありとみなす
    pend != "" && /[^[:space:]]/ { if (indent($0) > pind) pend = ""; else flush() }
    /^## 3\./                 { sec = 3; has3 = 1; next }
    /^### 提出[[:space:]]*$/  { if (sec == 3) { flush(); sec = 4; hassub = 1 }; next }
    /^## /                    { flush(); sec = 0 }
    /^### /                   { waived = 0; if (sec == 4) sec = 0; next }
    sec == 3 && /^- \[/ {
      waived = ($0 ~ /未実施(:|：)[[:space:]]*[^[:space:]]/) && ($0 !~ /未実施(:|：)[[:space:]]*<理由>/)
      if (/^- \[ \]/ && !waived) blanks[++n] = NR "\t" trim($0)
      next
    }
    sec == 3 && /証拠(:|：)[[:space:]]*$/ {
      if (!waived) { pend = NR "\t" trim($0); pind = indent($0) }
      next
    }
    sec == 4 && /^- \[[xX]\]/ { submitted = 1 }
    END {
      flush()
      print "HEADINGS " (has3 ? 1 : 0) " " (hassub ? 1 : 0)
      print "SUBMITTED " (submitted ? 1 : 0)
      for (i = 1; i <= n; i++) print "BLANK " blanks[i]
    }
  ' "$file")"

  headings="$(sed -n '1p' <<<"$result")"
  submitted="$(sed -n '2p' <<<"$result" | cut -d' ' -f2)"
  blanks="$(sed -n '3,$p' <<<"$result")"
  count=0
  [[ -n "$blanks" ]] && count="$(wc -l <<<"$blanks" | tr -d ' ')"

  if [[ "$headings" != "HEADINGS 1 1" ]]; then
    echo "FAIL: $rel — 見出し「## 3.」と「### 提出」の両方が要る ($headings)"
    annotate error "$rel" 1 "見出し「## 3.」と「### 提出」が見つからないので § 3 を検査できない。RELEASE_TEMPLATE.md の見出しを使う"
    status=1
    continue
  fi

  if [[ "$count" -eq 0 ]]; then
    echo "ok: $rel (§ 3 の空欄 0 件、提出の記録 $([[ "$submitted" == 1 ]] && echo あり || echo なし))"
    continue
  fi

  if [[ "$submitted" == 1 ]]; then
    level=error; label=FAIL; status=1
    msg="「### 提出」は [x] なのに § 3 に空欄がある。証拠を書くか、やっていないなら項目の行に「未実施: <理由>」と書く (後からチェックだけ付けない)"
  else
    level=warning; label=warn
    msg="§ 3 の空欄 (まだ提出前なので警告のみ)。提出の前に 0 件にする"
  fi
  echo "$label: $rel — § 3 の空欄 $count 件"
  while IFS=$'\t' read -r lineno text; do
    lineno="${lineno#BLANK }"
    echo "    $lineno: $text"
    annotate "$level" "$rel" "$lineno" "$msg"
  done <<<"$blanks"
done

exit "$status"
