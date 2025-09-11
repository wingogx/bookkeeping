import Foundation
import Combine
import AVFoundation
import Speech
import UserNotifications

/// 权限管理器
/// 负责管理应用所需的各种系统权限
public class PermissionManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var microphonePermission: PermissionStatus = .notDetermined
    @Published public var speechRecognitionPermission: PermissionStatus = .notDetermined
    @Published public var notificationPermission: PermissionStatus = .notDetermined
    
    // MARK: - Permission Status
    public enum PermissionStatus {
        case notDetermined
        case granted
        case denied
        case restricted
        
        public var displayText: String {
            switch self {
            case .notDetermined: return "未确定"
            case .granted: return "已授权"
            case .denied: return "已拒绝"
            case .restricted: return "受限制"
            }
        }
        
        public var isGranted: Bool {
            return self == .granted
        }
    }
    
    // MARK: - Initialization
    public init() {
        checkAllPermissions()
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    /// 检查所有权限状态
    public func checkAllPermissions() {
        checkMicrophonePermission()
        checkSpeechRecognitionPermission()
        checkNotificationPermission()
    }
    
    /// 请求所有必需权限
    public func requestAllRequiredPermissions() -> AnyPublisher<Bool, Never> {
        return Publishers.CombineLatest(
            requestMicrophonePermission(),
            requestSpeechRecognitionPermission()
        )
        .map { microphoneGranted, speechGranted in
            return microphoneGranted && speechGranted
        }
        .eraseToAnyPublisher()
    }
    
    /// 请求麦克风权限
    public func requestMicrophonePermission() -> AnyPublisher<Bool, Never> {
        return Future { promise in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.microphonePermission = granted ? .granted : .denied
                    promise(.success(granted))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 请求语音识别权限
    public func requestSpeechRecognitionPermission() -> AnyPublisher<Bool, Never> {
        return Future { promise in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        self.speechRecognitionPermission = .granted
                        promise(.success(true))
                    case .denied:
                        self.speechRecognitionPermission = .denied
                        promise(.success(false))
                    case .restricted:
                        self.speechRecognitionPermission = .restricted
                        promise(.success(false))
                    case .notDetermined:
                        self.speechRecognitionPermission = .notDetermined
                        promise(.success(false))
                    @unknown default:
                        self.speechRecognitionPermission = .notDetermined
                        promise(.success(false))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 请求通知权限
    public func requestNotificationPermission() -> AnyPublisher<Bool, Never> {
        return Future { promise in
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { granted, _ in
                DispatchQueue.main.async {
                    self.notificationPermission = granted ? .granted : .denied
                    promise(.success(granted))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 打开系统设置页面
    public func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    /// 检查核心功能是否可用
    public var coreFeatureAvailable: Bool {
        return microphonePermission.isGranted && speechRecognitionPermission.isGranted
    }
    
    /// 检查所有权限是否已授权
    public var allPermissionsGranted: Bool {
        return microphonePermission.isGranted && 
               speechRecognitionPermission.isGranted &&
               notificationPermission.isGranted
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        // 监听应用进入前台时刷新权限状态
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.checkAllPermissions()
        }
    }
    
    private func checkMicrophonePermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            microphonePermission = .granted
        case .denied:
            microphonePermission = .denied
        case .undetermined:
            microphonePermission = .notDetermined
        @unknown default:
            microphonePermission = .notDetermined
        }
    }
    
    private func checkSpeechRecognitionPermission() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            speechRecognitionPermission = .granted
        case .denied:
            speechRecognitionPermission = .denied
        case .restricted:
            speechRecognitionPermission = .restricted
        case .notDetermined:
            speechRecognitionPermission = .notDetermined
        @unknown default:
            speechRecognitionPermission = .notDetermined
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self.notificationPermission = .granted
                case .denied:
                    self.notificationPermission = .denied
                case .notDetermined:
                    self.notificationPermission = .notDetermined
                @unknown default:
                    self.notificationPermission = .notDetermined
                }
            }
        }
    }
    
    // MARK: - Permission Descriptions
    
    /// 获取权限描述信息
    public func getPermissionDescription(for permission: PermissionType) -> PermissionDescription {
        switch permission {
        case .microphone:
            return PermissionDescription(
                title: "麦克风访问",
                description: "VoiceBudget需要访问您的麦克风来录制语音记账内容",
                reason: "语音记账功能需要录制您的语音输入",
                status: microphonePermission
            )
        case .speechRecognition:
            return PermissionDescription(
                title: "语音识别",
                description: "VoiceBudget需要使用语音识别来将您的语音转换为文字",
                reason: "智能识别语音内容并自动分类记账信息",
                status: speechRecognitionPermission
            )
        case .notification:
            return PermissionDescription(
                title: "通知",
                description: "VoiceBudget需要发送通知来提醒您预算使用情况",
                reason: "及时提醒预算超支和重要的财务信息",
                status: notificationPermission
            )
        }
    }
    
    /// 获取权限请求策略
    public func getPermissionStrategy() -> PermissionStrategy {
        let missingPermissions = getMissingPermissions()
        
        if missingPermissions.isEmpty {
            return .allGranted
        } else if missingPermissions.contains(.microphone) || missingPermissions.contains(.speechRecognition) {
            return .coreRequired
        } else {
            return .optionalOnly
        }
    }
    
    private func getMissingPermissions() -> [PermissionType] {
        var missing: [PermissionType] = []
        
        if !microphonePermission.isGranted {
            missing.append(.microphone)
        }
        if !speechRecognitionPermission.isGranted {
            missing.append(.speechRecognition)
        }
        if !notificationPermission.isGranted {
            missing.append(.notification)
        }
        
        return missing
    }
}

// MARK: - Supporting Types

public enum PermissionType {
    case microphone
    case speechRecognition
    case notification
}

public struct PermissionDescription {
    public let title: String
    public let description: String
    public let reason: String
    public let status: PermissionManager.PermissionStatus
    
    public init(title: String, description: String, reason: String, status: PermissionManager.PermissionStatus) {
        self.title = title
        self.description = description
        self.reason = reason
        self.status = status
    }
}

public enum PermissionStrategy {
    case allGranted
    case coreRequired
    case optionalOnly
    
    public var displayMessage: String {
        switch self {
        case .allGranted:
            return "所有权限已获得，可以正常使用所有功能"
        case .coreRequired:
            return "需要麦克风和语音识别权限才能使用语音记账功能"
        case .optionalOnly:
            return "核心功能可用，建议开启通知权限以获得更好体验"
        }
    }
}

// MARK: - Extensions

extension PermissionManager {
    
    /// 创建权限请求引导流程
    public func createPermissionOnboardingSteps() -> [PermissionOnboardingStep] {
        return [
            PermissionOnboardingStep(
                type: .microphone,
                title: "开启麦克风",
                subtitle: "录制您的语音记账内容",
                icon: "mic.fill",
                isRequired: true,
                action: { self.requestMicrophonePermission() }
            ),
            PermissionOnboardingStep(
                type: .speechRecognition,
                title: "启用语音识别",
                subtitle: "智能识别语音并自动分类",
                icon: "waveform.badge.mic",
                isRequired: true,
                action: { self.requestSpeechRecognitionPermission() }
            ),
            PermissionOnboardingStep(
                type: .notification,
                title: "允许通知",
                subtitle: "及时提醒预算和记账信息",
                icon: "bell.fill",
                isRequired: false,
                action: { self.requestNotificationPermission() }
            )
        ]
    }
}

public struct PermissionOnboardingStep {
    public let type: PermissionType
    public let title: String
    public let subtitle: String
    public let icon: String
    public let isRequired: Bool
    public let action: () -> AnyPublisher<Bool, Never>
    
    public init(
        type: PermissionType,
        title: String,
        subtitle: String,
        icon: String,
        isRequired: Bool,
        action: @escaping () -> AnyPublisher<Bool, Never>
    ) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isRequired = isRequired
        self.action = action
    }
}

// MARK: - Required Imports (需要在实际项目中添加)
import UIKit