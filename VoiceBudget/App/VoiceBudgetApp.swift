import SwiftUI
import Speech
import AVFoundation

// MARK: - App Entry Point
@main
struct VoiceBudgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(DataManager.shared)
        }
    }
}

// MARK: - Data Models
struct Transaction: Identifiable, Codable {
    let id = UUID()
    let amount: Double
    let category: String
    let note: String
    let date: Date
    let isExpense: Bool
}

struct Budget: Codable {
    var monthlyLimit: Double
    var categoryLimits: [String: Double]
    
    static let `default` = Budget(
        monthlyLimit: 3000,
        categoryLimits: [
            "餐饮": 1000,
            "交通": 500,
            "购物": 800,
            "娱乐": 400,
            "其他": 300
        ]
    )
}

// MARK: - Data Manager
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var transactions: [Transaction] = []
    @Published var budget = Budget.default
    @Published var categories: [String] = ["餐饮", "交通", "购物", "娱乐", "生活", "医疗", "教育", "其他"]
    
    private let transactionsKey = "transactions"
    private let budgetKey = "budget"
    private let categoriesKey = "categories"
    
    init() {
        loadData()
    }
    
    // 添加交易
    func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
        saveData()
    }
    
    // 删除交易
    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        saveData()
    }
    
    // 获取今日交易
    var todayTransactions: [Transaction] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return transactions.filter {
            calendar.startOfDay(for: $0.date) == today
        }
    }
    
    // 获取本月支出
    var monthlyExpense: Double {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        return transactions
            .filter { transaction in
                let tMonth = calendar.component(.month, from: transaction.date)
                let tYear = calendar.component(.year, from: transaction.date)
                return tMonth == month && tYear == year && transaction.isExpense
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    // 获取分类支出
    func getCategoryExpense(category: String) -> Double {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        return transactions
            .filter { transaction in
                let tMonth = calendar.component(.month, from: transaction.date)
                let tYear = calendar.component(.year, from: transaction.date)
                return tMonth == month && tYear == year && 
                       transaction.isExpense && 
                       transaction.category == category
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    // 分类管理方法
    func addCategory(_ category: String) {
        if !categories.contains(category) && !category.isEmpty {
            categories.append(category)
            saveData()
        }
    }
    
    func deleteCategory(_ category: String) {
        // 检查是否有交易使用此分类
        let hasTransactions = transactions.contains { $0.category == category }
        if !hasTransactions {
            categories.removeAll { $0 == category }
            // 从预算中移除此分类
            budget.categoryLimits.removeValue(forKey: category)
            saveData()
        }
    }
    
    func updateCategory(oldName: String, newName: String) {
        if let index = categories.firstIndex(of: oldName) {
            categories[index] = newName
            
            // 更新所有使用此分类的交易
            for i in transactions.indices {
                if transactions[i].category == oldName {
                    let updatedTransaction = Transaction(
                        amount: transactions[i].amount,
                        category: newName,
                        note: transactions[i].note,
                        date: transactions[i].date,
                        isExpense: transactions[i].isExpense
                    )
                    transactions[i] = updatedTransaction
                }
            }
            
            // 更新预算设置
            if let limit = budget.categoryLimits[oldName] {
                budget.categoryLimits[newName] = limit
                budget.categoryLimits.removeValue(forKey: oldName)
            }
            
            saveData()
        }
    }
    
    // 保存数据
    func saveData() {
        if let encoded = try? JSONEncoder().encode(transactions) {
            UserDefaults.standard.set(encoded, forKey: transactionsKey)
        }
        if let encoded = try? JSONEncoder().encode(budget) {
            UserDefaults.standard.set(encoded, forKey: budgetKey)
        }
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: categoriesKey)
        }
    }
    
    // 加载数据
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: transactionsKey),
           let decoded = try? JSONDecoder().decode([Transaction].self, from: data) {
            transactions = decoded
        }
        if let data = UserDefaults.standard.data(forKey: budgetKey),
           let decoded = try? JSONDecoder().decode(Budget.self, from: data) {
            budget = decoded
        }
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            categories = decoded
        }
    }
}

