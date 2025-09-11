# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个语音记账App项目，专为iOS平台设计。项目目标是创建一个极简智能记账应用，核心功能包括：

- 语音输入记账
- 预算设置与管理  
- 分类统计
- 实时预算反馈
- 数据本地化存储与iCloud同步

## 技术栈

根据产品需求文档，项目将使用以下技术栈：

- **平台**: iOS (Swift/SwiftUI)
- **语音识别**: iOS Speech Framework
- **数据存储**: Core Data + CloudKit (iCloud同步)
- **UI框架**: SwiftUI
- **开发工具**: Xcode

## 项目结构

当前项目处于规划阶段，主要文档：

- `docs/first1.doc` - 产品需求文档，包含完整的功能规划和技术方案

## 关键产品特性

根据PRD文档，核心功能包括：

### 预算管理
- 支持周预算/月预算模式切换
- 自定义消费分类
- 预算分配与实时反馈
- 预算调整功能

### 语音记账
- 主界面麦克风悬浮按钮
- 语音转文本识别
- 智能分类匹配
- 确认与编辑机制

### 统计分析
- 消费趋势图表
- 分类占比饼图
- 预算使用进度条
- 历史记录查看

### 数据安全
- 本地Core Data存储
- iCloud CloudKit同步
- 数据加密
- 隐私保护

## 开发指导

### 设计原则
- 极简UI设计，符合iOS设计规范
- 单手操作友好
- 快速记账，3秒完成一笔记录
- 清晰的视觉反馈

### 技术要点
- 使用SwiftUI构建现代化界面
- 集成Speech Framework进行语音识别
- Core Data + CloudKit实现数据持久化和同步
- 遵循Apple隐私准则

### 开发阶段
当前项目处于需求分析阶段，建议的开发步骤：

1. 创建Xcode项目结构
2. 设计数据模型(Core Data)
3. 实现基础UI框架
4. 集成语音识别功能
5. 实现预算管理逻辑
6. 添加统计图表
7. 集成CloudKit同步
8. 测试和优化

## 注意事项

- 项目目标用户为个人记账需求，注重简洁和高效
- 必须严格遵循Apple的隐私和安全准则
- UI/UX设计需符合iOS Human Interface Guidelines
- 语音识别需要处理网络离线情况
- 数据同步需要考虑冲突解决机制