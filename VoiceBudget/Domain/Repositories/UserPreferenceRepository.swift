import Foundation

/// 用户偏好仓储协议
/// 定义用户设置和偏好数据访问的标准接口
public protocol UserPreferenceRepository {
    
    // MARK: - Basic Operations
    
    /// 获取用户偏好值
    /// - Parameters:
    ///   - key: 偏好设置的键
    ///   - defaultValue: 默认值，当偏好不存在时返回此值
    /// - Returns: 偏好值
    /// - Throws: 获取失败时抛出错误
    func getValue<T: Codable>(for key: UserPreferenceKey, defaultValue: T) async throws -> T
    
    /// 设置用户偏好值
    /// - Parameters:
    ///   - value: 要设置的值
    ///   - key: 偏好设置的键
    /// - Throws: 设置失败时抛出错误
    func setValue<T: Codable>(_ value: T, for key: UserPreferenceKey) async throws
    
    /// 删除用户偏好
    /// - Parameter key: 要删除的偏好键
    /// - Throws: 删除失败时抛出错误
    func removeValue(for key: UserPreferenceKey) async throws
    
    /// 检查偏好是否存在
    /// - Parameter key: 偏好键
    /// - Returns: 是否存在该偏好
    /// - Throws: 检查失败时抛出错误
    func hasValue(for key: UserPreferenceKey) async throws -> Bool
    
    // MARK: - Batch Operations
    
    /// 批量获取偏好值
    /// - Parameter keys: 偏好键列表
    /// - Returns: 键值对字典
    /// - Throws: 获取失败时抛出错误
    func getValues(for keys: [UserPreferenceKey]) async throws -> [UserPreferenceKey: Any]
    
    /// 批量设置偏好值
    /// - Parameter preferences: 要设置的偏好字典
    /// - Throws: 设置失败时抛出错误
    func setValues(_ preferences: [UserPreferenceKey: Any]) async throws
    
    /// 获取所有偏好
    /// - Returns: 所有偏好的键值对字典
    /// - Throws: 获取失败时抛出错误
    func getAllPreferences() async throws -> [UserPreferenceKey: Any]
    
    /// 清除所有偏好
    /// - Throws: 清除失败时抛出错误
    func clearAllPreferences() async throws
    
    // MARK: - Observation
    
    /// 观察偏好值变化
    /// - Parameter key: 要观察的偏好键
    /// - Returns: 异步序列，当偏好值变化时发出新值
    func observeValue<T: Codable>(for key: UserPreferenceKey, type: T.Type) -> AsyncStream<T?>
    
    /// 观察多个偏好值变化
    /// - Parameter keys: 要观察的偏好键列表
    /// - Returns: 异步序列，当任一偏好值变化时发出更新的键值对
    func observeValues(for keys: [UserPreferenceKey]) -> AsyncStream<[UserPreferenceKey: Any]>
}

// MARK: - User Preference Keys

/// 用户偏好键枚举
/// 定义所有可能的用户偏好设置
public enum UserPreferenceKey: String, CaseIterable {
    
    // MARK: - App Settings
    case firstLaunch = "first_launch"                    // 是否首次启动
    case onboardingCompleted = "onboarding_completed"    // 是否完成新手引导
    case appVersion = "app_version"                      // 应用版本
    case lastLaunchDate = "last_launch_date"            // 最后启动时间
    
    // MARK: - User Profile
    case userName = "user_name"                          // 用户昵称
    case userLevel = "user_level"                        // 用户等级
    case consecutiveRecordDays = "consecutive_record_days" // 连续记账天数
    case totalTransactionCount = "total_transaction_count" // 累计记账笔数
    
    // MARK: - Recording Preferences
    case defaultCurrency = "default_currency"           // 默认货币
    case enableVoiceRecording = "enable_voice_recording" // 启用语音记账
    case voiceRecognitionLanguage = "voice_recognition_language" // 语音识别语言
    case autoSaveTransactions = "auto_save_transactions" // 自动保存交易
    case defaultTransactionSource = "default_transaction_source" // 默认记账方式
    
    // MARK: - Category Settings
    case enabledCategoryMode = "enabled_category_mode"   // 启用的分类模式（beginner/advanced/custom）
    case unlockedCategories = "unlocked_categories"      // 已解锁的分类列表
    case customCategories = "custom_categories"          // 自定义分类列表
    case categoryUnlockDate = "category_unlock_date"     // 分类解锁日期记录
    
    // MARK: - Budget Settings
    case budgetReminderEnabled = "budget_reminder_enabled" // 启用预算提醒
    case budgetWarningThreshold = "budget_warning_threshold" // 预算警告阈值
    case defaultBudgetPeriod = "default_budget_period"    // 默认预算周期
    case budgetAllocationTemplate = "budget_allocation_template" // 预算分配模板
    
    // MARK: - Notification Settings
    case notificationsEnabled = "notifications_enabled"  // 启用通知
    case dailyReminderEnabled = "daily_reminder_enabled" // 每日记账提醒
    case dailyReminderTime = "daily_reminder_time"       // 每日提醒时间
    case budgetAlertEnabled = "budget_alert_enabled"     // 预算警告
    case achievementNotificationEnabled = "achievement_notification_enabled" // 成就通知
    
