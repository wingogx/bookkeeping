import Foundation

/// 更新用户偏好设置用例
public class UpdateUserPreferencesUseCase {
    
    // MARK: - Dependencies
    
    private let preferenceRepository: UserPreferenceRepository
    
    // MARK: - Initialization
    
    public init(preferenceRepository: UserPreferenceRepository) {
        self.preferenceRepository = preferenceRepository
    }
    
    // MARK: - Request & Response
    
    public struct Request {
        public let preferences: [UserPreferenceKey: Any]
        public let validateSettings: Bool
        
        public init(preferences: [UserPreferenceKey: Any], validateSettings: Bool = true) {
            self.preferences = preferences
            self.validateSettings = validateSettings
        }
    }
    
    public struct Response {
        public let success: Bool
        public let updatedPreferences: [UserPreferenceKey: Any]
        public let validationResults: [ValidationResult]
        public let requiresAppRestart: Bool
        public let error: UseCaseError?
        
        public init(
            success: Bool,
            updatedPreferences: [UserPreferenceKey: Any] = [:],
            validationResults: [ValidationResult] = [],
            requiresAppRestart: Bool = false,
            error: UseCaseError? = nil
        ) {
            self.success = success
            self.updatedPreferences = updatedPreferences
            self.validationResults = validationResults
            self.requiresAppRestart = requiresAppRestart
            self.error = error
        }
    }
    
    public struct ValidationResult {
        public let key: UserPreferenceKey
        public let isValid: Bool
        public let message: String?
        public let correctedValue: Any?
        
        public init(key: UserPreferenceKey, isValid: Bool, message: String? = nil, correctedValue: Any? = nil) {
            self.key = key
            self.isValid = isValid
            self.message = message
            self.correctedValue = correctedValue
        }
    }
    
    // MARK: - Execution
    
    public func execute(_ request: Request) async throws -> Response {
        
        do {
            var validationResults: [ValidationResult] = []
            var updatedPreferences: [UserPreferenceKey: Any] = [:]
            var requiresAppRestart = false
            
            // Validate each preference if requested
            if request.validateSettings {
                for (key, value) in request.preferences {
                    let validationResult = validatePreference(key: key, value: value)
                    validationResults.append(validationResult)
                    
                    if !validationResult.isValid {
                        // Skip invalid preferences
                        continue
                    }
                    
                    // Use corrected value if available
                    let finalValue = validationResult.correctedValue ?? value
                    updatedPreferences[key] = finalValue
                    
                    // Check if this preference requires app restart
                    if requiresRestartForPreference(key) {
                        requiresAppRestart = true
                    }
                }
            } else {
                updatedPreferences = request.preferences
            }
            
            // Update preferences in repository
            try await preferenceRepository.setValues(updatedPreferences)
            
            // Handle special preference updates
            try await handleSpecialPreferences(updatedPreferences)
            
            // Validate any validation errors
            let hasErrors = validationResults.contains { !$0.isValid }
            
            return Response(
                success: !hasErrors,
                updatedPreferences: updatedPreferences,
                validationResults: validationResults,
                requiresAppRestart: requiresAppRestart,
                error: hasErrors ? .invalidInput("部分设置验证失败") : nil
            )
            
        } catch {
            let useCaseError: UseCaseError
            
            if let repoError = error as? RepositoryError {
                useCaseError = .repositoryError(repoError.localizedDescription)
            } else {
                useCaseError = .unexpected(error.localizedDescription)
            }
            
            return Response(success: false, error: useCaseError)
        }
    }
    
    // MARK: - Private Methods
    
