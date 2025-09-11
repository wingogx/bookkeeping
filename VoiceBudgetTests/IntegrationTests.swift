import XCTest
import CoreData
@testable import VoiceBudget

/// 集成测试套件
/// 测试完整的用户流程和组件集成
final class IntegrationTests: XCTestCase {
    
    var coreDataStack: CoreDataStack!
    var transactionRepository: CoreDataTransactionRepository!
    var budgetRepository: CoreDataBudgetRepository!
    var preferenceRepository: UserDefaultsPreferenceRepository!
    
    override func setUpWithError() throws {
        super.setUp()
        coreDataStack = CoreDataStack.shared
        transactionRepository = CoreDataTransactionRepository(context: coreDataStack.viewContext)
        budgetRepository = CoreDataBudgetRepository(context: coreDataStack.viewContext)
        preferenceRepository = UserDefaultsPreferenceRepository()
    }
    
    override func tearDownWithError() throws {
        // 清理测试数据
        try cleanupTestData()
        coreDataStack = nil
        transactionRepository = nil
        budgetRepository = nil
        preferenceRepository = nil
        super.tearDown()
    }
    
    // MARK: - 完整用户流程测试
    
    func testCompleteUserJourney() async throws {
        // 1. 用户首次启动，设置偏好
        try await setupUserPreferences()
        
        // 2. 创建预算
        let budget = try await createTestBudget()
        
        // 3. 进行语音记账
        let voiceTransaction = try await processVoiceTransaction()
        
        // 4. 手动添加交易
        let manualTransaction = try await addManualTransaction()
        
        // 5. 检查预算状态
        let budgetStatus = try await checkBudgetStatus(budgetID: budget.id)
        
        // 6. 获取统计分析
        let analytics = try await getSpendingAnalytics()
        
        // 7. 验证数据一致性
        try verifyDataConsistency(
            budget: budget,
            transactions: [voiceTransaction, manualTransaction],
            budgetStatus: budgetStatus,
            analytics: analytics
        )
    }
    
    func testVoiceRecordingFlow() async throws {
        // 测试完整的语音记账流程
        let voiceUseCase = ProcessVoiceInputUseCase(
            transactionRepository: transactionRepository,
            preferenceRepository: preferenceRepository
        )
        
        let createUseCase = CreateTransactionUseCase(
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository
        )
        
        // 1. 处理语音输入
        let voiceRequest = ProcessVoiceInputUseCase.Request(voiceText: "午餐花了三十五块钱")
        let voiceResponse = try await voiceUseCase.execute(voiceRequest)
        
        XCTAssertTrue(voiceResponse.success)
        XCTAssertNotNil(voiceResponse.parsedTransaction)
        XCTAssertEqual(voiceResponse.parsedTransaction?.amount, 35.00)
        
        // 2. 创建交易记录
        guard let parsedTransaction = voiceResponse.parsedTransaction else {
            XCTFail("语音解析失败")
            return
        }
        
        let createRequest = CreateTransactionUseCase.Request(
            amount: parsedTransaction.amount,
            categoryID: parsedTransaction.categoryID ?? "dining",
            note: parsedTransaction.note,
            date: parsedTransaction.date,
            source: .voice
        )
        
        let createResponse = try await createUseCase.execute(createRequest)
        
        XCTAssertTrue(createResponse.success)
        XCTAssertNotNil(createResponse.transaction)
        XCTAssertEqual(createResponse.transaction?.amount, 35.00)
        XCTAssertEqual(createResponse.transaction?.source, .voice)
    }
    
