# 贡献指南

感谢您对VoiceBudget项目的关注！我们欢迎所有形式的贡献，包括但不限于代码、文档、bug报告和功能建议。

## 🤝 如何贡献

### 报告Bug
1. 在[Issues](https://github.com/wingogx/bookkeeping/issues)中搜索是否已有相似问题
2. 如果没有，创建新的issue并使用bug报告模板
3. 提供详细的复现步骤、环境信息和截图

### 功能建议
1. 在[Discussions](https://github.com/wingogx/bookkeeping/discussions)中讨论您的想法
2. 如果获得积极反馈，创建功能请求issue
3. 详细描述使用场景和预期效果

### 代码贡献
1. Fork本仓库到您的GitHub账户
2. 创建新的分支 (`git checkout -b feature/your-feature-name`)
3. 进行开发并遵循代码规范
4. 提交变更 (`git commit -m 'Add some feature'`)
5. 推送到您的分支 (`git push origin feature/your-feature-name`)
6. 创建Pull Request

## 📝 代码规范

### Swift代码风格
- 遵循[Swift API设计指南](https://swift.org/documentation/api-design-guidelines/)
- 使用4个空格缩进，不使用制表符
- 每行最大120个字符
- 使用驼峰命名法

### 单文件架构约束
- 所有核心代码集中在`VoiceBudgetApp.swift`
- 使用`// MARK:`注释分隔不同模块
- 按照数据模型→管理器→视图的顺序组织代码
- 避免创建新文件，除非绝对必要

### 代码组织
```swift
// MARK: - Data Models
// 数据模型定义

// MARK: - Data Manager
// 数据管理器

// MARK: - Voice Recognition Manager
// 语音识别管理器

// MARK: - Views
// 用户界面视图
```

### 注释规范
- 为复杂逻辑添加详细注释
- 使用中文注释说明业务逻辑
- 为公开方法添加文档注释

```swift
/// 解析语音输入的文本并提取交易信息
/// - Parameter text: 语音识别的文本
/// - Returns: 解析后的交易信息元组
func parseTransaction(from text: String) -> (amount: Double?, category: String?, note: String?, date: Date?, isExpense: Bool) {
    // 实现逻辑...
}
```

## 🧪 测试指南

### 开发测试
1. 在Xcode中运行项目 (`⌘ + R`)
2. 在iOS模拟器和真机上测试
3. 重点测试语音识别功能
4. 验证数据持久化正常

### PR测试要求
- [ ] 代码能够成功编译
- [ ] 核心功能正常工作
- [ ] 语音识别准确性测试
- [ ] UI/UX体验测试
- [ ] 数据导入导出测试

## 🔄 开发流程

### 分支策略
- `main`: 主分支，包含稳定版本
- `develop`: 开发分支，用于集成新功能
- `feature/*`: 功能分支，用于开发新功能
- `hotfix/*`: 热修复分支，用于紧急修复

### 提交信息规范
使用[约定式提交](https://www.conventionalcommits.org/zh-hans/)格式：

```
<类型>[可选的作用域]: <描述>

[可选的正文]

[可选的脚注]
```

类型：
- `feat`: 新功能
- `fix`: Bug修复
- `docs`: 文档更新
- `style`: 代码风格调整
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建过程或辅助工具的变动

示例：
```
feat(voice): 添加¥符号金额识别支持

- 支持¥和￥符号格式
- 提高金额识别准确率至98%
- 优化备注清理逻辑

Closes #123
```

## 📋 Pull Request检查清单

提交PR前请确保：

### 代码质量
- [ ] 代码遵循项目编码规范
- [ ] 没有引入新的编译警告或错误
- [ ] 添加了必要的注释和文档
- [ ] 代码已经过自测试

### 功能完整性
- [ ] 新功能按预期工作
- [ ] 不破坏现有功能
- [ ] 处理了边界条件和错误情况
- [ ] 用户体验友好

### 架构一致性
- [ ] 遵循单文件架构约束
- [ ] 使用合适的MARK注释分隔
- [ ] 数据模型支持Codable协议
- [ ] 保持iOS 14.0+兼容性

### 文档更新
- [ ] 更新了相关文档（如果需要）
- [ ] README.md中的信息仍然准确
- [ ] 添加了必要的代码注释

## 🎯 开发环境设置

### 必需工具
- macOS 11.0+
- Xcode 12.0+
- iOS 14.0+ SDK

### 推荐工具
- [SwiftLint](https://github.com/realm/SwiftLint): 代码风格检查
- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat): 代码格式化
- Git hooks: 自动代码检查

### 项目设置
1. 克隆仓库：`git clone https://github.com/wingogx/bookkeeping.git`
2. 打开项目：`open VoiceBudget.xcodeproj`
3. 确保目标设备为iOS 14.0+
4. 配置开发者证书（真机测试需要）

## 🚀 发布流程

### 版本号规范
使用[语义化版本](https://semver.org/lang/zh-CN/)：
- `主版本号.次版本号.修订号` (例如: 1.0.8)
- 主版本号：不兼容的API修改
- 次版本号：向下兼容的功能性新增
- 修订号：向下兼容的问题修正

### 发布检查清单
- [ ] 所有测试通过
- [ ] 更新版本号（Info.plist和代码中）
- [ ] 更新CHANGELOG.md
- [ ] 创建发布标签
- [ ] 推送到GitHub
- [ ] 创建GitHub Release

## 💬 社区

### 交流渠道
- [GitHub Issues](https://github.com/wingogx/bookkeeping/issues): Bug报告和功能请求
- [GitHub Discussions](https://github.com/wingogx/bookkeeping/discussions): 社区讨论
- [Email](mailto:wingogx@example.com): 直接联系维护者

### 行为准则
我们致力于为所有人提供一个友好、安全和受欢迎的环境，无论：
- 性别、性取向、性别认同和表达
- 年龄、残疾、外貌、身材
- 种族、民族、宗教、国籍
- 经验水平、教育背景、社会经济地位

请保持：
- 使用友好和包容的语言
- 尊重不同的观点和经历
- 优雅地接受建设性批评
- 专注于对社区最有利的事情
- 对其他社区成员表示同理心

## 📄 许可证

通过贡献代码，您同意您的贡献将在[MIT许可证](LICENSE)下获得许可。

## 🙏 致谢

感谢所有为VoiceBudget项目做出贡献的开发者和用户！您的支持使这个项目变得更好。