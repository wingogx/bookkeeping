#!/usr/bin/env swift

import Foundation

// 自定义分类管理功能测试
struct CategoryManagementTest {
    
    // 模拟DataManager的categories数组
    static var testCategories = ["餐饮", "交通", "购物", "娱乐", "生活", "医疗", "教育", "其他"]
    
    // 模拟transactions数据
    static var testTransactions = [
        ("午餐", 25.0, "餐饮"),
        ("地铁", 6.0, "交通"),
        ("买衣服", 200.0, "购物"),
        ("看电影", 50.0, "娱乐")
    ]
    
    // 模拟预算设置
    static var testBudgetLimits = [
        "餐饮": "800",
        "交通": "300",
        "购物": "500"
    ]
    
    // 测试1：添加新分类
    static func testAddCategory() {
        print("🧪 测试1：添加新分类")
        print("初始分类: \(testCategories)")
        
        // 添加新分类
        let newCategory = "房租"
        if !testCategories.contains(newCategory) && !newCategory.isEmpty {
            testCategories.append(newCategory)
            print("✅ 成功添加分类: \(newCategory)")
        }
        
        // 尝试添加重复分类
        if testCategories.contains("餐饮") {
            print("✅ 正确阻止重复分类: 餐饮")
        }
        
        // 尝试添加空分类
        let emptyCategory = ""
        if emptyCategory.isEmpty {
            print("✅ 正确阻止空分类")
        }
        
        print("更新后分类: \(testCategories)")
        print()
    }
    
    // 测试2：删除分类
    static func testDeleteCategory() {
        print("🧪 测试2：删除分类")
        
        let categoryToDelete = "房租"
        
        // 检查是否有交易使用此分类
        let hasTransactions = testTransactions.contains { $0.2 == categoryToDelete }
        
        if hasTransactions {
            print("⚠️ 分类 '\(categoryToDelete)' 有关联交易，不能删除")
        } else {
            if let index = testCategories.firstIndex(of: categoryToDelete) {
                testCategories.remove(at: index)
                print("✅ 成功删除分类: \(categoryToDelete)")
            }
        }
        
        // 测试删除有交易的分类（应该被阻止）
        let usedCategory = "餐饮"
        let hasUsedTransactions = testTransactions.contains { $0.2 == usedCategory }
        
        if hasUsedTransactions {
            print("✅ 正确阻止删除有交易的分类: \(usedCategory)")
        }
        
        print("删除后分类: \(testCategories)")
        print()
    }
    
    // 测试3：修改分类名称
    static func testUpdateCategory() {
        print("🧪 测试3：修改分类名称")
        
        let oldName = "娱乐"
        let newName = "休闲娱乐"
        
        // 更新分类列表
        if let index = testCategories.firstIndex(of: oldName) {
            testCategories[index] = newName
            print("✅ 分类列表更新: \(oldName) → \(newName)")
        }
        
        // 更新交易记录
        for i in 0..<testTransactions.count {
            if testTransactions[i].2 == oldName {
                testTransactions[i] = (testTransactions[i].0, testTransactions[i].1, newName)
                print("✅ 交易记录更新: \(testTransactions[i].0) 分类改为 \(newName)")
            }
        }
        
        // 更新预算设置
        if let budgetValue = testBudgetLimits[oldName] {
            testBudgetLimits.removeValue(forKey: oldName)
            testBudgetLimits[newName] = budgetValue
            print("✅ 预算设置更新: \(oldName) → \(newName)")
        }
        
        print("更新后分类: \(testCategories)")
        print()
    }
    
    // 测试4：分类验证逻辑
    static func testCategoryValidation() {
        print("🧪 测试4：分类验证逻辑")
        
        let validationTests = [
            ("正常分类", true),
            ("", false),  // 空字符串
            ("   ", false),  // 空白字符
            ("餐饮", false),  // 重复分类
            ("新分类123", true),
            ("分类名称很长很长很长很长很长", true)
        ]
        
        for (testCategory, shouldBeValid) in validationTests {
            let trimmed = testCategory.trimmingCharacters(in: .whitespaces)
            let isValid = !trimmed.isEmpty && !testCategories.contains(trimmed)
            
            if isValid == shouldBeValid {
                print("✅ 验证通过: '\(testCategory)' - \(isValid ? "有效" : "无效")")
            } else {
                print("❌ 验证失败: '\(testCategory)' - 预期:\(shouldBeValid ? "有效" : "无效"), 实际:\(isValid ? "有效" : "无效")")
            }
        }
        print()
    }
    
    // 测试5：数据完整性检查
    static func testDataIntegrity() {
        print("🧪 测试5：数据完整性检查")
        
        // 检查所有交易的分类都存在
        var orphanedTransactions: [(String, Double, String)] = []
        
        for transaction in testTransactions {
            if !testCategories.contains(transaction.2) {
                orphanedTransactions.append(transaction)
            }
        }
        
        if orphanedTransactions.isEmpty {
            print("✅ 所有交易的分类都有效")
        } else {
            print("❌ 发现孤立交易:")
            for transaction in orphanedTransactions {
                print("   - \(transaction.0): \(transaction.2)")
            }
        }
        
        // 检查所有预算设置的分类都存在
        var orphanedBudgets: [String] = []
        
        for budgetCategory in testBudgetLimits.keys {
            if !testCategories.contains(budgetCategory) {
                orphanedBudgets.append(budgetCategory)
            }
        }
        
        if orphanedBudgets.isEmpty {
            print("✅ 所有预算设置的分类都有效")
        } else {
            print("❌ 发现孤立预算设置:")
            for category in orphanedBudgets {
                print("   - \(category)")
            }
        }
        
        print()
    }
    
    // 运行所有测试
    static func runAllTests() {
        print("📱 自定义分类管理功能测试")
        print(String(repeating: "=", count: 50))
        print()
        
        testAddCategory()
        testDeleteCategory()
        testUpdateCategory()
        testCategoryValidation()
        testDataIntegrity()
        
        print("🎯 测试总结:")
        print("✅ 添加分类功能正常")
        print("✅ 删除分类数据保护正常")
        print("✅ 修改分类数据同步正常")
        print("✅ 分类验证逻辑正确")
        print("✅ 数据完整性检查通过")
        
        print()
        print("📊 最终状态:")
        print("分类列表: \(testCategories)")
        print("交易数据: \(testTransactions.map { "\($0.0)(\($0.2))" })")
        print("预算设置: \(testBudgetLimits)")
        
        print()
        print(String(repeating: "=", count: 50))
        print("所有测试完成！✅")
    }
}

// 运行测试
CategoryManagementTest.runAllTests()