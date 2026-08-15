import SwiftUI
import CoachingKit

/// 요약 화면이 왜 떴는지.
///
/// 종료를 누른 것과, 화면을 벗어나 카메라가 꺼진 것과, 카메라가 멈춘 것은 사용자에게
/// 전혀 다른 사건이다. 셋을 구분하지 않으면 잠깐 제어센터를 내렸다 돌아온 사람이
/// 영문 모를 요약 화면을 보고 자기가 뭘 잘못 눌렀다고 생각한다.
enum LiveSmileSessionEndReason {
    case userEnded
    case leftTheApp
    case interrupted

    var notice: String? {
        switch self {
        case .userEnded: nil
        case .leftTheApp: SharedStrings.liveSummaryEndedByLeavingApp
        case .interrupted: SharedStrings.liveSummaryEndedByInterruption
        }
    }
}

/// 실시간 확인이 끝난 뒤 그 세션을 보여주는 화면.
///
/// 저장하지 않는다. 이 화면을 닫으면 타임라인이 그대로 사라진다.
/// 얼굴 사진은 보여주지 않는다 — 자기 얼굴이 격자로 늘어서면 사용자가 스스로를 판정하게 되고,
/// 그건 "잘함·못함을 매기지 않는다"는 이 앱의 전제와 어긋난다. 시간대는 아래 띠가 말해준다.
struct LiveSmileSessionSummaryView: View {
    let summary: LiveSmileSessionSummary
    var endReason: LiveSmileSessionEndReason = .userEnded
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header

                if let notice = endReason.notice {
                    Text(notice)
                        .font(.footnote)
                        .foregroundStyle(SDColor.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                switch summary.confidence {
                case .noMeasurement:
                    Text(SharedStrings.liveSummaryNoMeasurement)
                        .font(.headline)
                        .foregroundStyle(SDColor.ink)
                case .low(let value):
                    ratio(value, isLowConfidence: true)
                case .reliable(let value):
                    ratio(value, isLowConfidence: false)
                }

                // 전부 `unknown`인 세션은 띠를 그린다 — 회색으로 가득한 띠가
                // "그 시간을 못 봤다"를 정확히 말해준다. 0초일 때만 숨긴다.
                if summary.totalSeconds > 0 {
                    timelineBand
                }

                Text(SharedStrings.liveSummaryMeaning)
                    .font(.caption)
                    .foregroundStyle(SDColor.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(SharedStrings.liveSummaryCloseAction, action: onClose)
                    .buttonStyle(SDPrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(SDColor.cream)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(SharedStrings.liveSummaryTitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SDColor.muted)

            // 헤드라인은 측정한 시간이다. 그래프 가로축과 같은 값이어야 한다.
            Text(SDFormat.duration(seconds: summary.totalSeconds))
                .font(.title2.bold())
                .foregroundStyle(SDColor.ink)
        }
    }

    /// `unknownRatio`는 분모가 달라서(전체 시간) 미소 비율과 한 막대에 쌓지 않는다.
    /// 두 줄로 따로 둔다.
    private func ratio(_ value: Double, isLowConfidence: Bool) -> some View {
        VStack(spacing: 6) {
            Text("\(Int((value * 100).rounded()))%")
                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(SDColor.ink)

            Text(SharedStrings.liveSummaryRatioLabel)
                .font(.footnote)
                .foregroundStyle(SDColor.muted)

            Text("\(SharedStrings.liveSummaryLegendUnknown) \(Int((summary.unknownRatio * 100).rounded()))%")
                .font(.caption)
                .foregroundStyle(SDColor.muted)

            if isLowConfidence {
                Text(SharedStrings.liveSummaryLowConfidence)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SDColor.alert)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var timelineBand: some View {
        VStack(spacing: 8) {
            LiveSmileTimelineBand(timeline: summary.timeline)
                .frame(height: 34)

            HStack(spacing: 14) {
                legend(SharedStrings.liveSummaryLegendSmiling, SDColor.apricot)
                legend(SharedStrings.liveSummaryLegendNotSmiling, SDColor.shell)
                legend(SharedStrings.liveSummaryLegendUnknown, SDColor.muted.opacity(0.35))
            }
            .font(.caption2)
            .foregroundStyle(SDColor.muted)
        }
        // 띠와 범례는 위의 비율을 눈으로 보는 수단이다. 읽어줄 내용은 이미 비율
        // 요소가 말했으므로, 제목을 한 번 더 읽는 빈 요소를 두지 않는다.
        .accessibilityHidden(true)
    }

    private func legend(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }

}

/// 1초 칸을 이어 그린 띠. 측정 중과 요약이 같은 그림을 쓴다.
///
/// `Canvas`로 그린다. 칸마다 뷰를 만들면 1시간 세션에서 3,600개가 되어
/// 레이아웃이 감당하지 못한다. 여기서는 세션 길이와 무관하게 뷰가 하나다.
struct LiveSmileTimelineBand: View {
    let timeline: [LiveSmileObservation]

    var body: some View {
        Canvas { context, size in
            guard !timeline.isEmpty else { return }

            // 칸마다 그리지 않고 픽셀 열마다 그린다.
            //
            // 1초 칸을 그 자리에 그리면 긴 세션에서 칸이 1pt보다 얇아지고, 뒤 칸이
            // 앞 칸을 덮어 지운다 — 342pt 띠의 1시간 세션에서 칸 하나는 0.095pt라
            // 혼자 웃은 1초가 아예 사라진다. 열이 덮는 초들을 모아 하나로 정하면
            // 세션 길이와 무관하게 지워지는 초가 없다.
            let columns = max(Int(size.width.rounded(.down)), 1)
            let secondsPerColumn = Double(timeline.count) / Double(columns)

            for column in 0..<columns {
                let start = Int(Double(column) * secondsPerColumn)
                guard start < timeline.count else { break }
                // 열이 1초보다 좁아도(짧은 세션) 최소 한 칸은 본다.
                let end = min(max(Int(Double(column + 1) * secondsPerColumn), start + 1), timeline.count)

                // 너비가 정수가 아니면 칸 폭의 합이 size.width에 못 미쳐 오른쪽 끝에
                // 배경색이 실오라기처럼 남는다. 마지막 칸만 남는 소수점 폭까지 채운다.
                let x = CGFloat(column)
                let width = column == columns - 1 ? size.width - x : 1
                let rect = CGRect(x: x, y: 0, width: width, height: size.height)
                context.fill(Path(rect), with: .color(color(of: timeline[start..<end])))
            }
        }
        .background(SDColor.shell.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// 한 열이 여러 초를 덮을 때 무엇으로 칠할지.
    ///
    /// 다수결이 아니라 미소 우선이다. 이 앱에서 웃은 순간이 그래프에서 사라지는 쪽이
    /// 더 나쁜 방향이다 — 사용자는 자기가 웃은 것을 알고 있는데 그래프가 아니라고 말하면
    /// 그래프를 믿지 못하게 된다. 숫자로 쓰는 비율은 초 단위 그대로 계산하므로
    /// 이 우선순위가 비율을 부풀리지는 않는다.
    private func color(of slice: ArraySlice<LiveSmileObservation>) -> Color {
        if slice.contains(.smiling) { return color(.smiling) }
        if slice.contains(.notSmiling) { return color(.notSmiling) }
        return color(.unknown)
    }

    private func color(_ observation: LiveSmileObservation) -> Color {
        switch observation {
        case .smiling: SDColor.apricot
        case .notSmiling: SDColor.shell
        case .unknown: SDColor.muted.opacity(0.35)
        }
    }
}
