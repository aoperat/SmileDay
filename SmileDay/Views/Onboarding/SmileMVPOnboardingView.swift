import SwiftUI
import SwiftData
import CoachingKit

/// 첫 실행 설정. 카메라도 기준선도 없다.
/// 사용자가 알림 시간을 확정한 다음에야 권한을 묻고, 거부해도 앱에는 들어갈 수 있다.
struct SmileMVPOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    let onFinished: () -> Void

    @State private var viewModel: SmileOnboardingViewModel?
    @State private var step: Step = .purpose

    private enum Step {
        case purpose
        case whyNotification
        case reminders
    }

    var body: some View {
        ZStack {
            SDColor.cream.ignoresSafeArea()

            if let viewModel {
                switch step {
                case .purpose:
                    IntroStep(
                        systemImage: "face.smiling",
                        title: "스마일데이",
                        message: "원하는 시간에 알림을 받고,\n잠깐 미소 짓는 습관을 만들어보세요.",
                        detail: "표정을 찍거나 점수를 매기지 않아요. 알림을 받고 몇 초 웃어본 것만 기록해요.",
                        actionTitle: "다음",
                        action: { step = .whyNotification }
                    )
                case .whyNotification:
                    IntroStep(
                        systemImage: "bell.badge",
                        title: "잊지 않도록 알려드릴게요",
                        message: "미소는 마음먹는다고 떠오르지 않아요.\n정해둔 시간에 알림이 대신 떠올려줍니다.",
                        detail: "알림은 이 기기 안에서만 울려요. 서버로 보내는 정보는 없어요.",
                        actionTitle: "시간 정하기",
                        action: { step = .reminders }
                    )
                case .reminders:
                    ReminderSetupStep(viewModel: viewModel, onFinished: onFinished)
                }
            }
        }
        .onAppear {
            guard viewModel == nil else { return }
            viewModel = SmileOnboardingViewModel(
                reminderRepository: ReminderRepository(modelContext: modelContext),
                scheduler: UserNotificationReminderScheduler(),
                store: UserDefaultsSmileOnboardingStore()
            )
        }
    }
}

private struct IntroStep: View {
    let systemImage: String
    let title: String
    let message: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundStyle(SDColor.coral)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2.bold())
                .foregroundStyle(SDColor.ink)

            Text(message)
                .font(.body)
                .foregroundStyle(SDColor.ink)
                .multilineTextAlignment(.center)

            Text(detail)
                .font(.footnote)
                .foregroundStyle(SDColor.muted)
                .multilineTextAlignment(.center)

            Spacer()

            Button(actionTitle, action: action)
                .buttonStyle(SDPrimaryButtonStyle())
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }
}

/// 권장 시간 3개를 보여주고 사용자가 확정하게 한다.
private struct ReminderSetupStep: View {
    let viewModel: SmileOnboardingViewModel
    let onFinished: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("언제 미소를 떠올릴까요?")
                    .font(.title3.bold())
                    .foregroundStyle(SDColor.ink)
                Text("시간과 미소를 바꿀 수 있어요. 나중에 설정에서 언제든 고칠 수 있어요.")
                    .font(.footnote)
                    .foregroundStyle(SDColor.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.drafts) { draft in
                        ReminderDraftRow(draft: draft, viewModel: viewModel)
                    }

                    Button {
                        viewModel.addDraft()
                    } label: {
                        Label("시간 추가", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SDColor.coral)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            VStack(spacing: 12) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(SDColor.coralDeep)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        await viewModel.confirm()
                        if viewModel.didComplete { onFinished() }
                    }
                } label: {
                    Text(viewModel.drafts.isEmpty ? "알림 없이 시작하기" : "이 시간으로 시작하기")
                }
                .buttonStyle(SDPrimaryButtonStyle())
                .disabled(viewModel.isSaving)

                Text("다음 단계에서 알림 권한을 물어봐요. 허용하지 않아도 앱은 사용할 수 있어요.")
                    .font(.caption)
                    .foregroundStyle(SDColor.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
}

private struct ReminderDraftRow: View {
    let draft: ReminderDraft
    let viewModel: SmileOnboardingViewModel

    private var time: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = draft.hour
                components.minute = draft.minute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                viewModel.updateTime(
                    draftID: draft.id,
                    hour: components.hour ?? draft.hour,
                    minute: components.minute ?? draft.minute
                )
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                DatePicker("알림 시간", selection: time, displayedComponents: .hourAndMinute)
                    .labelsHidden()

                Spacer()

                Button {
                    viewModel.removeDraft(id: draft.id)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(SDColor.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("이 시간 지우기")
            }

            GuidePickerRow(selectedID: draft.guideID, guides: viewModel.guides) { guideID in
                viewModel.updateGuide(draftID: draft.id, guideID: guideID)
            }
        }
        .sdCard(padding: 14, cornerRadius: 18)
    }
}
