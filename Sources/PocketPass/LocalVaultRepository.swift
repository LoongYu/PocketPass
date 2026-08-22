import Foundation
import PocketPassCore

/// macOS 保留旧的 Application Support/口袋密码 路径，
/// 实际加密、解密与文件保护由跨平台 PocketPassCore 统一实现。
final class LocalVaultRepository {
    let core: PocketPassCore.LocalVaultRepository

    init(directory customDirectory: URL? = nil) {
        core = PocketPassCore.LocalVaultRepository(directory: customDirectory, namespace: "口袋密码")
    }

    func load() throws -> VaultSnapshot? { try core.load() }
    func save(_ snapshot: VaultSnapshot) throws { try core.save(snapshot) }
}
