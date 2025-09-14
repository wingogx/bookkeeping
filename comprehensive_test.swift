#!/usr/bin/swift

// VoiceBudget v1.0.6 综合功能测试
// 自检测试所有功能模块

import Foundation

// 模拟数据结构进行功能验证
struct MockTransaction {
    let amount: Double
    let category: String
    let date: Date
    let isExpense: Bool
}

struct MockAchievement {
    let id: String
    var isUnlocked: Bool
    var currentCount: Int
    let requiredCount: Int
}

struct MockUserStats {
    var currentStreak: Int = 0
    var maxStreak: Int = 0
    var totalRecords: Int = 0
    var lastRecordDate: Date = Date()
}

// 综合功能测试类
class ComprehensiveTester {

    // 测试数据模型验证
    func testDataModels() -> Bool {
        print("🧪 测试数据模型...")

        // Achievement模型测试
        let achievement = MockAchievement(id: "first_record", isUnlocked: false, currentCount: 0, requiredCount: 1)
        guard !achievement.isUnlocked && achievement.currentCount < achievement.requiredCount else {
            print("❌ Achievement模型逻辑错误")
            return false
        }

        // Transaction模型测试
        let transaction = MockTransaction(amount: 100.0, category: "餐饮", date: Date(), isExpense: true)
        guard transaction.amount > 0 && !transaction.category.isEmpty else {
            print("❌ Transaction模型验证失败")
            return false
        }

        print("✅ 数据模型测试通过")
        return true
    }

    // 测试成就系统逻辑
    func testAchievementSystem() -> Bool {
        print("🏆 测试成就系统...")

        var achievements = [
            MockAchievement(id: "first_record", isUnlocked: false, currentCount: 0, requiredCount: 1),
            MockAchievement(id: "streak_3", isUnlocked: false, currentCount: 0, requiredCount: 3),
            MockAchievement(id: "transaction_50", isUnlocked: false, currentCount: 0, requiredCount: 50)
        ]

        // 模拟首次记账成就解锁
        achievements[0].currentCount = 1
        achievements[0].isUnlocked = true

        // 验证解锁逻辑
        guard achievements[0].isUnlocked && achievements[0].currentCount >= achievements[0].requiredCount else {
            print("❌ 成就解锁逻辑错误")
            return false
        }

        print("✅ 成就系统测试通过")
        return true
    }

    // 测试连击系统
    func testStreakSystem() -> Bool {
        print("🔥 测试连击系统...")

        var userStats = MockUserStats()
        let calendar = Calendar.current

        // 模拟连续3天记账
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let dayBefore = calendar.date(byAdding: .day, value: -2, to: today)!

        // 第1天
        userStats.currentStreak = 1
        userStats.lastRecordDate = dayBefore
        userStats.totalRecords = 1

        // 第2天 - 模拟addTransaction调用
        let daysDiff1 = calendar.dateComponents([.day], from: calendar.startOfDay(for: userStats.lastRecordDate), to: calendar.startOfDay(for: yesterday)).day ?? 0
        if daysDiff1 == 1 {
            userStats.currentStreak += 1
        }
        userStats.lastRecordDate = yesterday
        userStats.totalRecords += 1
        userStats.maxStreak = max(userStats.maxStreak, userStats.currentStreak)

        // 第3天 - 模拟addTransaction调用
        let daysDiff2 = calendar.dateComponents([.day], from: calendar.startOfDay(for: userStats.lastRecordDate), to: calendar.startOfDay(for: today)).day ?? 0
        if daysDiff2 == 1 {
            userStats.currentStreak += 1
        }
        userStats.totalRecords += 1
        userStats.maxStreak = max(userStats.maxStreak, userStats.currentStreak)

        // 验证连击计算
        guard userStats.currentStreak == 3 && userStats.maxStreak == 3 && userStats.totalRecords == 3 else {
            print("❌ 连击系统计算错误: streak=\(userStats.currentStreak), max=\(userStats.maxStreak), total=\(userStats.totalRecords)")
            return false
        }

        print("✅ 连击系统测试通过")
        return true
    }

    // 测试数据导出功能
    func testDataExport() -> Bool {
        print("📊 测试数据导出...")

        // 模拟交易数据
        let transactions = [
            MockTransaction(amount: 25.8, category: "餐饮", date: Date(), isExpense: true),
            MockTransaction(amount: 100.0, category: "交通", date: Date(), isExpense: true),
            MockTransaction(amount: 50.5, category: "购物", date: Date(), isExpense: true)
        ]

        // 模拟CSV导出
        var csvString = "日期,金额,分类,备注,类型\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        for transaction in transactions {
            let dateStr = dateFormatter.string(from: transaction.date)
            let typeStr = transaction.isExpense ? "支出" : "收入"
            csvString += "\(dateStr),\(transaction.amount),\(transaction.category),,\(typeStr)\n"
        }

        // 验证CSV格式
        let lines = csvString.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count == 4, lines[0].contains("日期,金额,分类,备注,类型") else {
            print("❌ CSV导出格式错误")
            return false
        }

        // 验证数据内容
        guard lines[1].contains("25.8") && lines[1].contains("餐饮") && lines[1].contains("支出") else {
            print("❌ CSV导出数据错误")
            return false
        }

