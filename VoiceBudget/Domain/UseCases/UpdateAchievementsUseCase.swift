import Foundation

/// 更新成就用例
public class UpdateAchievementsUseCase {
    
    // MARK: - Dependencies
    
    private let transactionRepository: TransactionRepository
    private let preferenceRepository: UserPreferenceRepository
    
    // MARK: - Initialization
    
    public init(
        transactionRepository: TransactionRepository,
        preferenceRepository: UserPreferenceRepository
    ) {
        self.transactionRepository = transactionRepository
        self.preferenceRepository = preferenceRepository
    }
    
    // MARK: - Request & Response
    
    public struct Request {
        public let event: AchievementEvent
        public let context: [String: Any]
        
        public init(event: AchievementEvent, context: [String: Any] = [:]) {
            self.event = event
            self.context = context
        }
    }
    
    public enum AchievementEvent {
        case transactionCreated
        case budgetCreated
        case budgetCompleted
        case streakUpdated
        case categoryUsed
        case voiceRecordingUsed
        case appLaunched
        case achievementShared
    }
    
    public struct Response {
        public let success: Bool
        public let unlockedAchievements: [AchievementEntity]
        public let updatedAchievements: [AchievementEntity]
        public let totalAchievements: [AchievementEntity]
        public let error: UseCaseError?
        
        public init(
            success: Bool,
            unlockedAchievements: [AchievementEntity] = [],
            updatedAchievements: [AchievementEntity] = [],
            totalAchievements: [AchievementEntity] = [],
            error: UseCaseError? = nil
        ) {
            self.success = success
            self.unlockedAchievements = unlockedAchievements
            self.updatedAchievements = updatedAchievements
            self.totalAchievements = totalAchievements
            self.error = error
        }
    }
    
    // MARK: - Execution
    
