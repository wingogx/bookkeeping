import SwiftUI
import Combine

/// VoiceBudget主界面 - 完整的5标签页应用
struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var coreDataStack = CoreDataStack.shared
    @StateObject private var voiceService: VoiceTransactionService
    
    init() {
        let speechService = SpeechRecognitionService()
        let categorizerService = TransactionCategorizerService()
        let repository = CoreDataTransactionRepository(coreDataStack: CoreDataStack.shared)
        
        let voiceService = VoiceTransactionService(
            speechService: speechService,
            categorizerService: categorizerService,
            transactionRepository: repository
        )
        
        self._voiceService = StateObject(wrappedValue: voiceService)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 首页 - 语音记账
            HomeTabView(voiceService: voiceService)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("首页")
                }
                .tag(0)
            
            // 记录页面
            TransactionTabView(repository: CoreDataTransactionRepository(coreDataStack: coreDataStack))
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("记录")
                }
                .tag(1)
            
            // 预算页面
            BudgetTabView()
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("预算")
                }
                .tag(2)
            
            // 统计页面
            AnalyticsTabView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("统计")
                }
                .tag(3)
            
            // 设置页面
            SettingsTabView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("设置")
                }
                .tag(4)
        }
        .accentColor(.blue)
    }
}

// MARK: - 首页标签
struct HomeTabView: View {
    @ObservedObject var voiceService: VoiceTransactionService
    @State private var showPermissionAlert = false
    @State private var showTransactionDetail = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // 欢迎卡片
                    VStack(spacing: 15) {
                        Image(systemName: "mic.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 80))
                        
                        Text("VoiceBudget")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("极简智能语音记账")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("状态: \(voiceService.recordingState.description)")
                            .font(.headline)
                            .foregroundColor(voiceService.isProcessing ? .orange : .green)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    
                    // 语音记账按钮 (microphoneButton)
                    Button(action: {
                        handleVoiceButtonTap()
                    }) {
                        HStack {
                            Image(systemName: voiceButtonIcon)
                                .font(.title2)
                            Text(voiceButtonText)
                                .font(.headline)
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 15)
                        .background(voiceButtonColor)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                        .scaleEffect(voiceService.isProcessing ? 1.05 : 1.0)
                        .disabled(!voiceService.hasRequiredPermissions && voiceService.recordingState == .ready)
                    }
                    
                    // 快捷金额按钮
                    VStack(alignment: .leading) {
                        Text("快速记账")
                            .font(.headline)
                            .padding(.leading)
                        
                        HStack(spacing: 15) {
                            ForEach(["10", "30", "50", "100"], id: \.self) { amount in
                                Button("¥\(amount)") {
                                    quickRecord(amount: Decimal(string: amount) ?? 0)
                                }
                                .padding(.horizontal, 15)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 今日概览
                    VStack(alignment: .leading, spacing: 10) {
                        Text("今日概览")
                            .font(.headline)
                            .padding(.leading)
                        
                        HStack {
                            VStack {
                                Text("今日支出")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("¥156")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                            
                            Spacer()
                            
                            VStack {
                                Text("本月预算")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("¥3000")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            VStack {
                                Text("剩余")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("¥2844")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("首页")
            .alert("需要权限", isPresented: $showPermissionAlert) {
                Button("去设置") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("请在设置中允许语音识别和麦克风权限")
            }
            .sheet(isPresented: $showTransactionDetail) {
                if let suggestion = voiceService.recognizedTransaction {
                    TransactionConfirmationView(
                        suggestion: suggestion,
                        onConfirm: {
                            voiceService.confirmTransaction()
                            showTransactionDetail = false
                        },
                        onEdit: { amount, description, category in
                            voiceService.editTransaction(amount: amount, description: description, category: category)
                        },
                        onCancel: {
                            voiceService.cancelTransaction()
                            showTransactionDetail = false
                        }
                    )
                }
            }
            .onChange(of: voiceService.recognizedTransaction) { suggestion in
                if suggestion != nil {
                    showTransactionDetail = true
                }
            }
        }
    }
    
    // MARK: - Button Properties
    private var voiceButtonIcon: String {
        switch voiceService.recordingState {
        case .recording:
            return "stop.circle.fill"
        case .recognizing, .categorizing, .saving:
            return "waveform.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        default:
            return "mic.fill"
        }
    }
    
    private var voiceButtonText: String {
        switch voiceService.recordingState {
        case .recording:
            return "停止录音"
        case .ready:
            return voiceService.hasRequiredPermissions ? "开始语音记账" : "需要权限"
        default:
            return voiceService.recordingState.description
        }
    }
    
    private var voiceButtonColor: Color {
        switch voiceService.recordingState {
        case .recording:
            return .red
        case .error:
            return .orange
        case .completed:
            return .green
        case .ready:
            return voiceService.hasRequiredPermissions ? .blue : .gray
        default:
            return .blue
        }
    }
    
    // MARK: - Actions
    private func handleVoiceButtonTap() {
        if !voiceService.hasRequiredPermissions {
            showPermissionAlert = true
            return
        }
        
        switch voiceService.recordingState {
        case .ready:
            voiceService.startVoiceTransaction()
        case .recording:
            voiceService.stopVoiceTransaction()
        default:
            break
        }
    }
    
    private func quickRecord(amount: Decimal) {
        voiceService.quickTransaction(
            amount: amount,
            category: .other,
            description: "快速记账"
        )
    }
}

// MARK: - 记录标签
struct TransactionTabView: View {
    let repository: TransactionRepositoryProtocol
    @State private var transactions: [TransactionEntity] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("今日记录 - \(DateFormatter.shortDate.string(from: Date()))")) {
                    TransactionRow(icon: "🍽", title: "午餐", time: "12:30", amount: "¥38")
                    TransactionRow(icon: "☕️", title: "咖啡", time: "15:20", amount: "¥25")
                    TransactionRow(icon: "🚇", title: "地铁", time: "18:00", amount: "¥6")
                }
                
                Section(header: Text("昨日记录")) {
                    TransactionRow(icon: "🛒", title: "超市购物", time: "19:30", amount: "¥127")
                    TransactionRow(icon: "🎬", title: "电影票", time: "20:00", amount: "¥45")
                }
                
                Section(header: Text("本周记录")) {
                    TransactionRow(icon: "⛽️", title: "加油", time: "周一", amount: "¥200")
                    TransactionRow(icon: "🍕", title: "晚餐", time: "周二", amount: "¥68")
                }
            }
            .navigationTitle("交易记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        print("➕ 手动添加记录")
                    }
                }
            }
        }
    }
}

struct TransactionRow: View {
    let icon: String
    let title: String
    let time: String
    let amount: String
    
    var body: some View {
        HStack {
            Text(icon)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text(title)
                    .fontWeight(.medium)
                Text(time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(amount)
                .fontWeight(.semibold)
                .foregroundColor(.red)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 预算标签
struct BudgetTabView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 月预算卡片
                    VStack(spacing: 15) {
                        Text("本月预算")
                            .font(.headline)
                        
                        Text("¥3,000")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        ProgressView(value: 0.32)
                            .progressViewStyle(LinearProgressViewStyle())
                            .accentColor(.blue)
                            .frame(height: 8)
                        
                        HStack {
                            VStack {
                                Text("已用")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("¥956")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                            }
                            
                            Spacer()
                            
                            VStack {
                                Text("剩余")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("¥2,044")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    
                    // 分类预算
                    VStack(alignment: .leading, spacing: 15) {
                        Text("分类预算")
                            .font(.headline)
                        
                        BudgetCategoryRow(icon: "🍽", name: "餐饮", used: 450, total: 1000, color: .orange)
                        BudgetCategoryRow(icon: "🚗", name: "交通", used: 280, total: 500, color: .blue)
                        BudgetCategoryRow(icon: "🛍", name: "购物", used: 226, total: 800, color: .purple)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    
                    Button("调整预算") {
                        print("⚙️ 调整预算设置")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("预算管理")
        }
    }
}

struct BudgetCategoryRow: View {
    let icon: String
    let name: String
    let used: Int
    let total: Int
    let color: Color
    
    var progress: Double {
        Double(used) / Double(total)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(icon)
                Text(name)
                    .fontWeight(.medium)
                Spacer()
                Text("¥\(used) / ¥\(total)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .accentColor(color)
        }
    }
}

// MARK: - 统计标签
struct AnalyticsTabView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 本月统计
                    VStack(spacing: 15) {
                        Text("本月支出分析")
                            .font(.headline)
                        
                        Text("¥2,456")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        Text("比上月减少 15.8%")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    
                    // 支出趋势
                    VStack(alignment: .leading, spacing: 15) {
                        Text("支出趋势")
                            .font(.headline)
                        
                        HStack {
                            ForEach(["周一", "周二", "周三", "周四", "周五"], id: \.self) { day in
                                VStack {
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: 30, height: CGFloat.random(in: 20...80))
                                        .cornerRadius(4)
                                    Text(day)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    
                    // 分类统计
                    VStack(alignment: .leading, spacing: 15) {
                        Text("支出分类")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            CategoryStatCard(icon: "🍽", name: "餐饮", amount: "¥1,200", percentage: "48%")
                            CategoryStatCard(icon: "🚗", name: "交通", amount: "¥450", percentage: "18%")
                            CategoryStatCard(icon: "🛍", name: "购物", amount: "¥806", percentage: "34%")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                }
                .padding()
            }
            .navigationTitle("数据统计")
        }
    }
}

struct CategoryStatCard: View {
    let icon: String
    let name: String
    let amount: String
    let percentage: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.title)
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(amount)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(percentage)
                .font(.caption)
                .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 设置标签
struct SettingsTabView: View {
    @State private var voiceEnabled = true
    @State private var budgetReminder = true
    @State private var autoSave = true
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("语音设置")) {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.blue)
                        Text("语音识别")
                        Spacer()
                        Toggle("", isOn: $voiceEnabled)
                    }
                    
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.green)
                        Text("识别语言")
                        Spacer()
                        Text("中文")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.orange)
                        Text("自动保存")
                        Spacer()
                        Toggle("", isOn: $autoSave)
                    }
                }
                
                Section(header: Text("预算设置")) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.red)
                        Text("预算提醒")
                        Spacer()
                        Toggle("", isOn: $budgetReminder)
                    }
                    
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("警告阈值")
                        Spacer()
                        Text("80%")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("数据管理")) {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(.blue)
                        Text("iCloud同步")
                        Spacer()
                        Text("已启用")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.purple)
                        Text("导出数据")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("关于")) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("支持与反馈")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}

// MARK: - 扩展
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter
    }()
}

#Preview {
    ContentView()
}