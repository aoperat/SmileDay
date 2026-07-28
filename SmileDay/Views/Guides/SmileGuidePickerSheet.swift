import SwiftUI
import CoachingKit

/// 상황 카드 하나를 고르는 시트. 홈, 설정의 알림 행, 온보딩이 모두 이 화면을 쓴다.
struct SmileGuidePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let guides: [SmileGuide]
    let selectedID: String
    let onSelect: (SmileGuide) -> Void
    /// nil이면 추가 버튼을 감춘다. 첫 설정처럼 카드 만들기로 끌고 가지 않는 화면이 쓴다.
    var onAddCard: (() -> Void)?

    private var slots: [DaySlot] {
        DaySlot.displayOrder.filter { slot in guides.contains { $0.slot == slot } }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(slots, id: \.self) { slot in
                    Section(slot.displayName) {
                        ForEach(guides.filter { $0.slot == slot }) { guide in
                            Button {
                                onSelect(guide)
                                dismiss()
                            } label: {
                                GuideRow(guide: guide, isSelected: guide.id == selectedID)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.white)
                }

                if let onAddCard {
                    Section {
                        Button(action: onAddCard) {
                            Label(SharedStrings.addCardAction, systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SDColor.coralDeep)
                        }
                    }
                    .listRowBackground(Color.white)
                }
            }
            .scrollContentBackground(.hidden)
            .background(SDColor.cream)
            .navigationTitle(SharedStrings.pickGuideTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .tint(SDColor.coralDeep)
    }
}

private struct GuideRow: View {
    let guide: SmileGuide
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(guide.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SDColor.ink)
                    .multilineTextAlignment(.leading)
                Text(guide.instruction)
                    .font(.caption)
                    .foregroundStyle(SDColor.muted)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SDColor.coralDeep)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
