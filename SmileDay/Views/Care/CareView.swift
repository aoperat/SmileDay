import SwiftUI
import SwiftData
import CoachingKit

/// 쉬어가기 탭.
///
/// 파일 이름은 Xcode 프로젝트 참조를 건드리지 않으려고 유지한다. 타입과 콘텐츠는
/// `SmilePractice` 기반으로 전환되어 얼굴 부위나 점수를 다루지 않는다.
struct CareView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SmilePracticeViewModel?
    @State private var playingPractice: SmilePractice?
    @State private var showSaveError = false
    #if DEBUG
    @State private var didAutoPlay = false
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("잠시 쉬어가기")
                    .font(.title3.bold())
                    .foregroundStyle(SDColor.ink)
                    .padding(.top, 6)

                if let viewModel {
                    if let recommendation = viewModel.recommendation {
                        RecommendationCard(recommendation: recommendation) {
                            playingPractice = recommendation.practice
                        }
                    }

                    CategoryChips(selected: Binding(
                        get: { viewModel.selectedCategory },
                        set: { viewModel.selectedCategory = $0 }
                    ))

                    ForEach(viewModel.filteredPractices) { practice in
                        PracticeRow(
                            practice: practice,
                            isFavorite: viewModel.visibleFavoriteIDs.contains(practice.id),
                            onPlay: { playingPractice = practice },
                            onToggleFavorite: { viewModel.toggleFavorite(practice.id) }
                        )
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .background(SDColor.cream)
        .onAppear {
            let vm = viewModel ?? SmilePracticeViewModel(
                careRepository: CareRepository(modelContext: modelContext),
                favorites: UserDefaultsSmilePracticeFavorites()
            )
            viewModel = vm
            try? vm.refresh()
            #if DEBUG
            // 1회만 자동 재생 — 커버가 닫힐 때 onAppear가 다시 불려도 재표시하지 않는다.
            if !didAutoPlay,
               let practiceID = UserDefaults.standard.string(forKey: "autoPlayRoutine") {
                didAutoPlay = true
                playingPractice = vm.practices.first { $0.id == practiceID }
            }
            #endif
        }
        .fullScreenCover(item: $playingPractice) { practice in
            CarePlayerView(practice: practice) { result in
                if let viewModel {
                    do {
                        if result.completed {
                            try viewModel.completePractice(practice, startedAt: result.startedAt)
                        } else {
                            try viewModel.abandonPractice(practice, startedAt: result.startedAt, completedSteps: result.completedSteps)
                        }
                    } catch {
                        showSaveError = true
                    }
                }
                playingPractice = nil
            }
        }
        .alert(SharedStrings.saveFailed, isPresented: $showSaveError) {
            Button("확인", role: .cancel) {}
        }
    }
}

private struct RecommendationCard: View {
    let recommendation: SmilePracticeRecommendation
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onPlay) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [SDColor.apricot, SDColor.coral],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 118)

                    Circle()
                        .fill(.white.opacity(0.95))
                        .frame(width: 42)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(SDColor.coralDeep)
                                .offset(x: 1)
                        }
                }
                .overlay(alignment: .topLeading) {
                    Text("지금 어울리는 시간")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(SDColor.ink.opacity(0.45), in: Capsule())
                        .padding(10)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(recommendation.practice.title) 시작하기"))

            HStack {
                Text(recommendation.practice.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(SDColor.ink)
                Spacer()
                Text("\(recommendation.practice.durationText) · \(recommendation.practice.category.displayName)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(SDColor.muted)
            }

            Text(recommendation.reason)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SDColor.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(hex: 0xFFF6E8), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .sdCard(padding: 12)
    }
}

private struct CategoryChips: View {
    @Binding var selected: SmilePracticeCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(title: "전체", isOn: selected == nil) { selected = nil }
                ForEach(SmilePracticeCategory.allCases, id: \.self) { category in
                    chip(title: category.displayName, isOn: selected == category) {
                        selected = selected == category ? nil : category
                    }
                }
            }
        }
    }

    private func chip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(isOn ? .white : SDColor.muted)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background {
                    if isOn {
                        Capsule().fill(SDColor.primaryGradient)
                    } else {
                        Capsule().fill(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

private struct PracticeRow: View {
    let practice: SmilePractice
    let isFavorite: Bool
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Button(action: onPlay) {
                HStack(spacing: 11) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(practice.category.thumbnailGradient)
                        .frame(width: 46, height: 46)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.95))
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(practice.title)
                            .font(.footnote.bold())
                            .foregroundStyle(SDColor.ink)
                        Text("\(practice.durationText) · \(practice.category.displayName)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(SDColor.muted)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isFavorite ? SDColor.coral : Color(hex: 0xE9D5C6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "즐겨찾기 해제" : "즐겨찾기")
        }
        .sdCard(padding: 11, cornerRadius: 18)
    }
}

extension SmilePracticeCategory {
    var thumbnailGradient: LinearGradient {
        let colors: [Color] = switch self {
        case .pause: [SDColor.sun, SDColor.apricot]
        case .breathe: [SDColor.lilac, Color(hex: 0x8F6FD1)]
        case .recall: [Color(hex: 0x6FCBB0), SDColor.mint]
        case .connect: [SDColor.coral, SDColor.coralWarm]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