    private func validatePreference(key: UserPreferenceKey, value: Any) -> ValidationResult {
        
        switch key {
        // App Settings Validation
        case .appVersion:
            if let version = value as? String, !version.isEmpty {
                return ValidationResult(key: key, isValid: true)
            }
            return ValidationResult(key: key, isValid: false, message: "应用版本格式无效")
            
        // Currency Validation
        case .defaultCurrency:
            if let currency = value as? String {
                let validCurrencies = ["CNY", "USD", "EUR", "JPY", "GBP", "HKD"]
                if validCurrencies.contains(currency) {
                    return ValidationResult(key: key, isValid: true)
                } else {
                    return ValidationResult(key: key, isValid: true, message: "使用默认货币", correctedValue: "CNY")
                }
            }
            return ValidationResult(key: key, isValid: false, message: "货币代码格式无效")
            
        // Language Validation
        case .voiceRecognitionLanguage:
            if let language = value as? String {
                let supportedLanguages = ["zh-CN", "zh-HK", "zh-TW", "en-US"]
                if supportedLanguages.contains(language) {
                    return ValidationResult(key: key, isValid: true)
                } else {
                    return ValidationResult(key: key, isValid: true, message: "使用默认语言", correctedValue: "zh-CN")
                }
            }
            return ValidationResult(key: key, isValid: false, message: "语言代码格式无效")
            
        // Numeric Range Validations
        case .consecutiveRecordDays:
            if let days = value as? Int {
                if days >= 0 && days <= 365 {
                    return ValidationResult(key: key, isValid: true)
                } else {
                    let corrected = max(0, min(days, 365))
                    return ValidationResult(key: key, isValid: true, message: "天数已调整到有效范围", correctedValue: corrected)
                }
            }
            return ValidationResult(key: key, isValid: false, message: "连续记账天数必须是数字")
            
        case .budgetWarningThreshold:
            if let threshold = value as? Double {
                if threshold >= 0.0 && threshold <= 1.0 {
                    return ValidationResult(key: key, isValid: true)
                } else {
                    let corrected = max(0.0, min(threshold, 1.0))
                    return ValidationResult(key: key, isValid: true, message: "阈值已调整到有效范围", correctedValue: corrected)
                }
            }
            return ValidationResult(key: key, isValid: false, message: "预算警告阈值必须是0到1之间的数值")
            
        case .autoLockTimeout:
            if let timeout = value as? Int {
                let validTimeouts = [0, 60, 300, 600, 1800, 3600] // 0=never, 1min, 5min, 10min, 30min, 1hour
                if validTimeouts.contains(timeout) {
                    return ValidationResult(key: key, isValid: true)
                } else {
                    return ValidationResult(key: key, isValid: true, message: "使用默认锁定时间", correctedValue: 300)
                }
            }
            return ValidationResult(key: key, isValid: false, message: "自动锁定时间格式无效")
            
        case .backupFrequency:
            if let frequency = value as? Int {
                if frequency > 0 && frequency <= 30 {
                    return ValidationResult(key: key, isValid: true)
                } else {
                    let corrected = max(1, min(frequency, 30))
                    return ValidationResult(key: key, isValid: true, message: "备份频率已调整到有效范围", correctedValue: corrected)
                }
            }
            return ValidationResult(key: key, isValid: false, message: "备份频率必须是1-30天")
            
        // Theme Validation
        case .themeMode:
            if let theme = value as? String {
                let validThemes = ["light", "dark", "auto"]
                if validThemes.contains(theme) {
                    return ValidationResult(key: key, isValid: true)
                } else {
                    return ValidationResult(key: key, isValid: true, message: "使用自动主题", correctedValue: "auto")
                }
            }
            return ValidationResult(key: key, isValid: false, message: "主题设置无效")
            
        case .accentColor:
            if let color = value as? String, isValidColorHex(color) {
                return ValidationResult(key: key, isValid: true)
            }
            return ValidationResult(key: key, isValid: true, message: "使用默认强调色", correctedValue: "#007AFF")
            
        // Font Size Validation
        case .fontSize:
            if let size = value as? Double {
                if size >= 12.0 && size <= 24.0 {
                    return ValidationResult(key: key, isValid: true)
                } else {
                    let corrected = max(12.0, min(size, 24.0))
                    return ValidationResult(key: key, isValid: true, message: "字体大小已调整到有效范围", correctedValue: corrected)
                }
            }
            return ValidationResult(key: key, isValid: false, message: "字体大小必须是数值")
            
        // Time Validation for Daily Reminder
        case .dailyReminderTime:
            if let timeString = value as? String, isValidTimeFormat(timeString) {
                return ValidationResult(key: key, isValid: true)
            }
            return ValidationResult(key: key, isValid: true, message: "使用默认提醒时间", correctedValue: "20:00")
            
        // Security Level Validation
        case .securityLevel:
            if let level = value as? String {
                let validLevels = ["low", "medium", "high"]
                if validLevels.contains(level) {
                    return ValidationResult(key: key, isValid: true)
                } else {
                    return ValidationResult(key: key, isValid: true, message: "使用中等安全级别", correctedValue: "medium")
                }
            }
            return ValidationResult(key: key, isValid: false, message: "安全级别设置无效")
            
        // Boolean preferences - always valid if Bool
        case .firstLaunch, .onboardingCompleted, .enableVoiceRecording, .autoSaveTransactions,
             .budgetReminderEnabled, .notificationsEnabled, .dailyReminderEnabled, .budgetAlertEnabled,
             .achievementNotificationEnabled, .biometricAuthEnabled, .authRequiredOnLaunch,
             .authRequiredOnSensitiveOperation, .enableHapticFeedback, .enableSoundEffects,
             .animationEnabled, .reducedMotionEnabled, .cloudSyncEnabled, .autoBackupEnabled,
             .enableAnalytics, .insightNotificationEnabled, .shareUsageData, .personalizedRecommendations,
             .socialSharingEnabled, .shareWithFriends, .achievementSharingEnabled, .anonymousMode,
             .widgetEnabled, .widgetShowBudget, .enableVoiceOver, .highContrastMode, .enableLargeText,
             .developerModeEnabled, .debugLoggingEnabled, .experimentalFeaturesEnabled, .betaTesterMode:
            
            if value is Bool {
                return ValidationResult(key: key, isValid: true)
            }
            return ValidationResult(key: key, isValid: false, message: "设置值必须是布尔类型")
            
        // Date preferences
        case .lastLaunchDate, .categoryUnlockDate, .lastSyncDate:
            if value is Date {
                return ValidationResult(key: key, isValid: true)
            }
            return ValidationResult(key: key, isValid: false, message: "日期格式无效")
            
        // Default case for other preferences
        default:
            return ValidationResult(key: key, isValid: true)
        }
    }
    
