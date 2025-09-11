import Foundation

// 测试智能分类服务
func testTransactionCategorizer() {
    print("🧪 开始测试智能分类服务...")
    
    let categorizer = TransactionCategorizerService()
    
    let testCases = [
        "今天午餐花了38块",
        "打车去机场用了120元", 
        "在淘宝买了一件衣服200块",
        "看电影票价45元",
        "去医院看病花了300",
        "报了一个英语培训班2000块",
        "交了这个月的电费150元",
        "给朋友买了生日礼物88块"
    ]
    
    for testCase in testCases {
        let result = categorizer.categorizeTransaction(from: testCase)
        
        print("\n输入: \(testCase)")
        print("分类: \(result.category.localizedName) (\(result.category.rawValue))")
        print("金额: \(result.extractedAmount?.description ?? "未识别")")
        print("描述: \(result.extractedDescription ?? "未识别")")
        print("置信度: \(String(format: "%.2f", result.confidence))")
        print("图标: \(result.category.icon)")
        print("---")
    }
    
    print("✅ 智能分类服务测试完成")
}

// 如果这个文件被直接运行，执行测试
if CommandLine.arguments.count > 0 && CommandLine.arguments[0].contains("test_categorizer") {
    testTransactionCategorizer()
}