import SwiftUI
import UniformTypeIdentifiers

struct EditItemView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: VaultItem
    @State private var name: String
    @State private var categoryID: UUID?
    @State private var selectedTags: [String]
    @State private var note: String
    @State private var symbol: String
    @State private var iconData: Data?
    @State private var accounts: [LoginAccount]
    @State private var attachments: [ImageAttachment]
    @State private var showingIconPicker = false
    @State private var showingImageImporter = false
    @State private var showingTagPicker = false

    init(item: VaultItem) {
        original = item
        _name = State(initialValue: item.name)
        _categoryID = State(initialValue: item.categoryID)
        _selectedTags = State(initialValue: item.tags)
        _note = State(initialValue: item.note)
        _symbol = State(initialValue: item.symbol)
        _iconData = State(initialValue: item.iconData)
        var migratedAccounts = item.accounts
        let legacyWebsite = item.website.trimmingCharacters(in: .whitespacesAndNewlines)
        let alreadyHasWebsiteField = migratedAccounts.contains { account in
            account.fields.contains { $0.name == "网址" }
        }
        if !legacyWebsite.isEmpty, legacyWebsite != "https://", !alreadyHasWebsiteField {
            if migratedAccounts.isEmpty {
                migratedAccounts.append(.init(id: UUID(), username: "", password: "", fields: []))
            }
            migratedAccounts[0].fields.append(
                .init(id: UUID(), name: "网址", value: legacyWebsite, isSecret: false)
            )
        }
        _accounts = State(initialValue: migratedAccounts)
        _attachments = State(initialValue: item.attachments ?? [])
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                InterfaceBrandLogoView()
                Text("编辑账户").font(.title2.bold())
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(.plain).padding(.horizontal, 18).padding(.vertical, 10)
                    .background(PocketTheme.card).clipShape(Capsule())
                Button("保存") { save() }
                    .buttonStyle(.plain).padding(.horizontal, 18).padding(.vertical, 10)
                    .background(PocketTheme.primaryButton).foregroundStyle(PocketTheme.primaryButtonText).clipShape(Capsule())
                    .disabled(name.isEmpty)
            }.padding(.horizontal, 22).padding(.vertical, 14)
            Divider().opacity(0.25)
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 10) {
                        Button { showingIconPicker = true } label: {
                            VStack(spacing: 6) {
                                VaultIconView(symbol: symbol, data: iconData, size: 52, cornerRadius: 15)
                                Text("图标选择").font(.caption).foregroundStyle(PocketTheme.muted)
                            }.frame(maxWidth: .infinity).padding(8)
                        }.buttonStyle(.plain).background(PocketTheme.card).clipShape(RoundedRectangle(cornerRadius: 18))
                        FormCard {
                            PlainInputRow {
                                TextField("名称", text: $name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(PocketTheme.primary)
                            }
                            PlainInputRow {
                                CategoryDropdown(selection: $categoryID)
                            }
                            PlainInputRow {
                                Button { showingTagPicker = true } label: {
                                    HStack {
                                        Text(selectedTags.isEmpty ? "标签" : selectedTags.joined(separator: "、"))
                                            .foregroundStyle(selectedTags.isEmpty ? PocketTheme.muted : PocketTheme.primary)
                                            .lineLimit(1)
                                        Spacer(); Image(systemName: "tag")
                                    }
                                }.buttonStyle(.plain)
                            }
                        }
                        FormCard {
                            NoteInputRow(text: $note, placeholder: "备注（可选）")
                        }
                        AttachmentStrip(attachments: $attachments)
                        Button { showingImageImporter = true } label: {
                            Text("添加图片").frame(maxWidth: .infinity)
                        }.buttonStyle(.plain).padding(10).background(PocketTheme.card).clipShape(Capsule()).disabled(attachments.count >= 5)
                    }.frame(maxWidth: .infinity)
                    VStack(spacing: 10) {
                        ForEach(Array(accounts.indices), id: \.self) { index in
                            LoginAccountEditor(account: $accounts[index], number: index + 1, canDelete: accounts.count > 1) {
                                accounts.remove(at: index)
                            }
                        }
                        Button {
                            accounts.append(.init(id: UUID(), username: "", password: "", fields: []))
                        } label: { Text("添加账号").frame(maxWidth: .infinity) }
                            .buttonStyle(.plain).padding(10).background(PocketTheme.card).clipShape(Capsule())
                    }.frame(maxWidth: .infinity)
                }.padding(16)
            }
        }.frame(width: 800, height: 600).background(PocketTheme.background)
            .buttonBorderShape(.capsule)
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $symbol, selectedIconData: $iconData)
            }
            .sheet(isPresented: $showingTagPicker) {
                TagPickerView(selectedTags: $selectedTags)
            }
            .fileImporter(isPresented: $showingImageImporter, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
                guard case .success(let urls) = result else { return }
                for url in urls.prefix(5 - attachments.count) {
                    let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    if let data = try? Data(contentsOf: url), data.count <= 5_000_000 {
                        attachments.append(.init(id: UUID(), filename: url.lastPathComponent, data: data))
                    }
                }
            }
    }

    private func save() {
        var item = original
        item.name = name; item.website = ""; item.categoryID = categoryID ?? original.categoryID
        item.tags = selectedTags; item.note = note; item.symbol = symbol; item.iconData = iconData
        item.accounts = accounts; item.attachments = attachments
        store.updateItem(item); dismiss()
    }
}
