import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationView {
            List {
                // 用户信息
                Section {
                    UserProfileRow()
                }
                
                // 记账设置
                Section("记账设置") {
                    SettingsRow(
                        icon: "mic.fill",
                        title: "语音记账",
                        subtitle: viewModel.voiceRecordingEnabled ? "已开启" : "已关闭"
                    ) {
                        Toggle("", isOn: $viewModel.voiceRecordingEnabled)
                    }
                    
                    SettingsRow(
                        icon: "globe",
                        title: "识别语言",
                        subtitle: viewModel.voiceLanguage
                    ) {
                        NavigationLink("", destination: LanguageSelectionView())
                    }
                    
                    SettingsRow(
                        icon: "square.and.arrow.down",
                        title: "自动保存",
                        subtitle: viewModel.autoSaveEnabled ? "已开启" : "已关闭"
                    ) {
                        Toggle("", isOn: $viewModel.autoSaveEnabled)
                    }
                }
                
                // 预算设置
                Section("预算设置") {
                    SettingsRow(
                        icon: "bell",
                        title: "预算提醒",
                        subtitle: viewModel.budgetRemindersEnabled ? "已开启" : "已关闭"
                    ) {
                        Toggle("", isOn: $viewModel.budgetRemindersEnabled)
                    }
                    
                    SettingsRow(
                        icon: "exclamationmark.triangle",
                        title: "警告阈值",
                        subtitle: "\(Int(viewModel.warningThreshold * 100))%"
                    ) {
                        NavigationLink("", destination: ThresholdSettingView())
                    }
                }
                
                // 通知设置
                Section("通知设置") {
                    SettingsRow(
                        icon: "bell.fill",
                        title: "推送通知",
                        subtitle: viewModel.notificationsEnabled ? "已开启" : "已关闭"
                    ) {
                        Toggle("", isOn: $viewModel.notificationsEnabled)
                    }
                    
                    if viewModel.notificationsEnabled {
                        SettingsRow(
                            icon: "clock",
                            title: "每日提醒",
                            subtitle: viewModel.dailyReminderEnabled ? "已开启" : "已关闭"
                        ) {
                            Toggle("", isOn: $viewModel.dailyReminderEnabled)
                        }
                        
                        if viewModel.dailyReminderEnabled {
                            SettingsRow(
                                icon: "clock.arrow.circlepath",
                                title: "提醒时间",
                                subtitle: viewModel.reminderTime
                            ) {
                                NavigationLink("", destination: ReminderTimeView())
                            }
                        }
                    }
                }
                
                // 外观设置
                Section("外观设置") {
                    SettingsRow(
                        icon: "paintbrush",
                        title: "主题",
                        subtitle: viewModel.themeMode.displayName
                    ) {
                        NavigationLink("", destination: ThemeSelectionView())
                    }
                    
                    SettingsRow(
                        icon: "textformat.size",
                        title: "字体大小",
                        subtitle: viewModel.fontSize.displayName
                    ) {
                        NavigationLink("", destination: FontSizeView())
                    }
                    
                    SettingsRow(
                        icon: "hand.tap",
                        title: "触觉反馈",
                        subtitle: viewModel.hapticFeedbackEnabled ? "已开启" : "已关闭"
                    ) {
                        Toggle("", isOn: $viewModel.hapticFeedbackEnabled)
                    }
                }
                
                // 数据管理
                Section("数据管理") {
                    SettingsRow(
                        icon: "icloud",
                        title: "iCloud同步",
                        subtitle: viewModel.cloudSyncEnabled ? "已开启" : "已关闭"
                    ) {
                        Toggle("", isOn: $viewModel.cloudSyncEnabled)
                    }
                    
                    SettingsRow(
                        icon: "square.and.arrow.up",
                        title: "导出数据",
                        subtitle: "备份您的记账数据"
                    ) {
                        NavigationLink("", destination: DataExportView())
                    }
                    
                    SettingsRow(
                        icon: "trash",
                        title: "清除数据",
                        subtitle: "删除所有本地数据"
                    ) {
                        Button("") {
                            viewModel.showClearDataAlert = true
                        }
                    }
                }
                
                // 安全设置
                Section("安全设置") {
                    if viewModel.biometricsAvailable {
                        SettingsRow(
                            icon: "faceid",
                            title: "生物识别",
                            subtitle: viewModel.biometricAuthEnabled ? "已开启" : "已关闭"
                        ) {
                            Toggle("", isOn: $viewModel.biometricAuthEnabled)
                        }
                    }
                    
                    SettingsRow(
                        icon: "lock",
                        title: "启动时验证",
                        subtitle: viewModel.authOnLaunchEnabled ? "已开启" : "已关闭"
                    ) {
                        Toggle("", isOn: $viewModel.authOnLaunchEnabled)
                    }
                }
                
                // 关于
                Section("关于") {
                    SettingsRow(
                        icon: "info.circle",
                        title: "版本",
                        subtitle: viewModel.appVersion
                    ) {
                        EmptyView()
                    }
                    
                    SettingsRow(
                        icon: "questionmark.circle",
                        title: "帮助与反馈",
                        subtitle: "获取使用帮助"
                    ) {
                        NavigationLink("", destination: HelpView())
                    }
                    
                    SettingsRow(
                        icon: "doc.text",
                        title: "隐私政策",
                        subtitle: "查看隐私政策"
                    ) {
                        NavigationLink("", destination: PrivacyPolicyView())
                    }
                }
            }
            .navigationTitle("设置")
            .alert("清除数据", isPresented: $viewModel.showClearDataAlert) {
                Button("取消", role: .cancel) { }
                Button("确认清除", role: .destructive) {
                    viewModel.clearAllData()
                }
            } message: {
                Text("此操作将删除所有本地数据，且不可恢复。如果已开启iCloud同步，云端数据不会被删除。")
            }
        }
        .onAppear {
            viewModel.loadSettings()
        }
    }
}

