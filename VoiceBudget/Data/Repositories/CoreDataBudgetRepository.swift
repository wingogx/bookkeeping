import Foundation
import CoreData

/// Core Data实现的预算仓储
public class CoreDataBudgetRepository: BudgetRepository {
    
    let context: NSManagedObjectContext
    
    public init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - CRUD Operations
    
    public func createBudget(_ budget: BudgetEntity) async throws -> BudgetEntity {
        return try await context.perform {
            let managedBudget = BudgetData(context: self.context)
            self.updateManagedBudget(managedBudget, with: budget)
            
            try self.context.save()
            
            return self.mapToEntity(managedBudget)
        }
    }
    
    public func getBudget(by id: UUID) async throws -> BudgetEntity? {
        return try await context.perform {
            let request: NSFetchRequest<BudgetData> = BudgetData.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            let results = try self.context.fetch(request)
            return results.first.map { self.mapToEntity($0) }
        }
    }
    
    public func getCurrentBudget() async throws -> BudgetEntity? {
        return try await context.perform {
            let request: NSFetchRequest<BudgetData> = BudgetData.fetchRequest()
            request.predicate = NSPredicate(format: "isActive == YES")
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            request.fetchLimit = 1
            
            let results = try self.context.fetch(request)
            return results.first.map { self.mapToEntity($0) }
        }
    }
    
    public func getBudget(
        for period: BudgetEntity.BudgetPeriod,
        containing date: Date = Date()
    ) async throws -> BudgetEntity? {
        return try await context.perform {
            let request: NSFetchRequest<BudgetData> = BudgetData.fetchRequest()
            
            let predicates = [
                NSPredicate(format: "period == %@", period.rawValue),
                NSPredicate(format: "startDate <= %@", date as NSDate),
                NSPredicate(format: "endDate >= %@", date as NSDate)
            ]
            
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.fetchLimit = 1
            
            let results = try self.context.fetch(request)
            return results.first.map { self.mapToEntity($0) }
        }
    }
    
    public func fetchBudgets(
        period: BudgetEntity.BudgetPeriod?,
        isActive: Bool?,
        limit: Int?,
        offset: Int = 0
    ) async throws -> [BudgetEntity] {
        return try await context.perform {
            let request: NSFetchRequest<BudgetData> = BudgetData.fetchRequest()
            
            var predicates: [NSPredicate] = []
            
            if let period = period {
                predicates.append(NSPredicate(format: "period == %@", period.rawValue))
            }
            
            if let isActive = isActive {
                predicates.append(NSPredicate(format: "isActive == %@", NSNumber(value: isActive)))
            }
            
            if !predicates.isEmpty {
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }
            
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            
            if let limit = limit {
                request.fetchLimit = limit
            }
            request.fetchOffset = offset
            
            let results = try self.context.fetch(request)
            return results.map { self.mapToEntity($0) }
        }
    }
    
    public func updateBudget(_ budget: BudgetEntity) async throws -> BudgetEntity {
        return try await context.perform {
            let request: NSFetchRequest<BudgetData> = BudgetData.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", budget.id as CVarArg)
            request.fetchLimit = 1
            
            guard let managedBudget = try self.context.fetch(request).first else {
                throw RepositoryError.entityNotFound
            }
            
            self.updateManagedBudget(managedBudget, with: budget)
            managedBudget.updatedAt = Date()
            
            try self.context.save()
            
            return self.mapToEntity(managedBudget)
        }
    }
    
    public func deleteBudget(id: UUID) async throws {
        try await context.perform {
            let request: NSFetchRequest<BudgetData> = BudgetData.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            guard let managedBudget = try self.context.fetch(request).first else {
                throw RepositoryError.entityNotFound
            }
            
            self.context.delete(managedBudget)
            try self.context.save()
        }
    }
    
    // MARK: - Budget Usage and Statistics
    
