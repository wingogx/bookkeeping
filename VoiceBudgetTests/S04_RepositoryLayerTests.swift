import XCTest
import CoreData
@testable import VoiceBudget

final class S04_RepositoryLayerTests: XCTestCase {
    
    var coreDataStack: CoreDataStack!
    
    override func setUpWithError() throws {
        super.setUp()
        coreDataStack = CoreDataStack.shared
    }
    
    override func tearDownWithError() throws {
        coreDataStack = nil
        super.tearDown()
    }
    
    // MARK: - TransactionRepository Tests
    
    func testCoreDataTransactionRepositoryExists() {
        let repository = CoreDataTransactionRepository(context: coreDataStack.viewContext)
        XCTAssertNotNil(repository)
    }
    
    func testCreateTransaction() async throws {
        let repository = CoreDataTransactionRepository(context: coreDataStack.viewContext)
        
        let transaction = TransactionEntity(
            id: UUID(),
            amount: 50.00,
            categoryID: "dining",
            note: "午餐",
            date: Date(),
            source: .voice
        )
        
        let createdTransaction = try await repository.createTransaction(transaction)
        XCTAssertEqual(createdTransaction.amount, transaction.amount)
        XCTAssertEqual(createdTransaction.categoryID, transaction.categoryID)
        XCTAssertEqual(createdTransaction.note, transaction.note)
    }
    
    func testGetTransactionById() async throws {
        let repository = CoreDataTransactionRepository(context: coreDataStack.viewContext)
        
        let originalTransaction = TransactionEntity(
            id: UUID(),
            amount: 30.00,
            categoryID: "transportation",
            note: "打车费用",
            date: Date(),
            source: .manual
        )
        
        let created = try await repository.createTransaction(originalTransaction)
        let retrieved = try await repository.getTransaction(by: created.id)
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, created.id)
        XCTAssertEqual(retrieved?.amount, created.amount)
    }
    
    func testFetchTransactionsWithFilters() async throws {
        let repository = CoreDataTransactionRepository(context: coreDataStack.viewContext)
        
        // Create test transactions
        let transaction1 = TransactionEntity(
            id: UUID(),
            amount: 25.00,
            categoryID: "dining",
            note: "早餐",
            date: Date(),
            source: .voice
        )
        
        let transaction2 = TransactionEntity(
            id: UUID(),
            amount: 15.00,
            categoryID: "dining",
            note: "咖啡",
            date: Date().addingTimeInterval(-3600), // 1 hour ago
            source: .manual
        )
        
        _ = try await repository.createTransaction(transaction1)
        _ = try await repository.createTransaction(transaction2)
        
        let results = try await repository.fetchTransactions(
            startDate: Date().addingTimeInterval(-7200), // 2 hours ago
            endDate: Date().addingTimeInterval(3600), // 1 hour from now
            categoryID: "dining",
            source: nil,
            limit: 10,
            offset: 0
        )
        
        XCTAssertGreaterThanOrEqual(results.count, 2)
    }
    
    // MARK: - BudgetRepository Tests
    
    func testCoreDataBudgetRepositoryExists() {
        let repository = CoreDataBudgetRepository(context: coreDataStack.viewContext)
        XCTAssertNotNil(repository)
    }
    
    func testCreateBudget() async throws {
        let repository = CoreDataBudgetRepository(context: coreDataStack.viewContext)
        
        let budget = BudgetEntity(
            id: UUID(),
            name: "月度预算",
            totalAmount: 3000.00,
            period: .month,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            categoryAllocations: [],
            isActive: true
        )
        
        let createdBudget = try await repository.createBudget(budget)
        XCTAssertEqual(createdBudget.name, budget.name)
        XCTAssertEqual(createdBudget.totalAmount, budget.totalAmount)
        XCTAssertEqual(createdBudget.period, budget.period)
    }
    
    func testGetCurrentBudget() async throws {
        let repository = CoreDataBudgetRepository(context: coreDataStack.viewContext)
        
        let activeBudget = BudgetEntity(
            id: UUID(),
            name: "当前预算",
            totalAmount: 2500.00,
            period: .month,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            categoryAllocations: [],
            isActive: true
        )
        
        _ = try await repository.createBudget(activeBudget)
        let currentBudget = try await repository.getCurrentBudget()
        
        XCTAssertNotNil(currentBudget)
        XCTAssertEqual(currentBudget?.name, activeBudget.name)
        XCTAssertEqual(currentBudget?.isActive, true)
    }
    
    // MARK: - UserPreferenceRepository Tests
    
    func testUserDefaultsPreferenceRepositoryExists() {
        let repository = UserDefaultsPreferenceRepository()
        XCTAssertNotNil(repository)
    }
    
    func testSetAndGetBoolPreference() async throws {
        let repository = UserDefaultsPreferenceRepository()
        
        try await repository.setBool(true, for: .enableVoiceRecording)
        let value = try await repository.getBool(for: .enableVoiceRecording)
        
        XCTAssertTrue(value)
    }
    
    func testSetAndGetStringPreference() async throws {
        let repository = UserDefaultsPreferenceRepository()
        
        try await repository.setString("zh-CN", for: .voiceRecognitionLanguage)
        let value = try await repository.getString(for: .voiceRecognitionLanguage)
        
        XCTAssertEqual(value, "zh-CN")
    }
    
    func testSetAndGetIntPreference() async throws {
        let repository = UserDefaultsPreferenceRepository()
        
        try await repository.setInt(7, for: .consecutiveRecordDays)
        let value = try await repository.getInt(for: .consecutiveRecordDays)
        
        XCTAssertEqual(value, 7)
    }
    
    func testObservePreferenceValue() async throws {
        let repository = UserDefaultsPreferenceRepository()
        
        let observeStream = repository.observeValue(for: .enableVoiceRecording, type: Bool.self)
        
        try await repository.setBool(false, for: .enableVoiceRecording)
        
        // Test that the stream emits values (basic functionality test)
        var iterator = observeStream.makeAsyncIterator()
        let firstValue = await iterator.next()
        XCTAssertNotNil(firstValue)
    }
    
    // MARK: - Integration Tests
    
    func testRepositoryDependencyInjection() {
        let transactionRepo = CoreDataTransactionRepository(context: coreDataStack.viewContext)
        let budgetRepo = CoreDataBudgetRepository(context: coreDataStack.viewContext)
        let preferenceRepo = UserDefaultsPreferenceRepository()
        
        XCTAssertNotNil(transactionRepo)
        XCTAssertNotNil(budgetRepo)
        XCTAssertNotNil(preferenceRepo)
    }
    
    func testCoreDataContextSharing() {
        let context = coreDataStack.viewContext
        
        let transactionRepo1 = CoreDataTransactionRepository(context: context)
        let transactionRepo2 = CoreDataTransactionRepository(context: context)
        
        XCTAssertEqual(transactionRepo1.context, transactionRepo2.context)
    }
    
    func testRepositoryErrorHandling() async {
        let repository = CoreDataTransactionRepository(context: coreDataStack.viewContext)
        
        do {
            // Test with invalid UUID
            _ = try await repository.getTransaction(by: UUID())
            // Should not throw an error for non-existent transaction (returns nil)
        } catch {
            XCTFail("Repository should handle non-existent entities gracefully")
        }
    }
}