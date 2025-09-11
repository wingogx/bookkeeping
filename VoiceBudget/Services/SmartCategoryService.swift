import Foundation
import NaturalLanguage

protocol SmartCategoryServiceProtocol {
    func categorizeTransaction(from text: String) -> TransactionCategory
    func extractAmount(from text: String) -> Double?
    func extractDescription(from text: String) -> String
    func analyzeSpendingPattern(transactions: [TransactionEntity]) -> SpendingPattern
}

class SmartCategoryService: SmartCategoryServiceProtocol {
    
    // MARK: - Category Keywords
    private let categoryKeywords: [TransactionCategory: [String]] = [
        .food: [
            "吃", "喝", "餐", "饭", "面", "汤", "菜", "肉", "鱼", "水果", "零食", "咖啡", "奶茶",
            "早餐", "午餐", "晚餐", "夜宵", "烧烤", "火锅", "麦当劳", "肯德基", "星巴克",
            "餐厅", "食堂", "外卖", "美团", "饿了么", "KFC", "麦当劳", "pizza", "汉堡"
        ],
        .transport: [
            "打车", "出租车", "地铁", "公交", "滴滴", "uber", "车费", "油费", "停车",
            "高铁", "火车", "飞机", "机票", "车票", "船票", "摩托", "自行车", "共享单车",
            "加油", "维修", "保险", "年检", "违章"
        ],
        .entertainment: [
            "电影", "游戏", "KTV", "酒吧", "夜店", "演唱会", "话剧", "音乐", "书籍",
            "健身", "游泳", "篮球", "足球", "网球", "瑜伽", "按摩", "SPA", "旅游",
            "景点", "门票", "娱乐", "休闲", "爱奇艺", "腾讯视频", "Netflix"
        ],
        .shopping: [
            "买", "购", "商场", "超市", "淘宝", "天猫", "京东", "拼多多", "苏宁", "亚马逊",
            "衣服", "鞋子", "包包", "化妆品", "护肤品", "香水", "首饰", "手表", "眼镜",
            "手机", "电脑", "耳机", "相机", "家电", "家具", "装修", "日用品", "洗发水"
        ],
        .health: [
            "医院", "看病", "药", "体检", "挂号", "治疗", "手术", "住院", "药店",
            "保健品", "维生素", "医疗", "健康", "牙医", "眼科", "中医", "西医", "疫苗"
        ]
    ]
    
    // MARK: - Public Methods
    func categorizeTransaction(from text: String) -> TransactionCategory {
        let normalizedText = text.lowercased()
        var categoryScores: [TransactionCategory: Int] = [:]
        
        // 计算每个类别的匹配分数
        for (category, keywords) in categoryKeywords {
            let score = keywords.reduce(0) { score, keyword in
                score + (normalizedText.contains(keyword) ? 1 : 0)
            }
            categoryScores[category] = score
        }
        
        // 返回得分最高的类别
        let bestMatch = categoryScores.max { $0.value < $1.value }
        return bestMatch?.key ?? .other
    }
    
