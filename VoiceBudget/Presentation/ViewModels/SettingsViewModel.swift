import Foundation
import LocalAuthentication

@MainActor
class SettingsViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let updateUserPreferencesUseCase: UpdateUserPreferencesUseCase
    private let preferenceRepository: UserPreferenceRepository
    
    // MARK: - Published Properties
    @Published var voiceRecordingEnabled = true
    @Published var voiceLanguage = "中文（简体）"
    @Published var autoSaveEnabled = true
    @Published var budgetRemindersEnabled = true
    @Published var warningThreshold = 0.8
    @Published var notificationsEnabled = true
    @Published var dailyReminderEnabled = false
    @Published var reminderTime = "20:00"
    @Published var themeMode = ThemeMode.auto
    @Published var fontSize = FontSize.medium
    @Published var hapticFeedbackEnabled = true
    @Published var cloudSyncEnabled = false
    @Published var biometricAuthEnabled = false
    @Published var authOnLaunchEnabled = false
    @Published var biometricsAvailable = false
    @Published var appVersion = "1.0.0"
    @Published var showClearDataAlert = false
    
    // MARK: - Initialization
    init() {
        let preferenceRepository = UserDefaultsPreferenceRepository()
        self.preferenceRepository = preferenceRepository
        self.updateUserPreferencesUseCase = UpdateUserPreferencesUseCase(
            preferenceRepository: preferenceRepository
        )
        
        checkBiometricsAvailability()
    }
    
    // MARK: - Public Methods
    
    func loadSettings() {
        Task {
            await loadUserPreferences()
        }
    }
    
    func updateVoiceRecording(_ enabled: Bool) {
        voiceRecordingEnabled = enabled
        updatePreference(.enableVoiceRecording, value: enabled)
    }
    
    func updateAutoSave(_ enabled: Bool) {
        autoSaveEnabled = enabled
        updatePreference(.autoSaveTransactions, value: enabled)
    }
    
    func updateBudgetReminders(_ enabled: Bool) {
        budgetRemindersEnabled = enabled
        updatePreference(.budgetReminderEnabled, value: enabled)
    }
    
    func updateNotifications(_ enabled: Bool) {
        notificationsEnabled = enabled
        updatePreference(.notificationsEnabled, value: enabled)
        
        if !enabled {
            dailyReminderEnabled = false
            updatePreference(.dailyReminderEnabled, value: false)
        }
    }
    
    func updateDailyReminder(_ enabled: Bool) {
        dailyReminderEnabled = enabled
        updatePreference(.dailyReminderEnabled, value: enabled)
    }
    
    func updateHapticFeedback(_ enabled: Bool) {
        hapticFeedbackEnabled = enabled
        updatePreference(.enableHapticFeedback, value: enabled)
    }
    
    func updateCloudSync(_ enabled: Bool) {
        cloudSyncEnabled = enabled
        updatePreference(.cloudSyncEnabled, value: enabled)
    }
    
    func updateBiometricAuth(_ enabled: Bool) {
        biometricAuthEnabled = enabled
        updatePreference(.biometricAuthEnabled, value: enabled)
    }
    
    func updateAuthOnLaunch(_ enabled: Bool) {
        authOnLaunchEnabled = enabled
        updatePreference(.authRequiredOnLaunch, value: enabled)
    }
    
    func clearAllData() {
        Task {
            do {
                // 清除所有偏好设置
                try await preferenceRepository.clearAllPreferences()
                
                // 重新加载默认设置
                await loadUserPreferences()
                
                print("所有数据已清除")
            } catch {
                print("清除数据失败: \(error)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadUserPreferences() async {
        do {
            voiceRecordingEnabled = try await preferenceRepository.getBool(for: .enableVoiceRecording, defaultValue: true)
            autoSaveEnabled = try await preferenceRepository.getBool(for: .autoSaveTransactions, defaultValue: true)
            budgetRemindersEnabled = try await preferenceRepository.getBool(for: .budgetReminderEnabled, defaultValue: true)
            warningThreshold = try await preferenceRepository.getDouble(for: .budgetWarningThreshold, defaultValue: 0.8)
            notificationsEnabled = try await preferenceRepository.getBool(for: .notificationsEnabled, defaultValue: true)
            dailyReminderEnabled = try await preferenceRepository.getBool(for: .dailyReminderEnabled, defaultValue: false)
            reminderTime = try await preferenceRepository.getString(for: .dailyReminderTime, defaultValue: "20:00")
            hapticFeedbackEnabled = try await preferenceRepository.getBool(for: .enableHapticFeedback, defaultValue: true)
            cloudSyncEnabled = try await preferenceRepository.getBool(for: .cloudSyncEnabled, defaultValue: false)
            biometricAuthEnabled = try await preferenceRepository.getBool(for: .biometricAuthEnabled, defaultValue: false)
            authOnLaunchEnabled = try await preferenceRepository.getBool(for: .authRequiredOnLaunch, defaultValue: false)
            
            let themeString = try await preferenceRepository.getString(for: .themeMode, defaultValue: "auto")
            themeMode = ThemeMode(rawValue: themeString) ?? .auto
            
            let languageCode = try await preferenceRepository.getString(for: .voiceRecognitionLanguage, defaultValue: "zh-CN")
            voiceLanguage = getLanguageDisplayName(languageCode)
            
            if let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                appVersion = versionString
            }
        } catch {
            print("加载设置失败: \(error)")
        }
    }
    
    private func updatePreference<T: Codable>(_ key: UserPreferenceKey, value: T) {
        Task {
            let preferences = [key: value as Any]
            let request = UpdateUserPreferencesUseCase.Request(preferences: preferences)
            _ = try? await updateUserPreferencesUseCase.execute(request)
        }
    }
    
    private func checkBiometricsAvailability() {
        let context = LAContext()
        var error: NSError?
        
        biometricsAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    private func getLanguageDisplayName(_ code: String) -> String {
        switch code {
        case "zh-CN": return "中文（简体）"
        case "zh-HK": return "中文（香港）"
        case "zh-TW": return "中文（台灣）"
        case "en-US": return "English"
        default: return "中文（简体）"
        }
    }
}

// MARK: - Supporting Types

enum ThemeMode: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"
    
    var displayName: String {
        switch self {
        case .light: return "浅色"
        case .dark: return "深色"
        case .auto: return "自动"
        }
    }
}

enum FontSize: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var displayName: String {
        switch self {
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        }
    }
}