    // MARK: - Security Settings
    case biometricAuthEnabled = "biometric_auth_enabled" // 生物识别验证
    case authRequiredOnLaunch = "auth_required_on_launch" // 启动时需要验证
    case authRequiredOnSensitiveOperation = "auth_required_on_sensitive_operation" // 敏感操作需要验证
    case autoLockTimeout = "auto_lock_timeout"           // 自动锁定超时时间
    case securityLevel = "security_level"                // 安全级别
    
    // MARK: - UI/UX Preferences
    case themeMode = "theme_mode"                        // 主题模式（light/dark/auto）
    case accentColor = "accent_color"                    // 强调色
    case enableHapticFeedback = "enable_haptic_feedback" // 启用触觉反馈
    case enableSoundEffects = "enable_sound_effects"     // 启用音效
    case animationEnabled = "animation_enabled"          // 启用动画
    case reducedMotionEnabled = "reduced_motion_enabled" // 减少动画效果
    
    // MARK: - Data Management
    case cloudSyncEnabled = "cloud_sync_enabled"         // 启用云同步
    case autoBackupEnabled = "auto_backup_enabled"       // 启用自动备份
    case backupFrequency = "backup_frequency"            // 备份频率
    case dataRetentionPolicy = "data_retention_policy"   // 数据保留策略
    case lastSyncDate = "last_sync_date"                 // 最后同步时间
    
    // MARK: - Analytics and Insights
    case enableAnalytics = "enable_analytics"            // 启用数据分析
    case insightNotificationEnabled = "insight_notification_enabled" // 洞察通知
    case shareUsageData = "share_usage_data"             // 分享使用数据
    case personalizedRecommendations = "personalized_recommendations" // 个性化推荐
    
    // MARK: - Social Features
    case socialSharingEnabled = "social_sharing_enabled" // 启用社交分享
    case shareWithFriends = "share_with_friends"         // 与朋友分享
    case achievementSharingEnabled = "achievement_sharing_enabled" // 成就分享
    case anonymousMode = "anonymous_mode"                // 匿名模式
    
    // MARK: - Widget Settings
    case widgetEnabled = "widget_enabled"                // 启用小组件
    case widgetSize = "widget_size"                      // 小组件尺寸
    case widgetUpdateFrequency = "widget_update_frequency" // 小组件更新频率
    case widgetShowBudget = "widget_show_budget"         // 小组件显示预算
    
    // MARK: - Accessibility
    case fontSize = "font_size"                          // 字体大小
    case enableVoiceOver = "enable_voice_over"          // 启用VoiceOver
    case highContrastMode = "high_contrast_mode"         // 高对比度模式
    case enableLargeText = "enable_large_text"          // 启用大字体
    
    // MARK: - Advanced Settings
    case developerModeEnabled = "developer_mode_enabled" // 开发者模式
    case debugLoggingEnabled = "debug_logging_enabled"   // 调试日志
    case experimentalFeaturesEnabled = "experimental_features_enabled" // 实验性功能
    case betaTesterMode = "beta_tester_mode"             // Beta测试模式
}

// MARK: - Convenience Extensions

public extension UserPreferenceRepository {
    
    /// 获取布尔值偏好
    func getBool(for key: UserPreferenceKey, defaultValue: Bool = false) async throws -> Bool {
        return try await getValue(for: key, defaultValue: defaultValue)
    }
    
    /// 设置布尔值偏好
    func setBool(_ value: Bool, for key: UserPreferenceKey) async throws {
        try await setValue(value, for: key)
    }
    
    /// 获取字符串偏好
    func getString(for key: UserPreferenceKey, defaultValue: String = "") async throws -> String {
        return try await getValue(for: key, defaultValue: defaultValue)
    }
    
    /// 设置字符串偏好
    func setString(_ value: String, for key: UserPreferenceKey) async throws {
        try await setValue(value, for: key)
    }
    
    /// 获取整数偏好
    func getInt(for key: UserPreferenceKey, defaultValue: Int = 0) async throws -> Int {
        return try await getValue(for: key, defaultValue: defaultValue)
    }
    
    /// 设置整数偏好
    func setInt(_ value: Int, for key: UserPreferenceKey) async throws {
        try await setValue(value, for: key)
    }
    
    /// 获取双精度浮点数偏好
    func getDouble(for key: UserPreferenceKey, defaultValue: Double = 0.0) async throws -> Double {
        return try await getValue(for: key, defaultValue: defaultValue)
    }
    
    /// 设置双精度浮点数偏好
    func setDouble(_ value: Double, for key: UserPreferenceKey) async throws {
        try await setValue(value, for: key)
    }
    
    /// 获取日期偏好
    func getDate(for key: UserPreferenceKey, defaultValue: Date = Date()) async throws -> Date {
        return try await getValue(for: key, defaultValue: defaultValue)
    }
    
    /// 设置日期偏好
    func setDate(_ value: Date, for key: UserPreferenceKey) async throws {
        try await setValue(value, for: key)
    }
}

// MARK: - Predefined Values

/// 预定义的偏好值
public struct UserPreferenceDefaults {
    public static let currency = "CNY"
    public static let budgetPeriod = BudgetEntity.BudgetPeriod.month
    public static let budgetWarningThreshold = 0.8
    public static let autoLockTimeout = 300 // 5分钟
    public static let backupFrequency = 7 // 7天
    public static let widgetUpdateFrequency = 30 // 30分钟
}