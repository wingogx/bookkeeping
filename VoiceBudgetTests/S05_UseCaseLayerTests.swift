import XCTest
import CoreData
@testable import VoiceBudget

final class S05_UseCaseLayerTests: XCTestCase {
    
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
        coreDataStack = nil
        transactionRepository = nil
        budgetRepository = nil
        preferenceRepository = nil
        super.tearDown()
    }
    
    // MARK: - Transaction Use Cases Tests
    
    func testCreateTransactionUseCaseExists() {
        let useCase = CreateTransactionUseCase(
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository
        )
        XCTAssertNotNil(useCase)
    }
    
    func testCreateTransactionUseCaseExecution() async throws {
        let useCase = CreateTransactionUseCase(
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository
        )
        
        let request = CreateTransactionUseCase.Request(
            amount: 50.00,
            categoryID: "dining",
            note: "午餐",
            date: Date(),
            source: .voice
        )
        
        let response = try await useCase.execute(request)
        
        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.transaction)
        XCTAssertEqual(response.transaction?.amount, 50.00)
        XCTAssertEqual(response.transaction?.categoryID, "dining")
    }
    
    func testGetTransactionHistoryUseCaseExists() {
        let useCase = GetTransactionHistoryUseCase(transactionRepository: transactionRepository)
        XCTAssertNotNil(useCase)
    }
    
    func testGetTransactionHistoryUseCaseExecution() async throws {
        let useCase = GetTransactionHistoryUseCase(transactionRepository: transactionRepository)
        
        // Create test transaction first
        _ = try await transactionRepository.createTransaction(TransactionEntity(
            id: UUID(),
            amount: 30.00,
            categoryID: "transportation",
            note: "地铁费用",
            date: Date(),
            source: .manual
        ))
        
        let request = GetTransactionHistoryUseCase.Request(
            startDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            endDate: Date(),
            categoryID: nil,
            limit: 10
        )
        
        let response = try await useCase.execute(request)
        
        XCTAssertTrue(response.success)
        XCTAssertFalse(response.transactions.isEmpty)
    }
    
    // MARK: - Budget Use Cases Tests
    
    func testCreateBudgetUseCaseExists() {
        let useCase = CreateBudgetUseCase(
            budgetRepository: budgetRepository,
            preferenceRepository: preferenceRepository
        )
        XCTAssertNotNil(useCase)
    }
    
    func testCreateBudgetUseCaseExecution() async throws {
        let useCase = CreateBudgetUseCase(
            budgetRepository: budgetRepository,
            preferenceRepository: preferenceRepository
        )
        
        let allocations = [
            BudgetEntity.BudgetCategoryAllocation(categoryID: "dining", categoryName: "餐饮", allocatedAmount: 800),
            BudgetEntity.BudgetCategoryAllocation(categoryID: "transportation", categoryName: "交通", allocatedAmount: 200)
        ]
        
        let request = CreateBudgetUseCase.Request(
            name: "测试预算",
            totalAmount: 1000.00,
            period: .month,
            categoryAllocations: allocations
        )
        
        let response = try await useCase.execute(request)
        
        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.budget)
        XCTAssertEqual(response.budget?.name, "测试预算")
        XCTAssertEqual(response.budget?.totalAmount, 1000.00)
    }
    
    func testGetBudgetStatusUseCaseExists() {
        let useCase = GetBudgetStatusUseCase(
            budgetRepository: budgetRepository,
            transactionRepository: transactionRepository
        )
        XCTAssertNotNil(useCase)
    }
    
    func testGetBudgetStatusUseCaseExecution() async throws {
        // Create test budget first
        let budget = BudgetEntity(
            id: UUID(),
            name: "测试预算",
            totalAmount: 1000.00,
            period: .month,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            categoryAllocations: [],
            isActive: true
        )
        
        let createdBudget = try await budgetRepository.createBudget(budget)
        
        let useCase = GetBudgetStatusUseCase(
            budgetRepository: budgetRepository,
            transactionRepository: transactionRepository
        )
        
        let request = GetBudgetStatusUseCase.Request(budgetID: createdBudget.id)
        let response = try await useCase.execute(request)
        
        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.budgetUsage)
        XCTAssertEqual(response.budgetUsage?.budgetID, createdBudget.id)
    }
    
    // MARK: - Voice Recognition Use Cases Tests
    
    func testProcessVoiceInputUseCaseExists() {
        let useCase = ProcessVoiceInputUseCase(
            transactionRepository: transactionRepository,
            preferenceRepository: preferenceRepository
        )
        XCTAssertNotNil(useCase)
    }
    
    func testProcessVoiceInputUseCaseExecution() async throws {
        let useCase = ProcessVoiceInputUseCase(
            transactionRepository: transactionRepository,
            preferenceRepository: preferenceRepository
        )
        
        let request = ProcessVoiceInputUseCase.Request(
            voiceText: "吃饭花了二十五块钱",
            audioData: nil
        )
        
        let response = try await useCase.execute(request)
        
        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.parsedTransaction)
        // Basic parsing should extract some amount
        XCTAssertGreaterThan(response.parsedTransaction?.amount ?? 0, 0)
    }
    
    // MARK: - Analytics Use Cases Tests
    
    func testGetSpendingAnalyticsUseCaseExists() {
        let useCase = GetSpendingAnalyticsUseCase(transactionRepository: transactionRepository)
        XCTAssertNotNil(useCase)
    }
    
    func testGetSpendingAnalyticsUseCaseExecution() async throws {
        // Create some test transactions
        let transactions = [
            TransactionEntity(id: UUID(), amount: 50.00, categoryID: "dining", note: "午餐", date: Date(), source: .voice),
            TransactionEntity(id: UUID(), amount: 30.00, categoryID: "dining", note: "晚餐", date: Date(), source: .manual),
            TransactionEntity(id: UUID(), amount: 20.00, categoryID: "transportation", note: "公交", date: Date(), source: .manual)
        ]
        
        for transaction in transactions {
            _ = try await transactionRepository.createTransaction(transaction)
        }
        
        let useCase = GetSpendingAnalyticsUseCase(transactionRepository: transactionRepository)
        
        let request = GetSpendingAnalyticsUseCase.Request(
            startDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            endDate: Date()
        )
        
        let response = try await useCase.execute(request)
        
        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.summary)
        XCTAssertFalse(response.categoryStatistics.isEmpty)
        XCTAssertFalse(response.dailyTrend.isEmpty)
    }
    
    // MARK: - Achievement Use Cases Tests
    
    func testUpdateAchievementsUseCaseExists() {
        let useCase = UpdateAchievementsUseCase(
            transactionRepository: transactionRepository,
            preferenceRepository: preferenceRepository
        )
        XCTAssertNotNil(useCase)
    }
    
    func testUpdateAchievementsUseCaseExecution() async throws {
        let useCase = UpdateAchievementsUseCase(
            transactionRepository: transactionRepository,
            preferenceRepository: preferenceRepository
        )
        
        let request = UpdateAchievementsUseCase.Request(
            event: .transactionCreated,
            context: ["transactionCount": 1]
        )
        
        let response = try await useCase.execute(request)
        
        XCTAssertTrue(response.success)
        // Check if any achievements were unlocked
        XCTAssertNotNil(response.unlockedAchievements)
    }
    
    // MARK: - User Preference Use Cases Tests
    
    func testUpdateUserPreferencesUseCaseExists() {
        let useCase = UpdateUserPreferencesUseCase(preferenceRepository: preferenceRepository)
        XCTAssertNotNil(useCase)
    }
    
    func testUpdateUserPreferencesUseCaseExecution() async throws {
        let useCase = UpdateUserPreferencesUseCase(preferenceRepository: preferenceRepository)
        
        let preferences = [
            UserPreferenceKey.enableVoiceRecording: true,
            UserPreferenceKey.defaultCurrency: "CNY",
            UserPreferenceKey.themeMode: "auto"
        ] as [UserPreferenceKey : Any]
        
        let request = UpdateUserPreferencesUseCase.Request(preferences: preferences)
        let response = try await useCase.execute(request)
        
        XCTAssertTrue(response.success)
        
        // Verify preferences were set
        let voiceEnabled = try await preferenceRepository.getBool(for: .enableVoiceRecording)
        let currency = try await preferenceRepository.getString(for: .defaultCurrency)
        
        XCTAssertTrue(voiceEnabled)
        XCTAssertEqual(currency, "CNY")
    }
    
    // MARK: - Integration Tests
    
    func testUseCaseDependencyInjection() {
        let createTransactionUseCase = CreateTransactionUseCase(
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository
        )
        
        let createBudgetUseCase = CreateBudgetUseCase(
            budgetRepository: budgetRepository,
            preferenceRepository: preferenceRepository
        )
        
        XCTAssertNotNil(createTransactionUseCase)
        XCTAssertNotNil(createBudgetUseCase)
    }
    
    func testUseCaseErrorHandling() async {
        let useCase = CreateTransactionUseCase(
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository
        )
        
        // Test with invalid data
        let request = CreateTransactionUseCase.Request(
            amount: -50.00, // Invalid negative amount
            categoryID: "",
            note: nil,
            date: Date(),
            source: .voice
        )
        
        do {
            let response = try await useCase.execute(request)
            // Should return failure rather than throw
            XCTAssertFalse(response.success)
            XCTAssertNotNil(response.error)
        } catch {
            // Error handling should be graceful
            XCTAssertTrue(error is UseCaseError)
        }
    }
    
    func testUseCaseChaining() async throws {
        // Test creating a transaction and then getting analytics
        let createUseCase = CreateTransactionUseCase(
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository
        )
        
        let analyticsUseCase = GetSpendingAnalyticsUseCase(
            transactionRepository: transactionRepository
        )
        
        // Create transaction
        let createRequest = CreateTransactionUseCase.Request(
            amount: 75.00,
            categoryID: "shopping",
            note: "购买衣服",
            date: Date(),
            source: .manual
        )
        
        let createResponse = try await createUseCase.execute(createRequest)
        XCTAssertTrue(createResponse.success)
        
        // Get analytics
        let analyticsRequest = GetSpendingAnalyticsUseCase.Request(
            startDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            endDate: Date()
        )
        
        let analyticsResponse = try await analyticsUseCase.execute(analyticsRequest)
        XCTAssertTrue(analyticsResponse.success)
        XCTAssertGreaterThanOrEqual(analyticsResponse.summary?.totalAmount ?? 0, 75.00)
    }
}