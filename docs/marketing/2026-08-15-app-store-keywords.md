# 스마일데이 App Store 검색 키워드 (ASO)

- 작성일: 2026-08-15
- 용도: App Store Connect의 이름·부제·키워드 필드 설계. 한국어 페이지 + (예정) 영어 페이지
- 짝 문서: `2026-08-05-app-store-metadata-ko.md` (현재 등록값), `2026-08-15-seo-keywords.md` (웹 SEO)
- 참고: 키워드 필드는 새 버전 제출 시에만 수정할 수 있다. 프로모션 텍스트만 수시 수정 가능.

## 원칙

1. **필드 간 중복 금지.** 이름·부제·키워드 필드는 각각 색인된다. 이름에 든 단어(스마일, 데이 / Smile, Day)는 부제·키워드에 다시 쓰지 않는다 — 자리 낭비다.
2. **키워드 필드는 낱말 단위.** Apple이 낱말을 조합해 구문을 만든다. "미소습관"보다 "미소,습관"이 조합 커버리지가 넓다.
3. **공백 없이 쉼표로만** 구분한다. 한/영 각 100자 제한.
4. 금지어(리프팅·안티에이징 계열, lift·anti-aging 계열)는 키워드 필드에도 쓰지 않는다. 심사에서 메타데이터도 본다.

## 한국어

### 이름 (30자)

```
스마일데이
```

### 부제 (30자) — 현재 없음, 추가 권장

부제는 검색 가중치가 이름 다음으로 높다. 후보 (모두 30자 이내):

1. `하루 몇 번, 5초의 미소 습관` ← 권장
2. `부담 없이 웃어보는 5초 습관`
3. `알림으로 챙기는 표정 습관`

### 키워드 필드 (100자)

현재 등록값 (37자, 복합어 방식):

```
미소습관,웃음습관,습관알림,미소기록,표정습관,하루루틴,마음챙김
```

제안값 (낱말 방식, 70자):

```
미소,웃음,습관,표정,연습,알림,기록,루틴,하루,인상,5초,무표정,입꼬리,직장인,감정,기분,마음챙김,셀프케어,리마인더,자기관리
```

> 확정 전 체크: 글자수 100자 이하, 오탈자, 이름·부제와 중복 없음.

이 조합이 커버하는 검색 구문 예: 미소 습관, 웃음 연습, 습관 알림, 표정 연습, 무표정, 입꼬리 연습, 하루 기록, 직장인 루틴, 감정 기록, 마음챙김 앱.

남는 예산(약 30자)은 출시 후 검색 성과를 보고 채운다. 후보: `위젯`(위젯 출시 후), `위로`, `자기돌봄`, `데일리`.

## 영어 (영어 페이지 추가 시)

`2026-08-15-english-localization-design.md` 7.1절의 결론 그대로: **번역이 아니라 재설계.** `smile habit` 직역이 아니라 실제 검색되는 계열(reminder, habit tracker, self care, mindfulness)에서 이 앱이 정말 하는 일과 겹치는 것만.

### 이름 (30자)

```
SmileDay
```

`[확인 필요: App Store에서 동명 앱 존재 여부 — 충돌 시 "SmileDay – Smile Reminders" 형태로 확장]`

### 부제 (30자) — 후보

이름의 "Smile"이 이미 색인되므로 부제는 habit·seconds 계열로 보완하되, 검색량을 고려해 smile을 한 번 더 실을지 선택:

1. `Five easy seconds to smile` (26자) ← 권장. 제품을 그대로 말한다
2. `A gentle daily smile habit` (26자)
3. `Small smile breaks, private` (27자)

금지어·스트릭 언어 없음 확인 완료.

### 키워드 필드 (100자)

제안값 (99자):

```
habit,reminder,tracker,routine,selfcare,mindful,mood,gentle,practice,micro,tiny,pause,break,checkin
```

- `smile`, `day`는 이름이 색인하므로 제외 (조합으로 "smile habit", "smile reminder", "daily smile" 커버).
- `mood`는 mood tracker 유입용. `mood disorder` 같은 의료 표현은 설명문에서도 쓰지 않는다.
- `free`, `best` 같은 예약·무의미 단어는 넣지 않는다.

커버 구문 예: smile reminder, smile habit tracker, daily routine, self care reminder, gentle habit tracker, mindful break, smile practice, tiny habit.

### 프로모션 텍스트 (170자) — 초안

```
A short pause to smile, even on a busy day. Reminders at the times you choose and a five-second guide make it easy to begin.
```

## 운영 메모

- 부제·키워드 변경은 A/B가 안 되므로(제출 단위) 한 번에 한 필드만 바꿔 검색 유입 변화를 읽는다.
- 분기마다 App Store Connect의 검색어 리포트와 대조해 안 걸리는 낱말을 교체한다.
- 스크린샷 자막도 전환율에 영향이 크다 — 자막 카피는 `2026-08-15-landing-page-copy.md`의 원칙 카드 4종을 재사용하면 된다.
