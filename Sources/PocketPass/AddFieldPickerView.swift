import SwiftUI

private struct FieldTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let isSecret: Bool
}

struct AddFieldPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String, Bool) -> Void
    @State private var showingCustomField = false

    private let templates = [
        FieldTemplate(name: "账户", icon: "person.crop.circle", isSecret: false),
        FieldTemplate(name: "密码", icon: "key.fill", isSecret: true),
        FieldTemplate(name: "手机号", icon: "phone.fill", isSecret: false),
        FieldTemplate(name: "邮箱", icon: "envelope.fill", isSecret: false),
        FieldTemplate(name: "网址", icon: "link", isSecret: false),
        FieldTemplate(name: "ID", icon: "number", isSecret: false),
        FieldTemplate(name: "昵称", icon: "person.fill", isSecret: false),
        FieldTemplate(name: "注册时间", icon: "calendar", isSecret: false)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                InterfaceBrandLogoView()
                Text("添加字段").font(.title2.bold())
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(PocketTheme.card).clipShape(Capsule())
            }
            .padding(.horizontal, 26).padding(.vertical, 20)

            VStack(spacing: 0) {
                ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                    Button {
                        addField(name: template.name, isSecret: template.isSecret)
                    } label: {
                        HStack(spacing: 18) {
                            Image(systemName: template.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(PocketTheme.primary.opacity(0.78))
                                .frame(width: 26)
                            Text(template.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(PocketTheme.primary.opacity(0.9))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 53)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < templates.count - 1 {
                        Divider().opacity(0.2).padding(.leading, 20)
                    }
                }
            }
            .background(PocketTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 26)

            Button { showingCustomField = true } label: {
                Label("自定义", systemImage: "plus.circle")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .background(PocketTheme.card)
            .clipShape(Capsule())
            .padding(.horizontal, 26).padding(.top, 16)

            Spacer(minLength: 22)
        }
        .frame(width: 470, height: 570)
        .background(PocketTheme.background)
        .buttonBorderShape(.capsule)
        .sheet(isPresented: $showingCustomField) {
            CustomFieldNameView { name in
                addField(name: name, isSecret: false)
            }
        }
    }

    private func addField(name: String, isSecret: Bool) {
        onSelect(name, isSecret)
        dismiss()
    }
}

private struct CustomFieldNameView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String) -> Void
    @State private var name = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                InterfaceBrandLogoView()
                Text("自定义字段").font(.title2.bold())
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(PocketTheme.card).clipShape(Capsule())
                Button("添加") {
                    onAdd(trimmedName)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(PocketTheme.primaryButton).foregroundStyle(PocketTheme.primaryButtonText).clipShape(Capsule())
                .disabled(trimmedName.isEmpty)
            }

            TextField("字段名称", text: $name)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(PocketTheme.card)
                .clipShape(Capsule())
                .padding(.top, 28)

            Spacer()
        }
        .padding(24)
        .frame(width: 470, height: 230)
        .background(PocketTheme.background)
        .buttonBorderShape(.capsule)
    }
}
