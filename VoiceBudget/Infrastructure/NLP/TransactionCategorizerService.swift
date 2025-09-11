import Foundation
import NaturalLanguage

/// 交易分类服务
/// 使用自然语言处理将语音文本智能分类为支出类型
public class TransactionCategorizerService {
    
    // MARK: - Category Definitions
    public struct CategoryMatch {
        public let category: TransactionCategory
        public let confidence: Double
        public let extractedAmount: Decimal?
        public let extractedDescription: String?
    }
    
    // MARK: - Category Keywords
    private let categoryKeywords: [TransactionCategory: [String]] = [
        .food: ["吃饭", "午餐", "晚餐", "早餐", "点餐", "外卖", "餐厅", "饭店", "咖啡", "奶茶", "零食", "食物", "菜", "米饭", "面条", "包子", "火锅", "烧烤", "麦当劳", "肯德基", "星巴克"],
        .transport: ["打车", "地铁", "公交", "出租车", "滴滴", "uber", "交通", "车费", "油费", "加油", "停车", "高铁", "火车", "飞机", "机票", "船票"],
        .shopping: ["买", "购物", "淘宝", "京东", "商场", "超市", "衣服", "鞋子", "包包", "化妆品", "电子产品", "手机", "电脑", "书", "文具"],
        .entertainment: ["电影", "KTV", "游戏", "娱乐", "音乐", "演唱会", "话剧", "展览", "游乐园", "网吧", "台球", "保龄球", "唱歌"],
        .healthcare: ["医院", "看病", "药", "体检", "牙医", "眼镜", "保健品", "按摩", "理疗", "康复", "疫苗"],
        .education: ["学费", "培训", "课程", "书本", "教材", "补习", "兴趣班", "驾校", "考试", "证书"],
        .utilities: ["水费", "电费", "燃气费", "网费", "电话费", "物业费", "房租", "宽带", "充值", "话费"],
        .other: ["其他", "杂费", "礼品", "红包", "捐款", "罚款", "维修", "保险", "税费"]
    ]
    
    // MARK: - Amount Extraction Patterns
    private let amountPatterns = [
        // 匹配 "花了30", "用了50块", "付了100元"
        try! NSRegularExpression(pattern: "(花了|用了|付了|消费了|支付了)([0-9]+\\.?[0-9]*)(元|块|毛|分)?", options: .caseInsensitive),
        // 匹配 "30块钱", "50元", "100"
        try! NSRegularExpression(pattern: "([0-9]+\\.?[0-9]*)(元|块|毛|分|块钱)", options: .caseInsensitive),
        // 匹配纯数字 "30", "50.5"
        try! NSRegularExpression(pattern: "([0-9]+\\.?[0-9]*)", options: .caseInsensitive)
    ]
    
    // MARK: - NL Processing
    private let tokenizer = NLTokenizer(unit: .word)
    private let tagger = NLTagger(tagSchemes: [.tokenType, .lexicalClass])
    
    public init() {
        tokenizer.setLanguage(.simplifiedChinese)
        tagger.setLanguage(.simplifiedChinese, range: nil)
    }
    
    // MARK: - Main Classification Method
    public func categorizeTransaction(from text: String) -> CategoryMatch {
        let cleanedText = cleanText(text)
        
        // 1. 提取金额
        let extractedAmount = extractAmount(from: cleanedText)
        
        // 2. 提取描述（去除金额部分）
        let extractedDescription = extractDescription(from: cleanedText)
        
        // 3. 分类匹配
        let categoryMatch = matchCategory(for: cleanedText)
        
        return CategoryMatch(
            category: categoryMatch.category,
            confidence: categoryMatch.confidence,
            extractedAmount: extractedAmount,
            extractedDescription: extractedDescription
        )
    }
    
