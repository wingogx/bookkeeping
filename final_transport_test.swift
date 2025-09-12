#!/usr/bin/env swift

import Foundation

// 完整的智能分类识别逻辑（与应用中一致）
func parseTransaction(from text: String) -> (amount: Double?, category: String?, note: String) {
    var amount: Double?
    var category: String?
    let note = text
    
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
    
    return (amount, category ?? "其他", note)
}

print("🚗 VoiceBudget 交通费用识别最终测试")
print(String(repeating: "=", count: 60))

// 用户重点关注的场景
let userScenarios = [
    ("共享单车包月99元", "交通"),
    ("地铁充卡100元", "交通"), 
    ("做地铁充值50元", "交通")
]

// 扩展测试场景
let testCases = [
    // ✅ 应该识别为交通的场景
    ("摩拜单车包月30元", "交通"),
    ("哈啰单车充值100元", "交通"),
    ("公交卡充值50元", "交通"),
    ("一卡通充100块", "交通"),
    ("滴滴打车50元", "交通"),
    ("美团打车费45元", "交通"),
    ("ETC充值500元", "交通"),
    ("停车费20元", "交通"),
    ("加油费300元", "交通"),
    ("高铁票180元", "交通"),
    ("机票1200元", "交通"),
    
    // ❌ 不应该识别为交通的场景  
    ("买单车2000元", "购物"),
    ("充手机话费50元", "生活"),
    ("包月健身卡200元", "其他"),
    ("买自行车1500元", "购物"),
    ("购买单车配件100元", "购物"),
    
    // 边界测试
    ("共享汽车租车费80元", "交通"),
    ("GoFun充值200元", "交通"),
    ("买茶具50元", "购物"),
    ("买咖啡机300元", "购物")
]

print("\n🎯 用户重点场景测试:")
print("输入文本 → 预期分类 | 实际识别 | 结果")
print(String(repeating: "-", count: 60))

var userTestsPassed = 0
for (testCase, expected) in userScenarios {
    let result = parseTransaction(from: testCase)
    let actual = result.category ?? "其他"
    let status = actual == expected ? "✅ 正确" : "❌ 错误"
    print("\(status) '\(testCase)' → \(expected) | \(actual)")
    if actual == expected { userTestsPassed += 1 }
}

print("\n📋 完整场景测试:")
print("输入文本 → 预期分类 | 实际识别 | 结果")  
print(String(repeating: "-", count: 60))

var totalTests = 0
var passedTests = 0

for (testCase, expected) in testCases {
    let result = parseTransaction(from: testCase)
    let actual = result.category ?? "其他"
    let status = actual == expected ? "✅ 正确" : "❌ 错误"
    print("\(status) '\(testCase)' → \(expected) | \(actual)")
    
    totalTests += 1
    if actual == expected { passedTests += 1 }
}

print("\n" + String(repeating: "=", count: 60))
print("📊 测试统计:")
print("用户场景通过率: \(userTestsPassed)/\(userScenarios.count) (\(Int(Double(userTestsPassed)/Double(userScenarios.count)*100))%)")
print("总体测试通过率: \(passedTests)/\(totalTests) (\(Int(Double(passedTests)/Double(totalTests)*100))%)")

print("\n✅ 关键改进:")
print("• ✅ 共享单车包月 - 正确识别为交通")
print("• ✅ 地铁充卡 - 正确识别为交通") 
print("• ✅ 各类充值场景 - 智能区分交通vs非交通")
print("• ✅ 购买vs使用 - 避免买单车误分类为交通")
print("• ✅ 新增60+交通相关关键词")

print("\n🎊 交通费用识别优化完成！")