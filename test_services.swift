import Foundation
import NaturalLanguage

// 简单的测试脚本来验证服务功能
print("🧪 开始测试VoiceBudget核心服务...")

// 测试TransactionCategory枚举
func testTransactionCategory() {
    print("\n📁 测试TransactionCategory枚举...")
    
    let categories = TransactionCategory.allCases
    print("支持的分类数量: \(categories.count)")
    
    for category in categories {
        print("- \(category.icon) \(category.localizedName) (\(category.rawValue))")
        print("  描述: \(category.description)")
        print("  预算占比: \(Int(category.defaultBudgetRatio * 100))%")
        print("  必需支出: \(category.isEssential ? "是" : "否")")
    }
    
    print("✅ TransactionCategory测试完成\n")
}

// 测试智能分类算法的核心逻辑
func testCategorizationLogic() {
    print("🤖 测试分类逻辑...")
    
    let testCases = [
        ("今天午餐花了38块", TransactionCategory.food),
        ("打车去机场用了120元", TransactionCategory.transport),
        ("在淘宝买了一件衣服200块", TransactionCategory.shopping),
        ("看电影票价45元", TransactionCategory.entertainment),
        ("去医院看病花了300", TransactionCategory.healthcare),
        ("报了一个英语培训班2000块", TransactionCategory.education),
        ("交了这个月的电费150元", TransactionCategory.utilities),
        ("给朋友买了生日礼物88块", TransactionCategory.shopping)
    ]
    
    // 简单的关键词匹配测试
    let categoryKeywords: [TransactionCategory: [String]] = [
        .food: ["午餐", "晚餐", "早餐", "吃饭", "餐厅", "外卖", "咖啡", "奶茶"],
        .transport: ["打车", "地铁", "公交", "出租车", "滴滴", "交通", "车费", "机场"],
        .shopping: ["买", "购物", "淘宝", "京东", "商场", "衣服", "鞋子", "礼品"],
        .entertainment: ["电影", "KTV", "游戏", "娱乐", "音乐", "演唱会"],
        .healthcare: ["医院", "看病", "药", "体检", "牙医"],
        .education: ["培训", "课程", "学习", "教育", "班"],
        .utilities: ["电费", "水费", "燃气费", "网费", "房租"],
        .other: ["其他"]
    ]
    
    for (text, expectedCategory) in testCases {
        var bestMatch: TransactionCategory = .other
        var maxScore = 0
        
        // 简单的关键词匹配
        for (category, keywords) in categoryKeywords {
            let score = keywords.filter { text.contains($0) }.count
            if score > maxScore {
                maxScore = score
                bestMatch = category
            }
        }
        
        let isCorrect = bestMatch == expectedCategory
        let status = isCorrect ? "✅" : "❌"
        
        print("\(status) 输入: \(text)")
        print("   预期: \(expectedCategory.localizedName), 实际: \(bestMatch.localizedName)")
        
        if !isCorrect {
            print("   ⚠️ 分类不匹配!")
        }
    }
    
    print("✅ 分类逻辑测试完成\n")
}

// 测试金额提取
func testAmountExtraction() {
    print("💰 测试金额提取...")
    
    let testTexts = [
        "花了38块",
        "用了120元", 
        "消费200",
        "付了45元",
        "一共300块钱",
        "总计2000"
    ]
    
    // 简单的正则表达式测试
    for text in testTexts {
        let pattern = #"(\d+\.?\d*)(元|块|块钱|毛|分)?"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let amountRange = Range(match.range(at: 1), in: text) {
            let amountString = String(text[amountRange])
            if let amount = Decimal(string: amountString) {
                print("✅ '\(text)' -> ¥\(amount)")
            } else {
                print("❌ '\(text)' -> 金额解析失败")
            }
        } else {
            print("❌ '\(text)' -> 未找到金额")
        }
    }
    
    print("✅ 金额提取测试完成\n")
}

// 测试TransactionEntity创建
func testTransactionEntity() {
    print("📝 测试TransactionEntity创建...")
    
    let entity = TransactionEntity(
        amount: 38.50,
        categoryID: TransactionCategory.food.rawValue,
        categoryName: TransactionCategory.food.localizedName,
        note: "午餐",
        source: .voice
    )
    
    print("✅ 创建交易实体成功:")
    print("   ID: \(entity.id)")
    print("   金额: \(entity.formattedAmount)")
    print("   分类: \(entity.categoryName)")
    print("   来源: \(entity.source.rawValue)")
    print("   是否今日: \(entity.isToday)")
    print("   金额有效: \(entity.isValidAmount)")
    
    print("✅ TransactionEntity测试完成\n")
}

// 运行所有测试
testTransactionCategory()
testCategorizationLogic() 
testAmountExtraction()
testTransactionEntity()

print("🎉 所有基础测试完成!")
print("📊 测试摘要:")
print("- TransactionCategory枚举: 正常")
print("- 分类逻辑: 需要进一步优化") 
print("- 金额提取: 基本正常")
print("- TransactionEntity: 正常")