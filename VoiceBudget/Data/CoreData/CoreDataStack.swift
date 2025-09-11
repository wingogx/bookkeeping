import Foundation
import CoreData

/// Core Data数据栈管理器
/// 负责管理NSPersistentContainer和NSManagedObjectContext
class CoreDataStack {
    
    /// 是否使用内存存储（用于测试）
    private let inMemory: Bool
    
    /// 持久化容器
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "VoiceBudgetModel")
        
        if inMemory {
            // 配置内存存储用于测试
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // 配置CloudKit同步
            let storeDescription = container.persistentStoreDescriptions.first
            storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // 启用文件保护（仅iOS）
            #if os(iOS)
            storeDescription?.setOption(
                FileProtectionType.completeUntilFirstUserAuthentication as NSString,
                forKey: NSPersistentStoreFileProtectionKey
            )
            #endif
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // 在生产环境中，应该有更完善的错误处理
                fatalError("Core Data加载失败: \(error), \(error.userInfo)")
            }
        }
        
        // 配置视图上下文
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    /// 主上下文（主线程使用）
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    /// 后台上下文（后台线程使用）
    var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    // MARK: - 初始化
    
    /// 初始化Core Data栈
    /// - Parameter inMemory: 是否使用内存存储，默认为false
    init(inMemory: Bool = false) {
        self.inMemory = inMemory
    }
    
    // MARK: - 保存操作
    
    /// 保存主上下文
    func save() {
        save(context: context)
    }
    
    /// 保存指定上下文
    /// - Parameter context: 要保存的上下文
    private func save(context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // 在生产环境中，应该有更完善的错误处理和日志记录
                let nsError = error as NSError
                fatalError("Core Data保存失败: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    /// 在后台执行操作并保存
    /// - Parameter block: 要执行的操作
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = backgroundContext
        context.perform {
            block(context)
            self.save(context: context)
        }
    }
}