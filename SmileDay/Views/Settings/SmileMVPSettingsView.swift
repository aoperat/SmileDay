import SwiftUI
import SwiftData
import CoachingKit

struct SmileMVPSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SmileReminderScheduleViewModel?
    @State private var messageViewModel: ReminderMessageViewModel?
    @State private var didSave = false
    @State private var loadFailed = false

    private let reminderMessageStore = UserDefaultsReminderMessageStore()
    private let nudgeStore = UserDefaultsLiveSmileNudgeSettingsStore()
    /// 실시간 확인 알림 설정. 바꾸는 즉시 저장한다 — 따로 저장 버튼을 두지 않는다.
    @State private var nudgeSettings = LiveSmileNudgeSettings.default

    var body: some View {
        List {
            if let viewModel {
                if loadFailed {
                    Section {
                        AppDataLoadFailureView {
                            Task { await loadSettings() }
                        }
                        .listRowInsets(EdgeInsets())
                    }
                    .listRowBackground(SDColor.cream)
                } else if viewModel.authorizationStatus == .denied {
                    permissionSection
                }

                if !loadFailed {
                    Section {
                        Toggle(isOn: Binding(
                            get: { viewModel.isEnabled },
                            set: { viewModel.updateEnabled($0) }
                        )) {
                            Text("미소 알림")
                                .foregroundStyle(SDColor.ink)
                        }
                        .tint(SDColor.coralDeep)

                        ReminderPatternControls(viewModel: viewModel)
                            .padding(.vertical, 6)

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(SDColor.alert)
                        } else if viewModel.pattern == nil {
                            Text("종료 시간은 시작 시간보다 늦어야 해요.")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(SDColor.alert)
                        }

                        Button {
                            Task {
                                didSave = await viewModel.save(requestAuthorization: viewModel.isEnabled)
                            }
                        } label: {
                            Text(viewModel.isSaving ? "저장 중…" : "알림 설정 저장")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SDInkButtonStyle())
                        .disabled(viewModel.isSaving || viewModel.pattern == nil)
                    } header: {
                        Text("반복 설정")
                            .foregroundStyle(SDColor.ink)
                    } footer: {
                        Text("놓친 알림은 다시 울리거나 한꺼번에 보내지 않아요.")
                            .foregroundStyle(SDColor.muted)
                    }
                    .listRowBackground(Color.white)
                }

                if didSave && !loadFailed {
                    Section {
                        Label("알림 설정을 저장했어요", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(SDColor.ink)
                    }
                    .listRowBackground(Color.white)
                }

                if !loadFailed {
                    if let messageViewModel {
                        Section {
                            NavigationLink {
                                ReminderMessageManagementView(
                                    viewModel: messageViewModel,
                                    onChanged: { didSave = false }
                                )
                            } label: {
                                HStack {
                                    Label("메시지 관리", systemImage: "text.bubble")
                                        .foregroundStyle(SDColor.ink)
                                    Spacer()
                                    Text("\(messageViewModel.messages.count)개")
                                        .foregroundStyle(SDColor.muted)
                                }
                            }
                        } header: {
                            Text("알림 문구")
                                .foregroundStyle(SDColor.ink)
                        } footer: {
                            Text("추가·수정·삭제하거나 순서를 바꿀 수 있어요.")
                                .foregroundStyle(SDColor.muted)
                        }
                        .listRowBackground(Color.white)
                    }

                    liveMonitorNudgeSection
                    dataSection
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(SDColor.cream)
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbarBackground(SDColor.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            if viewModel == nil {
                viewModel = SmileReminderScheduleViewModel(
                    scheduleRepository: SmileReminderScheduleRepository(modelContext: modelContext),
                    legacyReminderRepository: LegacyReminderRepository(modelContext: modelContext),
                    scheduler: UserNotificationReminderScheduler(),
                    messageStore: reminderMessageStore
                )
            }
            if messageViewModel == nil {
                messageViewModel = ReminderMessageViewModel(store: reminderMessageStore)
            }
            await loadSettings()
        }
    }

    private func loadSettings() async {
        do {
            try viewModel?.refresh()
            await viewModel?.refreshAuthorizationStatus()
            nudgeSettings = nudgeStore.settings
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    private var liveMonitorNudgeSection: some View {
        Section {
            Toggle(isOn: nudgeBinding(\.isEnabled)) {
                Text(SharedStrings.liveMonitorNudgeToggle)
                    .foregroundStyle(SDColor.ink)
            }
            .tint(SDColor.coralDeep)

            if nudgeSettings.isEnabled {
                Picker(selection: nudgeBinding(\.intervalSeconds)) {
                    ForEach(LiveSmileNudgeSettings.allowedIntervalSeconds, id: \.self) { seconds in
                        Text(intervalLabel(seconds)).tag(seconds)
                    }
                } label: {
                    Text(SharedStrings.liveMonitorNudgeIntervalLabel)
                        .foregroundStyle(SDColor.ink)
                }

                Toggle(isOn: nudgeBinding(\.isHapticEnabled)) {
                    Text(SharedStrings.liveMonitorNudgeHapticToggle)
                        .foregroundStyle(SDColor.ink)
                }
                .tint(SDColor.coralDeep)
            }
        } header: {
            Text(SharedStrings.liveMonitorNudgeSectionTitle)
                .foregroundStyle(SDColor.ink)
        } footer: {
            Text(SharedStrings.liveMonitorNudgeFooter)
                .foregroundStyle(SDColor.muted)
        }
        .listRowBackground(Color.white)
    }

    /// 바꾸는 즉시 저장하는 바인딩. 저장 버튼 없이 토글 하나로 끝난다.
    private func nudgeBinding<Value>(
        _ keyPath: WritableKeyPath<LiveSmileNudgeSettings, Value>
    ) -> Binding<Value> {
        Binding(
            get: { nudgeSettings[keyPath: keyPath] },
            set: { newValue in
                nudgeSettings[keyPath: keyPath] = newValue
                nudgeStore.settings = nudgeSettings
            }
        )
    }

    private func intervalLabel(_ seconds: Int) -> String {
        guard seconds >= 60 else { return "\(seconds)초" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return remainder == 0 ? "\(minutes)분" : "\(minutes)분 \(remainder)초"
    }

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
                .foregroundStyle(SDColor.ink)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.white)
    }

    private var dataSection: some View {
        Section {
            Label("모든 기록은 이 기기에만 저장됩니다", systemImage: "iphone")
                .foregroundStyle(SDColor.ink)
            Label("외부 서버로 전송되지 않습니다", systemImage: "lock.shield")
                .foregroundStyle(SDColor.ink)
            Label("앱을 삭제하면 모든 기록이 함께 삭제됩니다", systemImage: "trash")
                .foregroundStyle(SDColor.ink)
        } header: {
            Text("데이터 저장 위치")
                .foregroundStyle(SDColor.ink)
        } footer: {
            Text("완료한 시각만 저장해요. 실시간 확인은 사진을 남기지 않고, 그 결과도 화면을 닫으면 사라져요.")
                .foregroundStyle(SDColor.muted)
        }
        .listRowBackground(Color.white)
    }
}
