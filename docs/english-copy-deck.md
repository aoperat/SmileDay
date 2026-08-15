# 영어 문구 초안

- 날짜: 2026-07-31
- 상태: 초안 — **코드에 반영하지 않았다.** 1차 출시는 한국어 앱이다.
- 목적: 영어 출시를 결정했을 때 바로 쓸 수 있게 문구를 미리 정해둔다.

## 왜 코드가 아니라 문서인가

영어화의 어려운 부분은 엔지니어링이 아니라 **글쓰기**다. 문자열을 String Catalog로 빼는 일은
기계적이고 지금 하나 나중에 하나 드는 품이 같다. 반면 톤을 잡는 일은 지금 시작해도
한국어 출시에 아무 위험을 주지 않는다. 그래서 문구를 먼저, 코드는 나중에 한 번에.

**브랜치를 따로 파지 않는다.** 갈라두면 한국어 쪽 변경을 계속 옮겨 심어야 한다.

## 톤 규칙

직역이 실패하는 이유는 단어가 아니라 말투다. 한국어 문구는 다섯 가지를 지키고 있고,
영어도 같은 것을 지켜야 한다 — 다만 다른 장치로.

1. **감정을 명령하지 않는다.** 한국어의 "-볼까요?"는 권유다. 영어에서 이걸 `Let's!`로 옮기면
   응원단이 된다. 조건절로 옮긴다 — `if you're up for it`, `if now works`.
2. **웃지 않은 날은 실패가 아니다.** `You haven't…`, `Don't forget`, `streak`, `goal`,
   `missed`를 쓰지 않는다. 0인 날은 빈 상태이지 놓친 상태가 아니다.
3. **외모를 말하지 않는다.** `looks good on you`, `brighten your face`, `glow` 전부 안 된다.
   이 앱은 표정을 평가하지 않겠다고 했고, 칭찬도 평가다.
4. **과장하지 않는다.** "오늘 한 번 더 웃어봤어요"는 담담한 사실 진술이다.
   `Great job!`, `Amazing!`, 이모지 축하가 아니다.
5. **건강·미용 효과를 말하지 않는다** (App Store 1.4.1).

### 영어에서 특히 위험한 단어

한국어 금지어("리프팅", "젊어진다", "교정한다", "치료")를 번역한 목록이 아니다.
영어권 심사에서 더 직접적으로 걸리는 말은 따로 있다.

> lift, tone, firm, anti-aging, rejuvenate, wrinkle, therapy, therapeutic,
> treatment, cure, heal, depression, anxiety, mood disorder, clinically

우리 문구는 원래 이런 방향으로 쓰이지 않으므로 실무에서 걸릴 일은 거의 없다.
마케팅 문구나 App Store 설명을 쓸 때만 확인하면 된다.

## 문구

`직역`은 쓰지 않을 안이다. 무엇을 피했는지 남겨두려고 적는다.

### 앱 정체성

| 한국어 | 직역 | **제안** |
|---|---|---|
| 스마일데이 | SmileDay | **SmileDay** |
| 웃으면 좋잖아요 | It's nice to smile | **Smile, just because** |

"just because"가 "잖아요"의 일을 한다 — 이유를 대지 않아도 되는 가벼움.

### 홈

| 한국어 | 직역 | **제안** |
|---|---|---|
| 오늘 미소 | Today's smile | **Smiles today** |
| 3번 | 3 times | **3** + 라벨이 단위를 진다 (복수 규칙 필요) |
| 아직 오늘의 미소가 없어요 | No smiles yet today | **Today's still open** |
| 오늘 웃어본 순간이 하나씩 쌓이고 있어요 | Moments are piling up one by one | **They're adding up.** |
| 지금 한 번 웃기 | Smile once now | **Take five seconds** |
| 다음 알림 | Next notification | **Next reminder** |
| 설정된 알림이 없어요 | There is no set notification | **No reminders set** |
| 최근 7일 | Recent 7 days | **Last 7 days** |
| 총 14번 | 14 times in total | **14 in total** |

"아직 …없어요"를 `No smiles yet`으로 옮기면 0점표가 된다. **Today's still open**은
같은 사실을 말하면서 아직 남은 시간을 가리킨다.

"지금 한 번 웃기"는 영어 명령형(`Smile now`)이 되면 재촉이다. **Take five seconds**는
할 일의 크기만 말한다.

### 가이드

| 한국어 | 직역 | **제안** |
|---|---|---|
| 5초 동안 함께 있어요 | We are together for 5 seconds | **We'll sit here for five seconds** |
| 시작 | Start | **Start** |
| 턱과 어깨 힘을 빼고 편안하게 미소 지어보세요 | Relax your jaw and shoulders and smile comfortably | **Let your jaw and shoulders go soft.** |
| 오늘 한 번 더 웃어봤어요 | You smiled one more time today | **That's one more.** |
| 기록을 저장하지 못했어요. 다시 시도해주세요. | Failed to save the record. Please try again. | **Couldn't save that one. Try again?** |

### 안내 문구 (`SmileCueCatalog`)

