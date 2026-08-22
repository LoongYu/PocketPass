import CommonCrypto
import CryptoKit
import Foundation

public enum VaultDataTransfer {
    private static let magic = Data("POCKETPASS1".utf8)
    public static let maximumImportBytes = 250_000_000

    public enum TransferError: LocalizedError {
        case fileTooLarge

        public var errorDescription: String? {
            switch self {
            case .fileTooLarge: return "导入文件超过 250 MB 限制"
            }
        }
    }

    public static func json(snapshot: VaultSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    public static func importData(from url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile != false else { throw CocoaError(.fileReadUnsupportedScheme) }
        if let size = values.fileSize, size > maximumImportBytes { throw TransferError.fileTooLarge }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= maximumImportBytes else { throw TransferError.fileTooLarge }
        return data
    }

    public static func snapshot(fromJSON data: Data) throws -> VaultSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(VaultSnapshot.self, from: data)
    }

    public static func csv(snapshot: VaultSnapshot) -> Data {
        let categoryNames = Dictionary(uniqueKeysWithValues: snapshot.categories.map { ($0.id, $0.name) })
        var rows = ["名称,网址,分类,标签,用户名,密码,备注,自定义字段"]
        for item in snapshot.items where item.deletedAt == nil {
            for account in item.accounts {
                let fields = account.fields.map { field in
                    "\(field.name)=\(field.value)=\(field.isSecret ? "1" : "0")"
                }.joined(separator: "|")
                rows.append([
                    item.name, item.website, categoryNames[item.categoryID] ?? "其他",
                    item.tags.joined(separator: "|"), account.username, account.password, item.note, fields
                ].map(csvEscape).joined(separator: ","))
            }
        }
        return Data(rows.joined(separator: "\n").utf8)
    }

    public static func snapshot(fromCSV data: Data, baseCategories: [VaultCategory]) throws -> VaultSnapshot {
        guard let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        let rows = parseCSV(text)
        guard rows.count > 1 else { return VaultSnapshot(categories: baseCategories, items: []) }
        var categories = baseCategories
        var items: [VaultItem] = []
        var itemIndices: [String: Int] = [:]
        for columns in rows.dropFirst() where columns.count >= 7 {
            let categoryName = columns[2].isEmpty ? "其他" : columns[2]
            let categoryID = categoryID(named: categoryName, categories: &categories)
            let fields: [CustomField] = columns.count > 7 ? columns[7].split(separator: "|").compactMap { encoded in
                let components = encoded.split(separator: "=", omittingEmptySubsequences: false).map(String.init)
                guard components.count >= 2 else { return nil }
                let hasSecretMarker = components.count > 2 && ["0", "1"].contains(components.last ?? "")
                let valueEnd = hasSecretMarker ? components.count - 1 : components.count
                let value = components[1..<valueEnd].joined(separator: "=")
                return CustomField(name: components[0], value: value, isSecret: hasSecretMarker && components.last == "1")
            } : []
            let account = LoginAccount(username: columns[4], password: columns[5], fields: fields)
            let key = "\(columns[0].foldedKey)|\(categoryID.uuidString)|\(columns[1])"
            if let index = itemIndices[key] {
                items[index].accounts.append(account)
            } else {
                itemIndices[key] = items.count
                items.append(VaultItem(
                    name: columns[0], website: columns[1], categoryID: categoryID,
                    tags: columns[3].split(separator: "|").map(String.init), note: columns[6], accounts: [account]
                ))
            }
        }
        return VaultSnapshot(categories: categories, items: items)
    }

