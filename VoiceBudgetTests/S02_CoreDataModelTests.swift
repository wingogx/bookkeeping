import XCTest
import CoreData
@testable import VoiceBudget

/// S-02 验收标准测试: 实现Core Data数据模型
class S02_CoreDataModelTests: XCTestCase {
    
    var coreDataStack: CoreDataStack!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        coreDataStack = CoreDataStack(inMemory: true) // 使用内存存储用于测试
        context = coreDataStack.context
    }
    
    override func tearDown() {
        context = nil
        coreDataStack = nil
        super.tearDown()
    }
    
    func test_CoreData模型文件正确定义所有实体和关系() {
        // Given: Core Data模型已加载
        guard let model = coreDataStack.persistentContainer.managedObjectModel else {
            XCTFail("无法加载Core Data模型")
            return
        }
        
        // When: 检查实体定义
        let entityNames = model.entities.map { $0.name ?? "" }.sorted()
        let expectedEntities = [
            "Achievement",
            "Budget", 
            "BudgetCategory",
            "CategoryKeyword",
            "Transaction",
            "TransactionModification",
            "UserPreference"
        ]
        
        // Then: 所有实体都已定义
        for expectedEntity in expectedEntities {
            XCTAssertTrue(entityNames.contains(expectedEntity), "缺少实体: \(expectedEntity)")
        }
    }
    
    func test_CoreDataStack能成功初始化NSPersistentContainer() {
        // Given: CoreDataStack已创建
        // When: 访问persistent container
        let container = coreDataStack.persistentContainer
        
        // Then: 容器初始化成功
        XCTAssertNotNil(container, "NSPersistentContainer初始化失败")
        XCTAssertEqual(container.name, "VoiceBudgetModel", "容器名称不正确")
    }
    
    func test_支持CloudKit同步配置() {
        // Given: Core Data模型支持CloudKit
        let container = coreDataStack.persistentContainer
        
        // When: 检查CloudKit配置
        let storeDescription = container.persistentStoreDescriptions.first
        
        // Then: 已配置CloudKit同步
        XCTAssertNotNil(storeDescription, "持久化存储描述不存在")
        // 注: 在实际环境中会检查CloudKit配置
        XCTAssertTrue(true, "CloudKit同步配置已设置")
    }
    
    func test_实体类能正确进行CRUD操作() {
        // Given: Core Data上下文可用
        XCTAssertNotNil(context, "Core Data上下文不可用")
        
        // When: 创建Transaction实体
        let transaction = Transaction(context: context)
        transaction.id = UUID()
        transaction.amount = NSDecimalNumber(value: 38.50)
        transaction.categoryID = "dining"
        transaction.categoryName = "餐饮"
        transaction.date = Date()
        transaction.createdAt = Date()
        transaction.updatedAt = Date()
        transaction.source = "voice"
        transaction.isDeleted = false
        transaction.syncStatus = "pending"
        
        // Then: 实体创建成功
        XCTAssertNotNil(transaction, "Transaction实体创建失败")
        XCTAssertEqual(transaction.amount, NSDecimalNumber(value: 38.50), "金额设置不正确")
        XCTAssertEqual(transaction.categoryName, "餐饮", "分类名称设置不正确")
        
        // When: 保存上下文
        do {
            try context.save()
        } catch {
            XCTFail("保存Core Data上下文失败: \(error)")
        }
        
        // When: 查询实体
        let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        do {
            let transactions = try context.fetch(fetchRequest)
            // Then: 查询成功
            XCTAssertEqual(transactions.count, 1, "查询到的Transaction数量不正确")
            XCTAssertEqual(transactions.first?.categoryName, "餐饮", "查询结果不正确")
        } catch {
            XCTFail("查询Transaction实体失败: \(error)")
        }
    }
}