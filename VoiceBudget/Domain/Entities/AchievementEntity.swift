import Foundation

/// 成就领域实体
/// 表示用户成就的业务概念
public struct AchievementEntity: Codable, Identifiable, Equatable {
    
    // MARK: - Properties
    
    /// 成就ID
    public let id: String
    
    /// 成就标题
    public let title: String
    
    /// 成就描述
    public let description: String
    
    /// 图标名称
    public let iconName: String
    
    /// 是否已解锁
    public let isUnlocked: Bool
    
    /// 解锁时间
    public let unlockedAt: Date?
    
    /// 成就类型
    public let type: AchievementType
    
    /// 当前进度
    public let progress: Int
    
    /// 目标值
    public let target: Int
    
    // MARK: - Enums
    
    /// 成就类型
    public enum AchievementType: String, Codable, CaseIterable {
        case streak = "streak"       // 连击类成就
        case budget = "budget"       // 预算类成就
        case social = "social"       // 社交类成就
        case milestone = "milestone" // 里程碑成就
        case special = "special"     // 特殊成就
    }
    
    // MARK: - Initializer
    
    /// 初始化成就实体
    /// - Parameters:
    ///   - id: 成就ID
    ///   - title: 成就标题
    ///   - description: 成就描述
    ///   - iconName: 图标名称
    ///   - type: 成就类型
    ///   - target: 目标值，默认为1
    ///   - progress: 当前进度，默认为0
    ///   - isUnlocked: 是否已解锁，默认为false
    ///   - unlockedAt: 解锁时间
    public init(
        id: String,
        title: String,
        description: String,
        iconName: String,
        type: AchievementType,
        target: Int = 1,
        progress: Int = 0,
        isUnlocked: Bool = false,
        unlockedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.iconName = iconName
        self.type = type
        self.target = target
        self.progress = progress
        self.isUnlocked = isUnlocked
        self.unlockedAt = unlockedAt
    }
    
    // MARK: - Business Logic
    
    /// 进度百分比
    public var progressPercentage: Double {
        guard target > 0 else { return 0 }
        return Double(progress) / Double(target)
    }
    
    /// 是否已完成（进度达到目标）
    public var isCompleted: Bool {
        return progress >= target
    }
    
    /// 是否可以解锁
    public var canUnlock: Bool {
        return !isUnlocked && isCompleted
    }
    
    /// 更新进度
    /// - Parameter newProgress: 新的进度值
    /// - Returns: 更新后的成就实体
    public func updatingProgress(_ newProgress: Int) -> AchievementEntity {
        let clampedProgress = max(0, min(newProgress, target))
        
        return AchievementEntity(
            id: self.id,
            title: self.title,
            description: self.description,
            iconName: self.iconName,
            type: self.type,
            target: self.target,
            progress: clampedProgress,
            isUnlocked: self.isUnlocked,
            unlockedAt: self.unlockedAt
        )
    }
    
    /// 解锁成就
    /// - Returns: 解锁后的成就实体
    public func unlocked() -> AchievementEntity {
        guard canUnlock else { return self }
        
        return AchievementEntity(
            id: self.id,
            title: self.title,
            description: self.description,
            iconName: self.iconName,
            type: self.type,
            target: self.target,
            progress: self.progress,
            isUnlocked: true,
            unlockedAt: Date()
        )
    }
    
    /// 增加进度
    /// - Parameter increment: 增加的进度值，默认为1
    /// - Returns: 更新后的成就实体
    public func incrementingProgress(by increment: Int = 1) -> AchievementEntity {
        return updatingProgress(progress + increment)
    }
}

// MARK: - Predefined Achievements

extension AchievementEntity {
    
    /// 预定义成就列表
    public static let predefinedAchievements: [AchievementEntity] = [
        
        // 连击类成就
        AchievementEntity(
            id: "first_record",
            title: "记账新手",
            description: "完成首次记账",
            iconName: "star.fill",
            type: .milestone,
            target: 1
        ),
        
        AchievementEntity(
            id: "streak_3_days",
            title: "记账小能手",
            description: "连续记账3天",
            iconName: "flame.fill",
            type: .streak,
            target: 3
        ),
        
        AchievementEntity(
            id: "streak_7_days",
            title: "坚持之星",
            description: "连续记账7天",
            iconName: "star.circle.fill",
            type: .streak,
            target: 7
        ),
        
        AchievementEntity(
            id: "streak_15_days",
            title: "习惯大师",
            description: "连续记账15天",
            iconName: "crown.fill",
            type: .streak,
            target: 15
        ),
        
        AchievementEntity(
            id: "streak_30_days",
            title: "记账之王",
            description: "连续记账30天",
            iconName: "trophy.fill",
            type: .streak,
            target: 30
        ),
        
        // 预算类成就
        AchievementEntity(
            id: "first_budget",
            title: "预算新人",
            description: "首次设置预算",
            iconName: "chart.pie.fill",
            type: .budget,
            target: 1
        ),
        
        AchievementEntity(
            id: "budget_keeper",
            title: "预算守护者",
            description: "月度预算不超支",
            iconName: "checkmark.shield.fill",
            type: .budget,
            target: 1
        ),
        
        AchievementEntity(
            id: "money_saver",
            title: "省钱小能手",
            description: "与上月相比节约支出",
            iconName: "banknote.fill",
            type: .budget,
            target: 1
        ),
        
        // 社交类成就
        AchievementEntity(
            id: "first_share",
            title: "分享达人",
            description: "首次分享记账成就",
            iconName: "square.and.arrow.up.fill",
            type: .social,
            target: 1
        ),
        
        // 特殊成就
        AchievementEntity(
            id: "night_owl",
            title: "夜猫子",
            description: "晚上12点后记账",
            iconName: "moon.fill",
            type: .special,
            target: 1
        ),
        
        AchievementEntity(
            id: "early_bird",
            title: "早起鸟",
            description: "早上8点前记账",
            iconName: "sun.max.fill",
            type: .special,
            target: 1
        ),
        
        // 里程碑成就
        AchievementEntity(
            id: "transaction_100",
            title: "记账百强",
            description: "累计记账100笔",
            iconName: "number.circle.fill",
            type: .milestone,
            target: 100
        ),
        
        AchievementEntity(
            id: "category_explorer",
            title: "分类探索者",
            description: "使用所有基础分类",
            iconName: "map.fill",
            type: .milestone,
            target: 4 // 对应4个基础分类
        )
    ]
}