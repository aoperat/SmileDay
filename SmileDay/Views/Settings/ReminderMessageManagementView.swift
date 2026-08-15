import SwiftUI
import CoachingKit

struct ReminderMessageManagementView: View {
    let viewModel: ReminderMessageViewModel
    let onChanged: () -> Void

    @State private var editor: Editor?

    private struct Editor: Identifiable {
        let id = UUID()
        let messageID: String?
        let title: LocalizedStringResource
        var text: String
    }

    var body: some View {
        List {
            Section {
                ForEach(viewModel.messages) { message in
                    Button {
                        editor = Editor(
                            messageID: message.id,
                            title: .Settings.editMessageTitle,
                            text: message.resolvedText
                        )
                    } label: {
                        Text(message.resolvedText)
                            .foregroundStyle(SDColor.ink)
                            .multilineTextAlignment(.leading)
                    }
                    .accessibilityHint(Text(.Settings.editMessageHint))
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
                Text(.Settings.messagesListHeader)
                    .foregroundStyle(SDColor.ink)
            } footer: {
                Text(.Settings.messagesListFooter)
                    .foregroundStyle(SDColor.muted)
            }
            .listRowBackground(Color.white)
        }
        .scrollContentBackground(.hidden)
        .background(SDColor.cream)
        .navigationTitle(Text(.Settings.manageMessagesNavigationTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editor = Editor(messageID: nil, title: .Settings.addMessage, text: "")
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text(.Settings.addMessage))
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
            Text(.Settings.cannotDeleteTitle),
            isPresented: Binding(
                get: { editor == nil && viewModel.error != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button(.Settings.okAction) {
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

    let title: LocalizedStringResource
    let currentValidationMessage: () -> String?
    let onCancel: () -> Void
    let onSave: (String) -> Bool

    init(
        title: LocalizedStringResource,
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
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(.Settings.cancelAction, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(.Settings.saveAction) {
                        if !onSave(text) {
                            validationMessage = currentValidationMessage() ?? String(localized: .Settings.checkMessagePrompt)
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
