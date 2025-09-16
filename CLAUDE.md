# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

VoiceBudget是一个iOS原生语音记账应用，采用SwiftUI + MVVM架构的单文件设计。当前版本v1.0.8试用版功能完整，支持iOS 14.0+，专注于快速记账、预算管理和用户习惯养成。语音识别系统已优化，支持多种金额格式包括¥符号，提供完整的记账体验。

## 开发命令

### 构建和运行
- **构建项目**: 在Xcode中按`⌘ + B`或使用`Product → Build`
- **运行应用**: 在Xcode中按`⌘ + R`或使用`Product → Run`
- **清理构建**: `Product → Clean Build Folder` (⇧⌘K)

### 测试
- **Xcode测试**: 在Xcode中运行项目进行完整功能测试
- **真机测试**: 建议在真实iOS设备上测试语音识别功能以获得最佳效果
- **功能验证**: 重点测试语音记账、预算管理、成就系统、数据导出等核心功能

### 项目维护
```bash
# 打开Xcode项目
open VoiceBudget.xcodeproj

# 查看项目结构
find VoiceBudget -name "*.swift"

# 检查代码行数和复杂度
wc -l VoiceBudget/App/VoiceBudgetApp.swift

# 验证编译状态（需要完整Xcode）
# xcodebuild -scheme VoiceBudget build
```

### 版本控制
项目使用Git进行版本控制，包含`.gitignore`文件排除临时文件：
- Xcode构建文件和用户数据
- 临时文件和测试脚本
- 系统文件(.DS_Store)
- 开发过程文档

## 核心架构

### 单文件架构设计
整个应用的核心代码集中在`VoiceBudget/App/VoiceBudgetApp.swift`(4570+行)，采用模块化组织：

```
VoiceBudgetApp.swift
├── 应用入口点 (Lines 8-17)
│   └── VoiceBudgetApp: 主应用结构
├── 数据模型层 (Lines 19-200)
│   ├── Transaction: 交易记录数据模型
│   ├── Achievement: 成就系统数据模型
│   ├── UserStats: 用户统计数据模型
│   ├── AppSettings: 应用设置数据模型
│   ├── Budget: 预算管理数据模型
│   ├── CustomBudget: 自定义预算模型
│   └── ExportData: 数据导出模型
├── 数据管理层 (Lines 202-1746)
│   ├── DataManager: 核心数据管理器(单例模式)
│   │   ├── 日期工具方法 (Lines 245-315)
│   │   ├── 数据查询方法 (Lines 317-505)
│   │   ├── 成就管理 (Lines 506-597)
│   │   ├── 自定义预算管理 (Lines 598-689)
│   │   ├── 数据导出功能 (Lines 690-796)
│   │   └── 预算警告系统 (Lines 797-845)
│   ├── VoiceRecognitionManager: 语音识别管理器 (Lines 846-1746)
│   └── NotificationManager: 推送通知管理器 (Lines 1747-1963)
└── 用户界面层 (Lines 1964-4572)
    ├── OnboardingView: 新用户引导视图
    ├── ContentView: 主容器视图
    ├── HomeView: 首页视图
    ├── AddTransactionView: 添加交易视图
    ├── RecordsView: 记录列表视图
    ├── BudgetView: 预算管理视图
    ├── AnalyticsView: 统计分析视图
    ├── SettingsView: 设置页面视图
    ├── AchievementView: 成就展示视图
    └── ExportDataView: 数据导出视图
```

### 数据流架构
- **数据存储**: 使用UserDefaults进行本地持久化，支持Codable协议
- **状态管理**: 基于SwiftUI的@ObservableObject和@Published实现响应式更新
- **数据单例**: DataManager.shared作为全局数据管理中心
- **环境注入**: 通过.environmentObject(DataManager.shared)向子视图传递数据

### 关键设计模式
1. **MVVM架构**: View层绑定ViewModel(DataManager)，实现数据和UI分离
2. **单例模式**: DataManager采用单例确保数据一致性
3. **观察者模式**: 使用@Published属性实现数据变化自动通知UI更新
4. **策略模式**: 语音识别通过关键词匹配策略自动分类交易

### 单文件架构特点
- **优势**: 简化依赖管理、便于快速开发和维护、减少文件切换开销
- **组织方式**: 通过MARK注释分隔不同模块，按数据模型→管理器→视图的顺序组织
- **扩展策略**: 新功能优先在现有文件中扩展，避免过度拆分影响开发效率

## 核心功能模块

### 语音记账系统
- **语音识别**: 基于Speech Framework，支持150+关键词智能分类
- **关键组件**: `VoiceRecognitionManager`负责语音到文本转换和分类匹配
- **智能解析**: 支持多种金额格式如"吃饭30元"、"昨天打车15块"、"今日早餐¥7"
- **金额识别**: 支持¥符号、元、块、钱等多种货币表示法
- **多事务支持**: 支持"各"字语法，如"中午和晚上吃饭各花了10块"自动拆分为2条记录
- **时间解析**: 自动识别"昨天"、"今天"、"9月10号"等时间标记并设置相应日期
- **备注清理**: 自动清理"月日**"等语音识别残留字符，生成简洁备注

### 成就和连击系统
- **成就类型**: 8种预定义成就(首次记账、连击天数、预算控制等)
- **连击追踪**: 自动计算当前连击和最长连击，支持连击中断检测
- **解锁动画**: 成就解锁时触发动画和触觉反馈

### 预算管理系统
- **分类预算**: 支持8个默认分类的独立预算设置
- **自动汇总**: 分类预算自动汇总为月度总预算
- **三级预警**: 70%黄色提醒、90%橙色警告、100%红色超支
- **自定义预算**: 支持创建临时预算，设置自定义时间范围和预算限制
- **预算统计**: 实时显示预算使用进度、剩余天数和支出趋势

