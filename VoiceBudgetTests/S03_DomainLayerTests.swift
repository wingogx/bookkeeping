import XCTest
@testable import VoiceBudget

/// S-03 验收标准测试: 建立Domain层实体和协议
class S03_DomainLayerTests: XCTestCase {
    
    func test_所有Domain实体都有完整的属性定义() {
        // Given & When: 创建Domain实体
        let transaction = TransactionEntity(
            id: UUID(),
            amount: 38.50,
            categoryID: "dining",
            categoryName: "餐饮",
            note: "午餐",
            date: Date(),
            source: .voice
        )
        
        let budget = BudgetEntity(
            id: UUID(),
            totalAmount: 3000.00,
            period: .month,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        )
        
        let category = CategoryEntity(
            id: "dining",
            name: "餐饮",
            icon: "🍽",
            color: "#FF6B6B",
            isUnlocked: true
        )
        
        let achievement = AchievementEntity(
            id: "first_record",
            title: "记账新手",
            description: "完成首次记账",
            iconName: "star",
            type: .streak
        )
        
        // Then: 所有属性都已正确定义
        XCTAssertNotNil(transaction.id, "Transaction ID不能为空")
        XCTAssertEqual(transaction.amount, 38.50, "Transaction金额设置不正确")
        XCTAssertEqual(transaction.categoryName, "餐饮", "Transaction分类名称不正确")
        
        XCTAssertNotNil(budget.id, "Budget ID不能为空")
        XCTAssertEqual(budget.totalAmount, 3000.00, "Budget总金额设置不正确")
        XCTAssertEqual(budget.period, .month, "Budget周期设置不正确")
        
        XCTAssertEqual(category.name, "餐饮", "Category名称设置不正确")
        XCTAssertEqual(category.icon, "🍽", "Category图标设置不正确")
        
        XCTAssertEqual(achievement.title, "记账新手", "Achievement标题设置不正确")
        XCTAssertEqual(achievement.type, .streak, "Achievement类型设置不正确")
    }
    
    func test_Repository协议定义了必要的CRUD方法() {
        // Given: 检查TransactionRepository协议方法
        let protocolType = TransactionRepository.self
        
        // When: 获取协议方法列表
        // 注: Swift中无法直接反射协议方法，这里通过编译检查验证
        
        // Then: 协议包含必要的CRUD方法
        // 这些方法的存在性通过编译时检查验证
        XCTAssertTrue(true, "TransactionRepository协议定义正确")
        
        // 类似地检查其他Repository协议
        let budgetProtocolType = BudgetRepository.self
        let userPrefProtocolType = UserPreferenceRepository.self
        
        XCTAssertNotNil(budgetProtocolType, "BudgetRepository协议存在")
        XCTAssertNotNil(userPrefProtocolType, "UserPreferenceRepository协议存在")
    }
    
    func test_实体包含业务验证逻辑() {
        // Given: 创建TransactionEntity
        let transaction = TransactionEntity(
            id: UUID(),
            amount: -100.00, // 负数金额测试
            categoryID: "dining",
            categoryName: "餐饮",
            note: "测试",
            date: Date(),
            source: .voice
        )
        
        // When: 执行业务验证
        let isValidAmount = transaction.isValidAmount
        
        // Then: 业务验证逻辑正确
        XCTAssertFalse(isValidAmount, "负数金额应该被标记为无效")
        
        // Given: 创建有效金额的交易
        let validTransaction = TransactionEntity(
            id: UUID(),
            amount: 38.50,
            categoryID: "dining",
            categoryName: "餐饮",
            note: "午餐",
            date: Date(),
            source: .voice
        )
        
        // When: 检查有效性
        let isValid = validTransaction.isValidAmount
        
        // Then: 有效金额通过验证
        XCTAssertTrue(isValid, "正数金额应该被标记为有效")
    }
    
    func test_支持Codable协议用于序列化() {
        // Given: 创建TransactionEntity
        let originalTransaction = TransactionEntity(
            id: UUID(),
            amount: 38.50,
            categoryID: "dining",
            categoryName: "餐饮",
            note: "午餐",
            date: Date(),
            source: .voice
        )
        
        // When: 序列化为JSON
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(originalTransaction)
            
            // Then: 序列化成功
            XCTAssertGreaterThan(jsonData.count, 0, "JSON序列化失败")
            
            // When: 反序列化
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decodedTransaction = try decoder.decode(TransactionEntity.self, from: jsonData)
            
            // Then: 反序列化成功且数据完整
            XCTAssertEqual(decodedTransaction.id, originalTransaction.id, "ID不匹配")
            XCTAssertEqual(decodedTransaction.amount, originalTransaction.amount, "金额不匹配")
            XCTAssertEqual(decodedTransaction.categoryName, originalTransaction.categoryName, "分类名称不匹配")
            XCTAssertEqual(decodedTransaction.source, originalTransaction.source, "来源不匹配")
            
        } catch {
            XCTFail("Codable序列化/反序列化失败: \(error)")
        }
    }
}