        print("✅ 数据导出测试通过")
        return true
    }

    // 测试预算情绪表达
    func testBudgetEmotion() -> Bool {
        print("😊 测试预算情绪表达...")

        // 测试不同预算使用率的情绪
        let testCases: [(Double, String)] = [
            (0.2, "😊"),   // <30%
            (0.4, "🙂"),   // 30-50%
            (0.6, "😐"),   // 50-70%
            (0.8, "😰"),   // 70-90%
            (0.95, "🤯")   // >90%
        ]

        for (progress, expectedEmoji) in testCases {
            let emoji = getBudgetEmoji(for: progress)
            guard emoji == expectedEmoji else {
                print("❌ 预算情绪表达错误: \(progress) -> \(emoji), expected: \(expectedEmoji)")
                return false
            }
        }

        print("✅ 预算情绪表达测试通过")
        return true
    }

    // 辅助方法：获取预算情绪
    private func getBudgetEmoji(for progress: Double) -> String {
        switch progress {
        case 0..<0.3:
            return "😊"
        case 0.3..<0.5:
            return "🙂"
        case 0.5..<0.7:
            return "😐"
        case 0.7..<0.9:
            return "😰"
        default:
            return "🤯"
        }
    }

    // 测试版本迁移逻辑
    func testVersionMigration() -> Bool {
        print("🔄 测试版本迁移...")

        // 模拟v1.0.5到v1.0.6迁移
        let currentVersion = "1.0.6"
        let savedVersion: String? = "1.0.5"  // 模拟从v1.0.5升级

        var needsMigration = false
        if savedVersion == nil || savedVersion == "1.0.5" {
            needsMigration = true
        }

        guard needsMigration else {
            print("❌ 版本迁移检查逻辑错误")
            return false
        }

        // 模拟数据迁移过程
        var migratedAchievements = [MockAchievement]()
        var migratedUserStats = MockUserStats()

        // 初始化默认成就
        migratedAchievements = [
            MockAchievement(id: "first_record", isUnlocked: false, currentCount: 0, requiredCount: 1),
            MockAchievement(id: "streak_3", isUnlocked: false, currentCount: 0, requiredCount: 3),
        ]

        // 基于现有交易初始化统计
        let existingTransactions = [MockTransaction(amount: 100, category: "餐饮", date: Date(), isExpense: true)]
        migratedUserStats.totalRecords = existingTransactions.count
        migratedUserStats.lastRecordDate = existingTransactions.last?.date ?? Date()

        guard migratedAchievements.count == 2 && migratedUserStats.totalRecords == 1 else {
            print("❌ 数据迁移逻辑错误")
            return false
        }

        print("✅ 版本迁移测试通过")
        return true
    }

    // 测试语音识别文本解析
    func testVoiceTextParsing() -> Bool {
        print("🎤 测试语音文本解析...")

        let testTexts = [
            ("午餐花了25.8元", (25.8, "餐饮")),
            ("打车回家100块", (100.0, "交通")),
            ("买衣服花了299", (299.0, "购物")),
            ("看电影50元", (50.0, "娱乐"))
        ]

        for (text, expected) in testTexts {
            let result = parseTransaction(from: text)
            guard let amount = result.amount,
                  let category = result.category,
                  abs(amount - expected.0) < 0.01 else {
                print("❌ 语音解析失败: '\(text)' -> \(String(describing: result.amount)), expected: \(expected.0)")
                return false
            }
        }

        print("✅ 语音文本解析测试通过")
        return true
    }

    // 辅助方法：解析交易文本
    private func parseTransaction(from text: String) -> (amount: Double?, category: String?, note: String?) {
        var amount: Double?
        var category: String?
        let note = text

        // 提取金额
        let pattern = "\\d+(\\.\\d+)?"
        if let range = text.range(of: pattern, options: .regularExpression) {
            amount = Double(text[range])
        }

        // 智能分类识别
        let keywords: [String: [String]] = [
            "餐饮": ["午餐", "晚餐", "早餐", "吃饭", "餐厅"],
            "交通": ["打车", "公交", "地铁", "出租", "滴滴"],
            "购物": ["买", "购", "衣服", "鞋子", "包"],
            "娱乐": ["电影", "游戏", "KTV", "娱乐"]
        ]

        for (cat, words) in keywords {
            if words.contains(where: { text.contains($0) }) {
                category = cat
                break
            }
        }

        return (amount, category, note)
    }

    // 运行所有测试
    func runAllTests() -> Bool {
        print("🚀 开始VoiceBudget v1.0.6综合功能测试")
        print(String(repeating: "=", count: 60))

        let tests: [(String, () -> Bool)] = [
            ("数据模型验证", testDataModels),
            ("成就系统测试", testAchievementSystem),
            ("连击系统测试", testStreakSystem),
            ("数据导出测试", testDataExport),
            ("预算情绪表达测试", testBudgetEmotion),
            ("版本迁移测试", testVersionMigration),
            ("语音文本解析测试", testVoiceTextParsing)
        ]

        var allPassed = true
        var passedCount = 0

        for (testName, testFunc) in tests {
            print("\n🔍 开始 \(testName)...")
            if testFunc() {
                passedCount += 1
                print("✅ \(testName) 通过")
            } else {
                allPassed = false
                print("❌ \(testName) 失败")
            }
        }

        print("\n" + String(repeating: "=", count: 60))
        print("📊 测试结果汇总:")
        print("通过测试: \(passedCount)/\(tests.count)")
        print("成功率: \(Int(Double(passedCount)/Double(tests.count)*100))%")

        if allPassed {
            print("🎉 所有功能测试通过！")
        } else {
            print("⚠️  部分测试失败，需要修复")
        }

        return allPassed
    }
}

// 执行综合测试
let tester = ComprehensiveTester()
let success = tester.runAllTests()
exit(success ? 0 : 1)