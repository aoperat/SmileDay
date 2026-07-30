import SwiftUI
import CoachingKit

/// 실시간 확인이 끝난 뒤 그 세션을 보여주는 화면.
///
/// 저장하지 않는다. 이 화면을 닫으면 타임라인과 사진이 그대로 사라진다.
/// 사진에 미소 여부 색을 칠하지 않는다 — 한 장마다 판정을 붙이면 "안 웃은 나"의 격자가 된다.
struct LiveSmileSessionSummaryView: View {
    let summary: LiveSmileSessionSummary
    let snapshots: [UIImage]
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header

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

                timelineBand

                if !snapshots.isEmpty {
                    snapshotStrip
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
            Text(durationText(summary.totalSeconds))
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
                legend(SharedStrings.liveSummaryLegendSmiling, SDColor.coral)
                legend(SharedStrings.liveSummaryLegendNotSmiling, SDColor.shell)
                legend(SharedStrings.liveSummaryLegendUnknown, SDColor.muted.opacity(0.35))
            }
            .font(.caption2)
            .foregroundStyle(SDColor.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SharedStrings.liveSummaryTitle)
    }

    private func legend(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }

    private var snapshotStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 사진에 판정을 붙이지 않는다. 개수만 알려준다.
            Text("1분마다 \(snapshots.count)장")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SDColor.muted)

            LazyVGrid(columns: Array(repeating: GridItem(spacing: 4), count: 5), spacing: 4) {
                ForEach(Array(snapshots.enumerated()), id: \.offset) { _, image in
                    // 사진에 높이만 주면 프레임이 `scaledToFill`이 넘긴 폭을 그대로 물려받아
                    // 셀이 열 너비를 벗어나고 `clipped()`도 잘라내지 못한다 —
                    // 65pt 열에서 98pt로 측정된다. 크기는 빈 사각형이 정하고 사진은 그 위에 채운다.
                    Rectangle()
                        .fill(SDColor.shell)
                        .frame(height: 74)
                        .overlay(
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        guard minutes > 0 else { return "\(remainder)초" }
        return remainder == 0 ? "\(minutes)분" : "\(minutes)분 \(remainder)초"
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

            let slotWidth = size.width / CGFloat(timeline.count)
            for (index, observation) in timeline.enumerated() {
                let rect = CGRect(
                    x: CGFloat(index) * slotWidth,
                    y: 0,
                    // 폭이 소수면 칸 사이에 실선 틈이 보인다. 올려서 겹치게 둔다.
                    width: slotWidth.rounded(.up),
                    height: size.height
                )
                context.fill(Path(rect), with: .color(color(observation)))
            }
        }
        .background(SDColor.shell.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func color(_ observation: LiveSmileObservation) -> Color {
        switch observation {
        case .smiling: SDColor.coral
        case .notSmiling: SDColor.shell
        case .unknown: SDColor.muted.opacity(0.35)
        }
    }
}
