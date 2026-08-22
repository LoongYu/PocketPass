import LocalAuthentication
import SwiftUI

@MainActor
enum IOSAppAuthenticator {
    static func authenticate(language: IOSAppLanguage) async throws {
        let context = LAContext()
        context.localizedCancelTitle = language.text("取消", "Cancel")
        try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: language.text(
                "解锁口袋密码并访问本地账户数据",
                "Unlock PocketPass and access your local vault"
            )
        )
    }
}

struct IOSLockScreen: View {
    @EnvironmentObject private var settings: IOSAppSettings
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            IOSTheme.background.ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                IOSBrandMark(size: 92)
                VStack(spacing: 7) {
                    Text("口袋密码已锁定")
                        .font(.title2.bold())
                    Text("使用 Face ID 或设备密码解锁")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                Spacer()
                Button {
                    authenticate()
                } label: {
                    HStack(spacing: 10) {
                        if isAuthenticating { ProgressView().tint(.black) }
                        else { Image(systemName: "faceid") }
                        Text("解锁")
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(IOSTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isAuthenticating)
                .padding(.horizontal, 24)
                .padding(.bottom, 26)
            }
        }
        .task { authenticate() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("口袋密码已锁定")
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        errorMessage = nil
        Task { @MainActor in
            do {
                try await IOSAppAuthenticator.authenticate(language: settings.language)
                settings.unlockSucceeded()
            } catch {
                errorMessage = settings.language.text("未能验证身份，请重试", "Authentication failed. Please try again.")
            }
            isAuthenticating = false
        }
    }
}

@MainActor
enum IOSClipboardManager {
    static func copy(_ value: String) {
        UIPasteboard.general.string = value
        let changeCount = UIPasteboard.general.changeCount
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(30))
            guard UIPasteboard.general.changeCount == changeCount else { return }
            UIPasteboard.general.items = []
        }
    }
}
