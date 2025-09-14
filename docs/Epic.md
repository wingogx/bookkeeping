# 自动化开发队列 (Automated Development Queue)

## 📌 Epic
**将VoiceBudget从v1.0.5升级到v1.0.6，通过在现有单文件架构基础上增加触觉反馈、成就系统、数据导出、新用户引导和推送通知等功能，提升用户体验和留存率。**

---

## 📋 User Stories (原子任务队列)

### Phase 1: 数据模型基础 (Foundation)

#### 🔷 S-01: 添加v1.0.6新数据模型
**标题**: 在现有数据模型后添加Achievement、UserStats等新模型

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: 第42行后（Budget结构体之后）
- 创建结构体:
  - `Achievement: Identifiable, Codable`
  - `UserStats: Codable`
  - `AppSettings: Codable`
  - `MotivationMessages` (静态常量)
  - `ExportData` (含嵌套枚举)

**验收标准**:
```swift
assert(Achievement.defaultAchievements.count == 8)
assert(UserStats().currentStreak == 0)
assert(AppSettings().hapticFeedbackEnabled == true)
assert(MotivationMessages.recordSuccess.count >= 5)
```

---

### Phase 2: 核心管理器扩展 (Core Extensions)

#### 🔷 S-02: 扩展DataManager属性
**标题**: 在DataManager中添加v1.0.6所需的新属性

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: DataManager类内部（约第49行后）
- 添加属性:
  - `@Published var achievements: [Achievement]`
  - `@Published var userStats: UserStats`
  - `@Published var appSettings: AppSettings`
  - 存储键常量: `achievementsKey`, `userStatsKey`, `appSettingsKey`

**验收标准**:
```swift
assert(dataManager.achievements.count > 0)
assert(dataManager.userStats != nil)
assert(dataManager.appSettings.notificationEnabled == false) // 默认值
```

#### 🔷 S-03: 实现成就系统核心逻辑
**标题**: 在DataManager中添加成就检查和解锁方法

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: DataManager类内部（第160行左右）
- 添加方法:
  - `func checkAndUnlockAchievements()`
  - `func unlockAchievement(id: String)`
  - `func checkStreakAchievements()`

**验收标准**:
```swift
// 首次记账后
dataManager.addTransaction(testTransaction)
dataManager.checkAndUnlockAchievements()
assert(dataManager.achievements.first(where: { $0.id == "first_record" })?.isUnlocked == true)
```

#### 🔷 S-04: 实现连击系统
**标题**: 添加连击追踪和更新逻辑

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: DataManager类内部
- 添加方法:
  - `func updateStreak()`
  - `func isStreakBroken() -> Bool`
- 修改: `addTransaction()`方法，添加`updateStreak()`调用

**验收标准**:
```swift
// 连续两天记账
dataManager.updateStreak()
assert(dataManager.userStats.currentStreak > 0)
assert(dataManager.userStats.lastRecordDate != nil)
```

#### 🔷 S-05: 实现数据导出功能
**标题**: 添加CSV导出方法

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: DataManager类内部
- 添加方法:
  - `func exportToCSV(dateRange: ExportData.DateRange) -> String`
  - `func filterTransactions(by dateRange: ExportData.DateRange) -> [Transaction]`

**验收标准**:
```swift
let csvData = dataManager.exportToCSV(dateRange: .all)
assert(csvData.contains("日期,分类,金额,备注,类型"))
assert(csvData.split(separator: "\n").count > 1)
```

---

### Phase 3: 系统服务 (System Services)

#### 🔷 S-06: 创建NotificationManager
**标题**: 实现推送通知管理器

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: HapticManager类之后（约第231行后）
- 创建类: `NotificationManager`
- 实现方法:
  - `func requestAuthorization()`
  - `func scheduleReminders()`
  - `func sendBudgetAlert(percentage: Double)`

**验收标准**:
```swift
let notificationManager = NotificationManager()
notificationManager.requestAuthorization() { granted in
    assert(granted || !granted) // 权限请求已发出
}
```

#### 🔷 S-07: 扩展触觉反馈使用
**标题**: 在现有交互点集成HapticManager

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 修改位置:
  - HomeView: `addTransaction()`后添加`HapticManager.shared.success()`
  - BudgetView: 预算超支时添加`HapticManager.shared.warning()`
  - 成就解锁时: 添加`HapticManager.shared.success()`

**验收标准**:
```swift
// 手动测试：记账成功后应有触觉反馈
// 预算超过80%时应有警告反馈
```

---

### Phase 4: UI组件增强 (UI Enhancements)

#### 🔷 S-08: 添加鼓励文案显示
**标题**: 在HomeView中集成鼓励消息

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: HomeView的TodaySummary下方（约第540行）
- 添加:
  - 随机文案显示Text组件
  - 使用`.font(.caption)`和`.foregroundColor(.secondary)`

**验收标准**:
```swift
// UI测试：HomeView应显示鼓励文案
// 文案应从MotivationMessages.recordSuccess随机选择
```

#### 🔷 S-09: 添加预算情绪表达
**标题**: 在BudgetView中添加情绪符号

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: BudgetView（约第950行）
- 添加:
  - 计算属性`var budgetEmoji: String`
  - 在预算显示区域添加emoji显示

**验收标准**:
```swift
// 预算使用<30%时显示😊
// 预算使用>90%时显示🤯
```

#### 🔷 S-10: 创建成就展示视图
**标题**: 添加AchievementView和成就卡片组件

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: 文件末尾（第1550行后）
- 创建:
  - `struct AchievementView: View`
  - `struct AchievementCard: View`
- 样式: 复用现有卡片样式（`.background(Color.gray.opacity(0.1))`）