    public static func markdown(snapshot: VaultSnapshot) -> Data {
        let categoryNames = Dictionary(uniqueKeysWithValues: snapshot.categories.map { ($0.id, $0.name) })
        var lines = ["# 口袋密码导出", "", "> 此文件包含明文账户和密码，请妥善保管。", ""]
        for item in snapshot.items where item.deletedAt == nil {
            lines += [
                "### \(markdownEscape(item.name))",
                "- 分类：\(markdownEscape(categoryNames[item.categoryID] ?? "其他"))",
                "- 标签：\(markdownEscape(item.tags.joined(separator: "、")))",
                "- 网址：\(markdownEscape(item.website))",
                "- 备注：\(markdownEscape(item.note))",
                ""
            ]
            for (index, account) in item.accounts.enumerated() {
                lines += [
                    "#### 登录账号 \(index + 1)",
                    "- 用户名：\(markdownEscape(account.username))",
                    "- 密码：\(markdownEscape(account.password))"
                ]
                for field in account.fields {
                    let prefix = field.isSecret ? "🔒 " : "字段 "
                    lines.append("- \(prefix)\(markdownEscape(field.name))：\(markdownEscape(field.value))")
                }
                lines.append("")
            }
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    public static func snapshot(fromMarkdown data: Data, baseCategories: [VaultCategory]) throws -> VaultSnapshot {
        guard let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        var categories = baseCategories
        var items: [VaultItem] = []
        var currentName: String?
        var metadata: [String: String] = [:]
        var accountBlocks: [MarkdownAccount] = []
        var currentAccount: MarkdownAccount?

        let usernameKeys = Set(["用户名", "用户名称", "账号", "账户", "邮箱", "邮件", "手机号", "手机", "号码", "ID", "微信ID"])
        let passwordKeys = Set(["密码", "登录密码", "账户密码", "账号密码", "PASSWORD", "PASS", "PWD"])
        let metadataKeys = Set(["分类", "标签", "网址", "官网", "地址", "备注"])
        func normalizedKey(_ value: String) -> String {
            value.replacingOccurrences(of: " ", with: "").uppercased()
        }

        func finishAccount() {
            if let currentAccount, currentAccount.hasContent { accountBlocks.append(currentAccount) }
            currentAccount = nil
        }
        func finishItem() {
            finishAccount()
            guard let name = currentName, !name.isEmpty else { return }
            let categoryName = metadata["分类"].flatMap { $0.isEmpty ? nil : $0 } ?? "其他"
            let categoryID = categoryID(named: categoryName, categories: &categories)
            let accounts = accountBlocks.map { block in
                LoginAccount(
                    username: block.username,
                    password: block.password,
                    fields: block.fields
                )
            }
            items.append(VaultItem(
                name: name,
                website: metadata["网址"] ?? "",
                categoryID: categoryID,
                tags: (metadata["标签"] ?? "").split(whereSeparator: { "、,，|".contains($0) }).map(String.init),
                note: metadata["备注"] ?? "",
                accounts: accounts.isEmpty ? [LoginAccount(username: "", password: "")] : accounts
            ))
            currentName = nil
            metadata = [:]
            accountBlocks = []
        }

        for rawLine in text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("### ") && !line.hasPrefix("#### ") {
                finishItem()
                currentName = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("#### ") {
                finishAccount()
                currentAccount = MarkdownAccount()
            } else if let pair = markdownPair(line) {
                let key = normalizedKey(pair.0)
                if metadataKeys.contains(key) {
                    switch key {
                    case "官网", "地址": metadata["网址"] = pair.1
                    default: metadata[pair.0] = pair.1
                    }
                } else if usernameKeys.contains(key) {
                    if currentAccount?.username.isEmpty == false || currentAccount?.password.isEmpty == false { finishAccount() }
                    if currentAccount == nil { currentAccount = MarkdownAccount() }
                    currentAccount?.username = pair.1
                } else if pair.0.hasPrefix("字段 ") {
                    if currentAccount == nil { currentAccount = MarkdownAccount() }
                    currentAccount?.fields.append(CustomField(
                        name: String(pair.0.dropFirst("字段 ".count)), value: pair.1, isSecret: false
                    ))
                } else if pair.0.hasPrefix("🔒 ") {
                    if currentAccount == nil { currentAccount = MarkdownAccount() }
                    currentAccount?.fields.append(CustomField(
                        name: String(pair.0.dropFirst("🔒 ".count)), value: pair.1, isSecret: true
                    ))
                } else if passwordKeys.contains(key) {
                    if currentAccount == nil { currentAccount = MarkdownAccount() }
                    currentAccount?.password = pair.1
                } else {
                    if currentAccount == nil { currentAccount = MarkdownAccount() }
                    currentAccount?.fields.append(CustomField(
                        name: pair.0, value: pair.1,
                        isSecret: pair.0.localizedCaseInsensitiveContains("pin")
                    ))
                }
            } else if line.isEmpty {
                finishAccount()
            }
        }
        finishItem()
        return VaultSnapshot(categories: categories, items: items)
    }

    public static func encryptedBackup(snapshot: VaultSnapshot, password: String) throws -> Data {
        let plaintext = try json(snapshot: snapshot)
        var generator = SystemRandomNumberGenerator()
        let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
        let box = try AES.GCM.seal(plaintext, using: try backupKey(password: password, salt: salt))
        guard let combined = box.combined else { throw VaultStorageError.malformedCiphertext }
        return magic + salt + combined
    }

    public static func decryptBackup(_ data: Data, password: String) throws -> VaultSnapshot {
        guard data.starts(with: magic), data.count > magic.count + 16 else { throw VaultStorageError.malformedCiphertext }
        let saltEnd = magic.count + 16
        let key = try backupKey(password: password, salt: Data(data[magic.count..<saltEnd]))
        let plaintext = try AES.GCM.open(try AES.GCM.SealedBox(combined: data[saltEnd...]), using: key)
        return try snapshot(fromJSON: plaintext)
    }

    public static func isEncryptedBackup(_ data: Data) -> Bool { data.starts(with: magic) }

    private static func categoryID(named name: String, categories: inout [VaultCategory]) -> UUID {
        if let category = categories.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return category.id }
        let category = VaultCategory(name: name, icon: "folder.fill", colorHex: "888888")
        categories.append(category)
        return category.id
    }

    private static func backupKey(password: String, salt: Data) throws -> SymmetricKey {
        var derived = [UInt8](repeating: 0, count: 32)
        let status = password.withCString { pointer in
            salt.withUnsafeBytes { bytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2), pointer, password.utf8.count,
                    bytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 200_000, &derived, derived.count
                )
            }
        }
        guard status == kCCSuccess else { throw VaultStorageError.malformedCiphertext }
        return SymmetricKey(data: Data(derived))
    }

    private static func csvEscape(_ value: String) -> String { "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\"" }
    private static func markdownEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "\r\n", with: " ").replacingOccurrences(of: "\n", with: " / ")
    }
    private static func markdownPair(_ line: String) -> (String, String)? {
        let cleaned = line.drop(while: { $0 == "-" || $0 == "*" || $0.isWhitespace })
        guard let separator = cleaned.firstIndex(where: { $0 == "：" || $0 == ":" }) else { return nil }
        let key = cleaned[..<separator].trimmingCharacters(in: .whitespaces)
        let value = cleaned[cleaned.index(after: separator)...].trimmingCharacters(in: .whitespaces)
        return key.isEmpty ? nil : (key, value)
    }
    private static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], field = "", quoted = false
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "\"" {
                let next = text.index(after: index)
                if quoted, next < text.endIndex, text[next] == "\"" { field.append("\""); index = next }
                else { quoted.toggle() }
            } else if character == ",", !quoted { row.append(field); field = "" }
            else if character == "\n", !quoted { row.append(field); rows.append(row); row = []; field = "" }
            else if character != "\r" { field.append(character) }
            index = text.index(after: index)
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }

    private struct MarkdownAccount {
        var username = ""
        var password = ""
        var fields: [CustomField] = []

        var hasContent: Bool {
            !username.isEmpty || !password.isEmpty || fields.contains { !$0.name.isEmpty || !$0.value.isEmpty }
        }
    }
}

private extension String {
    var foldedKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)
    }
}
