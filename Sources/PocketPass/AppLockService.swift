import Foundation
import LocalAuthentication

@MainActor
final class AppLockService {
    var canUseDeviceAuthentication: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func authenticate() async throws {
        let context = LAContext()
        context.localizedCancelTitle = "取消"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? LAError(.authenticationFailed)
        }
        try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "使用 Touch ID 或设备密码解锁口袋密码"
        )
    }
}