    public func execute(_ request: Request) async throws -> Response {
        
        do {
            // Get current achievements from preferences
            var currentAchievements = try await getCurrentAchievements()
            
            var unlockedAchievements: [AchievementEntity] = []
            var updatedAchievements: [AchievementEntity] = []
            
            // Process the event and update relevant achievements
            switch request.event {
            case .transactionCreated:
                let results = try await processTransactionCreated(
                    achievements: currentAchievements,
                    context: request.context
                )
                unlockedAchievements.append(contentsOf: results.unlocked)
                updatedAchievements.append(contentsOf: results.updated)
                
            case .budgetCreated:
                let results = processBudgetCreated(
                    achievements: currentAchievements,
                    context: request.context
                )
                unlockedAchievements.append(contentsOf: results.unlocked)
                updatedAchievements.append(contentsOf: results.updated)
                
            case .streakUpdated:
                let results = processStreakUpdated(
                    achievements: currentAchievements,
                    context: request.context
                )
                unlockedAchievements.append(contentsOf: results.unlocked)
                updatedAchievements.append(contentsOf: results.updated)
                
            case .categoryUsed:
                let results = processCategoryUsed(
                    achievements: currentAchievements,
                    context: request.context
                )
                unlockedAchievements.append(contentsOf: results.unlocked)
                updatedAchievements.append(contentsOf: results.updated)
                
            case .voiceRecordingUsed:
                let results = processVoiceRecordingUsed(
                    achievements: currentAchievements,
                    context: request.context
                )
                unlockedAchievements.append(contentsOf: results.unlocked)
                updatedAchievements.append(contentsOf: results.updated)
                
            case .appLaunched:
                let results = processAppLaunched(
                    achievements: currentAchievements,
                    context: request.context
                )
                unlockedAchievements.append(contentsOf: results.unlocked)
                updatedAchievements.append(contentsOf: results.updated)
                
            case .achievementShared:
                let results = processAchievementShared(
                    achievements: currentAchievements,
                    context: request.context
                )
                unlockedAchievements.append(contentsOf: results.unlocked)
                updatedAchievements.append(contentsOf: results.updated)
                
            default:
                break
            }
            
            // Update achievements with new progress and unlock status
            for updated in updatedAchievements {
                if let index = currentAchievements.firstIndex(where: { $0.id == updated.id }) {
                    currentAchievements[index] = updated
                }
            }
            
            // Save updated achievements
            try await saveAchievements(currentAchievements)
            
            // Update related preferences
            try await updateAchievementPreferences(unlockedAchievements: unlockedAchievements)
            
            return Response(
                success: true,
                unlockedAchievements: unlockedAchievements,
                updatedAchievements: updatedAchievements,
                totalAchievements: currentAchievements
            )
            
        } catch {
            return Response(
                success: false,
                error: .unexpected(error.localizedDescription)
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func getCurrentAchievements() async throws -> [AchievementEntity] {
        // Try to load from preferences, fallback to predefined achievements
        if let achievementsData = try? await preferenceRepository.getValue(
            for: .customCategories, // Using as temp storage for achievements
            defaultValue: Data()
        ), !achievementsData.isEmpty {
            return try JSONDecoder().decode([AchievementEntity].self, from: achievementsData)
        }
        
        // Return predefined achievements with initial progress
        return AchievementEntity.predefinedAchievements
    }
    
    private func saveAchievements(_ achievements: [AchievementEntity]) async throws {
        let data = try JSONEncoder().encode(achievements)
        // Using custom categories key as temp storage - in production, you'd have a dedicated key
        try await preferenceRepository.setValue(data, for: .customCategories)
    }
    
    private func processTransactionCreated(
        achievements: [AchievementEntity],
        context: [String: Any]
    ) async throws -> (unlocked: [AchievementEntity], updated: [AchievementEntity]) {
        
        var unlocked: [AchievementEntity] = []
        var updated: [AchievementEntity] = []
        
        // Get total transaction count
        let totalCount = try await transactionRepository.getTotalTransactionCount()
        
        // Update milestone achievements
        let milestoneAchievements = ["first_record", "transaction_100"]
        for achievementID in milestoneAchievements {
            if let achievement = achievements.first(where: { $0.id == achievementID }) {
                let newProgress = totalCount
                let updatedAchievement = achievement.updatingProgress(newProgress)
                
                updated.append(updatedAchievement)
                
                if updatedAchievement.canUnlock {
                    unlocked.append(updatedAchievement.unlocked())
                }
            }
        }
        
        return (unlocked, updated)
    }
    
    private func processBudgetCreated(
        achievements: [AchievementEntity],
        context: [String: Any]
    ) -> (unlocked: [AchievementEntity], updated: [AchievementEntity]) {
        
        var unlocked: [AchievementEntity] = []
        var updated: [AchievementEntity] = []
        
        // Update first budget achievement
        if let achievement = achievements.first(where: { $0.id == "first_budget" }) {
            let updatedAchievement = achievement.incrementingProgress()
            updated.append(updatedAchievement)
            
            if updatedAchievement.canUnlock {
                unlocked.append(updatedAchievement.unlocked())
            }
        }
        
        return (unlocked, updated)
    }
    
    private func processStreakUpdated(
        achievements: [AchievementEntity],
        context: [String: Any]
    ) -> (unlocked: [AchievementEntity], updated: [AchievementEntity]) {
        
        var unlocked: [AchievementEntity] = []
        var updated: [AchievementEntity] = []
        
        guard let streakDays = context["streakDays"] as? Int else {
            return (unlocked, updated)
        }
        
        // Update streak achievements
        let streakAchievements = ["streak_3_days", "streak_7_days", "streak_15_days", "streak_30_days"]
        for achievementID in streakAchievements {
            if let achievement = achievements.first(where: { $0.id == achievementID }) {
                let updatedAchievement = achievement.updatingProgress(streakDays)
                updated.append(updatedAchievement)
                
                if updatedAchievement.canUnlock {
                    unlocked.append(updatedAchievement.unlocked())
                }
            }
        }
        
        return (unlocked, updated)
    }
    
    private func processCategoryUsed(
        achievements: [AchievementEntity],
        context: [String: Any]
    ) -> (unlocked: [AchievementEntity], updated: [AchievementEntity]) {
        
        var unlocked: [AchievementEntity] = []
        var updated: [AchievementEntity] = []
        
        guard let categoriesUsed = context["categoriesUsed"] as? [String] else {
            return (unlocked, updated)
        }
        
        // Update category explorer achievement
        if let achievement = achievements.first(where: { $0.id == "category_explorer" }) {
            let uniqueCategories = Set(categoriesUsed).count
            let updatedAchievement = achievement.updatingProgress(uniqueCategories)
            updated.append(updatedAchievement)
            
            if updatedAchievement.canUnlock {
                unlocked.append(updatedAchievement.unlocked())
            }
        }
        
        return (unlocked, updated)
    }
    
    private func processVoiceRecordingUsed(
        achievements: [AchievementEntity],
        context: [String: Any]
    ) -> (unlocked: [AchievementEntity], updated: [AchievementEntity]) {
        
        var unlocked: [AchievementEntity] = []
        var updated: [AchievementEntity] = []
        
        // Check time-based achievements
        guard let recordingTime = context["recordingTime"] as? Date else {
            return (unlocked, updated)
        }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: recordingTime)
        
        // Night owl achievement (after midnight)
        if hour >= 0 && hour < 6 {
            if let achievement = achievements.first(where: { $0.id == "night_owl" }) {
                let updatedAchievement = achievement.incrementingProgress()
                updated.append(updatedAchievement)
                
                if updatedAchievement.canUnlock {
                    unlocked.append(updatedAchievement.unlocked())
                }
            }
        }
        
        // Early bird achievement (before 8 AM)
        if hour >= 5 && hour < 8 {
            if let achievement = achievements.first(where: { $0.id == "early_bird" }) {
                let updatedAchievement = achievement.incrementingProgress()
                updated.append(updatedAchievement)
                
                if updatedAchievement.canUnlock {
                    unlocked.append(updatedAchievement.unlocked())
                }
            }
        }
        
        return (unlocked, updated)
    }
    
    private func processAppLaunched(
        achievements: [AchievementEntity],
        context: [String: Any]
    ) -> (unlocked: [AchievementEntity], updated: [AchievementEntity]) {
        
        // App launch can contribute to streak tracking
        // This is handled elsewhere, so return empty for now
        return ([], [])
    }
    
    private func processAchievementShared(
        achievements: [AchievementEntity],
        context: [String: Any]
    ) -> (unlocked: [AchievementEntity], updated: [AchievementEntity]) {
        
        var unlocked: [AchievementEntity] = []
        var updated: [AchievementEntity] = []
        
        // Update first share achievement
        if let achievement = achievements.first(where: { $0.id == "first_share" }) {
            let updatedAchievement = achievement.incrementingProgress()
            updated.append(updatedAchievement)
            
            if updatedAchievement.canUnlock {
                unlocked.append(updatedAchievement.unlocked())
            }
        }
        
        return (unlocked, updated)
    }
    
    private func updateAchievementPreferences(unlockedAchievements: [AchievementEntity]) async throws {
        if !unlockedAchievements.isEmpty {
            // Update notification settings if achievements were unlocked
            let notificationsEnabled = try await preferenceRepository.getBool(
                for: .achievementNotificationEnabled,
                defaultValue: true
            )
            
            if notificationsEnabled {
                // In a real app, you would trigger local notifications here
                print("Achievement unlocked notifications would be sent for: \(unlockedAchievements.map(\.title).joined(separator: ", "))")
            }
        }
    }
}