    public func getBudgetUsage(
        budgetID: UUID,
        upToDate: Date = Date()
    ) async throws -> BudgetUsage {
        return try await context.perform {
            // Get budget
            guard let budget = try await self.getBudget(by: budgetID) else {
                throw RepositoryError.entityNotFound
            }
            
            // Get transactions for this budget period
            let transactionRequest: NSFetchRequest<TransactionData> = TransactionData.fetchRequest()
            transactionRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "date >= %@", budget.startDate as NSDate),
                NSPredicate(format: "date <= %@", min(budget.endDate, upToDate) as NSDate),
                NSPredicate(format: "deletedAt == nil")
            ])
            
            let transactions = try self.context.fetch(transactionRequest)
            let usedAmount = transactions.reduce(Decimal.zero) { $0 + ($1.amount as Decimal) }
            let remainingAmount = budget.totalAmount - usedAmount
            let usagePercentage = Double(truncating: (usedAmount / budget.totalAmount) as NSDecimalNumber) * 100
            
            // Calculate days remaining
            let daysRemaining = Calendar.current.dateComponents([.day], from: upToDate, to: budget.endDate).day ?? 0
            
            // Calculate average daily spent
            let daysElapsed = Calendar.current.dateComponents([.day], from: budget.startDate, to: upToDate).day ?? 1
            let averageDailySpent = daysElapsed > 0 ? usedAmount / Decimal(daysElapsed) : Decimal.zero
            
            // Project total spending
            let totalDaysInPeriod = Calendar.current.dateComponents([.day], from: budget.startDate, to: budget.endDate).day ?? 1
            let projectedTotal = averageDailySpent * Decimal(totalDaysInPeriod)
            
            // Determine status and if on track
            let status: BudgetStatus
            let isOnTrack: Bool
            
            if usagePercentage > 100 {
                status = .exceeded
                isOnTrack = false
            } else if usagePercentage >= 80 {
                status = .warning
                isOnTrack = projectedTotal <= budget.totalAmount
            } else {
                status = .safe
                isOnTrack = true
            }
            
            return BudgetUsage(
                budgetID: budgetID,
                totalBudget: budget.totalAmount,
                usedAmount: usedAmount,
                remainingAmount: remainingAmount,
                usagePercentage: usagePercentage,
                status: status,
                daysRemaining: max(0, daysRemaining),
                averageDailySpent: averageDailySpent,
                projectedTotal: projectedTotal,
                isOnTrack: isOnTrack
            )
        }
    }
    
    public func getCategoryBudgetUsage(
        budgetID: UUID,
        upToDate: Date = Date()
    ) async throws -> [CategoryBudgetUsage] {
        return try await context.perform {
            // Get budget
            guard let budget = try await self.getBudget(by: budgetID) else {
                throw RepositoryError.entityNotFound
            }
            
            // Get transactions grouped by category
            let transactionRequest: NSFetchRequest<TransactionData> = TransactionData.fetchRequest()
            transactionRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "date >= %@", budget.startDate as NSDate),
                NSPredicate(format: "date <= %@", min(budget.endDate, upToDate) as NSDate),
                NSPredicate(format: "deletedAt == nil")
            ])
            
            let transactions = try self.context.fetch(transactionRequest)
            let transactionsByCategory = Dictionary(grouping: transactions) { $0.categoryID ?? "unknown" }
            
            return budget.categoryAllocations.map { allocation in
                let categoryTransactions = transactionsByCategory[allocation.categoryID] ?? []
                let usedAmount = categoryTransactions.reduce(Decimal.zero) { $0 + ($1.amount as Decimal) }
                let remainingAmount = allocation.allocatedAmount - usedAmount
                let usagePercentage = allocation.allocatedAmount > 0 ? 
                    Double(truncating: (usedAmount / allocation.allocatedAmount) as NSDecimalNumber) * 100 : 0
                
                let status: BudgetStatus
                if usagePercentage > 100 {
                    status = .exceeded
                } else if usagePercentage >= 80 {
                    status = .warning
                } else {
                    status = .safe
                }
                
                return CategoryBudgetUsage(
                    categoryID: allocation.categoryID,
                    categoryName: allocation.categoryName,
                    allocatedAmount: allocation.allocatedAmount,
                    usedAmount: usedAmount,
                    remainingAmount: remainingAmount,
                    usagePercentage: usagePercentage,
                    status: status,
                    transactionCount: categoryTransactions.count
                )
            }
        }
    }
    
    public func getBudgetExecutionTrend(budgetID: UUID) async throws -> [BudgetExecutionData] {
        return try await context.perform {
            // Get budget
            guard let budget = try await self.getBudget(by: budgetID) else {
                throw RepositoryError.entityNotFound
            }
            
            // Get all transactions for this budget period
            let transactionRequest: NSFetchRequest<TransactionData> = TransactionData.fetchRequest()
            transactionRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "date >= %@", budget.startDate as NSDate),
                NSPredicate(format: "date <= %@", budget.endDate as NSDate),
                NSPredicate(format: "deletedAt == nil")
            ])
            transactionRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            
            let transactions = try self.context.fetch(transactionRequest)
            
            // Calculate total days in budget period
            let totalDays = Calendar.current.dateComponents([.day], from: budget.startDate, to: budget.endDate).day ?? 1
            let dailyTargetSpent = budget.totalAmount / Decimal(totalDays)
            
            // Group transactions by day and calculate cumulative spending
            let calendar = Calendar.current
            let transactionsByDay = Dictionary(grouping: transactions) { transaction in
                calendar.startOfDay(for: transaction.date ?? Date())
            }
            
            var executionData: [BudgetExecutionData] = []
            var cumulativeSpent = Decimal.zero
            
            // Generate data for each day in the budget period
            var currentDate = calendar.startOfDay(for: budget.startDate)
            let endDate = calendar.startOfDay(for: budget.endDate)
            var dayCount = 0
            
            while currentDate <= endDate {
                let dayTransactions = transactionsByDay[currentDate] ?? []
                let dailySpent = dayTransactions.reduce(Decimal.zero) { $0 + ($1.amount as Decimal) }
                cumulativeSpent += dailySpent
                
                let targetCumulativeSpent = dailyTargetSpent * Decimal(dayCount + 1)
                let remainingBudget = budget.totalAmount - cumulativeSpent
                
                executionData.append(BudgetExecutionData(
                    date: currentDate,
                    cumulativeSpent: cumulativeSpent,
                    dailySpent: dailySpent,
                    remainingBudget: remainingBudget,
                    targetCumulativeSpent: targetCumulativeSpent
                ))
                
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                dayCount += 1
            }
            
            return executionData
        }
    }
    
    // MARK: - Budget Validation
    
    public func canModifyBudget(budgetID: UUID) async throws -> Bool {
        return try await context.perform {
            guard let budget = try await self.getBudget(by: budgetID) else {
                return false
            }
            
            // Can't modify if budget period has ended
            if budget.endDate < Date() {
                return false
            }
            
            // Can modify if budget hasn't started yet or is currently active
            return true
        }
    }
    
    public func validateBudgetAllocation(_ budget: BudgetEntity) async throws -> BudgetValidationResult {
        var errors: [BudgetValidationResult.ValidationError] = []
        var warnings: [BudgetValidationResult.ValidationWarning] = []
        
        // Validate total allocation
        let totalAllocated = budget.categoryAllocations.reduce(Decimal.zero) { $0 + $1.allocatedAmount }
        
        if totalAllocated > budget.totalAmount {
            errors.append(BudgetValidationResult.ValidationError(
                code: "OVER_ALLOCATION",
                message: "分类预算总额超过了总预算"
            ))
        } else if totalAllocated < budget.totalAmount {
            let unallocated = budget.totalAmount - totalAllocated
            warnings.append(BudgetValidationResult.ValidationWarning(
                code: "UNDER_ALLOCATION",
                message: "还有 ¥\(unallocated) 未分配到分类"
            ))
        }
        
        // Validate date range
        if budget.startDate >= budget.endDate {
            errors.append(BudgetValidationResult.ValidationError(
                code: "INVALID_DATE_RANGE",
                message: "预算开始日期必须早于结束日期"
            ))
        }
        
        // Validate amounts
        if budget.totalAmount <= 0 {
            errors.append(BudgetValidationResult.ValidationError(
                code: "INVALID_TOTAL_AMOUNT",
                message: "预算总额必须大于0"
            ))
        }
        
        // Check for negative allocations
        for allocation in budget.categoryAllocations {
            if allocation.allocatedAmount < 0 {
                errors.append(BudgetValidationResult.ValidationError(
                    code: "NEGATIVE_ALLOCATION",
                    message: "分类预算金额不能为负数"
                ))
            }
        }
        
        return BudgetValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    public func checkBudgetConflict(_ budget: BudgetEntity) async throws -> Bool {
        return try await context.perform {
            let request: NSFetchRequest<BudgetData> = BudgetData.fetchRequest()
            
            let predicates: [NSPredicate] = [
                NSPredicate(format: "id != %@", budget.id as CVarArg),
                NSPredicate(format: "period == %@", budget.period.rawValue),
                NSPredicate(format: "isActive == YES"),
                NSPredicate(format: "(startDate <= %@ AND endDate >= %@) OR (startDate <= %@ AND endDate >= %@)",
                          budget.startDate as NSDate, budget.startDate as NSDate,
                          budget.endDate as NSDate, budget.endDate as NSDate)
            ]
            
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            
            let conflictingCount = try self.context.count(for: request)
            return conflictingCount > 0
        }
    }
    
    // MARK: - Budget Management
    
    public func activateBudget(id: UUID) async throws {
        try await context.perform {
            // Get the budget to activate
            guard let targetBudget = try await self.getBudget(by: id) else {
                throw RepositoryError.entityNotFound
            }
            
            // Deactivate all other budgets with the same period
            let deactivateRequest: NSFetchRequest<BudgetData> = BudgetData.fetchRequest()
            deactivateRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "id != %@", id as CVarArg),
                NSPredicate(format: "period == %@", targetBudget.period.rawValue),
                NSPredicate(format: "isActive == YES")
            ])
            
            let otherActiveBudgets = try self.context.fetch(deactivateRequest)
            for budget in otherActiveBudgets {
                budget.isActive = false
                budget.updatedAt = Date()
            }
            
            // Activate the target budget
            let activateRequest: NSFetchRequest<BudgetData> = BudgetData.fetchRequest()
            activateRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            activateRequest.fetchLimit = 1
            
            guard let managedBudget = try self.context.fetch(activateRequest).first else {
                throw RepositoryError.entityNotFound
            }
            
            managedBudget.isActive = true
            managedBudget.updatedAt = Date()
            
            try self.context.save()
        }
    }
    
    public func deactivateBudget(id: UUID) async throws {
        try await context.perform {
            let request: NSFetchRequest<BudgetData> = BudgetData.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            guard let managedBudget = try self.context.fetch(request).first else {
                throw RepositoryError.entityNotFound
            }
            
            managedBudget.isActive = false
            managedBudget.updatedAt = Date()
            
            try self.context.save()
        }
    }
    
    public func cloneBudgetToNextPeriod(budgetID: UUID) async throws -> BudgetEntity {
        return try await context.perform {
            guard let originalBudget = try await self.getBudget(by: budgetID) else {
                throw RepositoryError.entityNotFound
            }
            
            let calendar = Calendar.current
            let nextStartDate: Date
            let nextEndDate: Date
            
            switch originalBudget.period {
            case .week:
                nextStartDate = calendar.date(byAdding: .weekOfYear, value: 1, to: originalBudget.startDate)!
                nextEndDate = calendar.date(byAdding: .weekOfYear, value: 1, to: originalBudget.endDate)!
            case .month:
                nextStartDate = calendar.date(byAdding: .month, value: 1, to: originalBudget.startDate)!
                nextEndDate = calendar.date(byAdding: .month, value: 1, to: originalBudget.endDate)!
            }
            
            let clonedBudget = BudgetEntity(
                id: UUID(),
                name: "\(originalBudget.name) (副本)",
                totalAmount: originalBudget.totalAmount,
                period: originalBudget.period,
                startDate: nextStartDate,
                endDate: nextEndDate,
                categoryAllocations: originalBudget.categoryAllocations,
                isActive: false
            )
            
            return try await self.createBudget(clonedBudget)
        }
    }
    
    // MARK: - Data Analysis
    
    public func getBudgetHistoryAnalysis(
        period: BudgetEntity.BudgetPeriod,
        count: Int = 6
    ) async throws -> BudgetHistoryAnalysis {
        return try await context.perform {
            let request: NSFetchRequest<BudgetData> = BudgetData.fetchRequest()
            request.predicate = NSPredicate(format: "period == %@", period.rawValue)
            request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
            request.fetchLimit = count
            
            let budgets = try self.context.fetch(request).map { self.mapToEntity($0) }
            
            guard !budgets.isEmpty else {
                return BudgetHistoryAnalysis(
                    period: period,
                    averageSpent: Decimal.zero,
                    averageBudget: Decimal.zero,
                    averageUsageRate: 0,
                    successRate: 0,
                    trend: .stable,
                    categoryAnalysis: []
                )
            }
            
            // Calculate averages
            var totalSpent = Decimal.zero
            var totalBudget = Decimal.zero
            var successfulPeriods = 0
            var categoryTotals: [String: (spent: Decimal, budget: Decimal, count: Int)] = [:]
            
            for budget in budgets {
                let usage = try await self.getBudgetUsage(budgetID: budget.id, upToDate: budget.endDate)
                
                totalSpent += usage.usedAmount
                totalBudget += budget.totalAmount
                
                if usage.status != .exceeded {
                    successfulPeriods += 1
                }
                
                // Category analysis
                let categoryUsages = try await self.getCategoryBudgetUsage(budgetID: budget.id, upToDate: budget.endDate)
                for categoryUsage in categoryUsages {
                    let existing = categoryTotals[categoryUsage.categoryID] ?? (Decimal.zero, Decimal.zero, 0)
                    categoryTotals[categoryUsage.categoryID] = (
                        existing.spent + categoryUsage.usedAmount,
                        existing.budget + categoryUsage.allocatedAmount,
                        existing.count + 1
                    )
                }
            }
            
            let averageSpent = totalSpent / Decimal(budgets.count)
            let averageBudget = totalBudget / Decimal(budgets.count)
            let averageUsageRate = Double(truncating: (averageSpent / averageBudget) as NSDecimalNumber) * 100
            let successRate = Double(successfulPeriods) / Double(budgets.count) * 100
            
            // Determine trend
            let trend: BudgetTrend
            if budgets.count >= 3 {
                let recentSpent = budgets.prefix(3).reduce(Decimal.zero) { total, budget in
                    // This is simplified - in practice you'd get actual spending data
                    total + budget.totalAmount * 0.8 // Assume 80% usage as example
                }
                let olderSpent = budgets.suffix(3).reduce(Decimal.zero) { total, budget in
                    total + budget.totalAmount * 0.8
                }
                
                if recentSpent > olderSpent * 1.1 {
                    trend = .increasing
                } else if recentSpent < olderSpent * 0.9 {
                    trend = .decreasing
                } else {
                    trend = .stable
                }
            } else {
                trend = .stable
            }
            
            // Category analysis
            let categoryAnalysis = categoryTotals.map { (categoryID, totals) in
                let avgSpent = totals.count > 0 ? totals.spent / Decimal(totals.count) : Decimal.zero
                let avgBudget = totals.count > 0 ? totals.budget / Decimal(totals.count) : Decimal.zero
                let avgUsageRate = avgBudget > 0 ? Double(truncating: (avgSpent / avgBudget) as NSDecimalNumber) * 100 : 0
                
                return CategoryHistoryAnalysis(
                    categoryID: categoryID,
                    categoryName: categoryID, // In practice, you'd lookup the actual name
                    averageSpent: avgSpent,
                    averageAllocation: avgBudget,
                    averageUsageRate: avgUsageRate,
                    trend: .stable // Simplified for now
                )
            }
            
            return BudgetHistoryAnalysis(
                period: period,
                averageSpent: averageSpent,
                averageBudget: averageBudget,
                averageUsageRate: averageUsageRate,
                successRate: successRate,
                trend: trend,
                categoryAnalysis: categoryAnalysis
            )
        }
    }
    
    public func generateBudgetSuggestion(
        for period: BudgetEntity.BudgetPeriod,
        baseOnHistory: Bool = true
    ) async throws -> BudgetSuggestion {
        guard baseOnHistory else {
            // Return default suggestion if not based on history
            let defaultAllocations = [
                BudgetEntity.BudgetCategoryAllocation(categoryID: "dining", categoryName: "餐饮", allocatedAmount: 800),
                BudgetEntity.BudgetCategoryAllocation(categoryID: "transportation", categoryName: "交通", allocatedAmount: 200),
                BudgetEntity.BudgetCategoryAllocation(categoryID: "shopping", categoryName: "购物", allocatedAmount: 500),
                BudgetEntity.BudgetCategoryAllocation(categoryID: "others", categoryName: "其他", allocatedAmount: 300)
            ]
            
            return BudgetSuggestion(
                suggestedTotalAmount: 1800,
                categoryAllocations: defaultAllocations,
                reasoning: "基于默认消费模式的建议预算",
                confidenceScore: 0.5,
                basedOnPeriods: 0
            )
        }
        
        let historyAnalysis = try await getBudgetHistoryAnalysis(period: period, count: 6)
        
        // Adjust suggestion based on historical data
        let adjustedTotal = historyAnalysis.averageSpent * 1.1 // Add 10% buffer
        
        let allocations = historyAnalysis.categoryAnalysis.map { categoryAnalysis in
            BudgetEntity.BudgetCategoryAllocation(
                categoryID: categoryAnalysis.categoryID,
                categoryName: categoryAnalysis.categoryName,
                allocatedAmount: categoryAnalysis.averageSpent * 1.1
            )
        }
        
        let confidenceScore = min(0.9, Double(historyAnalysis.categoryAnalysis.count) / 4.0 * 0.8 + 0.1)
        
        return BudgetSuggestion(
            suggestedTotalAmount: adjustedTotal,
            categoryAllocations: allocations,
            reasoning: "基于过去\(historyAnalysis.categoryAnalysis.count)个周期的历史数据，建议增加10%作为缓冲",
            confidenceScore: confidenceScore,
            basedOnPeriods: historyAnalysis.categoryAnalysis.count
        )
    }
    
    // MARK: - Private Methods
    
    private func updateManagedBudget(_ managed: BudgetData, with entity: BudgetEntity) {
        managed.id = entity.id
        managed.name = entity.name
        managed.totalAmount = entity.totalAmount as NSDecimalNumber
        managed.period = entity.period.rawValue
        managed.startDate = entity.startDate
        managed.endDate = entity.endDate
        managed.isActive = entity.isActive
        
        // Handle category allocations
        if let allocationsData = try? JSONEncoder().encode(entity.categoryAllocations) {
            managed.categoryAllocationsData = allocationsData
        }
        
        if managed.createdAt == nil {
            managed.createdAt = Date()
        }
        managed.updatedAt = Date()
    }
    
    private func mapToEntity(_ managed: BudgetData) -> BudgetEntity {
        let categoryAllocations: [BudgetEntity.BudgetCategoryAllocation]
        if let data = managed.categoryAllocationsData,
           let decoded = try? JSONDecoder().decode([BudgetEntity.BudgetCategoryAllocation].self, from: data) {
            categoryAllocations = decoded
        } else {
            categoryAllocations = []
        }
        
        return BudgetEntity(
            id: managed.id ?? UUID(),
            name: managed.name ?? "",
            totalAmount: managed.totalAmount as Decimal,
            period: BudgetEntity.BudgetPeriod(rawValue: managed.period ?? "month") ?? .month,
            startDate: managed.startDate ?? Date(),
            endDate: managed.endDate ?? Date(),
            categoryAllocations: categoryAllocations,
            isActive: managed.isActive,
            createdAt: managed.createdAt ?? Date(),
            updatedAt: managed.updatedAt ?? Date()
        )
    }
}