import Foundation
import Combine

/// UserDefaults实现的用户偏好仓储
public class UserDefaultsPreferenceRepository: UserPreferenceRepository {
    
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let subject = PassthroughSubject<(UserPreferenceKey, Any?), Never>()
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - Basic Operations
    
    public func getValue<T: Codable>(for key: UserPreferenceKey, defaultValue: T) async throws -> T {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                if let data = self.userDefaults.data(forKey: key.rawValue) {
                    do {
                        let value = try self.decoder.decode(T.self, from: data)
                        continuation.resume(returning: value)
                    } catch {
                        continuation.resume(returning: defaultValue)
                    }
                } else {
                    continuation.resume(returning: defaultValue)
                }
            }
        }
    }
    
    public func setValue<T: Codable>(_ value: T, for key: UserPreferenceKey) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                do {
                    let data = try self.encoder.encode(value)
                    self.userDefaults.set(data, forKey: key.rawValue)
                    
                    // Notify observers
                    self.subject.send((key, value))
                    
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: RepositoryError.encodingError)
                }
            }
        }
    }
    
    public func removeValue(for key: UserPreferenceKey) async throws {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                self.userDefaults.removeObject(forKey: key.rawValue)
                
                // Notify observers
                self.subject.send((key, nil))
                
                continuation.resume(returning: ())
            }
        }
    }
    
    public func hasValue(for key: UserPreferenceKey) async throws -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let exists = self.userDefaults.object(forKey: key.rawValue) != nil
                continuation.resume(returning: exists)
            }
        }
    }
    
    // MARK: - Batch Operations
    
    public func getValues(for keys: [UserPreferenceKey]) async throws -> [UserPreferenceKey: Any] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                var result: [UserPreferenceKey: Any] = [:]
                
                for key in keys {
                    if let data = self.userDefaults.data(forKey: key.rawValue) {
                        // Try to decode as common types
                        if let stringValue = try? self.decoder.decode(String.self, from: data) {
                            result[key] = stringValue
                        } else if let boolValue = try? self.decoder.decode(Bool.self, from: data) {
                            result[key] = boolValue
                        } else if let intValue = try? self.decoder.decode(Int.self, from: data) {
                            result[key] = intValue
                        } else if let doubleValue = try? self.decoder.decode(Double.self, from: data) {
                            result[key] = doubleValue
                        } else if let dateValue = try? self.decoder.decode(Date.self, from: data) {
                            result[key] = dateValue
                        } else {
                            // Store raw data if we can't decode to common types
                            result[key] = data
                        }
                    }
                }
                
                continuation.resume(returning: result)
            }
        }
    }
    
    public func setValues(_ preferences: [UserPreferenceKey: Any]) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                do {
                    for (key, value) in preferences {
                        let data = try self.encoder.encode(AnyEncodable(value))
                        self.userDefaults.set(data, forKey: key.rawValue)
                        
                        // Notify observers
                        self.subject.send((key, value))
                    }
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: RepositoryError.encodingError)
                }
            }
        }
    }
    
    public func getAllPreferences() async throws -> [UserPreferenceKey: Any] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                var result: [UserPreferenceKey: Any] = [:]
                
                for key in UserPreferenceKey.allCases {
                    if let data = self.userDefaults.data(forKey: key.rawValue) {
                        // Try to decode as common types
                        if let stringValue = try? self.decoder.decode(String.self, from: data) {
                            result[key] = stringValue
                        } else if let boolValue = try? self.decoder.decode(Bool.self, from: data) {
                            result[key] = boolValue
                        } else if let intValue = try? self.decoder.decode(Int.self, from: data) {
                            result[key] = intValue
                        } else if let doubleValue = try? self.decoder.decode(Double.self, from: data) {
                            result[key] = doubleValue
                        } else if let dateValue = try? self.decoder.decode(Date.self, from: data) {
                            result[key] = dateValue
                        } else {
                            result[key] = data
                        }
                    }
                }
                
                continuation.resume(returning: result)
            }
        }
    }
    
    public func clearAllPreferences() async throws {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                for key in UserPreferenceKey.allCases {
                    self.userDefaults.removeObject(forKey: key.rawValue)
                    
                    // Notify observers
                    self.subject.send((key, nil))
                }
                
                continuation.resume(returning: ())
            }
        }
    }
    
    // MARK: - Observation
    
    public func observeValue<T: Codable>(for key: UserPreferenceKey, type: T.Type) -> AsyncStream<T?> {
        return AsyncStream { continuation in
            let cancellable = subject
                .filter { $0.0 == key }
                .sink { (_, value) in
                    if let value = value as? T {
                        continuation.yield(value)
                    } else {
                        continuation.yield(nil)
                    }
                }
            
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
    
    public func observeValues(for keys: [UserPreferenceKey]) -> AsyncStream<[UserPreferenceKey: Any]> {
        return AsyncStream { continuation in
            let cancellable = subject
                .filter { keys.contains($0.0) }
                .sink { _ in
                    Task {
                        do {
                            let values = try await self.getValues(for: keys)
                            continuation.yield(values)
                        } catch {
                            // Handle error silently or log it
                        }
                    }
                }
            
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
}

// MARK: - Convenience Extensions Implementation

public extension UserDefaultsPreferenceRepository {
    
    func getBool(for key: UserPreferenceKey, defaultValue: Bool = false) async throws -> Bool {
        return try await getValue(for: key, defaultValue: defaultValue)
    }
    
    func setBool(_ value: Bool, for key: UserPreferenceKey) async throws {
        try await setValue(value, for: key)
    }
    
    func getString(for key: UserPreferenceKey, defaultValue: String = "") async throws -> String {
        return try await getValue(for: key, defaultValue: defaultValue)
    }
    
    func setString(_ value: String, for key: UserPreferenceKey) async throws {
        try await setValue(value, for: key)
    }
    
    func getInt(for key: UserPreferenceKey, defaultValue: Int = 0) async throws -> Int {
        return try await getValue(for: key, defaultValue: defaultValue)
    }
    
    func setInt(_ value: Int, for key: UserPreferenceKey) async throws {
        try await setValue(value, for: key)
    }
    
    func getDouble(for key: UserPreferenceKey, defaultValue: Double = 0.0) async throws -> Double {
        return try await getValue(for: key, defaultValue: defaultValue)
    }
    
    func setDouble(_ value: Double, for key: UserPreferenceKey) async throws {
        try await setValue(value, for: key)
    }
    
    func getDate(for key: UserPreferenceKey, defaultValue: Date = Date()) async throws -> Date {
        return try await getValue(for: key, defaultValue: defaultValue)
    }
    
    func setDate(_ value: Date, for key: UserPreferenceKey) async throws {
        try await setValue(value, for: key)
    }
}

// MARK: - Helper Types

/// A type-erased wrapper for encoding any value
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    
    init<T: Encodable>(_ value: T) {
        _encode = { encoder in
            try value.encode(to: encoder)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

// MARK: - UserDefaults Extensions

private extension UserDefaults {
    
    /// Safe method to get data that won't crash on type mismatch
    func safeData(forKey key: String) -> Data? {
        return object(forKey: key) as? Data
    }
}

// MARK: - Migration Support

public extension UserDefaultsPreferenceRepository {
    
    /// Migrate old UserDefaults values to the new structured format
    func migrateOldPreferences() async throws {
        // Example migration logic for common preference types
        let legacyMappings: [String: UserPreferenceKey] = [
            "enable_voice_recording": .enableVoiceRecording,
            "default_currency": .defaultCurrency,
            "theme_mode": .themeMode,
            "notifications_enabled": .notificationsEnabled
        ]
        
        for (oldKey, newKey) in legacyMappings {
            if let oldValue = userDefaults.object(forKey: oldKey) {
                // Migrate based on expected type
                do {
                    if let boolValue = oldValue as? Bool {
                        try await setBool(boolValue, for: newKey)
                    } else if let stringValue = oldValue as? String {
                        try await setString(stringValue, for: newKey)
                    } else if let intValue = oldValue as? Int {
                        try await setInt(intValue, for: newKey)
                    } else if let doubleValue = oldValue as? Double {
                        try await setDouble(doubleValue, for: newKey)
                    }
                    
                    // Remove old key after successful migration
                    userDefaults.removeObject(forKey: oldKey)
                } catch {
                    // Log migration error but don't fail completely
                    print("Failed to migrate preference \(oldKey): \(error)")
                }
            }
        }
    }
    
    /// Reset specific preference groups
    func resetPreferenceGroup(_ group: PreferenceGroup) async throws {
        let keysToReset: [UserPreferenceKey]
        
        switch group {
        case .appSettings:
            keysToReset = [.firstLaunch, .onboardingCompleted, .appVersion, .lastLaunchDate]
        case .notifications:
            keysToReset = [.notificationsEnabled, .dailyReminderEnabled, .dailyReminderTime, .budgetAlertEnabled, .achievementNotificationEnabled]
        case .security:
            keysToReset = [.biometricAuthEnabled, .authRequiredOnLaunch, .authRequiredOnSensitiveOperation, .autoLockTimeout, .securityLevel]
        case .ui:
            keysToReset = [.themeMode, .accentColor, .enableHapticFeedback, .enableSoundEffects, .animationEnabled, .reducedMotionEnabled]
        case .all:
            keysToReset = UserPreferenceKey.allCases
        }
        
        for key in keysToReset {
            try await removeValue(for: key)
        }
    }
}

public enum PreferenceGroup {
    case appSettings
    case notifications
    case security
    case ui
    case all
}