    func extractAmount(from text: String) -> Double? {
        // 使用正则表达式提取金额
        let patterns = [
            "\\d+\\.\\d+", // 23.50
            "\\d+", // 23
            "\\d+块\\d*", // 23块5
            "\\d+元\\d*" // 23元5角
        ]
        
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                let amountString = String(text[range])
                
                // 处理不同格式
                if amountString.contains("块") || amountString.contains("元") {
                    // 提取数字部分
                    let numbers = amountString.components(separatedBy: CharacterSet.decimalDigits.inverted)
                        .compactMap { Double($0) }
                    
                    if numbers.count >= 1 {
                        let yuan = numbers[0]
                        let jiao = numbers.count > 1 ? numbers[1] / 10.0 : 0
                        return yuan + jiao
                    }
                } else {
                    return Double(amountString)
                }
            }
        }
        
        return nil
    }
    
    func extractDescription(from text: String) -> String {
        // 移除金额信息，保留描述性内容
        var description = text
        
        // 移除常见的金额表达
        let amountPatterns = [
            "\\d+\\.\\d+元?块?",
            "\\d+元?块?",
            "花了\\d+",
            "用了\\d+",
            "买了\\d+",
            "¥\\d+"
        ]
        
        for pattern in amountPatterns {
            description = description.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
        
        // 清理空格和标点
        description = description
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
        
        return description.isEmpty ? text : description
    }
    
    func analyzeSpendingPattern(transactions: [TransactionEntity]) -> SpendingPattern {
        guard !transactions.isEmpty else {
            return SpendingPattern(
                averageDaily: 0,
                mostFrequentCategory: .other,
                totalSpent: 0,
                transactionCount: 0,
                categoryDistribution: [:]
            )
        }
        
        let totalSpent = transactions.reduce(0) { $0 + $1.amount }
        let transactionCount = transactions.count
        
        // 计算类别分布
        let categoryDistribution = Dictionary(grouping: transactions, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        
        // 找出最常用的类别
        let mostFrequentCategory = categoryDistribution.max { $0.value < $1.value }?.key ?? .other
        
        // 计算日均消费
        let dateRange = transactions.map(\.createdAt).sorted()
        let daysDifference = Calendar.current.dateComponents([.day], 
                                                           from: dateRange.first ?? Date(), 
                                                           to: dateRange.last ?? Date()).day ?? 1
        let averageDaily = totalSpent / Double(max(daysDifference, 1))
        
        return SpendingPattern(
            averageDaily: averageDaily,
            mostFrequentCategory: mostFrequentCategory,
            totalSpent: totalSpent,
            transactionCount: transactionCount,
            categoryDistribution: categoryDistribution
        )
    }
}

// MARK: - Advanced Natural Language Processing
extension SmartCategoryService {
    
    /// 使用苹果的自然语言处理框架进行更智能的分类
    func categorizeTransactionWithNLP(from text: String) -> TransactionCategory {
        let tagger = NLTagger(tagSchemes: [.tokenType, .lexicalClass])
        tagger.string = text
        
        var keywords: [String] = []
        
        // 提取名词和动词作为关键词
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, 
                           unit: .word, 
                           scheme: .lexicalClass) { tag, tokenRange in
            
            if let tag = tag, (tag == .noun || tag == .verb) {
                let keyword = String(text[tokenRange]).lowercased()
                keywords.append(keyword)
            }
            
            return true
        }
        
        // 使用提取的关键词进行分类
        return categorizeByKeywords(keywords)
    }
    
    private func categorizeByKeywords(_ keywords: [String]) -> TransactionCategory {
        var categoryScores: [TransactionCategory: Double] = [:]
        
        for (category, categoryKeywords) in categoryKeywords {
            let score = keywords.reduce(0.0) { score, keyword in
                let matchScore = categoryKeywords.contains { $0.contains(keyword) || keyword.contains($0) }
                return score + (matchScore ? 1.0 : 0.0)
            }
            categoryScores[category] = score
        }
        
        return categoryScores.max { $0.value < $1.value }?.key ?? .other
    }
}

// MARK: - Data Models
struct SpendingPattern {
    let averageDaily: Double
    let mostFrequentCategory: TransactionCategory
    let totalSpent: Double
    let transactionCount: Int
    let categoryDistribution: [TransactionCategory: Double]
    
    var insights: [String] {
        var insights: [String] = []
        
        // 日均消费分析
        if averageDaily > 100 {
            insights.append("日均消费较高，建议关注支出控制")
        } else if averageDaily < 20 {
            insights.append("消费习惯良好，支出控制得当")
        }
        
        // 类别分析
        let categoryName = mostFrequentCategory.displayName
        let categoryAmount = categoryDistribution[mostFrequentCategory] ?? 0
        let categoryPercentage = (categoryAmount / totalSpent) * 100
        
        if categoryPercentage > 50 {
            insights.append("\(categoryName)支出占比过高(\(categoryPercentage.rounded())%)")
        }
        
        // 交易频次分析
        if transactionCount > totalSpent / 10 {
            insights.append("小额消费频繁，建议减少冲动消费")
        }
        
        return insights
    }
}