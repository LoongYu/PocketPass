import Foundation

@main
struct MarkdownTransferValidation {
    static func main() throws {
        let markdown = """
        # 账户资料

        ### 微信小号
        分类：社交
        用户名：wechat-one
        密码：sample-one

        用户名：wechat-two
        密码：sample-two

        ### 谷歌账号
        分类：工作
        用户名：google-one
        密码：sample-three

        ### 电报号
        分类：社交
        用户名：telegram-one
        密码：sample-four
        """
        let snapshot = try DataTransferService.snapshot(fromMarkdown: Data(markdown.utf8), baseCategories: VaultCategory.samples)

        guard !snapshot.items.isEmpty else { throw ValidationError("没有解析到账户项目") }
        guard snapshot.items.contains(where: { $0.name == "微信小号" && $0.accounts.count == 2 }) else {
            throw ValidationError("未正确合并两个微信小号")
        }
        guard snapshot.items.contains(where: { $0.name == "谷歌账号" && $0.accounts.count == 1 }) else {
            throw ValidationError("未正确解析谷歌账号")
        }
        guard snapshot.items.contains(where: { $0.name == "电报号" && $0.accounts.count == 1 }) else {
            throw ValidationError("未正确解析电报号")
        }

        let exported = DataTransferService.markdown(snapshot: snapshot)
        let roundTrip = try DataTransferService.snapshot(fromMarkdown: exported, baseCategories: VaultCategory.samples)
        let sourceAccountCount = snapshot.items.reduce(0) { $0 + $1.accounts.count }
        let roundTripAccountCount = roundTrip.items.reduce(0) { $0 + $1.accounts.count }
        guard snapshot.items.count == roundTrip.items.count, sourceAccountCount == roundTripAccountCount else {
            throw ValidationError("Markdown 导出后重新导入的数据数量不一致")
        }

        print("Markdown validation passed: \(snapshot.items.count) items, \(sourceAccountCount) accounts")
    }

    struct ValidationError: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}