@MainActor
class LanguageSelectionViewModel: ObservableObject {
    @Published var selectedLanguage = "zh-CN"
    
    let availableLanguages = [
        Language(code: "zh-CN", name: "中文（简体）"),
        Language(code: "zh-HK", name: "中文（香港）"),
        Language(code: "zh-TW", name: "中文（台灣）"),
        Language(code: "en-US", name: "English")
    ]
    
    private let preferenceRepository = UserDefaultsPreferenceRepository()
    
    init() {
        loadSelectedLanguage()
    }
    
    func selectLanguage(_ code: String) {
        selectedLanguage = code
        Task {
            try? await preferenceRepository.setString(code, for: .voiceRecognitionLanguage)
        }
    }
    
    private func loadSelectedLanguage() {
        Task {
            selectedLanguage = try await preferenceRepository.getString(for: .voiceRecognitionLanguage, defaultValue: "zh-CN")
        }
    }
}

struct Language {
    let code: String
    let name: String
}

@MainActor
class DataExportViewModel: ObservableObject {
    @Published var selectedFormat: ExportFormat = .csv
    @Published var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var endDate = Date()
    @Published var isExporting = false
    
    private let transactionRepository: TransactionRepository
    
    init() {
        let coreDataStack = CoreDataStack.shared
        self.transactionRepository = CoreDataTransactionRepository(context: coreDataStack.viewContext)
    }
    
    func exportData() {
        guard !isExporting else { return }
        
        isExporting = true
        
        Task {
            do {
                let data = try await transactionRepository.exportTransactions(
                    startDate: startDate,
                    endDate: endDate,
                    format: selectedFormat
                )
                
                await MainActor.run {
                    isExporting = false
                    // 在实际应用中，这里会触发系统分享对话框
                    print("导出数据成功，大小: \(data.count) 字节")
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    print("导出失败: \(error)")
                }
            }
        }
    }
}