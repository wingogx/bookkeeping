import Foundation

/// 分类领域实体
/// 表示记账分类的业务概念
public struct CategoryEntity: Codable, Identifiable, Equatable {
    
    // MARK: - Properties
    
    /// 分类ID
    public let id: String
    
    /// 分类名称
    public let name: String
    
    /// 分类图标
    public let icon: String
    
    /// 分类颜色代码
    public let color: String
    
    /// 显示顺序
    public let displayOrder: Int
    
    /// 是否为自定义分类
    public let isCustom: Bool
    
    /// 是否已解锁
    public let isUnlocked: Bool
    
    /// 解锁日期
    public let unlockDate: Date?
    
    /// 关键词映射
    public let keywords: [String]
    
    // MARK: - Initializer
    
    /// 初始化分类实体
    /// - Parameters:
    ///   - id: 分类ID
    ///   - name: 分类名称
    ///   - icon: 分类图标
    ///   - color: 分类颜色代码
    ///   - displayOrder: 显示顺序，默认为0
    ///   - isCustom: 是否为自定义分类，默认为false
    ///   - isUnlocked: 是否已解锁，默认为true
    ///   - unlockDate: 解锁日期
    ///   - keywords: 关键词映射，默认为空数组
    public init(
        id: String,
        name: String,
        icon: String,
        color: String,
        displayOrder: Int = 0,
        isCustom: Bool = false,
        isUnlocked: Bool = true,
        unlockDate: Date? = nil,
        keywords: [String] = []
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.displayOrder = displayOrder
        self.isCustom = isCustom
        self.isUnlocked = isUnlocked
        self.unlockDate = unlockDate
        self.keywords = keywords
    }
    
    // MARK: - Business Logic
    
    /// 是否匹配给定的关键词
    /// - Parameter keyword: 要匹配的关键词
    /// - Returns: 是否匹配
    public func matches(keyword: String) -> Bool {
        let lowercaseKeyword = keyword.lowercased()
        return keywords.contains { $0.lowercased().contains(lowercaseKeyword) } ||
               name.lowercased().contains(lowercaseKeyword)
    }
    
    /// 关键词匹配得分（用于智能分类）
    /// - Parameter text: 要分析的文本
    /// - Returns: 匹配得分（0-1之间）
    public func matchingScore(for text: String) -> Double {
        let lowercaseText = text.lowercased()
        var score: Double = 0
        
        // 精确匹配分类名称
        if lowercaseText.contains(name.lowercased()) {
            score += 0.8
        }
        
        // 匹配关键词
        for keyword in keywords {
            if lowercaseText.contains(keyword.lowercased()) {
                score += 0.6 / Double(keywords.count)
            }
        }
        
        return min(score, 1.0)
    }
    
    /// 创建解锁后的分类实体
    /// - Returns: 解锁后的分类实体
    public func unlocked() -> CategoryEntity {
        return CategoryEntity(
            id: self.id,
            name: self.name,
            icon: self.icon,
            color: self.color,
            displayOrder: self.displayOrder,
            isCustom: self.isCustom,
            isUnlocked: true,
            unlockDate: Date(),
            keywords: self.keywords
        )
    }
    
    /// 添加关键词
    /// - Parameter keyword: 要添加的关键词
    /// - Returns: 添加关键词后的分类实体
    public func addingKeyword(_ keyword: String) -> CategoryEntity {
        guard !keywords.contains(keyword.lowercased()) else { return self }
        
        var newKeywords = keywords
        newKeywords.append(keyword.lowercased())
        
        return CategoryEntity(
            id: self.id,
            name: self.name,
            icon: self.icon,
            color: self.color,
            displayOrder: self.displayOrder,
            isCustom: self.isCustom,
            isUnlocked: self.isUnlocked,
            unlockDate: self.unlockDate,
            keywords: newKeywords
        )
    }
}

// MARK: - Predefined Categories

extension CategoryEntity {
    
    /// 预定义分类 - 新手模式（4个核心分类）
    public static let beginnerCategories: [CategoryEntity] = [
        CategoryEntity(
            id: "dining",
            name: "吃吃喝喝",
            icon: "🍽",
            color: "#FF6B6B",
            displayOrder: 1,
            keywords: ["早餐", "午餐", "晚餐", "外卖", "吃饭", "喝茶", "咖啡", "下午茶", "聚餐", "夜宵"]
        ),
        CategoryEntity(
            id: "shopping",
            name: "买买买",
            icon: "🛍",
            color: "#4ECDC4",
            displayOrder: 2,
            keywords: ["买衣服", "买鞋", "淘宝", "京东", "网购", "化妆品", "买包", "礼品", "购物"]
        ),
        CategoryEntity(
            id: "transportation",
            name: "出行路上",
            icon: "🚗",
            color: "#45B7D1",
            displayOrder: 3,
            keywords: ["打车", "地铁", "公交", "加油", "停车", "高铁", "机票", "共享单车", "出租车"]
        ),
        CategoryEntity(
            id: "others",
            name: "其他",
            icon: "🤷‍♀️",
            color: "#96CEB4",
            displayOrder: 4,
            keywords: ["其他", "杂项", "未分类"]
        )
    ]
    
    /// 预定义分类 - 精细模式（8个分类）
    public static let advancedCategories: [CategoryEntity] = [
        CategoryEntity(
            id: "dining",
            name: "餐饮",
            icon: "🍴",
            color: "#FF6B6B",
            displayOrder: 1,
            isUnlocked: false,
            keywords: ["早餐", "午餐", "晚餐", "外卖", "咖啡", "小食"]
        ),
        CategoryEntity(
            id: "transportation", 
            name: "交通",
            icon: "🚆",
            color: "#45B7D1",
            displayOrder: 2,
            isUnlocked: false,
            keywords: ["打车", "地铁", "公交", "加油", "高铁", "飞机"]
        ),
        CategoryEntity(
            id: "shopping",
            name: "购物",
            icon: "🛍",
            color: "#4ECDC4",
            displayOrder: 3,
            isUnlocked: false,
            keywords: ["服装", "数码", "化妆品", "网购", "礼品"]
        ),
        CategoryEntity(
            id: "living",
            name: "生活",
            icon: "🏠",
            color: "#96CEB4",
            displayOrder: 4,
            isUnlocked: false,
            keywords: ["买菜", "超市", "日用品", "水电", "房租"]
        ),
        CategoryEntity(
            id: "entertainment",
            name: "娱乐",
            icon: "🎬",
            color: "#FECA57",
            displayOrder: 5,
            isUnlocked: false,
            keywords: ["电影", "KTV", "游戏", "旅游", "运动"]
        ),
        CategoryEntity(
            id: "medical",
            name: "医疗",
            icon: "🏥",
            color: "#FF9FF3",
            displayOrder: 6,
            isUnlocked: false,
            keywords: ["看病", "买药", "体检", "牙科"]
        ),
        CategoryEntity(
            id: "education",
            name: "学习",
            icon: "📚",
            color: "#54A0FF",
            displayOrder: 7,
            isUnlocked: false,
            keywords: ["书籍", "课程", "培训", "教育"]
        ),
        CategoryEntity(
            id: "others",
            name: "其他",
            icon: "🤷‍♀️",
            color: "#C4C4C4",
            displayOrder: 8,
            keywords: ["其他", "杂项"]
        )
    ]
}