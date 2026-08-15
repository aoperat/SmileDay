import SwiftUI
import SwiftData
import CoachingKit

struct SmileMVPSettingsView: View {
    /// 화면을 떠나며 대기 중인 반영을 끝낸 뒤 부른다. 홈이 이 시점에 다시 읽어야
    /// "다음 알림"이 방금 정한 시각을 보여준다.
    var onScheduleApplied: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SmileReminderScheduleViewModel?
    @State private var messageViewModel: ReminderMessageViewModel?
    @State private var loadFailed = false
    /// 알림을 끄기 전에 한 번 확인한다.
    @State private var isConfirmingDisable = false

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
                        // 끄는 것은 이 앱의 유일한 흐름을 멈추는 일이라 한 번 확인한다.
                        // 켜는 것은 되돌리기 쉬우니 그대로 반영한다.
                        Toggle(isOn: Binding(
                            get: { viewModel.isEnabled },
                            set: { isOn in
                                if isOn {
                                    viewModel.updateEnabled(true)
                                } else {
                                    isConfirmingDisable = true
                                }
                            }
                        )) {
                            Text("미소 알림")
                                .foregroundStyle(SDColor.ink)
                        }
                        .tint(SDColor.sunDeep)

                        ReminderPatternControls(viewModel: viewModel)
                            .padding(.vertical, 6)

                        if let error = viewModel.error {
                            Text(error.message)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(SDColor.alert)
                        } else if !viewModel.isPatternValid {
                            Text(.invalidPattern)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(SDColor.alert)
                        }
                    } header: {
                        Text("반복 설정")
                            .foregroundStyle(SDColor.ink)
                    } footer: {
                        // 저장 버튼이 없으므로 반영됐다는 사실은 여기서 말한다.
                        Text(viewModel.isSaving ? "저장 중…" : "바꾸면 바로 적용돼요. 놓친 알림은 다시 울리거나 한꺼번에 보내지 않아요.")
                            .foregroundStyle(SDColor.muted)
                    }
                    .listRowBackground(Color.white)
                }

                if !loadFailed {
                    if let messageViewModel {
                        Section {
                            NavigationLink {
                                ReminderMessageManagementView(
                                    viewModel: messageViewModel,
                                    // 문구를 바꾸는 것만으로는 이미 예약된 알림이 바뀌지 않는다.
                                    // 저장 버튼이 없어졌으므로 여기서 재예약을 건다.
                                    onChanged: { viewModel.applyMessageChange() }
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
                    legalSection
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
        .alert(
            SharedStrings.disableRemindersConfirmTitle,
            isPresented: $isConfirmingDisable
        ) {
            // 취소하면 토글은 저절로 제자리로 돌아온다 — viewModel.isEnabled를 읽기 때문이다.
            Button(SharedStrings.disableRemindersCancelAction, role: .cancel) {}
            Button(SharedStrings.disableRemindersConfirmAction, role: .destructive) {
                viewModel?.updateEnabled(false)
            }
        } message: {
            Text(SharedStrings.disableRemindersConfirmMessage)
        }
        .task {
            if viewModel == nil {
                viewModel = SmileReminderScheduleViewModel(
                    scheduleRepository: SmileReminderScheduleRepository(modelContext: modelContext),
                    legacyReminderRepository: LegacyReminderRepository(modelContext: modelContext),
                    scheduler: UserNotificationReminderScheduler(),
                    messageStore: reminderMessageStore,
                    // 바꾼 것 자체가 결정이다. 저장 버튼을 한 번 더 누르게 하지 않는다.
                    appliesChangesImmediately: true
                )
            }
            if messageViewModel == nil {
                messageViewModel = ReminderMessageViewModel(store: reminderMessageStore)
            }
            await loadSettings()
        }
        // 시간 다이얼을 굴린 직후 뒤로 나가면 반영이 아직 지연 중이다. 여기서 끝내지
        // 않으면 홈이 옛 일정을 읽어 "다음 알림"에 지난 시각을 그린다.
        .onDisappear {
            Task {
                await viewModel?.flushPendingApply()
                onScheduleApplied()
            }
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
            .tint(SDColor.sunDeep)

            if nudgeSettings.isEnabled {
                Picker(selection: nudgeBinding(\.intervalSeconds)) {
                    ForEach(LiveSmileNudgeSettings.allowedIntervalSeconds, id: \.self) { seconds in
                        Text(SDFormat.duration(seconds: seconds)).tag(seconds)
                    }
                } label: {
                    Text(SharedStrings.liveMonitorNudgeIntervalLabel)
                        .foregroundStyle(SDColor.ink)
                }

                Toggle(isOn: nudgeBinding(\.isHapticEnabled)) {
                    Text(SharedStrings.liveMonitorNudgeHapticToggle)
                        .foregroundStyle(SDColor.ink)
                }
                .tint(SDColor.sunDeep)
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

    private var permissionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(SharedStrings.notificationDeniedNotice)
                    .font(.footnote)
                    .foregroundStyle(SDColor.ink)

                Button(SharedStrings.openSystemSettings, action: SDSystemSettings.open)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SDColor.ink)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.white)
    }

    /// 개인정보처리방침과 고객지원. 심사가 앱 안에서도 찾을 수 있기를 요구하는 링크다.
    ///
    /// 주소를 만들지 못하면 그 줄을 아예 그리지 않는다 — 눌러도 아무 일이 없는 항목을
    /// 남겨두면 링크가 있다고 믿게 만든다.
    private var legalSection: some View {
        Section {
            if let url = URL(string: SharedStrings.privacyPolicyURLString) {
                Link(destination: url) {
                    externalLinkLabel(SharedStrings.privacyPolicyTitle, systemImage: "hand.raised")
                }
            }

            if let url = URL(string: SharedStrings.supportURLString) {
                Link(destination: url) {
                    externalLinkLabel(SharedStrings.supportTitle, systemImage: "questionmark.circle")
                }
            }
        } header: {
            Text(SharedStrings.legalSectionTitle)
                .foregroundStyle(SDColor.ink)
        } footer: {
            Text(SharedStrings.legalSectionFooter)
                .foregroundStyle(SDColor.muted)
        }
        .listRowBackground(Color.white)
    }

    /// 앱 밖으로 나간다는 사실을 화살표로 알린다. VoiceOver도 같은 안내를 받는다.
    private func externalLinkLabel(_ title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(SDColor.ink)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SDColor.muted)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("사파리에서 열려요")
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
