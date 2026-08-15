import SwiftUI
import CoachingKit

struct ReminderMessageManagementView: View {
    let viewModel: ReminderMessageViewModel
    let onChanged: () -> Void

    @State private var editor: Editor?

    private struct Editor: Identifiable {
        let id = UUID()
        let messageID: String?
        let title: String
        var text: String
    }

    var body: some View {
        List {
            Section {
                ForEach(viewModel.messages) { message in
                    Button {
                        editor = Editor(
                            messageID: message.id,
                            title: "메시지 수정",
                            text: message.resolvedText
                        )
                    } label: {
                        Text(message.resolvedText)
                            .foregroundStyle(SDColor.ink)
                            .multilineTextAlignment(.leading)
                    }
                    .accessibilityHint("두 번 탭하여 메시지를 수정합니다")
                }
                .onMove { source, destination in
                    viewModel.move(fromOffsets: source, toOffset: destination)
                    onChanged()
                }
                .onDelete { offsets in
                    for index in offsets.sorted(by: >) {
                        if viewModel.remove(id: viewModel.messages[index].id) {
                            onChanged()
                        }
                    }
                }
            } header: {
                Text("알림 메시지")
                    .foregroundStyle(SDColor.ink)
            } footer: {
                Text("위에서부터 알림 시간 순서대로 반복해 사용해요. 바꾸면 다음 알림부터 바로 적용돼요.")
                    .foregroundStyle(SDColor.muted)
            }
            .listRowBackground(Color.white)
        }
        .scrollContentBackground(.hidden)
        .background(SDColor.cream)
        .navigationTitle("메시지 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editor = Editor(messageID: nil, title: "메시지 추가", text: "")
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("메시지 추가")
            }
        }
        .sheet(item: $editor) { editor in
            ReminderMessageEditor(
                title: editor.title,
                initialText: editor.text,
                validationMessage: { viewModel.error?.message },
                onCancel: {
                    viewModel.clearError()
                    self.editor = nil
                },
                onSave: { text in
                    let didSave: Bool
                    if let messageID = editor.messageID {
                        didSave = viewModel.update(id: messageID, text: text)
                    } else {
                        didSave = viewModel.add(text: text)
                    }
                    if didSave {
                        onChanged()
                        self.editor = nil
                    }
                    return didSave
                }
            )
            .presentationDetents([.medium])
        }
        .alert(
            "메시지를 삭제할 수 없어요",
            isPresented: Binding(
                get: { editor == nil && viewModel.error != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("확인") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.error?.message ?? "")
        }
    }
}

private struct ReminderMessageEditor: View {
    @FocusState private var isFocused: Bool
    @State private var text: String
    @State private var validationMessage: String?

    let title: String
    let currentValidationMessage: () -> String?
    let onCancel: () -> Void
    let onSave: (String) -> Bool

    init(
        title: String,
        initialText: String,
        validationMessage: @escaping () -> String?,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Bool
    ) {
        self.title = title
        currentValidationMessage = validationMessage
        self.onCancel = onCancel
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .focused($isFocused)
                        .frame(minHeight: 100)
                        .foregroundStyle(SDColor.ink)

                    Text("\(text.count)/100")
                        .font(.caption)
                        .foregroundStyle(text.count > 100 ? SDColor.alert : SDColor.muted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } footer: {
                    if let validationMessage {
                        Text(validationMessage)
                            .foregroundStyle(SDColor.alert)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        if !onSave(text) {
                            validationMessage = currentValidationMessage() ?? "메시지를 확인해주세요."
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}