| 한국어 | **제안** |
|---|---|
| 나를 아끼는 사람에게 어떤 표정을 보여주고 싶나요? | **What face would you want someone who loves you to see?** |
| 반가운 사람을 만났을 때의 표정을 떠올려보세요. | **Picture running into someone you're glad to see.** |
| 오늘의 나에게 따뜻한 표정을 보내볼까요? | **Send today's you something warm.** |
| 고마운 사람을 떠올리며 가볍게 미소 지어보세요. | **Think of someone you're grateful for.** |
| 기분 좋은 인사를 건네듯 표정을 지어보세요. | **Like you're greeting someone you like.** |
| 크게 웃지 않아도 괜찮아요. 편안한 미소면 충분해요. | **It doesn't have to be big. Easy is enough.** |
| 떠오르는 장면이 없어도 괜찮아요. 잠깐 얼굴의 힘만 빼보세요. | **Nothing has to come to mind. Just let your face loosen.** |
| 지금 괜찮다면 입꼬리를 살짝 올려볼까요? | **If you're up for it, let the corners lift a little.** |

> `lift`는 심사 위험어 목록에 있어 자동 검사(`StringCatalogGuaranteeTests`)에 걸린다. 카탈로그에는 `let the corners rise a little`로 시딩했다 — 2단계에서 최종 표현을 정한다.

### 알림 문구 (`ReminderMessageCatalog`)

알림은 짧아야 한다. 잠금화면에서 두 줄을 넘기면 잘린다.

| 한국어 | **제안** |
|---|---|
| 지금 괜찮다면 5초만 편안하게 미소 지어보세요. | **Five easy seconds, if now works.** |
| 잠깐 어깨 힘을 빼고 입꼬리를 살짝 올려볼까요? | **Drop your shoulders. Let the corners lift.** |
| 반가운 사람에게 인사하듯 가볍게 미소 지어보세요. | **Like you just spotted a friend.** |
| 크게 웃지 않아도 괜찮아요. 편안한 미소면 충분해요. | **Doesn't have to be big. Easy is plenty.** |
| 고마운 사람을 떠올리며 잠깐 미소 지어볼까요? | **Someone you're grateful for — picture them.** |
| 화면에서 눈을 떼고 얼굴의 힘을 가볍게 풀어볼까요? | **Look away from the screen. Let your face go.** |
| 오늘의 나에게 따뜻한 표정을 보내볼까요? | **Something warm, for today's you.** |
| 지금 잠깐, 편한 만큼 밝게 웃어볼까요? | **As bright as feels easy. Just for a second.** |

### 알림 버튼

| 한국어 | **제안** |
|---|---|
| 웃었어요 | **I smiled** |
| 가이드 열기 | **Open guide** |

### 온보딩

| 한국어 | **제안** |
|---|---|
| 평소 잘 웃지 않는 나를 위해, 하루에 몇 번 잠깐 웃어보는 시간을 만들어요. | **For the days that go by without one. A few short moments to smile.** |
| 표정을 찍거나 점수를 매기지 않아요. 웃어본 횟수만 이 기기에 기록해요. | **No photos, no scores. Just a count, kept on this phone.** |
| 잊지 않도록 알려드릴게요 | **A reminder, so it doesn't slip** |
| 알림을 놓쳐도 재촉하거나 몰아서 보내지 않아요. | **Miss one and nothing piles up. We won't ask twice.** |
| 알림 없이 시작하기 | **Start without reminders** |

### 실시간 미소 확인

| 한국어 | **제안** |
|---|---|
| 실시간 미소 확인 | **Live smile check** |
| 카메라 화면 없이 미소 신호만 보여드려요. | **Just the signal — no camera view unless you turn it on.** |
| 이 표시는 웃음의 좋고 나쁨이 아니라, 지금 카메라가 감지한 입꼬리 움직임을 보여줘요. | **This isn't a verdict on your smile. It's what the camera reads at your mouth corners.** |
| 측정된 시간이 없어요. | **Nothing measured.** |
| 얼굴이 보인 동안 미소 | **Smiling, while your face was visible** |

## 나중에 할 엔지니어링

문구가 확정된 뒤 한 번에 처리한다.

- 앱 타깃에 String Catalog(`.xcstrings`) 추가. 한국어가 소스 언어다.
- **CoachingKit의 문자열 41개를 어떻게 할지 결정한다.** 패키지를 로컬라이즈하려면
  `defaultLocalization`과 리소스 번들이 필요하다. 대안은 이 문구들을 앱 타깃으로 올리는 것 —
  패키지에 사용자 문구가 있는 것 자체가 원래 계층에 어긋나므로 이쪽이 나을 수 있다.
- **`ko_KR` 고정을 푼다.** `SmileDayApp`의 `.environment(\.locale,)`과 `SDFormat.koreanLocale`
  두 곳이다. 지금은 기기 언어와 무관하게 한국어 날짜를 그린다.
- **복수 규칙.** "3번", "총 14번", "\(count)장" 같은 문자열은 영어에서
  `1 smile` / `2 smiles`로 갈린다. String Catalog의 plural variation으로 옮겨야 한다.
- App Store 설명·스크린샷은 별도. 위 위험 단어 목록을 그때 확인한다.