## API兼容性注意事项

### SwiftUI版本兼容
- **最低支持**: iOS 14.0 (实际项目设置为iOS 15.0)
- **关键API**: 使用`.toolbar`替代已弃用的`.navigationBarItems`
- **动画API**: 使用`.animation(_:value:)`替代已弃用的`.animation(_:)`

### 权限要求
- **麦克风权限**: 语音识别功能必需
- **推送权限**: 预算提醒和定时通知
- **无网络依赖**: 语音识别使用设备本地Speech Framework

## 测试策略

### 测试验证要点
功能测试重点覆盖：
- **数据模型**: Achievement, UserStats, AppSettings等核心数据结构
- **语音解析**: 语音识别、关键词匹配、分类自动化
- **成就系统**: 连击追踪、成就解锁逻辑验证
- **数据导出**: CSV导出、数据筛选功能
- **UI交互**: 界面响应、数据同步、用户体验

### 人工测试重点
1. **语音识别准确性**: 真实设备测试中文语音识别
2. **触觉反馈效果**: 记账成功、成就解锁的震动反馈
3. **数据持久化**: 应用重启后数据保持完整
4. **边界条件**: 大金额输入、特殊字符处理、网络异常

## 数据结构要点

### 核心数据模型关系
```swift
DataManager (单例)
├── transactions: [Transaction] // 所有交易记录
├── budget: Budget // 预算配置
├── categories: [String] // 分类列表
├── achievements: [Achievement] // 成就列表
├── userStats: UserStats // 用户统计
└── appSettings: AppSettings // 应用设置
```

### 数据持久化键值
- `transactions`: 交易记录数组
- `budget`: 预算配置对象
- `categories`: 分类字符串数组
- `achievements`: 成就数组
- `userStats`: 用户统计对象
- `appSettings`: 应用设置对象

## 语音识别关键词映射

项目内置150+关键词智能分类系统，主要分类：
- **餐饮类**: 早餐、午餐、晚餐、外卖、咖啡等
- **交通类**: 打车、地铁、公交、加油、停车等
- **购物类**: 淘宝、京东、买衣服、化妆品等
- **生活类**: 买菜、超市、水电、房租等

### 金额格式支持
语音识别系统支持多种金额表示格式：
- **¥符号格式**: "¥7"、"￥100"
- **货币单位**: "30元"、"15块"、"20钱"
- **纯数字**: "2500"（两位以上数字）

修改分类逻辑需要更新`parseTransaction`和`parseMultipleTransactions`方法中的关键词数组和金额解析模式。

## 常见问题解决

### 编译错误
- **Unicode转义**: 避免使用`\uXXXX`格式，直接使用中文字符
- **API兼容**: 确保使用iOS 14+兼容的SwiftUI API
- **权限声明**: Info.plist需包含NSMicrophoneUsageDescription

### 运行时问题
- **语音识别失败**: 检查设备麦克风权限和网络连接
- **金额无法识别**: 确保金额格式匹配支持的模式（¥符号、元、块、钱、纯数字）
- **数据丢失**: DataManager的saveData()调用时机和UserDefaults键值
- **UI响应异常**: 确保数据更新在主线程执行
- **备注显示异常**: 检查语音识别结果清理逻辑，确保移除无意义字符

## 开发注意事项

### 代码修改指南
- **单文件约束**: 所有核心逻辑集中在`VoiceBudgetApp.swift`，避免创建新文件
- **MARK分区**: 新功能需要添加适当的`// MARK:`注释保持代码组织清晰
- **数据模型**: 新增数据模型需要实现`Codable`协议支持UserDefaults持久化
- **UI组件**: 新视图组件直接在现有文件中定义，遵循SwiftUI + MVVM模式
- **错误处理**: 使用详细的错误处理和备份机制，确保数据完整性
- **性能优化**: 使用选择性数据保存(`saveSpecificData`)提高性能

### 代码质量最佳实践
- **数据一致性**: 关键操作使用原子性更新，失败时自动回滚
- **日期计算**: 使用统一的日期工具方法(`isSameDay`, `isCurrentMonth`, `daysBetween`)避免重复代码
- **访问控制**: 合理使用`private`和`internal`访问级别控制方法可见性
- **编译清洁**: 避免未使用的变量和不可达的代码块

### 常见开发任务
- **添加新分类**: 更新DataManager的默认分类数组和语音识别关键词映射
- **修改成就系统**: 在Achievement.defaultAchievements中添加新成就类型
- **扩展语音识别**: 在parseTransaction和parseMultipleTransactions方法中添加新的关键词匹配规则
- **金额格式支持**: 修改amountPatterns数组添加新的金额识别模式
- **备注清理优化**: 在unwantedWords数组中添加需要清理的字符或词汇
- **数据导出格式**: 在ExportData模型中添加新的导出格式支持
- **自定义预算**: 在CustomBudget模型中扩展预算类型和计算逻辑

### 语音识别调试
当语音识别出现问题时，检查以下关键点：
1. **权限检查**: 确保麦克风和语音识别权限已授权
2. **日志分析**: 查看控制台输出的"🔍 识别到文本"和"💰 智能提取金额"日志
3. **模式匹配**: 验证金额格式是否在amountPatterns数组中
4. **分类匹配**: 检查关键词是否在priorityCategories中定义
5. **多事务解析**: 确认parseMultipleTransactions逻辑正确处理单笔和多笔交易

## 项目文档参考

- `docs/PRD.md`: 完整产品需求文档和功能规格说明