    func testBudgetManagementFlow() async throws {
        // 测试完整的预算管理流程
        let createBudgetUseCase = CreateBudgetUseCase(
            budgetRepository: budgetRepository,
            preferenceRepository: preferenceRepository
        )
        
        let getBudgetStatusUseCase = GetBudgetStatusUseCase(
            budgetRepository: budgetRepository,
            transactionRepository: transactionRepository
        )
        
        // 1. 创建预算
        let allocations = [
            BudgetEntity.BudgetCategoryAllocation(categoryID: "dining", categoryName: "餐饮", allocatedAmount: 800),
            BudgetEntity.BudgetCategoryAllocation(categoryID: "transportation", categoryName: "交通", allocatedAmount: 200)
        ]
        
        let createRequest = CreateBudgetUseCase.Request(
            name: "测试月预算",
            totalAmount: 1000.00,
            period: .month,
            categoryAllocations: allocations
        )
        
        let createResponse = try await createBudgetUseCase.execute(createRequest)
        
        XCTAssertTrue(createResponse.success)
        XCTAssertNotNil(createResponse.budget)
        
        guard let budget = createResponse.budget else {
            XCTFail("预算创建失败")
            return
        }
        
        // 2. 添加一些交易
        _ = try await transactionRepository.createTransaction(TransactionEntity(
            id: UUID(),
            amount: 150.00,
            categoryID: "dining",
            note: "测试餐饮支出",
            date: Date(),
            source: .manual
        ))
        
        // 3. 检查预算状态
        let statusRequest = GetBudgetStatusUseCase.Request(budgetID: budget.id, includeCategoryBreakdown: true)
        let statusResponse = try await getBudgetStatusUseCase.execute(statusRequest)
        
        XCTAssertTrue(statusResponse.success)
        XCTAssertNotNil(statusResponse.budgetUsage)
        XCTAssertEqual(statusResponse.budgetUsage?.usedAmount, 150.00)
        XCTAssertFalse(statusResponse.categoryUsages.isEmpty)
        
        // 4. 验证分类预算使用情况
        let diningCategoryUsage = statusResponse.categoryUsages.first { $0.categoryID == "dining" }
        XCTAssertNotNil(diningCategoryUsage)
        XCTAssertEqual(diningCategoryUsage?.usedAmount, 150.00)
        XCTAssertEqual(diningCategoryUsage?.allocatedAmount, 800.00)
    }
    
    func testAnalyticsFlow() async throws {
        // 测试分析功能流程
        let analyticsUseCase = GetSpendingAnalyticsUseCase(transactionRepository: transactionRepository)
        
        // 1. 创建测试数据
        let testTransactions = [
            TransactionEntity(id: UUID(), amount: 50.00, categoryID: "dining", note: "早餐", date: Date(), source: .voice),
            TransactionEntity(id: UUID(), amount: 80.00, categoryID: "dining", note: "午餐", date: Date(), source: .manual),
            TransactionEntity(id: UUID(), amount: 25.00, categoryID: "transportation", note: "公交", date: Date(), source: .manual),
            TransactionEntity(id: UUID(), amount: 200.00, categoryID: "shopping", note: "购物", date: Date().addingTimeInterval(-86400), source: .manual)
        ]
        
        for transaction in testTransactions {
            _ = try await transactionRepository.createTransaction(transaction)
        }
        
        // 2. 获取分析数据
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let endDate = Date()
        
        let request = GetSpendingAnalyticsUseCase.Request(
            startDate: startDate,
            endDate: endDate,
            includeComparisons: true,
            includeTrends: true
        )
        
        let response = try await analyticsUseCase.execute(request)
        
        // 3. 验证分析结果
        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.summary)
        XCTAssertFalse(response.categoryStatistics.isEmpty)
        XCTAssertFalse(response.insights.isEmpty)
        
        // 验证汇总数据
        XCTAssertEqual(response.summary?.transactionCount, 4)
        XCTAssertEqual(response.summary?.totalAmount, 355.00)
        
