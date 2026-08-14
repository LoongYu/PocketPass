import SwiftUI

struct PasswordGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    let onUse: ((String) -> Void)?

    @State private var length = 20
    @State private var includeUppercase = true
    @State private var includeNumbers = true
    @State private var includeSymbols = true
    @State private var password = ""
    @State private var copied = false

    init(onUse: ((String) -> Void)? = nil) {
        self.onUse = onUse
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                InterfaceBrandLogoView()
                Text("生成密码").font(.title2.bold())
                Spacer()
                Button("关闭") { dismiss() }.buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("生成的密码").font(.caption).foregroundStyle(PocketTheme.muted)
                HStack(spacing: 10) {
                    Text(password)
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .textSelection(.enabled)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Button { generate() } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 32, height: 28)
                            .background(PocketTheme.controlFill).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("重新生成")
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .background(PocketTheme.input)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            VStack(spacing: 0) {
                HStack {
                    Text("密码长度")
                    Spacer()
                    Text("\(length)").monospacedDigit().foregroundStyle(PocketTheme.accent)
                }
                .padding(.horizontal, 16).frame(height: 52)
                Slider(value: lengthBinding, in: 8...64, step: 1)
                    .tint(PocketTheme.accent)
                    .padding(.horizontal, 16).padding(.bottom, 14)
                Divider().overlay(PocketTheme.border)
                optionRow("大写字母", isOn: $includeUppercase)
                Divider().overlay(PocketTheme.border)
                optionRow("数字", isOn: $includeNumbers)
                Divider().overlay(PocketTheme.border)
                optionRow("符号", isOn: $includeSymbols)
            }
            .background(PocketTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18))

            HStack(spacing: 12) {
                Button {
                    ClipboardManager.copy(password)
                    copied = true
                } label: {
                    Label {
                        Text(LocalizedStringKey(copied ? "已复制" : "复制密码"))
                    } icon: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 12)
                .background(PocketTheme.card)
                .clipShape(Capsule())

                if let onUse {
                    Button {
                        onUse(password)
                        dismiss()
                    } label: {
                        Label("使用密码", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 12)
                    .background(PocketTheme.primaryButton)
                    .foregroundStyle(PocketTheme.primaryButtonText)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(24)
        .frame(width: 500, height: 510)
        .background(PocketTheme.background)
        .buttonBorderShape(.capsule)
        .onAppear { generate() }
        .onChange(of: length) { _, _ in generate() }
        .onChange(of: includeUppercase) { _, _ in generate() }
        .onChange(of: includeNumbers) { _, _ in generate() }
        .onChange(of: includeSymbols) { _, _ in generate() }
    }

    private var lengthBinding: Binding<Double> {
        Binding(get: { Double(length) }, set: { length = Int($0) })
    }

    private func optionRow(_ title: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch).tint(PocketTheme.accent)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private func generate() {
        password = PasswordGeneratorService.generate(
            length: length,
            includeUppercase: includeUppercase,
            includeNumbers: includeNumbers,
            includeSymbols: includeSymbols
        )
        copied = false
    }
}
