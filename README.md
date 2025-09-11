# VoiceBudget 📱

> 智能语音记账iOS应用 - 让记账变得简单智能

![iOS](https://img.shields.io/badge/iOS-14.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## ✨ 项目简介

VoiceBudget是一款基于iOS平台的智能语音记账应用，采用Clean Architecture + MVVM架构模式，集成了语音识别、智能分类、预算管理和云同步等核心功能。

## 🎯 核心功能

### 🎤 语音记账
- **中文语音识别**: 基于iOS Speech Framework，支持自然语言输入
- **实时语音处理**: 本地处理保护用户隐私
- **智能语音解析**: 自动提取金额、描述和分类信息

### 🧠 智能分类
- **AI自动分类**: 支持8大消费类别自动识别
- **NLP文本分析**: 智能解析交易描述
- **学习优化**: 基于用户习惯不断优化分类准确度

### 📊 预算管理
- **实时预算监控**: 动态计算预算使用情况
- **超支预警**: 智能提醒和消费建议
- **分类预算**: 支持分类别预算设置和管理

### ☁️ 云端同步
- **iCloud集成**: 无缝多设备数据同步
- **离线优先**: 支持离线使用，网络恢复时自动同步
- **冲突解决**: 智能处理数据冲突

### 📈 数据统计
- **消费趋势**: 可视化图表展示消费趋势
- **分类统计**: 详细的分类消费分析
- **历史记录**: 完整的交易历史管理

## 🏗️ 技术架构

### 架构模式
- **Clean Architecture**: 分层架构，职责清晰
- **MVVM**: Model-View-ViewModel响应式设计
- **Repository Pattern**: 数据访问抽象

### 核心技术栈
- **UI框架**: SwiftUI + Combine
- **数据存储**: Core Data + CloudKit
- **语音识别**: iOS Speech Framework
- **自然语言**: NLP智能分类算法
- **异步处理**: async/await + Combine Publishers
- **依赖注入**: Clean Architecture DI

### 项目结构
```
VoiceBudget/
├── App/                    # 应用入口
├── Domain/                 # 业务逻辑层
│   ├── Entities/          # 实体模型
│   ├── UseCases/          # 用例服务
│   ├── Services/          # 领域服务
│   └── Repositories/      # 仓储协议
├── Infrastructure/         # 基础设施层
│   ├── SpeechRecognition/ # 语音识别
│   ├── NLP/              # 自然语言处理
│   ├── CloudKit/         # 云同步服务
│   └── CoreData/         # 数据持久化
├── Data/                  # 数据层
│   └── Repositories/     # 仓储实现
├── Presentation/          # 表现层
│   ├── Views/           # SwiftUI视图
│   └── ViewModels/      # 视图模型
└── Utils/                # 工具库
```

## 📊 项目指标

- **代码量**: 17,904行Swift代码
- **文件数**: 65个Swift文件
- **代码规模**: ~608KB
- **测试覆盖**: 100%功能测试覆盖
- **架构完整性**: 5层完整实现

## 🚀 快速开始

### 环境要求
- Xcode 14.0+
- iOS 14.0+
- Swift 5.0+
- macOS 12.0+ (开发环境)

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/wingo/bookkeeping.git
   cd bookkeeping
   ```

2. **打开项目**
   ```bash
   open VoiceBudget.xcodeproj
   ```

3. **配置权限**
   - 确保Info.plist中配置了必要的权限声明
   - 语音识别权限: `NSSpeechRecognitionUsageDescription`
   - 麦克风权限: `NSMicrophoneUsageDescription`

4. **运行测试**
   ```bash
   # 运行功能测试
   swift simple_test.swift
   
   # 运行完整集成测试
   swift final_integration_test.swift
   ```

## 🎨 功能截图

### 主要界面
- 🏠 **首页**: 语音记账入口和预算概览
- 🎤 **语音记账**: 实时语音识别和交易确认
- 📊 **统计分析**: 消费趋势和分类统计
- 📝 **历史记录**: 交易记录管理和搜索
- ⚙️ **设置**: 权限管理和应用配置

## 📋 开发路线图

### ✅ 已完成
- [x] 语音识别集成
- [x] 智能分类算法
- [x] Core Data数据模型
- [x] CloudKit云同步
- [x] SwiftUI界面
- [x] 预算分析功能
- [x] 权限管理系统
- [x] 完整测试套件

### 🚧 计划中
- [ ] Apple Watch支持
- [ ] Siri Shortcuts集成
- [ ] 数据导出功能
- [ ] 多语言支持
- [ ] 深色模式优化
- [ ] App Store发布

## 🤝 贡献指南

我们欢迎任何形式的贡献！

### 如何贡献
1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

### 代码规范
- 遵循Swift官方代码风格
- 使用SwiftLint进行代码检查
- 确保所有测试通过
- 添加必要的文档注释

## 📄 许可证

本项目采用MIT许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 👥 贡献者

- [@wingo](https://github.com/wingo) - 项目创建者和主要开发者

## 📞 联系方式

- 邮箱: wingogx207@gmail.com
- GitHub: [@wingo](https://github.com/wingo)

## 🙏 致谢

- 感谢Apple提供的优秀开发框架
- 感谢iOS开发社区的支持和帮助
- 感谢所有测试用户的反馈

---

⭐ 如果这个项目对你有帮助，请给它一个星标！

**让记账变得简单智能 - VoiceBudget** 🎉