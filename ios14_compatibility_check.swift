#!/usr/bin/env swift

import Foundation

// iOS 14兼容性检查工具
struct iOS14CompatibilityChecker {
    
    // iOS 15+ API列表（需要避免使用的）
    static let iOS15APIs = [
        // SwiftUI
        ".listRowSeparator(",
        "Color.brown",
        "Color.cyan", 
        ".foregroundColor(.tertiary)",
        "Section(",  // 无header的Section
        "#Preview",
        ".refreshable",
        ".searchable",
        ".swipeActions",
        ".task(",
        ".badge(",
        ".symbolRenderingMode(",
        ".symbolVariant(",
        "@FocusState",
        ".focused(",
        ".submitLabel(",
        ".listRowSeparatorTint(",
        ".listSectionSeparator(",
        
        // 颜色
        ".mint",
        ".indigo",
        ".teal",
        ".cyan",
        ".brown",
        
        // 其他
        ".confirmationDialog(",
        ".interactiveDismissDisabled(",
        ".presentationDetents(",
        ".presentationDragIndicator("
    ]
    
    static func checkFile(_ filePath: String) -> [String] {
        var issues: [String] = []
        
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return ["无法读取文件: \(filePath)"]
        }
        
        let lines = content.components(separatedBy: .newlines)
        
        for (lineNumber, line) in lines.enumerated() {
            for api in iOS15APIs {
                if line.contains(api) {
                    // 特殊检查Section
                    if api == "Section(" {
                        // 检查是否是无header的Section
                        if line.contains("Section {") || (line.contains("Section(") && !line.contains("header:")) {
                            issues.append("第\(lineNumber + 1)行: 使用了iOS 15+ Section语法 - '\(line.trimmingCharacters(in: .whitespaces))'")
                        }
                    } else {
                        issues.append("第\(lineNumber + 1)行: 使用了iOS 15+ API '\(api)' - '\(line.trimmingCharacters(in: .whitespaces))'")
                    }
                }
            }
        }
        
        return issues
    }
}

print("📱 iOS 14 兼容性检查工具")
print(String(repeating: "=", count: 50))

let appFilePath = "/Users/win/Documents/ai 编程/cc/语音记账本/VoiceBudget/App/VoiceBudgetApp.swift"

print("\n🔍 检查文件: VoiceBudgetApp.swift")
print(String(repeating: "-", count: 50))

let issues = iOS14CompatibilityChecker.checkFile(appFilePath)

if issues.isEmpty {
    print("✅ 恭喜！未发现iOS 15+ API使用")
    print("✅ 代码完全兼容iOS 14.0+")
} else {
    print("⚠️  发现 \(issues.count) 个兼容性问题:")
    print()
    for issue in issues {
        print("❌ \(issue)")
    }
}

print("\n" + String(repeating: "=", count: 50))

// 推荐的iOS 14兼容替代方案
print("\n📋 iOS 14兼容替代方案:")
print()
print("iOS 15+ API          →  iOS 14 兼容方案")
print(String(repeating: "-", count: 50))
print("Section { }          →  Section(header: Text(\"\")) { }")
print("Color.brown          →  Color(red: 0.6, green: 0.4, blue: 0.2)")
print("Color.cyan           →  Color(red: 0.0, green: 0.7, blue: 1.0)")
print(".foregroundColor(.tertiary) → .foregroundColor(.secondary)")
print(".listRowSeparator()  →  移除或使用自定义分隔线")
print(".refreshable         →  移除或使用自定义下拉刷新")
print("#Preview             →  PreviewProvider协议")

print("\n✅ 修复建议:")
print("• 使用Color(red:green:blue:)替代iOS 15+颜色")
print("• Section必须有header参数，可以是空Text")  
print("• 避免使用tertiary颜色，改用secondary")
print("• 移除listRowSeparator等iOS 15+修饰符")

print("\n🎯 兼容性测试通过后，应用将支持:")
print("• iOS 14.0+")  
print("• iPhone 6s及更新机型")
print("• iPad (第6代)及更新机型")

print("\n" + String(repeating: "=", count: 50))
print("检查完成!")