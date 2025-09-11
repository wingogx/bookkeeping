import SwiftUI

struct MainTabView: View {
    @StateObject private var mainViewModel = MainViewModel()
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("首页")
                }
            
            TransactionListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("记录")
                }
            
            BudgetView()
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("预算")
                }
            
            AnalyticsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("统计")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("设置")
                }
        }
        .environmentObject(mainViewModel)
        .accentColor(.blue)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}