**验收标准**:
```swift
// AchievementView应显示8个成就
// 已解锁成就应有不同视觉状态
```

#### 🔷 S-11: 添加连击显示器
**标题**: 在HomeView导航栏显示连击数

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: HomeView的NavigationView
- 添加:
  - `.navigationBarItems(trailing: StreakIndicator())`
  - 创建`struct StreakIndicator: View`

**验收标准**:
```swift
// 导航栏右侧应显示当前连击数
// 格式："🔥 3天"
```

---

### Phase 5: 设置页面扩展 (Settings Extensions)

#### 🔷 S-12: 添加数据导出界面
**标题**: 在SettingsView中添加导出功能

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: SettingsView（约第1320行）
- 添加:
  - 新Section："数据导出"
  - 导出按钮和日期范围选择
  - ShareSheet调用

**验收标准**:
```swift
// 点击导出按钮应生成CSV
// 应弹出系统分享Sheet
```

#### 🔷 S-13: 添加通知设置
**标题**: 在SettingsView中添加通知管理

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: SettingsView现有设置下方
- 添加:
  - 通知开关Toggle
  - 提醒时间选择器
  - 预算警告开关

**验收标准**:
```swift
// Toggle应绑定到appSettings.notificationEnabled
// 更改设置应触发scheduleReminders()
```

#### 🔷 S-14: 添加成就入口
**标题**: 在SettingsView中添加成就查看入口

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: SettingsView
- 添加:
  - NavigationLink到AchievementView
  - 显示已解锁成就数量

**验收标准**:
```swift
// 应显示"成就 (3/8)"格式
// 点击应导航到AchievementView
```

---

### Phase 6: 新用户体验 (New User Experience)

#### 🔷 S-15: 创建引导页面
**标题**: 实现OnboardingView三屏引导

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: 文件末尾
- 创建:
  - `struct OnboardingView: View`
  - 使用TabView + PageTabViewStyle
  - 三屏内容："3秒记账"、"让记账有趣"、"掌握财务"

**验收标准**:
```swift
// OnboardingView应有3个页面
// 应有跳过和完成按钮
// 完成后设置hasCompletedOnboarding = true
```

#### 🔷 S-16: 集成引导流程
**标题**: 在ContentView中集成首次使用引导

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: ContentView
- 添加:
  - `@State private var showOnboarding`
  - `.fullScreenCover(isPresented: $showOnboarding)`
  - 判断逻辑：检查`appSettings.hasCompletedOnboarding`

**验收标准**:
```swift
// 首次启动应显示OnboardingView
// 完成引导后不再显示
```

#### 🔷 S-17: 实现成就解锁动画
**标题**: 添加成就解锁提示

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: HomeView
- 添加:
  - `@State private var unlockedAchievement: Achievement?`
  - `.alert()`显示解锁成就
  - 动画效果

**验收标准**:
```swift
// 解锁成就时应显示Alert
// Alert应包含成就标题和描述
```

---

### Phase 7: 数据持久化升级 (Data Persistence)

#### 🔷 S-18: 扩展数据加载和保存
**标题**: 更新DataManager的loadData和saveData方法

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: DataManager的`saveData()`和`loadData()`方法
- 修改:
  - 添加achievements、userStats、appSettings的保存
  - 添加相应的加载逻辑

**验收标准**:
```swift
// 重启应用后
assert(dataManager.achievements.count == previousAchievements.count)
assert(dataManager.userStats.currentStreak == previousStreak)
```

---

### Phase 8: 集成测试与优化 (Integration & Polish)

#### 🔷 S-19: 添加版本迁移逻辑
**标题**: 实现v1.0.5到v1.0.6的平滑升级

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: DataManager的`init()`方法
- 添加:
  - 版本检查
  - 初始化新数据结构
  - 设置默认值

**验收标准**:
```swift
// 从v1.0.5升级后
assert(dataManager.achievements != nil)
assert(dataManager.userStats != nil)
assert(所有现有交易数据保留)
```

#### 🔷 S-20: 更新版本信息
**标题**: 更新应用版本号和设置页面显示

**技术规格**:
- 文件: `VoiceBudgetApp.swift`
- 位置: SettingsView（约第1334行）
- 修改:
  - 版本号从"1.0.5"改为"1.0.6"
  - 副标题从"MVP版本"改为"功能完整版"

**验收标准**:
```swift
// 设置页面应显示"1.0.6"
// 应显示"功能完整版"
```

---

## 📊 执行统计

- **总任务数**: 20个原子任务
- **预计代码增量**: ~1000行
- **影响文件数**: 1个（VoiceBudgetApp.swift）
- **新增组件**: 10个
- **修改组件**: 8个

## ⚡ 执行顺序说明

1. **Phase 1-2**: 数据基础（S-01到S-05）- 必须先建立数据模型
2. **Phase 3**: 系统服务（S-06到S-07）- 依赖数据模型
3. **Phase 4**: UI增强（S-08到S-11）- 依赖数据和服务
4. **Phase 5**: 设置扩展（S-12到S-14）- 依赖前面所有
5. **Phase 6**: 新用户体验（S-15到S-17）- 可并行但建议顺序
6. **Phase 7**: 数据持久化（S-18）- 必须在所有数据模型完成后
7. **Phase 8**: 集成优化（S-19到S-20）- 最后执行

## ✅ 完成标准

所有20个Story完成后：
1. 应用版本显示为v1.0.6
2. 8个默认成就可正常解锁
3. 连击系统正确计算
4. 数据可导出为CSV
5. 新用户看到引导页面
6. 触觉反馈在各交互点工作
7. 所有数据正确持久化

---

**文档生成时间**: 2025-01-14
**文档类型**: 自动化开发队列
**执行模式**: 严格顺序执行
**状态**: 待执行