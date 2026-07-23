import SwiftUI
import SwiftData
import CoachingKit

struct CareView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: CareViewModel?
    @State private var playingRoutine: CareRoutine?
    @State private var showSaveError = false
    #if DEBUG
    @State private var didAutoPlay = false
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("오늘의 케어")
                    .font(.title3.bold())
                    .foregroundStyle(SDColor.ink)
                    .padding(.top, 6)

                if let viewModel {
                    if let recommendation = viewModel.recommendation {
                        RecommendationCard(recommendation: recommendation) {
                            playingRoutine = recommendation.routine
                        }
                    }

                    CategoryChips(selected: Binding(
                        get: { viewModel.selectedCategory },
                        set: { viewModel.selectedCategory = $0 }
                    ))

                    ForEach(viewModel.filteredRoutines) { routine in
                        RoutineRow(
                            routine: routine,
                            isFavorite: viewModel.favoriteIDs.contains(routine.id),
                            onPlay: { playingRoutine = routine },
                            onToggleFavorite: { viewModel.toggleFavorite(routine.id) }
                        )
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .background(SDColor.cream)
        .onAppear {
            let vm = viewModel ?? CareViewModel(
                sessionRepository: SessionRepository(modelContext: modelContext),
                careRepository: CareRepository(modelContext: modelContext),
                favorites: UserDefaultsCareFavorites()
            )
            viewModel = vm
            try? vm.refresh()
            #if DEBUG
            // 1회만 자동 재생 — 커버가 닫힐 때 onAppear가 다시 불려도 재표시하지 않는다.
            if !didAutoPlay,
               let routineID = UserDefaults.standard.string(forKey: "autoPlayRoutine") {
                didAutoPlay = true
                playingRoutine = vm.routines.first { $0.id == routineID }
            }
            #endif
        }
        .fullScreenCover(item: $playingRoutine) { routine in
            CarePlayerView(routine: routine) { result in
                if let viewModel {
                    do {
                        if result.completed {
                            try viewModel.completeRoutine(routine, startedAt: result.startedAt)
                        } else {
                            try viewModel.abandonRoutine(routine, startedAt: result.startedAt, completedSteps: result.completedSteps)
                        }
                    } catch {
                        showSaveError = true
                    }
                }
                playingRoutine = nil
            }
        }
        .alert(SharedStrings.saveFailed, isPresented: $showSaveError) {
            Button("확인", role: .cancel) {}
        }
    }
}

private struct RecommendationCard: View {
    let recommendation: CareRecommendation
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
                    Text("오늘의 추천")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(SDColor.ink.opacity(0.45), in: Capsule())
                        .padding(10)
                }
            }
            .buttonStyle(.plain)

            HStack {
                Text(recommendation.routine.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(SDColor.ink)
                Spacer()
                Text("\(recommendation.routine.durationText) · \(recommendation.routine.difficulty.displayName)")
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
    @Binding var selected: CareCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(title: "전체", isOn: selected == nil) { selected = nil }
                ForEach(CareCategory.allCases, id: \.self) { category in
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
    }
}

private struct RoutineRow: View {
    let routine: CareRoutine
    let isFavorite: Bool
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Button(action: onPlay) {
                HStack(spacing: 11) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(routine.category.thumbnailGradient)
                        .frame(width: 46, height: 46)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.95))
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(routine.title)
                            .font(.footnote.bold())
                            .foregroundStyle(SDColor.ink)
                        Text("\(routine.durationText) · \(routine.difficulty.displayName)")
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

extension CareCategory {
    var thumbnailGradient: LinearGradient {
        let colors: [Color] = switch self {
        case .lift: [SDColor.sun, SDColor.apricot]
        case .relax: [SDColor.lilac, Color(hex: 0x8F6FD1)]
        case .depuff: [Color(hex: 0x6FCBB0), SDColor.mint]
        case .morning: [SDColor.coral, SDColor.coralWarm]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
