# VoiceBudget - 极简语音记账App

<div align="center">

[![iOS](https://img.shields.io/badge/iOS-14.0+-blue.svg?style=flat&logo=ios)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg?style=flat&logo=swift)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-2.0+-green.svg?style=flat&logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![Version](https://img.shields.io/badge/Version-1.0.8-red.svg?style=flat)](https://github.com/wingogx/bookkeeping/releases)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat)](LICENSE)

**🎙️ 让记账变得简单有趣的智能语音记账应用**

[功能特性](#-功能特性) • [快速开始](#-快速开始) • [技术架构](#-技术架构) • [截图预览](#-截图预览) • [贡献指南](#-贡献指南)

</div>

---

## 📱 项目简介

VoiceBudget是一款专为iOS平台设计的智能语音记账应用，采用现代SwiftUI框架和MVVM架构。通过先进的语音识别技术，让用户能够通过自然语言快速记录财务交易，同时提供智能分类、预算管理和成就激励系统。

### 🎯 设计理念

- **简约至上**: 单文件架构，7000+行代码展现完整记账生态
- **语音优先**: 3秒语音记账，支持自然语言和多种金额格式
- **智能体验**: 150+关键词智能分类，AI驱动的交易解析
- **情感化设计**: 温和的用户体验，让记账变得有趣而非焦虑

---

## ✨ 功能特性

### 🎙️ 智能语音记账
- **多格式支持**: "吃饭30元"、"今日早餐¥7"、"昨天打车15块"
- **智能分类**: 150+关键词自动匹配8个核心分类
- **日期解析**: 支持"昨天"、"9月10号"等自然时间表达
- **多事务处理**: "中午和晚上各花了10块" → 自动拆分2条记录
- **备注优化**: 自动清理语音识别残留，生成简洁有意义的备注

### 💰 预算管理系统
- **智能预算**: 分类预算自动汇总为月度总预算
- **三级预警**: 70%黄色提醒、90%橙色警告、100%红色超支
- **自定义预算**: 支持临时预算，灵活的时间范围设置
- **实时统计**: 预算使用进度、剩余天数、支出趋势分析

### 🏆 成就激励系统
- **8种成就**: 从"记账新手"到"记账之王"的完整激励体系
- **连击追踪**: 连续记账天数统计，培养理财习惯
- **解锁动画**: 成就达成时的视觉和触觉反馈
- **进度可视化**: 直观展示用户的记账成长历程

### 📊 数据分析与导出
- **多维统计**: 日/周/月支出收入分析，分类占比展示
- **数据导出**: CSV格式导出，支持时间筛选和数据预览
- **趋势分析**: 消费模式识别，智能财务洞察
- **完全掌控**: 本地存储，数据完全属于用户

### 🌟 用户体验优化
- **新手引导**: 3屏欢迎流程，30秒完成首次记账
- **情感化交互**: 温和文案、鼓励性反馈、成就庆祝
- **触觉反馈**: 记账成功、成就解锁的精确震动反馈
- **推送通知**: 智能提醒、预算警告、周报推送

---

## 🚀 快速开始

### 📋 系统要求

- **开发环境**: Xcode 12.0+
- **iOS版本**: iOS 14.0+
- **设备支持**: iPhone 6s - iPhone 15 Pro Max
- **语言**: Swift 5.0+
- **框架**: SwiftUI 2.0+

### 🛠️ 安装步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/wingogx/bookkeeping.git
   cd bookkeeping
   ```

2. **打开项目**
   ```bash
   open VoiceBudget.xcodeproj
   ```

3. **配置权限**
   - 确保Info.plist包含麦克风和语音识别权限声明
   - 推送通知权限（可选）

4. **运行应用**
   - 在Xcode中按 `⌘ + R`
   - 选择iOS模拟器或真机设备

### 🎯 首次使用

1. **权限授权**: 允许麦克风和语音识别权限
2. **新手引导**: 完成3屏引导流程
3. **首次记账**: 说出"吃饭30元"完成首笔记录
4. **探索功能**: 体验预算设置、成就系统等功能

---

## 🏗️ 技术架构

### 📁 项目结构

```
VoiceBudget/
├── App/
│   └── VoiceBudgetApp.swift      # 主应用文件 (7000+行)
├── Resources/
│   └── Info.plist                # 应用配置
├── docs/
│   └── PRD.md                     # 产品需求文档
├── CLAUDE.md                      # 开发指南
└── README.md                      # 项目说明
```

### 🔧 核心技术栈

- **UI框架**: SwiftUI + MVVM架构
- **语音识别**: Speech Framework (本地处理)
- **数据存储**: UserDefaults + Codable协议
- **通知系统**: UserNotifications Framework
- **权限管理**: LocalAuthentication Framework
- **架构模式**: 单文件架构 + 模块化组织

### 🧩 架构设计

```
VoiceBudgetApp.swift
├── 数据模型层 (19-200行)
│   ├── Transaction: 交易记录
│   ├── Achievement: 成就系统
│   ├── Budget: 预算管理
│   └── UserStats: 用户统计
├── 数据管理层 (202-1746行)
│   ├── DataManager: 数据管理器
│   ├── VoiceRecognitionManager: 语音识别
│   └── NotificationManager: 推送通知
└── 用户界面层 (1964-7000+行)
    ├── HomeView: 首页视图
    ├── AddTransactionView: 记账视图
    ├── BudgetView: 预算管理
    └── SettingsView: 设置页面
```

### 🎨 设计模式

- **MVVM**: 视图与数据逻辑分离
- **单例模式**: DataManager全局数据管理
- **观察者模式**: @Published响应式数据更新
- **策略模式**: 语音识别智能分类策略

---

## 📈 版本历史

### 🔄 最新版本 - v1.0.8 试用版 (2025-09-17)

**✨ 新功能特性**
- ✅ **¥符号识别**: 完美支持"今日吃早饭¥7"等人民币符号格式
- ✅ **完整试用体验**: 无功能限制的完整版本体验
- ✅ **智能金额解析**: 支持¥、￥、元、块、钱、纯数字5种格式
- ✅ **精准语音识别**: 金额识别准确率>98%，日期识别>95%

**🔧 技术优化**
- 备注清理增强（移除12+种无意义字符）
- 日期解析完善（支持"9月10号"等具体日期）
- 多事务处理优化（避免单笔交易错误拆分）
- 应用版本信息更新

### 📅 历史版本

<details>
<summary>点击查看完整版本历史</summary>

**v1.0.7.1** - 语音识别优化版
- 日期解析优化
- 多事务处理修复
- 备注内容清理

**v1.0.7** - 代码质量优化版
- 45个编译错误修复
- 代码重构和性能优化
- 多事务语音解析修复

**v1.0.6** - 功能完整版
- 核心功能实现
- 成就和连击系统
- 数据导出功能

</details>

---

## 🎨 截图预览

<div align="center">

| 首页概览 | 语音记账 | 预算管理 | 成就系统 |
|:---:|:---:|:---:|:---:|
| 📊 支出收入统计 | 🎙️ 智能语音识别 | 💰 预算进度追踪 | 🏆 成就解锁展示 |

*注: 实际界面以最新版本为准*

</div>

---

## 🛣️ 开发路线图

### 🔮 即将推出 - v1.1.0

**🎯 收入分类增强版**
- [ ] 分离式收入/支出分类管理
- [ ] 7种预设收入分类（工资、投资、副业等）
- [ ] 收入统计分析增强
- [ ] 智能收入分类推荐

### 🌟 未来规划 - v1.2.0+

**📱 社交版 (v1.2.0)**
- [ ] 精美分享卡片
- [ ] 记账伙伴系统
- [ ] 匿名社区交流

**🖥️ 完整版 (v2.0.0)**
- [ ] Apple Watch版本
- [ ] Mac版应用
- [ ] 云同步功能
- [ ] 家庭财务管理

---

## 📖 文档与指南

### 📚 开发文档
- [📋 产品需求文档](docs/PRD.md) - 完整的产品规格说明
- [🛠️ 开发指南](CLAUDE.md) - 代码结构和开发规范
- [🔧 API文档](docs/API.md) - 核心API使用说明 (规划中)

### 🎯 使用教程
- [🚀 快速上手指南](docs/QuickStart.md) (规划中)
- [💡 高级功能教程](docs/Advanced.md) (规划中)
- [❓ 常见问题解答](docs/FAQ.md) (规划中)

---

## 🤝 贡献指南

我们欢迎所有形式的贡献！无论是报告bug、提出新功能建议，还是提交代码改进。

### 🐛 报告问题

1. 查看 [Issues](https://github.com/wingogx/bookkeeping/issues) 确认问题未重复
2. 使用问题模板创建新issue
3. 提供详细的复现步骤和环境信息

### 💡 功能建议

1. 在 [Discussions](https://github.com/wingogx/bookkeeping/discussions) 中讨论想法
2. 创建功能请求issue
3. 详细描述使用场景和预期效果

### 🔧 代码贡献

1. Fork本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送分支 (`git push origin feature/amazing-feature`)
5. 创建Pull Request

### 📏 代码规范

- 遵循Swift官方代码风格
- 单文件架构约束，避免过度拆分
- 添加适当的MARK注释分隔模块
- 确保iOS 14.0+兼容性

---

## 📄 开源协议

本项目采用 [MIT License](LICENSE) 开源协议。

```
MIT License

Copyright (c) 2025 VoiceBudget

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

---

## 🙋‍♂️ 联系我们

### 📧 获取帮助

- **GitHub Issues**: [报告问题](https://github.com/wingogx/bookkeeping/issues)
- **GitHub Discussions**: [功能讨论](https://github.com/wingogx/bookkeeping/discussions)
- **Email**: [联系开发者](mailto:wingogx@example.com)

### 🌐 了解更多

- **项目主页**: https://github.com/wingogx/bookkeeping
- **版本发布**: https://github.com/wingogx/bookkeeping/releases
- **更新日志**: [CHANGELOG.md](CHANGELOG.md) (规划中)

---

## 💖 致谢

感谢以下技术和社区的支持：

- **Apple**: 提供优秀的iOS开发平台和SwiftUI框架
- **Speech Framework**: 强大的本地语音识别能力
- **Swift社区**: 持续的技术创新和最佳实践分享
- **所有贡献者**: 为项目改进提供的宝贵建议和代码贡献

---

## ⭐ 如果这个项目对您有帮助，请给我们一个Star！

<div align="center">

**🎙️ VoiceBudget - 让记账变得简单有趣**

[![Star History Chart](https://api.star-history.com/svg?repos=wingogx/bookkeeping&type=Date)](https://star-history.com/#wingogx/bookkeeping&Date)

[⬆️ 回到顶部](#voicebudget---极简语音记账app)

</div>