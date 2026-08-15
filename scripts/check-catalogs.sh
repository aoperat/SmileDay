#!/usr/bin/env bash
# String Catalog 게이트.
# 1단계에서는 needs_review 가 많은 것이 정상이다 — 개수만 보고한다.
# 2단계 종료 조건: en/ko 값이 비었거나 needs_review/new 인 항목이 0개. STRICT=1 로 강제한다.
set -euo pipefail
cd "$(dirname "$0")/.."
total=0; review=0; empty=0
for f in SmileDay/Resources/{Localizable,Home,Onboarding,Settings,Coaching}.xcstrings; do
  t=$(jq '.strings | length' "$f")
  r=$(jq '[.strings[] | .localizations[]? | ((.stringUnit.state // empty), (.variations.plural[]?.stringUnit.state // empty)) | select(. == "needs_review" or . == "new")] | length' "$f")
  e=$(jq '[.strings | to_entries[] | select((.value.localizations.en // null) == null or (.value.localizations.ko // null) == null)] | length' "$f")
  printf "%-22s keys=%-4s needs_review=%-4s missing_lang=%s\n" "$(basename "$f")" "$t" "$r" "$e"
  total=$((total+t)); review=$((review+r)); empty=$((empty+e))
done
echo "TOTAL                  keys=$total needs_review=$review missing_lang=$empty"
[ "$empty" -eq 0 ] || { echo "FAIL: keys missing a language"; exit 1; }
if [ "${STRICT:-0}" = "1" ] && [ "$review" -ne 0 ]; then echo "FAIL: needs_review remaining (phase-2 gate)"; exit 1; fi
