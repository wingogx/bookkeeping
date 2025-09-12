#!/usr/bin/env swift

import Foundation

// 当前的交通关键词识别逻辑测试
func parseTransportCategory(from text: String) -> String? {
    let currentTransportKeywords = [
        "地铁", "公交", "打车", "滴滴", "出租车", "火车", "高铁", 
        "飞机", "机票", "车票", "加油", "停车", "过路费", "ETC"
    ]
    
    for keyword in currentTransportKeywords {
        if text.contains(keyword) {
            return "交通-当前识别"
        }
    }
    return nil
}

// 增强的交通关键词识别逻辑
func parseEnhancedTransportCategory(from text: String) -> String? {
    let enhancedTransportKeywords = [
        // 传统交通工具
        "地铁", "公交", "打车", "滴滴", "出租车", "火车", "高铁", "飞机",
        
        // 共享出行
        "共享单车", "单车", "摩拜", "哈啰", "青桔", "小蓝车", "ofo",
        "共享汽车", "GoFun", "EVCARD", "盼达", "car2go",
        
        // 交通充值场景
        "充卡", "充值", "充交通卡", "公交卡", "地铁卡", "一卡通", "羊城通", "深圳通",
        "包月", "月卡", "季卡", "年卡", "套餐",
        
        // 网约车平台
        "美团打车", "曹操出行", "神州专车", "首汽约车", "T3出行",
        
        // 票务相关
        "机票", "车票", "船票", "地铁票", "公交票", "高铁票", "动车票",
        
        // 汽车相关
        "加油", "油费", "停车", "停车费", "过路费", "高速费", "ETC", "洗车",
        "保养", "维修", "年检", "保险",
        
        // 其他出行
        "打车费", "车费", "路费", "交通费", "出行费", "通勤", "班车"
    ]
    
    for keyword in enhancedTransportKeywords {
        if text.contains(keyword) {
            return "交通-增强识别"
        }
    }
    return nil
}

print("🚗 交通费用识别测试")
print(String(repeating: "=", count: 60))

// 测试用例 - 包含用户提到的场景
let testCases = [
    // 用户提到的场景
    "共享单车包月99元",
    "地铁充卡100元", 
    "做地铁充值50元",
    
    // 其他复合交通场景
    "摩拜单车月卡30元",
    "哈啰单车充值100元",
    "公交卡充值50元",
    "一卡通充100块",
    "滴滴充值200元",
    "美团打车50元",
    "GoFun共享汽车租车费80元",
    "ETC充值500元",
    "停车费20元",
    "加油费300元",
    "高铁票180元",
    "机票1200元",
    
    // 边界情况
    "买单车2000元",  // 购买单车 vs 租用单车
    "充手机话费50元",  // 非交通充值
    "包月健身卡200元"   // 非交通包月
]

print("\n📋 识别对比测试:")
print("输入文本 → 当前识别 | 增强识别")
print(String(repeating: "-", count: 60))

for testCase in testCases {
    let current = parseTransportCategory(from: testCase) ?? "未识别"
    let enhanced = parseEnhancedTransportCategory(from: testCase) ?? "未识别"
    let status = enhanced.contains("增强") ? "✅ 改进" : (current.contains("当前") ? "✅ 保持" : "❌ 遗漏")
    print("\(status) '\(testCase)' → \(current) | \(enhanced)")
}

print("\n🎯 关键改进点:")
print("• 共享出行: 摩拜、哈啰、青桔、ofo、GoFun等")
print("• 充值场景: 充卡、充值、一卡通、包月、月卡等")  
print("• 网约车: 美团打车、曹操出行、神州专车等")
print("• 汽车服务: 保养、维修、年检、洗车等")
print("• 复合词汇: 共享单车包月、地铁充卡等")

print("\n" + String(repeating: "=", count: 60))
print("测试完成 - 交通识别优化方案")