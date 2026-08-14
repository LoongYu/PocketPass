import SwiftUI

struct TagPickerView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding private var selectedTags: [String]
    @State private var draftSelection: Set<String>
    @State private var newTag = ""

    init(selectedTags: Binding<[String]>) {
        _selectedTags = selectedTags
        _draftSelection = State(initialValue: Set(selectedTags.wrappedValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                InterfaceBrandLogoView()
                Text("选择标签").font(.title2.bold())
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(.bordered)
                Button("完成") {
                    selectedTags = draftSelection.sorted()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(PocketTheme.primaryButton).foregroundStyle(PocketTheme.primaryButtonText)
            }

            HStack(spacing: 12) {
                TextField("新建标签", text: $newTag)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    .background(PocketTheme.card).clipShape(Capsule())
                    .onSubmit { createTag() }
                Button("添加") { createTag() }
                    .buttonStyle(.borderedProminent)
                    .tint(PocketTheme.accent).foregroundStyle(.black)
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if store.allTags.isEmpty {
                Text("暂无标签，可在上方新建")
                    .font(.callout).foregroundStyle(PocketTheme.muted)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                        ForEach(store.allTags, id: \.self) { tag in
                            Button {
                                if draftSelection.contains(tag) { draftSelection.remove(tag) }
                                else { draftSelection.insert(tag) }
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: draftSelection.contains(tag) ? "checkmark" : "tag.fill")
                                    Text(tag).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 14).padding(.vertical, 11)
                                .background(draftSelection.contains(tag) ? PocketTheme.accent : PocketTheme.card)
                                .foregroundStyle(draftSelection.contains(tag) ? .black : PocketTheme.primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(width: 520, height: 500)
        .background(PocketTheme.background)
        .buttonBorderShape(.capsule)
    }

    private func createTag() {
        let value = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        store.addTag(value)
        draftSelection.insert(value)
        newTag = ""
    }
}
