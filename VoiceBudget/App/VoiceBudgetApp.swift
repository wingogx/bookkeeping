import SwiftUI
import Combine
import AVFoundation
import Speech
import UserNotifications

/// VoiceBudget应用程序主入口
@main
struct VoiceBudgetApp: App {
    
    // MARK: - Properties
    @StateObject private var coreDataStack = CoreDataStack.shared
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var networkMonitor = NetworkMonitor()
    
    // MARK: - Scene Configuration
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataStack.viewContext)
                .environmentObject(coreDataStack)
                .environmentObject(permissionManager)
                .environmentObject(networkMonitor)
                .onAppear {
                    setupApplication()
                }
        }
    }
    
    // MARK: - Application Setup
    private func setupApplication() {
        // 1. 检查权限状态
        permissionManager.checkAllPermissions()
        
        // 2. 启动网络监控
        networkMonitor.startMonitoring()
        
        // 3. 设置通知
        setupNotifications()
        
        // 4. 检查是否首次启动
        checkFirstLaunch()
        
        // 5. 预加载数据
        preloadData()
    }
    
    private func setupNotifications() {
        // 请求通知权限
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if granted {
                print("通知权限已获得")
            } else if let error = error {
                print("通知权限请求失败: \(error)")
            }
        }
    }
    
    private func checkFirstLaunch() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
            UserDefaults.standard.set(Date(), forKey: "FirstLaunchDate")
            
            // 设置默认配置
            setDefaultSettings()
        }
    }
    
    private func setDefaultSettings() {
        let defaults = UserDefaults.standard
        
        // 默认设置
        if defaults.object(forKey: "VoiceLanguage") == nil {
            defaults.set("zh-CN", forKey: "VoiceLanguage")
        }
        
        if defaults.object(forKey: "CurrencyCode") == nil {
            defaults.set("CNY", forKey: "CurrencyCode")
        }
        
        if defaults.object(forKey: "AutoSync") == nil {
            defaults.set(true, forKey: "AutoSync")
        }
        
        if defaults.object(forKey: "BudgetNotifications") == nil {
            defaults.set(true, forKey: "BudgetNotifications")
        }
    }
    
    private func preloadData() {
        // 预加载分类数据
        _ = TransactionCategory.allCases
    }
}

// MARK: - Network Monitor
class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .wifi
    
    enum ConnectionType {
        case wifi
        case cellular
        case none
    }
    
    func startMonitoring() {
        // 简化的网络监控
        isConnected = true
        connectionType = .wifi
    }
}

// MARK: - Permission Manager  
class PermissionManager: ObservableObject {
    @Published var microphonePermission: PermissionStatus = .notDetermined
    @Published var speechRecognitionPermission: PermissionStatus = .notDetermined
    @Published var notificationPermission: PermissionStatus = .notDetermined
    
    enum PermissionStatus {
        case notDetermined
        case granted
        case denied
        case restricted
    }
    
    func checkAllPermissions() {
        checkMicrophonePermission()
        checkSpeechRecognitionPermission()
        checkNotificationPermission()
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
    
    func requestMicrophonePermission() -> AnyPublisher<Bool, Never> {
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
    
    func requestSpeechRecognitionPermission() -> AnyPublisher<Bool, Never> {
        return Future { promise in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    let granted = status == .authorized
                    self.speechRecognitionPermission = granted ? .granted : .denied
                    promise(.success(granted))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    var allPermissionsGranted: Bool {
        return microphonePermission == .granted && 
               speechRecognitionPermission == .granted
    }
}