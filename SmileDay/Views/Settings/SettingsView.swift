import SwiftUI
import SwiftData
import CoachingKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?
    @State private var isResettingBaseline = false

    let onBaselineUpdated: (Baseline) -> Void

    var body: some View {
        NavigationStack {
            List {
                if let viewModel {
                    Section {
                        NavigationLink {
                            ReminderListView(viewModel: viewModel)
                        } label: {
                            SettingsRow(icon: "bell.fill", chipColor: SDColor.apricot, title: "리마인더") {
                                Text("\(viewModel.reminders.count)개")
                                    .foregroundStyle(SDColor.muted)
                            }
                        }

                        Button {
                            isResettingBaseline = true
                        } label: {
                            SettingsRow(icon: "arrow.clockwise", chipColor: SDColor.coral, title: "기준 표정 다시 찍기") {
                                VStack(alignment: .trailing, spacing: 2) {
                                    if let weeks = viewModel.baselineAgeWeeks {
                                        Text("\(weeks)주 전")
                                            .foregroundStyle(SDColor.muted)
                                    }
                                    if viewModel.shouldRecommendReset {
                                        Text("원하면 다시 찍어도 돼요")
                                            .font(.caption2)
                                            .foregroundStyle(SDColor.muted)
                                    }
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .listRowBackground(Color.white)

                    Section {
                        NavigationLink {
                            DataLocationView()
                        } label: {
                            SettingsRow(icon: "lock.fill", chipColor: SDColor.mint, title: "데이터 저장 위치") {
                                Text("기기에만 저장")
                                    .foregroundStyle(SDColor.muted)
                            }
                        }

                        SettingsRow(icon: "person.fill", chipColor: SDColor.lilac, title: "계정") {
                            Text("준비 중")
                                .foregroundStyle(.tertiary)
                        }
                    } footer: {
                        Text("모든 기록은 회원가입 없이 이 기기 안에만 저장돼요. 사진과 영상은 저장하지 않아요.")
                            .font(.caption)
                            .foregroundStyle(SDColor.muted)
                    }
                    .listRowBackground(Color.white)
                }
            }
            .scrollContentBackground(.hidden)
            .background(SDColor.cream)
            .navigationTitle("설정")
            // NavigationStack 내부에서도 네이티브 탭바가 다시 나타나지 않도록 명시한다.
            .toolbar(.hidden, for: .tabBar)
        }
        .tint(SDColor.coral)
        .onAppear {
            let vm = viewModel ?? SettingsViewModel(
                reminderRepository: ReminderRepository(modelContext: modelContext),
                sessionRepository: SessionRepository(modelContext: modelContext),
                scheduler: UserNotificationReminderScheduler()
            )
            viewModel = vm
            try? vm.refresh()
        }
        .fullScreenCover(isPresented: $isResettingBaseline) {
            BaselineCaptureView(
                onBaselineSaved: { newBaseline in
                    onBaselineUpdated(newBaseline)
                    isResettingBaseline = false
                    try? viewModel?.refresh()
                },
                onCancel: { isResettingBaseline = false }
            )
        }
    }
}

struct SettingsRow<Trailing: View>: View {
    let icon: String
    let chipColor: Color
    let title: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(chipColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SDColor.ink)

            Spacer()

            trailing
                .font(.footnote.weight(.medium))
        }
        .padding(.vertical, 2)
    }
}
