import Foundation
import CoreData
import Combine

/// Core Data堆栈管理
/// 负责Core Data的初始化、持久化存储管理和上下文管理
public class CoreDataStack: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = CoreDataStack()
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "VoiceBudget")
        
        // 配置CloudKit同步
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description.")
        }
        
        // 启用CloudKit同步
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption("iCloud.com.voicebudget.app" as NSString, forKey: "NSPersistentStoreCloudKitContainerIdentifier")
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // 在生产环境中，这里应该有更优雅的错误处理
                print("Core Data error: \(error), \(error.userInfo)")
                
                // 如果加载失败，尝试删除存储并重新创建
                self.handlePersistentStoreLoadingError(container: container, error: error)
            } else {
                print("Core Data loaded successfully: \(storeDescription)")
            }
        }
        
        // 启用自动合并来自CloudKit的变更
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }()
    
    // MARK: - Contexts
    public var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    public var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    // MARK: - Private Initializer
    private init() {
        // 设置通知监听
        setupNotifications()
    }
    
    // MARK: - Save Operations
    public func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("Core Data context saved successfully")
            } catch {
                let nsError = error as NSError
                print("Core Data save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    public func saveContext(_ context: NSManagedObjectContext) {
        context.perform {
            if context.hasChanges {
                do {
                    try context.save()
                    print("Core Data background context saved successfully")
                } catch {
                    let nsError = error as NSError
                    print("Core Data background save error: \(nsError), \(nsError.userInfo)")
                }
            }
        }
    }
    
    // MARK: - Background Operations
    public func performBackgroundTask<T>(
        _ block: @escaping (NSManagedObjectContext) throws -> T
    ) -> AnyPublisher<T, Error> {
        return Future<T, Error> { promise in
            let context = self.backgroundContext
            context.perform {
                do {
                    let result = try block(context)
                    
                    if context.hasChanges {
                        try context.save()
                    }
                    
                    promise(.success(result))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Batch Operations
    public func batchDelete(fetchRequest: NSFetchRequest<NSFetchRequestResult>) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let context = self.backgroundContext
            context.perform {
                do {
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    deleteRequest.resultType = .resultTypeObjectIDs
                    
                    let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                    let objectIDArray = result?.result as? [NSManagedObjectID]
                    let changes = [NSDeletedObjectsKey: objectIDArray ?? []]
                    
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.viewContext])
                    
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    private func setupNotifications() {
        // 监听远程变更通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: persistentContainer.persistentStoreCoordinator
        )
    }
    
    @objc private func storeRemoteChange(_ notification: Notification) {
        print("Received remote store change notification")
        
        DispatchQueue.main.async {
            // 通知UI更新
            self.objectWillChange.send()
        }
    }
    
    private func handlePersistentStoreLoadingError(container: NSPersistentCloudKitContainer, error: NSError) {
        print("Attempting to recover from Core Data loading error...")
        
        // 获取存储URL
        guard let storeDescription = container.persistentStoreDescriptions.first,
              let storeURL = storeDescription.url else {
            fatalError("Unable to get store URL")
        }
        
        do {
            // 尝试删除存储文件
            let fileManager = FileManager.default
            let storeDirectory = storeURL.deletingLastPathComponent()
            let storeFiles = try fileManager.contentsOfDirectory(at: storeDirectory, 
                                                               includingPropertiesForKeys: nil, 
                                                               options: [])
            
            for file in storeFiles {
                if file.lastPathComponent.hasPrefix(storeURL.lastPathComponent) {
                    try fileManager.removeItem(at: file)
                    print("Deleted store file: \(file)")
                }
            }
            
            // 重新加载存储
            container.loadPersistentStores { _, reloadError in
                if let reloadError = reloadError {
                    fatalError("Failed to reload Core Data store after recovery: \(reloadError)")
                } else {
                    print("Core Data store reloaded successfully after recovery")
                }
            }
            
        } catch {
            fatalError("Failed to recover from Core Data error: \(error)")
        }
    }
    
    // MARK: - Debugging
    #if DEBUG
    public func printDatabaseStatistics() {
        let context = viewContext
        
        // 统计各实体的记录数
        let entityNames = ["Transaction", "Budget"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            
            do {
                let count = try context.count(for: fetchRequest)
                print("\(entityName): \(count) records")
            } catch {
                print("Failed to count \(entityName): \(error)")
            }
        }
    }
    
    public func clearAllData() {
        let entityNames = ["Transaction", "Budget"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try persistentContainer.viewContext.execute(deleteRequest)
                print("Cleared all \(entityName) records")
            } catch {
                print("Failed to clear \(entityName): \(error)")
            }
        }
        
        save()
    }
    #endif
}

// MARK: - Extensions
extension CoreDataStack {
    
    /// 创建子上下文用于批量操作
    public func createChildContext() -> NSManagedObjectContext {
        let childContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        childContext.parent = viewContext
        return childContext
    }
    
    /// 合并子上下文的更改到主上下文
    public func mergeChildContext(_ childContext: NSManagedObjectContext) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            childContext.perform {
                do {
                    if childContext.hasChanges {
                        try childContext.save()
                        
                        // 保存父上下文
                        self.viewContext.performAndWait {
                            do {
                                if self.viewContext.hasChanges {
                                    try self.viewContext.save()
                                }
                                promise(.success(()))
                            } catch {
                                promise(.failure(error))
                            }
                        }
                    } else {
                        promise(.success(()))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Error Handling
public enum CoreDataError: Error, LocalizedError {
    case saveError(Error)
    case fetchError(Error)
    case deleteError(Error)
    case invalidContext
    
    public var errorDescription: String? {
        switch self {
        case .saveError(let error):
            return "保存数据失败: \(error.localizedDescription)"
        case .fetchError(let error):
            return "获取数据失败: \(error.localizedDescription)"
        case .deleteError(let error):
            return "删除数据失败: \(error.localizedDescription)"
        case .invalidContext:
            return "无效的数据上下文"
        }
    }
}