    // MARK: - Text Cleaning
    private func cleanText(_ text: String) -> String {
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "。", with: ".")
            .lowercased()
    }
    
    // MARK: - Amount Extraction
    private func extractAmount(from text: String) -> Decimal? {
        for pattern in amountPatterns {
            let range = NSRange(text.startIndex..., in: text)
            let matches = pattern.matches(in: text, options: [], range: range)
            
            for match in matches {
                if match.numberOfRanges > 1 {
                    let amountRange = match.range(at: 1)
                    if let range = Range(amountRange, in: text) {
                        let amountString = String(text[range])
                        if let amount = Decimal(string: amountString) {
                            return amount
                        }
                    }
                }
            }
        }
        return nil
    }
    
    // MARK: - Description Extraction
    private func extractDescription(from text: String) -> String? {
        var description = text
        
        // 移除金额相关的词汇
        for pattern in amountPatterns {
            description = pattern.stringByReplacingMatches(
                in: description,
                options: [],
                range: NSRange(description.startIndex..., in: description),
                withTemplate: ""
            )
        }
        
        // 移除常见的动词
        let verbsToRemove = ["花了", "用了", "付了", "消费了", "支付了", "买了", "去了", "在"]
        for verb in verbsToRemove {
            description = description.replacingOccurrences(of: verb, with: "")
        }
        
        let cleaned = description
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "，。,. "))
        
        return cleaned.isEmpty ? nil : cleaned
    }
    
    // MARK: - Category Matching
    private func matchCategory(for text: String) -> (category: TransactionCategory, confidence: Double) {
        var bestMatch: TransactionCategory = .other
        var bestScore: Double = 0.0
        
        // 分词处理
        tokenizer.string = text
        let tokens = tokenizer.tokens(for: text.startIndex..<text.endIndex)
        let words = tokens.map { String(text[$0]) }
        
        // 逐个类别匹配
        for (category, keywords) in categoryKeywords {
            let score = calculateCategoryScore(words: words, keywords: keywords, originalText: text)
            if score > bestScore {
                bestScore = score
                bestMatch = category
            }
        }
        
        // 如果最高分太低，归类为其他
        if bestScore < 0.3 {
            bestMatch = .other
            bestScore = 1.0
        }
        
        return (bestMatch, bestScore)
    }
    
    // MARK: - Score Calculation
    private func calculateCategoryScore(words: [String], keywords: [String], originalText: String) -> Double {
        var score: Double = 0.0
        let totalWords = words.count
        
        for word in words {
            for keyword in keywords {
                // 精确匹配
                if word == keyword {
                    score += 1.0
                }
                // 包含匹配
                else if word.contains(keyword) || keyword.contains(word) {
                    score += 0.7
                }
                // 字符相似度匹配
                else if similarity(word, keyword) > 0.8 {
                    score += 0.5
                }
            }
        }
        
        // 归一化分数
        return min(score / Double(max(totalWords, 1)), 1.0)
    }
    
    // MARK: - String Similarity
    private func similarity(_ s1: String, _ s2: String) -> Double {
        let longer = s1.count > s2.count ? s1 : s2
        let shorter = s1.count > s2.count ? s2 : s1
        
        if longer.count == 0 {
            return 1.0
        }
        
        let editDistance = levenshteinDistance(s1, s2)
        return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Count = s1Array.count
        let s2Count = s2Array.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: s2Count + 1), count: s1Count + 1)
        
        for i in 0...s1Count {
            matrix[i][0] = i
        }
        
        for j in 0...s2Count {
            matrix[0][j] = j
        }
        
        for i in 1...s1Count {
            for j in 1...s2Count {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = Swift.min(
                    matrix[i-1][j] + 1,      // 删除
                    matrix[i][j-1] + 1,      // 插入
                    matrix[i-1][j-1] + cost  // 替换
                )
            }
        }
        
        return matrix[s1Count][s2Count]
    }
}

// MARK: - Transaction Category Extension
extension TransactionCategory {
    var localizedName: String {
        switch self {
        case .food: return "餐饮"
        case .transport: return "交通"
        case .shopping: return "购物"
        case .entertainment: return "娱乐"
        case .healthcare: return "医疗"
        case .education: return "教育"
        case .utilities: return "生活缴费"
        case .other: return "其他"
        }
    }
    
    var icon: String {
        switch self {
        case .food: return "🍽"
        case .transport: return "🚗"
        case .shopping: return "🛍"
        case .entertainment: return "🎬"
        case .healthcare: return "🏥"
        case .education: return "📚"
        case .utilities: return "💡"
        case .other: return "📝"
        }
    }
}

// MARK: - Preview/Testing Helpers
#if DEBUG
extension TransactionCategorizerService {
    public func testCategorization() {
        let testCases = [
            "今天午餐花了38块",
            "打车去机场用了120元",
            "在淘宝买了一件衣服200块",
            "看电影票价45元",
            "去医院看病花了300",
            "报了一个英语培训班2000块",
            "交了这个月的电费150元",
            "给朋友买了生日礼物88块"
        ]
        
        for testCase in testCases {
            let result = categorizeTransaction(from: testCase)
            print("输入: \(testCase)")
            print("分类: \(result.category.localizedName)")
            print("金额: \(result.extractedAmount?.description ?? "未识别")")
            print("描述: \(result.extractedDescription ?? "未识别")")
            print("置信度: \(String(format: "%.2f", result.confidence))")
            print("---")
        }
    }
}
#endif