        // 验证分类统计
        let diningStats = response.categoryStatistics.first { $0.categoryID == "dining" }
        XCTAssertNotNil(diningStats)
        XCTAssertEqual(diningStats?.totalAmount, 130.00)
        XCTAssertEqual(diningStats?.transactionCount, 2)
    }
    
    func testUserPreferencesFlow() async throws {
        // 测试用户偏好设置流程
        let updatePreferencesUseCase = UpdateUserPreferencesUseCase(preferenceRepository: preferenceRepository)
        
        // 1. 设置用户偏好
        let preferences: [UserPreferenceKey: Any] = [
            .enableVoiceRecording: true,
            .defaultCurrency: "CNY",
            .budgetWarningThreshold: 0.8,
            .themeMode: "dark",
            .dailyReminderEnabled: true,
            .dailyReminderTime: "19:00"
        ]
        
        let request = UpdateUserPreferencesUseCase.Request(preferences: preferences)
        let response = try await updatePreferencesUseCase.execute(request)
        
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.updatedPreferences.count, preferences.count)
        
        // 2. 验证偏好已保存
        let voiceEnabled = try await preferenceRepository.getBool(for: .enableVoiceRecording)
        let currency = try await preferenceRepository.getString(for: .defaultCurrency)
        let threshold = try await preferenceRepository.getDouble(for: .budgetWarningThreshold)
        
        XCTAssertTrue(voiceEnabled)
        XCTAssertEqual(currency, "CNY")
        XCTAssertEqual(threshold, 0.8)
    }
    
    func testDataConsistencyAfterOperations() async throws {
        // 测试多个操作后的数据一致性
        
        // 1. 创建预算
        let budget = try await createTestBudget()
        
        // 2. 添加多个交易
        var transactions: [TransactionEntity] = []
        for i in 1...5 {
            let transaction = TransactionEntity(
                id: UUID(),
                amount: Decimal(i * 20),
                categoryID: "dining",
                note: "测试交易 \(i)",
                date: Date().addingTimeInterval(TimeInterval(-i * 3600)), // 每小时一笔
                source: .manual
            )
            let saved = try await transactionRepository.createTransaction(transaction)
            transactions.append(saved)
        }
        
        // 3. 获取预算使用情况
        let budgetUsage = try await budgetRepository.getBudgetUsage(budgetID: budget.id)
        
        // 4. 获取交易汇总
        let summary = try await transactionRepository.getTransactionSummary(
            startDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            endDate: Date(),
            categoryID: nil
        )
        
        // 5. 验证数据一致性
        let expectedTotal = transactions.reduce(Decimal.zero) { $0 + $1.amount }
        XCTAssertEqual(budgetUsage.usedAmount, expectedTotal)
        XCTAssertEqual(summary.totalAmount, expectedTotal)
        XCTAssertEqual(summary.transactionCount, transactions.count)
    }
    
    func testConcurrentOperations() async throws {
        // 测试并发操作的安全性
        
        await withTaskGroup(of: Void.self) { group in
            // 同时创建多个交易
            for i in 1...10 {
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    
                    let transaction = TransactionEntity(
                        id: UUID(),
                        amount: Decimal(i * 10),
                        categoryID: "dining",
                        note: "并发测试 \(i)",
                        date: Date(),
                        source: .manual
                    )
                    
                    do {
                        _ = try await self.transactionRepository.createTransaction(transaction)
                    } catch {
                        print("并发创建交易失败: \(error)")
                    }
                }
            }
        }
        
        // 验证所有交易都已创建
        let totalCount = try await transactionRepository.getTotalTransactionCount()
        XCTAssertGreaterThanOrEqual(totalCount, 10)
    }
    
    // MARK: - 辅助方法
    
    private func setupUserPreferences() async throws {
        let preferences: [UserPreferenceKey: Any] = [
            .firstLaunch: false,
            .onboardingCompleted: true,
            .enableVoiceRecording: true,
            .defaultCurrency: "CNY",
            .budgetWarningThreshold: 0.8
        ]
        
        try await preferenceRepository.setValues(preferences)
    }
    
    private func createTestBudget() async throws -> BudgetEntity {
        let allocations = [
            BudgetEntity.BudgetCategoryAllocation(categoryID: "dining", categoryName: "餐饮", allocatedAmount: 600),
            BudgetEntity.BudgetCategoryAllocation(categoryID: "transportation", categoryName: "交通", allocatedAmount: 200),
            BudgetEntity.BudgetCategoryAllocation(categoryID: "shopping", categoryName: "购物", allocatedAmount: 300),
            BudgetEntity.BudgetCategoryAllocation(categoryID: "others", categoryName: "其他", allocatedAmount: 100)
        ]
        
        let budget = BudgetEntity(
            id: UUID(),
            name: "集成测试预算",
            totalAmount: 1200.00,
            period: .month,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            categoryAllocations: allocations,
            isActive: true
        )
        
        return try await budgetRepository.createBudget(budget)
    }
    
    private func processVoiceTransaction() async throws -> TransactionEntity {
        let voiceUseCase = ProcessVoiceInputUseCase(
            transactionRepository: transactionRepository,
            preferenceRepository: preferenceRepository
        )
        
        let createUseCase = CreateTransactionUseCase(
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository
        )
        
        // 处理语音输入
        let voiceRequest = ProcessVoiceInputUseCase.Request(voiceText: "晚餐花了四十二块钱")
        let voiceResponse = try await voiceUseCase.execute(voiceRequest)
        
        guard voiceResponse.success, let parsed = voiceResponse.parsedTransaction else {
            throw TestError.voiceProcessingFailed
        }
        
        // 创建交易
        let createRequest = CreateTransactionUseCase.Request(
            amount: parsed.amount,
            categoryID: parsed.categoryID ?? "dining",
            note: parsed.note,
            date: parsed.date,
            source: .voice
        )
        
        let createResponse = try await createUseCase.execute(createRequest)
        
        guard createResponse.success, let transaction = createResponse.transaction else {
            throw TestError.transactionCreationFailed
        }
        
        return transaction
    }
    
    private func addManualTransaction() async throws -> TransactionEntity {
        let transaction = TransactionEntity(
            id: UUID(),
            amount: 25.50,
            categoryID: "transportation",
            note: "地铁费用",
            date: Date(),
            source: .manual
        )
        
        return try await transactionRepository.createTransaction(transaction)
    }
    
    private func checkBudgetStatus(budgetID: UUID) async throws -> BudgetUsage {
        let useCase = GetBudgetStatusUseCase(
            budgetRepository: budgetRepository,
            transactionRepository: transactionRepository
        )
        
        let request = GetBudgetStatusUseCase.Request(budgetID: budgetID)
        let response = try await useCase.execute(request)
        
        guard response.success, let budgetUsage = response.budgetUsage else {
            throw TestError.budgetStatusFailed
        }
        
        return budgetUsage
    }
    
    private func getSpendingAnalytics() async throws -> GetSpendingAnalyticsUseCase.Response {
        let useCase = GetSpendingAnalyticsUseCase(transactionRepository: transactionRepository)
        
        let request = GetSpendingAnalyticsUseCase.Request(
            startDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            endDate: Date()
        )
        
        return try await useCase.execute(request)
    }
    
    private func verifyDataConsistency(
        budget: BudgetEntity,
        transactions: [TransactionEntity],
        budgetStatus: BudgetUsage,
        analytics: GetSpendingAnalyticsUseCase.Response
    ) throws {
        // 验证预算和交易的金额一致性
        let totalSpent = transactions.reduce(Decimal.zero) { $0 + $1.amount }
        XCTAssertEqual(budgetStatus.usedAmount, totalSpent)
        
        // 验证分析数据的一致性
        XCTAssertTrue(analytics.success)
        XCTAssertEqual(analytics.summary?.transactionCount, transactions.count)
        
        // 验证预算状态计算正确
        let expectedUsagePercentage = Double(truncating: (totalSpent / budget.totalAmount) as NSDecimalNumber) * 100
        XCTAssertEqual(budgetStatus.usagePercentage, expectedUsagePercentage, accuracy: 0.01)
    }
    
    private func cleanupTestData() throws {
        // 清理Core Data中的测试数据
        let context = coreDataStack.viewContext
        
        // 删除所有测试实体
        let entityNames = ["TransactionData", "BudgetData"]
        
        for entityName in entityNames {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            
            do {
                try context.execute(deleteRequest)
                try context.save()
            } catch {
                print("清理测试数据失败: \(error)")
            }
        }
        
        // 清理UserDefaults测试数据
        for key in UserPreferenceKey.allCases {
            UserDefaults.standard.removeObject(forKey: key.rawValue)
        }
    }
}

// MARK: - Test Errors

enum TestError: Error {
    case voiceProcessingFailed
    case transactionCreationFailed
    case budgetStatusFailed
    case dataInconsistency
}

extension TestError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .voiceProcessingFailed:
            return "语音处理失败"
        case .transactionCreationFailed:
            return "交易创建失败"
        case .budgetStatusFailed:
            return "预算状态获取失败"
        case .dataInconsistency:
            return "数据不一致"
        }
    }
}