struct UserProfileRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("记账用户")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("坚持记账，理财有道")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            NavigationLink("", destination: UserProfileView()) {
                EmptyView()
            }
        }
        .padding(.vertical, 4)
    }
}

struct SettingsRow<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let content: () -> Content
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            content()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail Views

struct LanguageSelectionView: View {
    @StateObject private var viewModel = LanguageSelectionViewModel()
    
    var body: some View {
        List {
            ForEach(viewModel.availableLanguages, id: \.code) { language in
                HStack {
                    Text(language.name)
                    Spacer()
                    if language.code == viewModel.selectedLanguage {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectLanguage(language.code)
                }
            }
        }
        .navigationTitle("识别语言")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ThresholdSettingView: View {
    @State private var threshold: Double = 0.8
    
    var body: some View {
        VStack(spacing: 20) {
            Text("预算警告阈值")
                .font(.headline)
            
            Text("当预算使用超过此阈值时，将收到警告提醒")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack {
                Text("\(Int(threshold * 100))%")
                    .font(.title)
                    .fontWeight(.bold)
                
                Slider(value: $threshold, in: 0.5...0.95, step: 0.05)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("警告阈值")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataExportView: View {
    @StateObject private var viewModel = DataExportViewModel()
    
    var body: some View {
        List {
            Section("导出格式") {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    HStack {
                        Text(format.displayName)
                        Spacer()
                        if format == viewModel.selectedFormat {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectedFormat = format
                    }
                }
            }
            
            Section("时间范围") {
                DatePicker("开始日期", selection: $viewModel.startDate, displayedComponents: .date)
                DatePicker("结束日期", selection: $viewModel.endDate, displayedComponents: .date)
            }
            
            Section {
                Button("开始导出") {
                    viewModel.exportData()
                }
                .disabled(viewModel.isExporting)
                
                if viewModel.isExporting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("正在导出...")
                    }
                }
            }
        }
        .navigationTitle("数据导出")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpView: View {
    var body: some View {
        List {
            Section("常见问题") {
                NavigationLink("如何使用语音记账？", destination: Text("帮助内容"))
                NavigationLink("如何设置预算？", destination: Text("帮助内容"))
                NavigationLink("数据如何同步？", destination: Text("帮助内容"))
            }
            
            Section("联系我们") {
                HStack {
                    Text("邮箱")
                    Spacer()
                    Text("support@voicebudget.com")
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("帮助与反馈")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("隐私政策")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("我们重视您的隐私...")
                    .font(.body)
                
                // 更多隐私政策内容
            }
            .padding()
        }
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct UserProfileView: View {
    var body: some View {
        Text("用户资料")
            .navigationTitle("个人资料")
    }
}

struct ThemeSelectionView: View {
    var body: some View {
        Text("主题选择")
            .navigationTitle("主题")
    }
}

struct FontSizeView: View {
    var body: some View {
        Text("字体大小")
            .navigationTitle("字体大小")
    }
}

struct ReminderTimeView: View {
    var body: some View {
        Text("提醒时间")
            .navigationTitle("提醒时间")
    }
}

// MARK: - Extensions

extension ExportFormat {
    var displayName: String {
        switch self {
        case .csv: return "CSV 文件"
        case .json: return "JSON 文件"
        case .xlsx: return "Excel 文件"
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}