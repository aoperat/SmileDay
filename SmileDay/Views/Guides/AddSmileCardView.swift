import SwiftUI
import CoachingKit

/// 내 상황 카드를 만드는 시트. 제목만 있으면 되고 안내 문구는 비워둘 수 있다.
struct AddSmileCardView: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: SmileLibraryViewModel
    /// 만든 카드를 바로 고르고 싶은 화면이 쓴다.
    var onAdded: (SmileGuide) -> Void = { _ in }

    @State private var title = ""
    @State private var instruction = ""
    @State private var slot: DaySlot = .anytime

    private var isTitleBlank: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(SharedStrings.cardTitleLabel) {
                    TextField(SharedStrings.cardTitlePlaceholder, text: $title)
                }
                .listRowBackground(Color.white)

                Section {
                    TextField(SmileGuideCatalog.defaultInstruction, text: $instruction, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text(SharedStrings.cardInstructionLabel)
                } footer: {
                    Text(SharedStrings.cardInstructionHint)
                        .font(.caption)
                        .foregroundStyle(SDColor.muted)
                }
                .listRowBackground(Color.white)

                Section(SharedStrings.cardSlotLabel) {
                    Picker(SharedStrings.cardSlotLabel, selection: $slot) {
                        ForEach(DaySlot.displayOrder, id: \.self) { slot in
                            Text(slot.displayName).tag(slot)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.white)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(SDColor.alert)
                        .listRowBackground(Color.white)
                }
            }
            .scrollContentBackground(.hidden)
            .background(SDColor.cream)
            .navigationTitle("카드 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(isTitleBlank)
                }
            }
        }
        .tint(SDColor.coralDeep)
    }

    private func save() {
        do {
            onAdded(try viewModel.addCard(title: title, instruction: instruction, slot: slot))
            dismiss()
        } catch {
            // viewModel.errorMessage가 폼 안에 표시된다.
        }
    }
}
