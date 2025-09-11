import Foundation
import CoreData
import Combine

/// Core Data实现的交易数据仓库
public class CoreDataTransactionRepository: TransactionRepositoryProtocol {
    
    // MARK: - Dependencies
    private let coreDataStack: CoreDataStack
    private let context: NSManagedObjectContext
    
    // MARK: - Initialization
    public init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
        self.context = coreDataStack.viewContext
    }
    
    // MARK: - Create
    public func create(_ entity: TransactionEntity) -> AnyPublisher<TransactionEntity, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.unknown))
                return
            }
            
            do {
                let transaction = Transaction(context: self.context)
                self.mapEntityToManagedObject(entity, to: transaction)
                
                try self.context.save()
                
                let createdEntity = self.mapManagedObjectToEntity(transaction)
                promise(.success(createdEntity))
                
            } catch {
                promise(.failure(RepositoryError.saveFailed(error)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Read
    public func findById(_ id: UUID) -> AnyPublisher<TransactionEntity?, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.unknown))
                return
            }
            
            let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@ AND isDeleted == NO", id as CVarArg)
            request.fetchLimit = 1
            
            do {
                let results = try self.context.fetch(request)
                let entity = results.first.map { self.mapManagedObjectToEntity($0) }
                promise(.success(entity))
            } catch {
                promise(.failure(RepositoryError.fetchFailed(error)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func findAll() -> AnyPublisher<[TransactionEntity], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.unknown))
                return
            }
            
            let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
            request.predicate = NSPredicate(format: "isDeleted == NO")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]
            
            do {
                let results = try self.context.fetch(request)
                let entities = results.map { self.mapManagedObjectToEntity($0) }
                promise(.success(entities))
            } catch {
                promise(.failure(RepositoryError.fetchFailed(error)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func findByDateRange(_ startDate: Date, _ endDate: Date) -> AnyPublisher<[TransactionEntity], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.unknown))
                return
            }
            
            let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
            request.predicate = NSPredicate(
                format: "date >= %@ AND date <= %@ AND isDeleted == NO",
                startDate as CVarArg, endDate as CVarArg
            )
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]
            
            do {
                let results = try self.context.fetch(request)
                let entities = results.map { self.mapManagedObjectToEntity($0) }
                promise(.success(entities))
            } catch {
                promise(.failure(RepositoryError.fetchFailed(error)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func findByCategory(_ categoryID: String) -> AnyPublisher<[TransactionEntity], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.unknown))
                return
            }
            
            let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
            request.predicate = NSPredicate(
                format: "categoryID == %@ AND isDeleted == NO",
                categoryID
            )
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]
            
            do {
                let results = try self.context.fetch(request)
                let entities = results.map { self.mapManagedObjectToEntity($0) }
                promise(.success(entities))
            } catch {
                promise(.failure(RepositoryError.fetchFailed(error)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Update
    public func update(_ entity: TransactionEntity) -> AnyPublisher<TransactionEntity, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.unknown))
                return
            }
            
            let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", entity.id as CVarArg)
            request.fetchLimit = 1
            
            do {
                let results = try self.context.fetch(request)
                guard let transaction = results.first else {
                    promise(.failure(RepositoryError.notFound))
                    return
                }
                
                self.mapEntityToManagedObject(entity, to: transaction)
                transaction.updatedAt = Date()
                
                try self.context.save()
                
                let updatedEntity = self.mapManagedObjectToEntity(transaction)
                promise(.success(updatedEntity))
                
            } catch {
                promise(.failure(RepositoryError.saveFailed(error)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Delete
    public func delete(_ id: UUID) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.unknown))
                return
            }
            
            let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            do {
                let results = try self.context.fetch(request)
                guard let transaction = results.first else {
                    promise(.failure(RepositoryError.notFound))
                    return
                }
                
                // 软删除
                transaction.isDeleted = true
                transaction.updatedAt = Date()
                
                try self.context.save()
                promise(.success(()))
                
            } catch {
                promise(.failure(RepositoryError.saveFailed(error)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Statistics
    public func getTotalByCategory(_ categoryID: String, startDate: Date, endDate: Date) -> AnyPublisher<Decimal, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.unknown))
                return
            }
            
            let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
            request.predicate = NSPredicate(
                format: "categoryID == %@ AND date >= %@ AND date <= %@ AND isDeleted == NO",
                categoryID, startDate as CVarArg, endDate as CVarArg
            )
            
            do {
                let results = try self.context.fetch(request)
                let total = results.compactMap { $0.amount as Decimal? }.reduce(0, +)
                promise(.success(total))
            } catch {
                promise(.failure(RepositoryError.fetchFailed(error)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func getTotalByDateRange(_ startDate: Date, _ endDate: Date) -> AnyPublisher<Decimal, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.unknown))
                return
            }
            
            let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
            request.predicate = NSPredicate(
                format: "date >= %@ AND date <= %@ AND isDeleted == NO",
                startDate as CVarArg, endDate as CVarArg
            )
            
            do {
                let results = try self.context.fetch(request)
                let total = results.compactMap { $0.amount as Decimal? }.reduce(0, +)
                promise(.success(total))
            } catch {
                promise(.failure(RepositoryError.fetchFailed(error)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func getCategoryStatistics(_ startDate: Date, _ endDate: Date) -> AnyPublisher<[CategoryStatistic], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.unknown))
                return
            }
            
            let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
            request.predicate = NSPredicate(
                format: "date >= %@ AND date <= %@ AND isDeleted == NO",
                startDate as CVarArg, endDate as CVarArg
            )
            
            do {
                let results = try self.context.fetch(request)
                
                // 按分类分组统计
                var categoryTotals: [String: Decimal] = [:]
                for transaction in results {
                    let categoryID = transaction.categoryID ?? "other"
                    let amount = transaction.amount as Decimal? ?? 0
                    categoryTotals[categoryID, default: 0] += amount
                }
                
                let statistics = categoryTotals.map { categoryID, total in
                    CategoryStatistic(
                        categoryID: categoryID,
                        categoryName: TransactionCategory(rawValue: categoryID)?.localizedName ?? "其他",
                        totalAmount: total,
                        transactionCount: results.filter { $0.categoryID == categoryID }.count,
                        averageAmount: categoryTotals[categoryID]! / Decimal(max(results.filter { $0.categoryID == categoryID }.count, 1))
                    )
                }.sorted { $0.totalAmount > $1.totalAmount }
                
                promise(.success(statistics))
            } catch {
                promise(.failure(RepositoryError.fetchFailed(error)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Search
    public func searchByDescription(_ searchText: String) -> AnyPublisher<[TransactionEntity], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.unknown))
                return
            }
            
            let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
            request.predicate = NSPredicate(
                format: "(note CONTAINS[cd] %@ OR categoryName CONTAINS[cd] %@) AND isDeleted == NO",
                searchText, searchText
            )
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]
            
            do {
                let results = try self.context.fetch(request)
                let entities = results.map { self.mapManagedObjectToEntity($0) }
                promise(.success(entities))
            } catch {
                promise(.failure(RepositoryError.fetchFailed(error)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Mapping Methods
    private func mapEntityToManagedObject(_ entity: TransactionEntity, to managedObject: Transaction) {
        managedObject.id = entity.id
        managedObject.amount = entity.amount as NSDecimalNumber
        managedObject.categoryID = entity.categoryID
        managedObject.categoryName = entity.categoryName
        managedObject.note = entity.note
        managedObject.date = entity.date
        managedObject.source = entity.source.rawValue
        managedObject.createdAt = entity.createdAt
        managedObject.updatedAt = Date()
        managedObject.syncStatus = entity.syncStatus.rawValue
        managedObject.isDeleted = false
    }
    
    private func mapManagedObjectToEntity(_ managedObject: Transaction) -> TransactionEntity {
        return TransactionEntity(
            id: managedObject.id ?? UUID(),
            amount: managedObject.amount as Decimal? ?? 0,
            categoryID: managedObject.categoryID ?? "other",
            categoryName: managedObject.categoryName ?? "其他",
            note: managedObject.note,
            date: managedObject.date ?? Date(),
            source: TransactionEntity.TransactionSource(rawValue: managedObject.source ?? "manual") ?? .manual,
            createdAt: managedObject.createdAt ?? Date(),
            syncStatus: TransactionEntity.SyncStatus(rawValue: managedObject.syncStatus ?? "pending") ?? .pending
        )
    }
}

// MARK: - Repository Errors
public enum RepositoryError: LocalizedError {
    case unknown
    case notFound
    case saveFailed(Error)
    case fetchFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .unknown:
            return "未知错误"
        case .notFound:
            return "记录不存在"
        case .saveFailed(let error):
            return "保存失败: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "获取数据失败: \(error.localizedDescription)"
        }
    }
}