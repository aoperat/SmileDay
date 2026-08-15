import SwiftUI
import SwiftData
import UIKit
import CoachingKit

struct SmileMVPOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    let onFinished: () -> Void

    @State private var viewModel: SmileOnboardingViewModel?
    @State private var step: Step = .purpose

    private enum Step {
        case purpose
        case whyNotification
        case schedule
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
                        message: "평소 잘 웃지 않는 나를 위해,\n하루에 몇 번 잠깐 웃어보는 시간을 만들어요.",
                        detail: "표정을 찍거나 점수를 매기지 않아요. 웃어본 횟수만 이 기기에 기록해요.",
                        actionTitle: "다음",
                        action: { step = .whyNotification }
                    )
                case .whyNotification:
                    IntroStep(
                        systemImage: "bell.badge",
                        title: "잊지 않도록 알려드릴게요",
                        message: "활동 시간과 반복 주기를 정하면\n알림이 미소를 떠올려줘요.",
                        detail: "알림을 놓쳐도 재촉하거나 몰아서 보내지 않아요.",
                        actionTitle: "시간 정하기",
                        action: { step = .schedule }
                    )
                case .schedule:
                    OnboardingScheduleStep(viewModel: viewModel, onFinished: onFinished)
                }
            }
        }
        .onAppear {
            guard viewModel == nil else { return }
            let schedule = SmileReminderScheduleViewModel(
                scheduleRepository: SmileReminderScheduleRepository(modelContext: modelContext),
                legacyReminderRepository: LegacyReminderRepository(modelContext: modelContext),
                scheduler: UserNotificationReminderScheduler()
            )
            viewModel = SmileOnboardingViewModel(
                schedule: schedule,
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
        // 접근성 글씨 크기에서는 이 문구가 화면보다 길어진다. 고정 VStack이면 SwiftUI가
        // 남는 자리에 맞추려고 텍스트를 잘라내는데, 잘려나가는 문장이 하필 얼굴을 찍지
        // 않는다는 약속이다. minHeight로 평소의 가운데 정렬은 지키고, 넘칠 때만 스크롤한다.
        // 마지막 단계(OnboardingScheduleStep)는 이미 같은 이유로 ScrollView 안에 있다.
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 0)

                    Image(systemName: systemImage)
                        .font(.system(size: 64))
                        .foregroundStyle(SDColor.sunDeep)
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

                    Spacer(minLength: 0)

                    Button(actionTitle, action: action)
                        .buttonStyle(SDPrimaryButtonStyle())
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
    }
}

private struct OnboardingScheduleStep: View {
    let viewModel: SmileOnboardingViewModel
    let onFinished: () -> Void

    @State private var isConfirmingSkip = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("미소 알림")
                        .font(.title2.bold())
                        .foregroundStyle(SDColor.ink)
                    Text("정한 시간 안에서 같은 간격으로 알려드려요.")
                        .font(.body)
                        .foregroundStyle(SDColor.muted)
                }

                ReminderPatternControls(viewModel: viewModel.schedule)
                    .sdCard()

                if let error = viewModel.error {
                    Text(error.message)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SDColor.alert)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if !viewModel.schedule.isPatternValid {
                    Text(.invalidPattern)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SDColor.alert)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task {
                        await viewModel.confirm()
                        if viewModel.didComplete { onFinished() }
                    }
                } label: {
                    if viewModel.isSaving {
                        // 버튼이 노랑이라 흰 스피너는 1.7:1로 사실상 보이지 않는다.
                        ProgressView().tint(SDColor.ink)
                    } else {
                        Text("이 시간으로 시작하기")
                    }
                }
                .buttonStyle(SDPrimaryButtonStyle())
                .disabled(viewModel.isSaving || viewModel.schedule.pattern == nil)

                // 알림이 이 앱의 유일한 흐름이라 한 번 더 확인한다. 막지는 않는다.
                Button("알림 없이 시작하기") { isConfirmingSkip = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SDColor.ink)
                    .frame(maxWidth: .infinity)

                Text("알림 권한을 허용하지 않아도 앱에서 직접 미소 시간을 시작할 수 있어요.")
                    .font(.footnote)
                    .foregroundStyle(SDColor.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        // alert를 쓴다. confirmationDialog는 .cancel 역할 버튼의 문구를 제 것으로 바꿔버려
        // "알림 받을래요"라는 선택지가 사라지고, 되돌릴 방법이 없는 것처럼 보인다.
        // 한 번 더 묻는 의미는 두 선택지가 나란히 보일 때만 생긴다.
        .alert(
            Text(.skipRemindersConfirmTitle),
            isPresented: $isConfirmingSkip
        ) {
            Button(.skipRemindersCancelAction, role: .cancel) {}
            Button(.skipRemindersConfirmAction, role: .destructive) {
                Task {
                    await viewModel.skipReminders()
                    if viewModel.didComplete { onFinished() }
                }
            }
        } message: {
            Text(.skipRemindersConfirmMessage)
        }
        // 시스템 권한 대화상자는 한 번만 뜬다. 거부했다면 앱에서 다시 물을 수 없으므로
        // 무엇이 없어졌는지와 어디서 되돌리는지를 여기서 알려준다.
        .alert(
            Text(.onboardingPermissionDeniedTitle),
            isPresented: .constant(viewModel.wasPermissionDenied)
        ) {
            Button(.openSystemSettings) {
                SDSystemSettings.open()
                viewModel.continueWithoutPermission()
                if viewModel.didComplete { onFinished() }
            }
            Button(.onboardingContinueAnyway, role: .cancel) {
                viewModel.continueWithoutPermission()
                if viewModel.didComplete { onFinished() }
            }
        } message: {
            Text(.onboardingPermissionDeniedMessage)
        }
    }
}

struct ReminderPatternControls: View {
    let viewModel: SmileReminderScheduleViewModel

    private var startTime: Binding<Date> {
        timeBinding(hour: viewModel.startHour, minute: viewModel.startMinute) {
            viewModel.updateStart(hour: $0, minute: $1)
        }
    }

    private var endTime: Binding<Date> {
        timeBinding(hour: viewModel.endHour, minute: viewModel.endMinute) {
            viewModel.updateEnd(hour: $0, minute: $1)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            DatePicker("시작 시간", selection: startTime, displayedComponents: .hourAndMinute)
                .foregroundStyle(SDColor.ink)

            Divider()

            DatePicker("종료 시간", selection: endTime, displayedComponents: .hourAndMinute)
                .foregroundStyle(SDColor.ink)

            Divider()

            Picker("반복 주기", selection: Binding(
                get: { viewModel.intervalMinutes },
                set: { viewModel.updateInterval($0) }
            )) {
                ForEach(SmileReminderPattern.allowedIntervals, id: \.self) { minutes in
                    Text(SDFormat.reminderInterval(minutes: minutes)).tag(minutes)
                }
            }
            .foregroundStyle(SDColor.ink)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(SDColor.ink)
                        .accessibilityHidden(true)
                    Text("하루 \(viewModel.occurrenceTimes.count)번 알려드려요")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SDColor.ink)
                }

                // 22:00~02:00을 잘못 고른 것으로 읽지 않게, 그렇게 이해했다고 말해준다.
                if viewModel.crossesMidnight {
                    Text(.reminderWindowCrossesMidnight)
                        .font(.caption)
                        .foregroundStyle(SDColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(SDColor.shell, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func timeBinding(
        hour: Int,
        minute: Int,
        update: @escaping (Int, Int) -> Void
    ) -> Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                update(components.hour ?? hour, components.minute ?? minute)
            }
        )
    }
}