// MARK: - Voice Recognition Manager
class VoiceRecognitionManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var errorMessage = ""
    
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        requestAuthorization()
    }
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("语音识别已授权")
                case .denied:
                    self.errorMessage = "语音识别权限被拒绝"
                case .restricted:
                    self.errorMessage = "语音识别受限"
                case .notDetermined:
                    self.errorMessage = "语音识别权限未确定"
                @unknown default:
                    self.errorMessage = "未知错误"
                }
            }
        }
    }
    
    func startRecording() {
        if audioEngine.isRunning {
            stopRecording()
            return
        }
        
        recognizedText = ""
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "音频会话设置失败"
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                self.recognizedText = result.bestTranscription.formattedString
            }
            
            if error != nil || result?.isFinal == true {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isRecording = false
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = "无法启动音频引擎"
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
    }
    
    // 解析识别的文本
    func parseTransaction(from text: String) -> (amount: Double?, category: String?, note: String?) {
        var amount: Double?
        var category: String?
        var note = text
        
        // 提取金额
        let pattern = "\\d+(\\.\\d+)?"
        if let range = text.range(of: pattern, options: .regularExpression) {
            amount = Double(text[range])
        }
        
        // 智能分类识别 - 按优先级匹配关键词
        // 具体关键词优先级高于通用关键词
        let priorityCategories = [
            ("餐饮", ["奶茶", "咖啡", "茶", "饮料", "吃饭", "午餐", "晚餐", "早餐", "饭", "菜", "餐厅", "外卖", "点餐", "聚餐", "宵夜", "零食", "小吃"]),
            ("交通", [
                // 传统交通工具
                "地铁", "公交", "打车", "滴滴", "出租车", "火车", "高铁", "飞机",
                // 共享出行服务
                "共享单车", "摩拜", "哈啰", "青桔", "小蓝车", "ofo", "单车包月", "单车充值",
                "共享汽车", "GoFun", "EVCARD", "盼达", "car2go",
                // 交通卡充值场景  
                "充卡", "地铁充卡", "公交卡充值", "交通卡", "一卡通", "羊城通", "深圳通",
                "交通充值", "地铁充值", "公交充值",
                // 交通套餐服务
                "交通包月", "地铁月卡", "公交月卡", "交通季卡", "交通年卡",
                // 网约车平台
                "美团打车", "曹操出行", "神州专车", "首汽约车", "T3出行",
                // 票务相关
                "机票", "车票", "船票", "地铁票", "公交票", "高铁票", "动车票",
                // 汽车相关
                "加油", "油费", "停车费", "过路费", "高速费", "ETC", "洗车费",
                "汽车保养", "车辆维修", "汽车年检", "车险",
                // 出行费用
                "打车费", "车费", "路费", "交通费", "出行费", "通勤费", "班车费"
            ]),
            ("娱乐", ["电影", "游戏", "KTV", "唱歌", "旅游", "景点", "门票", "酒吧", "娱乐", "看电影", "演出", "音乐会"]),
            ("生活", ["房租", "水电费", "话费", "网费", "物业费", "生活用品", "洗衣", "理发", "美容", "按摩"]),
            ("医疗", ["医院", "看病", "药", "体检", "医疗", "挂号", "治疗", "医生"]),
            ("教育", ["学费", "培训", "课程", "书籍", "学习", "教育", "辅导", "考试"]),
            ("购物", ["买", "购买", "商场", "超市", "淘宝", "京东", "网购", "衣服", "鞋子", "化妆品", "日用品", "电器", "手机", "电脑"]),
            ("其他", ["其他", "杂费", "礼物", "红包", "捐赠"])
        ]
        
        // 智能匹配逻辑 - 处理边界情况
        func intelligentCategoryMatch() -> String? {
            // 排除误分类的场景
            let exclusions: [String: [String]] = [
                "交通": ["买单车", "买自行车", "购买单车", "健身卡", "游泳卡", "会员卡"], // 避免购买单车被误分类为交通
                "餐饮": ["买茶具", "买咖啡机", "茶叶", "咖啡豆"] // 避免购买饮品工具被误分类为餐饮
            ]
            
            // 按优先级顺序匹配
            for (categoryName, keywords) in priorityCategories {
                // 检查是否应该排除
                if let excludeKeywords = exclusions[categoryName] {
                    var shouldExclude = false
                    for excludeKeyword in excludeKeywords {
                        if text.contains(excludeKeyword) {
                            shouldExclude = true
                            break
                        }
                    }
                    if shouldExclude {
                        continue // 跳过这个分类
                    }
                }
                
                // 正常匹配逻辑
                for keyword in keywords {
                    if text.contains(keyword) {
                        return categoryName
                    }
                }
            }
            return nil
        }
        
        category = intelligentCategoryMatch()
        
        // 如果没有匹配到分类，默认使用"其他"
        if category == nil {
            category = "其他"
        }
        
        return (amount, category, note)
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("首页")
                }
                .tag(0)
            
            RecordsView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("记录")
                }
                .tag(1)
            
            BudgetView()
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("预算")
                }
                .tag(2)
            
            AnalyticsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("统计")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("设置")
                }
                .tag(4)
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var voiceManager = VoiceRecognitionManager()
    @State private var showingAddTransaction = false
    @State private var manualAmount = ""
    @State private var selectedCategory = "餐饮"
    @State private var transactionNote = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 语音记账卡片
                    VStack(spacing: 15) {
                        Image(systemName: voiceManager.isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 60))
                            .foregroundColor(voiceManager.isRecording ? .red : .blue)
                        
                        Text(voiceManager.isRecording ? "正在录音..." : "点击开始语音记账")
                            .font(.headline)
                        
                        if !voiceManager.recognizedText.isEmpty {
                            Text(voiceManager.recognizedText)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            if voiceManager.isRecording {
                                voiceManager.stopRecording()
                                // 解析并添加交易
                                let parsed = voiceManager.parseTransaction(from: voiceManager.recognizedText)
                                if let amount = parsed.amount {
                                    let transaction = Transaction(
                                        amount: amount,
                                        category: parsed.category ?? "其他",
                                        note: parsed.note ?? "",
                                        date: Date(),
                                        isExpense: true
                                    )
                                    dataManager.addTransaction(transaction)
                                }
                            } else {
                                voiceManager.startRecording()
                            }
                        }) {
                            Text(voiceManager.isRecording ? "停止录音" : "开始录音")
                                .font(.headline)
                                .padding()
                                .frame(width: 200)
                                .background(voiceManager.isRecording ? Color.red : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(25)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)
                    
                    // 手动添加按钮
                    Button(action: { showingAddTransaction = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("手动添加记账")
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    // 今日概览
                    TodaySummary()
                    
                    // 最近交易
                    RecentTransactions()
                }
                .padding()
            }
            .navigationTitle("语音记账")
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView(isPresented: $showingAddTransaction)
            }
        }
    }
}

