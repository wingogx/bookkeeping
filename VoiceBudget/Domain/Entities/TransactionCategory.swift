import Foundation

/// 交易分类枚举
/// 定义了所有支持的交易分类类型
public enum TransactionCategory: String, CaseIterable, Codable {
    case food = "food"                 // 餐饮
    case transport = "transport"       // 交通  
    case shopping = "shopping"         // 购物
    case entertainment = "entertainment" // 娱乐
    case healthcare = "healthcare"     // 医疗
    case education = "education"       // 教育
    case utilities = "utilities"       // 生活缴费
    case other = "other"              // 其他
    
    /// 本地化显示名称
    public var localizedName: String {
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
    
    /// 分类图标
    public var icon: String {
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
    
    /// 分类颜色
    public var colorHex: String {
        switch self {
        case .food: return "#FF6B6B"
        case .transport: return "#45B7D1"
        case .shopping: return "#4ECDC4"
        case .entertainment: return "#FECA57"
        case .healthcare: return "#FF9FF3"
        case .education: return "#54A0FF"
        case .utilities: return "#96CEB4"
        case .other: return "#C4C4C4"
        }
    }
    
    /// 分类描述
    public var description: String {
        switch self {
        case .food: return "餐饮食物相关支出"
        case .transport: return "交通出行相关支出"
        case .shopping: return "购物消费相关支出"
        case .entertainment: return "娱乐休闲相关支出"
        case .healthcare: return "医疗健康相关支出"
        case .education: return "教育学习相关支出"
        case .utilities: return "水电煤气等生活缴费"
        case .other: return "其他未分类支出"
        }
    }
    
    /// 默认预算占比（基于常见理财建议）
    public var defaultBudgetRatio: Double {
        switch self {
        case .food: return 0.30        // 30% 餐饮
        case .transport: return 0.15   // 15% 交通
        case .shopping: return 0.20    // 20% 购物
        case .entertainment: return 0.10 // 10% 娱乐
        case .healthcare: return 0.05  // 5% 医疗
        case .education: return 0.05   // 5% 教育
        case .utilities: return 0.10   // 10% 生活缴费
        case .other: return 0.05       // 5% 其他
        }
    }
    
    /// 是否为必需支出
    public var isEssential: Bool {
        switch self {
        case .food, .transport, .healthcare, .utilities:
            return true
        case .shopping, .entertainment, .education, .other:
            return false
        }
    }
    
    /// 分类优先级（用于智能分类时的决策）
    public var priority: Int {
        switch self {
        case .food: return 1
        case .transport: return 2
        case .utilities: return 3
        case .healthcare: return 4
        case .shopping: return 5
        case .education: return 6
        case .entertainment: return 7
        case .other: return 8
        }
    }
}

// MARK: - Category Statistics Helper
public struct CategoryStatistic {
    public let categoryID: String
    public let categoryName: String
    public let totalAmount: Decimal
    public let transactionCount: Int
    public let averageAmount: Decimal
    public let percentage: Double?
    
    public init(
        categoryID: String,
        categoryName: String,
        totalAmount: Decimal,
        transactionCount: Int,
        averageAmount: Decimal,
        percentage: Double? = nil
    ) {
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.totalAmount = totalAmount
        self.transactionCount = transactionCount
        self.averageAmount = averageAmount
        self.percentage = percentage
    }
    
    /// 对应的分类枚举
    public var category: TransactionCategory {
        return TransactionCategory(rawValue: categoryID) ?? .other
    }
    
    /// 格式化金额显示
    public var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSDecimalNumber(decimal: totalAmount)) ?? "¥0.00"
    }
    
    /// 格式化平均金额显示
    public var formattedAverageAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSDecimalNumber(decimal: averageAmount)) ?? "¥0.00"
    }
}

// MARK: - Category Extensions for SwiftUI
#if canImport(SwiftUI)
import SwiftUI

extension TransactionCategory {
    /// SwiftUI Color
    public var color: Color {
        return Color(hex: colorHex) ?? .gray
    }
}

// Color extension to support hex colors
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}
#endif

// MARK: - Hashable Conformance
extension TransactionCategory: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}