    private func isValidColorHex(_ color: String) -> Bool {
        let hexPattern = "^#[A-Fa-f0-9]{6}$"
        return color.range(of: hexPattern, options: .regularExpression) != nil
    }
    
    private func isValidTimeFormat(_ time: String) -> Bool {
        let timePattern = "^([01]?[0-9]|2[0-3]):[0-5][0-9]$"
        return time.range(of: timePattern, options: .regularExpression) != nil
    }
    
    private func requiresRestartForPreference(_ key: UserPreferenceKey) -> Bool {
        // Preferences that require app restart
        let restartRequired: [UserPreferenceKey] = [
            .voiceRecognitionLanguage,
            .themeMode,
            .debugLoggingEnabled,
            .developerModeEnabled,
            .experimentalFeaturesEnabled
        ]
        
        return restartRequired.contains(key)
    }
    
    private func handleSpecialPreferences(_ preferences: [UserPreferenceKey: Any]) async throws {
        
        // Handle onboarding completion
        if let completed = preferences[.onboardingCompleted] as? Bool, completed {
            // Set first launch to false if onboarding is completed
            try await preferenceRepository.setBool(false, for: .firstLaunch)
        }
        
        // Handle biometric auth changes
        if let biometricEnabled = preferences[.biometricAuthEnabled] as? Bool {
            if biometricEnabled {
                // Ensure auth is required on launch if biometric is enabled
                try await preferenceRepository.setBool(true, for: .authRequiredOnLaunch)
            }
        }
        
        // Handle cloud sync enablement
        if let cloudSyncEnabled = preferences[.cloudSyncEnabled] as? Bool, cloudSyncEnabled {
            // Enable auto backup when cloud sync is enabled
            try await preferenceRepository.setBool(true, for: .autoBackupEnabled)
        }
        
        // Handle notification changes
        if let notificationsEnabled = preferences[.notificationsEnabled] as? Bool, !notificationsEnabled {
            // Disable all notification types when notifications are disabled
            try await preferenceRepository.setBool(false, for: .dailyReminderEnabled)
            try await preferenceRepository.setBool(false, for: .budgetAlertEnabled)
            try await preferenceRepository.setBool(false, for: .achievementNotificationEnabled)
            try await preferenceRepository.setBool(false, for: .insightNotificationEnabled)
        }
        
        // Handle developer mode
        if let devModeEnabled = preferences[.developerModeEnabled] as? Bool, devModeEnabled {
            // Enable debug logging when developer mode is enabled
            try await preferenceRepository.setBool(true, for: .debugLoggingEnabled)
        }
        
        // Update last update time
        try await preferenceRepository.setDate(Date(), for: .lastSyncDate)
    }
}