// MARK: - Today Summary
struct TodaySummary: View {
    @EnvironmentObject var dataManager: DataManager
    
    var todayExpense: Double {
        dataManager.todayTransactions
            .filter { $0.isExpense }
            .reduce(0) { $0 + $1.amount }
    }
    
    var remainingBudget: Double {
        dataManager.budget.monthlyLimit - dataManager.monthlyExpense
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日概览")
                .font(.headline)
            
            HStack(spacing: 8) {
                // 今日支出
                VStack(spacing: 4) {
                    Text("今日支出")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .minimumScaleFactor(0.8)
                    Text("¥\(todayExpense, specifier: "%.1f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 30)
                
                // 本月支出
                VStack(spacing: 4) {
                    Text("本月支出")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .minimumScaleFactor(0.8)
                    Text("¥\(dataManager.monthlyExpense, specifier: "%.1f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 30)
                
                // 剩余预算
                VStack(spacing: 4) {
                    Text("剩余预算")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .minimumScaleFactor(0.8)
                    Text("¥\(remainingBudget, specifier: "%.1f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(remainingBudget > 0 ? .green : .red)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Recent Transactions
struct RecentTransactions: View {
    @EnvironmentObject var dataManager: DataManager
    
    var recentTransactions: [Transaction] {
        Array(dataManager.transactions.sorted { $0.date > $1.date }.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近交易")
                .font(.headline)
            
            if recentTransactions.isEmpty {
                Text("暂无交易记录")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(recentTransactions) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
        }
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: Transaction
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(transaction.category)
                    .font(.headline)
                Text(transaction.note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(transaction.isExpense ? "-" : "+")¥\(transaction.amount, specifier: "%.2f")")
                    .font(.headline)
                    .foregroundColor(transaction.isExpense ? .red : .green)
                Text(dateFormatter.string(from: transaction.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Add Transaction View
struct AddTransactionView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var dataManager: DataManager
    
    @State private var amount = ""
    @State private var selectedCategory = "餐饮"
    @State private var note = ""
    @State private var isExpense = true
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("交易信息")) {
                    TextField("金额", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    Picker("类型", selection: $isExpense) {
                        Text("支出").tag(true)
                        Text("收入").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Picker("分类", selection: $selectedCategory) {
                        ForEach(dataManager.categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    
                    TextField("备注", text: $note)
                    
                    DatePicker("日期", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("添加交易")
            .navigationBarItems(
                leading: Button("取消") { isPresented = false },
                trailing: Button("保存") {
                    if let amountValue = Double(amount) {
                        let transaction = Transaction(
                            amount: amountValue,
                            category: selectedCategory,
                            note: note,
                            date: selectedDate,
                            isExpense: isExpense
                        )
                        dataManager.addTransaction(transaction)
                        isPresented = false
                    }
                }
            )
        }
    }
}

// MARK: - Records View
struct RecordsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    
    var filteredTransactions: [Transaction] {
        var result = dataManager.transactions
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.note.contains(searchText) || $0.category.contains(searchText)
            }
        }
        
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        return result.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 搜索栏
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("搜索交易", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)
                    
                    // 分类筛选
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            CategoryFilterButton(
                                title: "全部",
                                isSelected: selectedCategory == nil,
                                action: { selectedCategory = nil }
                            )
                            
                            ForEach(dataManager.categories, id: \.self) { category in
                                CategoryFilterButton(
                                    title: category,
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 统计信息
                    if !filteredTransactions.isEmpty {
                        HStack {
                            Text("共 \(filteredTransactions.count) 条记录")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("总计: ¥\(filteredTransactions.reduce(0) { $0 + $1.amount }, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    // 交易记录列表
                    if filteredTransactions.isEmpty {
                        // 空状态
                        VStack(spacing: 20) {
                            Image(systemName: "tray")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("暂无交易记录")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("开始语音记账或手动添加交易")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 50)
                    } else {
                        // 显示所有交易记录
                        ForEach(filteredTransactions) { transaction in
                            SimpleTransactionRow(transaction: transaction)
                                .padding(.horizontal)
                                .onTapGesture {
                                    // 预留：点击查看详情
                                }
                        }
                    }
                    
                    // 底部间距
                    Spacer(minLength: 100)
                }
                .padding(.top)
            }
            .navigationTitle("交易记录")
        }
    }
}

// MARK: - Simple Transaction Row
struct SimpleTransactionRow: View {
    let transaction: Transaction
    @EnvironmentObject var dataManager: DataManager
    @State private var showingDeleteAlert = false
    
    private var categoryIcon: String {
        switch transaction.category {
        case "餐饮": return "fork.knife"
        case "交通": return "car.fill"
        case "购物": return "bag.fill"
        case "娱乐": return "gamecontroller.fill"
        case "生活": return "house.fill"
        case "医疗": return "cross.case.fill"
        case "教育": return "book.fill"
        default: return "ellipsis.circle.fill"
        }
    }
    
    private var categoryColor: Color {
        switch transaction.category {
        case "餐饮": return .orange
        case "交通": return .blue
        case "购物": return .green
        case "娱乐": return .purple
        case "生活": return Color(red: 0.6, green: 0.4, blue: 0.2)
        case "医疗": return .red
        case "教育": return Color(red: 0.0, green: 0.7, blue: 1.0)
        default: return .gray
        }
    }
    
    var body: some View {
        HStack {
            // 分类图标
            Image(systemName: categoryIcon)
                .font(.title2)
                .foregroundColor(categoryColor)
                .frame(width: 40, height: 40)
                .background(categoryColor.opacity(0.1))
                .clipShape(Circle())
            
            // 交易信息
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.category)
                    .font(.headline)
                Text(transaction.note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(DateFormatter.transactionDisplay.string(from: transaction.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 金额
            Text("¥\(transaction.amount, specifier: "%.2f")")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(categoryColor)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
        .contextMenu {
            Button(action: {
                dataManager.deleteTransaction(transaction)
            }) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let transactionDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}



// MARK: - Category Filter Button
struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(15)
        }
    }
}

// MARK: - Budget View
struct BudgetView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var editingBudget = false
    @State private var newMonthlyLimit = ""
    
    var budgetProgress: Double {
        min(dataManager.monthlyExpense / dataManager.budget.monthlyLimit, 1.0)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 月度预算
                    VStack(spacing: 15) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("本月预算")
                                    .font(.headline)
                                Text("(分类预算自动汇总)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("设置分类预算") { editingBudget = true }
                                .font(.subheadline)
                        }
                        
                        Text("¥\(dataManager.budget.monthlyLimit, specifier: "%.0f")")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        ProgressView(value: budgetProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: budgetProgress > 0.8 ? .red : .blue))
                        
                        HStack {
                            VStack {
                                Text("已用")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("¥\(dataManager.monthlyExpense, specifier: "%.2f")")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                            }
                            
                            Spacer()
                            
                            VStack {
                                Text("剩余")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("¥\(dataManager.budget.monthlyLimit - dataManager.monthlyExpense, specifier: "%.2f")")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            VStack {
                                Text("使用率")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(budgetProgress * 100))%")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)
                    
                    // 分类预算
                    VStack(alignment: .leading, spacing: 15) {
                        Text("分类预算")
                            .font(.headline)
                        
                        ForEach(dataManager.categories, id: \.self) { category in
                            let limit = dataManager.budget.categoryLimits[category] ?? 0
                            CategoryBudgetRow(
                                category: category,
                                limit: limit,
                                used: dataManager.getCategoryExpense(category: category)
                            )
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)
                }
                .padding()
            }
            .navigationTitle("预算管理")
            .sheet(isPresented: $editingBudget) {
                EditBudgetView(isPresented: $editingBudget)
            }
        }
    }
}

// MARK: - Category Budget Row
struct CategoryBudgetRow: View {
    let category: String
    let limit: Double
    let used: Double
    
    var progress: Double {
        limit > 0 ? min(used / limit, 1.0) : 0
    }
    
    var progressColor: Color {
        if progress > 0.9 { return .red }
        if progress > 0.7 { return .orange }
        return .blue
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(category)
                    .fontWeight(.medium)
                Spacer()
                if limit > 0 {
                    Text("¥\(used, specifier: "%.0f") / ¥\(limit, specifier: "%.0f")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("未设置预算")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .italic()
                }
            }
            
            if limit > 0 {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)
                    .cornerRadius(3)
                    .overlay(
                        Text("点击设置预算以启用进度跟踪")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    )
            }
        }
    }
}

// MARK: - Edit Budget View
struct EditBudgetView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var dataManager: DataManager
    @State private var categoryLimits: [String: String] = [:]
    
    // 计算分类预算总和
    var calculatedTotalBudget: Double {
        return categoryLimits.compactMap { Double($0.value) }.reduce(0, +)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("分类预算设置")) {
                    ForEach(dataManager.categories, id: \.self) { category in
                        HStack {
                            Text(category)
                                .font(.subheadline)
                            Spacer()
                            TextField("0", text: Binding(
                                get: { categoryLimits[category] ?? "" },
                                set: { categoryLimits[category] = $0 }
                            ))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                            Text("元")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                Section(header: Text("预算汇总")) {
                    HStack {
                        Text("月度总预算")
                            .font(.headline)
                        Spacer()
                        Text("¥\(calculatedTotalBudget, specifier: "%.0f")")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                    
                    if calculatedTotalBudget == 0 {
                        Text("请设置各分类预算")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Text("各分类预算自动累计为月度总预算")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("快速设置")) {
                    VStack(spacing: 12) {
                        Text("推荐预算分配（基于¥3000总预算）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("应用推荐分配") {
                            categoryLimits = [
                                "餐饮": "900",  // 30%
                                "交通": "450",  // 15%
                                "购物": "600",  // 20%
                                "娱乐": "300",  // 10%
                                "生活": "450",  // 15%
                                "医疗": "150",  // 5%
                                "教育": "120",  // 4%
                                "其他": "30"    // 1%
                            ]
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("预算设置")
            .navigationBarItems(
                leading: Button("取消") { isPresented = false },
                trailing: Button("保存") {
                    // 保存分类预算
                    for (category, limitStr) in categoryLimits {
                        if let limit = Double(limitStr), limit > 0 {
                            dataManager.budget.categoryLimits[category] = limit
                        } else {
                            dataManager.budget.categoryLimits[category] = 0
                        }
                    }
                    
                    // 清理不存在的分类预算
                    let validCategories = Set(dataManager.categories)
                    dataManager.budget.categoryLimits = dataManager.budget.categoryLimits.filter { validCategories.contains($0.key) }
                    
                    // 自动计算并设置月度总预算
                    dataManager.budget.monthlyLimit = calculatedTotalBudget
                    
                    // 保存数据到本地
                    dataManager.saveData()
                    
                    isPresented = false
                }
            )
        }
        .onAppear {
            // 初始化分类预算数据
            for category in dataManager.categories {
                let limit = dataManager.budget.categoryLimits[category] ?? 0
                categoryLimits[category] = limit > 0 ? "\(Int(limit))" : ""
            }
        }
    }
}

// MARK: - Analytics View
struct AnalyticsView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var categoryExpenses: [(String, Double)] {
        dataManager.categories.map { category in
            (category, dataManager.getCategoryExpense(category: category))
        }.filter { $0.1 > 0 }
    }
    
    var totalExpense: Double {
        categoryExpenses.reduce(0) { $0 + $1.1 }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 月度总览
                    VStack(spacing: 15) {
                        Text("本月支出")
                            .font(.headline)
                        
                        Text("¥\(dataManager.monthlyExpense, specifier: "%.2f")")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        HStack {
                            VStack {
                                Text("日均支出")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("¥\(dataManager.monthlyExpense / Double(Calendar.current.component(.day, from: Date())), specifier: "%.2f")")
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            VStack {
                                Text("交易笔数")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(dataManager.transactions.filter { $0.isExpense }.count)")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)
                    
                    // 分类统计
                    VStack(alignment: .leading, spacing: 15) {
                        Text("分类支出")
                            .font(.headline)
                        
                        ForEach(categoryExpenses.sorted { $0.1 > $1.1 }, id: \.0) { category, expense in
                            HStack {
                                Text(category)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("¥\(expense, specifier: "%.2f")")
                                        .fontWeight(.semibold)
                                    Text("\(Int((expense / totalExpense) * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)
                }
                .padding()
            }
            .navigationTitle("数据统计")
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("voiceEnabled") private var voiceEnabled = true
    @AppStorage("budgetReminder") private var budgetReminder = true
    @State private var showingClearAlert = false
    @State private var showingCategoryManager = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("语音设置")) {
                    Toggle("启用语音识别", isOn: $voiceEnabled)
                }
                
                Section(header: Text("预算设置")) {
                    Toggle("预算提醒", isOn: $budgetReminder)
                }
                
                Section(header: Text("分类管理")) {
                    NavigationLink(destination: CategoryManagerView()) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text("管理分类")
                        }
                    }
                    
                    HStack {
                        Text("当前分类数")
                        Spacer()
                        Text("\(dataManager.categories.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("数据管理")) {
                    Button(action: { showingClearAlert = true }) {
                        Text("清空所有数据")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("1.0.5")
                                .foregroundColor(.secondary)
                            Text("MVP版本")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack {
                        Text("记录总数")
                        Spacer()
                        Text("\(dataManager.transactions.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("分类数量")
                        Spacer()
                        Text("\(dataManager.categories.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("支持系统")
                        Spacer()
                        Text("iOS 14.0+")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .alert(isPresented: $showingClearAlert) {
                Alert(
                    title: Text("清空数据"),
                    message: Text("确定要清空所有交易记录吗？此操作不可恢复。"),
                    primaryButton: .destructive(Text("清空")) {
                        dataManager.transactions.removeAll()
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
        }
    }
}

// MARK: - Category Manager View
struct CategoryManagerView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var newCategoryName = ""
    @State private var showingDeleteAlert = false
    @State private var selectedCategory = ""
    @State private var editingCategory: String? = nil
    @State private var editingCategoryName = ""
    
    var body: some View {
        List {
            Section(header: Text("添加新分类")) {
                HStack {
                    TextField("输入分类名称", text: $newCategoryName)
                    Button("添加") {
                        if !newCategoryName.isEmpty {
                            dataManager.addCategory(newCategoryName)
                            newCategoryName = ""
                        }
                    }
                    .disabled(newCategoryName.isEmpty)
                }
            }
            
            Section(header: Text("当前分类")) {
                ForEach(dataManager.categories, id: \.self) { category in
                    HStack {
                        if editingCategory == category {
                            TextField("分类名称", text: $editingCategoryName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            Text(category)
                                .font(.subheadline)
                        }
                        
                        Spacer()
                        
                        // 显示使用此分类的交易数量
                        let transactionCount = dataManager.transactions.filter { $0.category == category }.count
                        if transactionCount > 0 {
                            Text("\(transactionCount)条记录")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if editingCategory == category {
                            Button("保存") {
                                if !editingCategoryName.isEmpty && editingCategoryName != category {
                                    dataManager.updateCategory(oldName: category, newName: editingCategoryName)
                                }
                                editingCategory = nil
                            }
                            .foregroundColor(.green)
                            .font(.caption)
                            
                            Button("取消") {
                                editingCategory = nil
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        } else {
                            Button("编辑") {
                                editingCategory = category
                                editingCategoryName = category
                            }
                            .foregroundColor(.blue)
                            .font(.caption)
                        }
                    }
                    .contextMenu {
                        Button("重命名") {
                            editingCategory = category
                            editingCategoryName = category
                        }
                        
                        Button("删除") {
                            selectedCategory = category
                            showingDeleteAlert = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            
            Section(header: Text("使用说明")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("• 点击'编辑'可直接修改分类名")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• 长按分类可显示快捷菜单")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• 有交易记录的分类不能删除")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• 重命名会自动更新所有记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("分类管理")
        .navigationBarItems(trailing: Button("完成") {
            editingCategory = nil // 退出编辑状态
        })
        .alert(isPresented: $showingDeleteAlert) {
            let hasTransactions = dataManager.transactions.contains { $0.category == selectedCategory }
            if hasTransactions {
                return Alert(
                    title: Text("删除分类"),
                    message: Text("此分类还有交易记录，无法删除。请先删除或修改相关交易。"),
                    dismissButton: .default(Text("确定"))
                )
            } else {
                return Alert(
                    title: Text("删除分类"),
                    message: Text("确定要删除分类'\(selectedCategory)'吗？"),
                    primaryButton: .destructive(Text("删除")) {
                        dataManager.deleteCategory(selectedCategory)
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DataManager.shared)
    }
}