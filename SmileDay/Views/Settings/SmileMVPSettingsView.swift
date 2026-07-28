import SwiftUI
import SwiftData
import CoachingKit

/// 알림 CRUD, 미소 카드 관리, 데이터 저장 위치. 기준선 재촬영과 Pro는 없다.
struct SmileMVPSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?
    @State private var libraryViewModel: SmileLibraryViewModel?

    @State private var newTime = Date()
    @State private var newGuide: SmileGuide = SmileGuideCatalog.default
    @State private var isPickingNewGuide = false
    @State private var editingReminder: ReminderSetting?
    @State private var isAddingCard = false
    @State private var pendingRemoval: GuideRemovalImpact?

    private var guides: [SmileGuide] { libraryViewModel?.guides ?? [] }

    var body: some View {
        List {
            if let viewModel, let libraryViewModel {
                if viewModel.authorizationStatus == .denied {
                    permissionSection
                }

                remindersSection(viewModel)
                addReminderSection(viewModel)
                cardsSection(libraryViewModel)
                if !libraryViewModel.hiddenGuides.isEmpty {
                    hiddenCardsSection(libraryViewModel)
                }
                dataSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(SDColor.cream)
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                let library = SmileGuideLibrary(
                    modelContext: modelContext,
                    hiddenStore: UserDefaultsHiddenSmileGuideStore()
                )
                viewModel = SettingsViewModel(
                    reminderRepository: ReminderRepository(modelContext: modelContext),
                    sessionRepository: SessionRepository(modelContext: modelContext),
                    library: library,
                    scheduler: UserNotificationReminderScheduler()
                )
                libraryViewModel = SmileLibraryViewModel(
                    library: library,
                    reminderRepository: ReminderRepository(modelContext: modelContext),
                    scheduler: UserNotificationReminderScheduler()
                )
            }
            try? viewModel?.refresh()
            try? libraryViewModel?.refresh()
            await viewModel?.refreshAuthorizationStatus()
        }
        .sheet(isPresented: $isPickingNewGuide) {
            SmileGuidePickerSheet(
                guides: guides,
                selectedID: newGuide.id,
                onSelect: { newGuide = $0 },
                onAddCard: {
                    isPickingNewGuide = false
                    isAddingCard = true
                }
            )
        }
        .sheet(item: $editingReminder) { reminder in
            if let viewModel {
                SmileGuidePickerSheet(
                    guides: guides,
                    selectedID: viewModel.guide(for: reminder).id,
                    onSelect: { guide in
                        Task { try? await viewModel.updateReminderGuide(reminder, guideID: guide.id) }
                    },
                    onAddCard: {
                        editingReminder = nil
                        isAddingCard = true
                    }
                )
            }
        }
        .sheet(isPresented: $isAddingCard) {
            if let libraryViewModel {
                AddSmileCardView(viewModel: libraryViewModel) { added in
                    newGuide = added
                }
            }
        }
        .alert("이 카드를 지울까요?", isPresented: Binding(
            get: { pendingRemoval != nil },
            set: { if !$0 { pendingRemoval = nil } }
        )) {
            Button("취소", role: .cancel) { pendingRemoval = nil }
            Button(SharedStrings.deleteCardAction, role: .destructive) {
                guard let impact = pendingRemoval else { return }
                pendingRemoval = nil
                Task {
                    try? await libraryViewModel?.remove(impact.guide)
                    try? viewModel?.refresh()
                }
            }
        } message: {
            if let impact = pendingRemoval {
                if impact.isInUse {
                    Text("이 카드를 쓰는 알림이 \(impact.affectedReminderTimes.count)개 있어요.\n\(impact.affectedReminderTimes.joined(separator: ", "))\n\n지우면 이 알림들은 '\(impact.replacement.title)'로 바뀝니다.")
                } else {
                    Text("'\(impact.guide.title)'를 목록에서 지웁니다.")
                }
            }
        }
    }

    // MARK: - 섹션

    private var permissionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(SharedStrings.notificationDeniedNotice)
                    .font(.footnote)
                    .foregroundStyle(SDColor.ink)

                Button(SharedStrings.openSystemSettings) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SDColor.coralDeep)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.white)
    }

    private func remindersSection(_ viewModel: SettingsViewModel) -> some View {
        Section("내 알림") {
            if viewModel.reminders.isEmpty {
                Text(SharedStrings.noReminderYet)
                    .font(.subheadline)
                    .foregroundStyle(SDColor.muted)
            }

            ForEach(viewModel.reminders, id: \.notificationID) { reminder in
                ReminderRow(
                    reminder: reminder,
                    guide: viewModel.guide(for: reminder),
                    viewModel: viewModel,
                    onPickGuide: { editingReminder = reminder }
                )
            }
            .onDelete { indexSet in
                for index in indexSet {
                    try? viewModel.removeReminder(viewModel.reminders[index])
                }
            }
        }
        .listRowBackground(Color.white)
    }

    private func addReminderSection(_ viewModel: SettingsViewModel) -> some View {
        Section("알림 추가") {
            DatePicker("시간", selection: $newTime, displayedComponents: .hourAndMinute)

            GuideSelectionRow(guide: newGuide) { isPickingNewGuide = true }
                .padding(.vertical, 2)

            Button("추가") {
                let components = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                Task {
                    try? await viewModel.addReminder(
                        hour: components.hour ?? 9,
                        minute: components.minute ?? 0,
                        guideID: newGuide.id
                    )
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .listRowBackground(Color.white)
    }

    private func cardsSection(_ libraryViewModel: SmileLibraryViewModel) -> some View {
        Section {
            ForEach(libraryViewModel.guides) { guide in
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(guide.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SDColor.ink)
                        Text(guide.slot.displayName)
                            .font(.caption)
                            .foregroundStyle(SDColor.muted)
                    }

                    Spacer(minLength: 8)

                    Button(guide.isBuiltIn ? SharedStrings.hideCardAction : SharedStrings.deleteCardAction) {
                        pendingRemoval = try? libraryViewModel.removalImpact(for: guide)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SDColor.alert)
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 2)
            }

            Button(SharedStrings.addCardAction) { isAddingCard = true }
                .font(.subheadline.weight(.semibold))
        } header: {
            Text(SharedStrings.myCardsTitle)
        } footer: {
            Text("기본 카드는 숨겼다가 언제든 되돌릴 수 있어요.")
                .font(.caption)
                .foregroundStyle(SDColor.muted)
        }
        .listRowBackground(Color.white)
    }

    private func hiddenCardsSection(_ libraryViewModel: SmileLibraryViewModel) -> some View {
        Section(SharedStrings.hiddenCardsTitle) {
            ForEach(libraryViewModel.hiddenGuides) { guide in
                HStack {
                    Text(guide.title)
                        .font(.subheadline)
                        .foregroundStyle(SDColor.muted)

                    Spacer()

                    Button(SharedStrings.restoreCardAction) {
                        try? libraryViewModel.restore(guide)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SDColor.coralDeep)
                    .buttonStyle(.borderless)
                }
            }
        }
        .listRowBackground(Color.white)
    }

    private var dataSection: some View {
        Section {
            Label("모든 기록은 이 기기에만 저장됩니다", systemImage: "iphone")
            Label("외부 서버로 전송되지 않습니다", systemImage: "lock.shield")
            Label("앱을 삭제하면 모든 기록이 함께 삭제됩니다", systemImage: "trash")
        } header: {
            Text("데이터 저장 위치")
        } footer: {
            Text("완료한 시각과 어떤 카드였는지만 저장해요. 사진과 영상은 찍지도, 저장하지도 않아요.")
                .font(.caption)
                .foregroundStyle(SDColor.muted)
        }
        .listRowBackground(Color.white)
    }
}

private struct ReminderRow: View {
    let reminder: ReminderSetting
    let guide: SmileGuide
    let viewModel: SettingsViewModel
    let onPickGuide: () -> Void

    private var time: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = reminder.hour
                components.minute = reminder.minute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                Task {
                    try? await viewModel.updateReminderTime(
                        reminder,
                        hour: components.hour ?? reminder.hour,
                        minute: components.minute ?? reminder.minute
                    )
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                DatePicker("알림 시간", selection: time, displayedComponents: .hourAndMinute)
                    .labelsHidden()

                Spacer()

                Toggle("알림 켜기", isOn: Binding(
                    get: { reminder.isEnabled },
                    set: { _ in Task { try? await viewModel.toggleReminder(reminder) } }
                ))
                .labelsHidden()
            }

            GuideSelectionRow(guide: guide, onTap: onPickGuide)
        }
        .padding(.vertical, 4)
    }
}
