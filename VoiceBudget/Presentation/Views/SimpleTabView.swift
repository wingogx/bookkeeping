import SwiftUI

struct SimpleTabView: View {
    var body: some View {
        TabView {
            // 首页 - 简化版
            NavigationView {
                VStack(spacing: 30) {
                    Image(systemName: "mic.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 80))
                    
                    Text("VoiceBudget")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("点击麦克风开始语音记账")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        // 语音记账功能
                        print("开始语音记账")
                    }) {
                        HStack {
                            Image(systemName: "mic.fill")
                            Text("开始记账")
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
                .navigationTitle("首页")
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("首页")
            }
            
            // 记录页面
            NavigationView {
                List {
                    Text("暂无记录")
                        .foregroundColor(.secondary)
                }
                .navigationTitle("交易记录")
            }
            .tabItem {
                Image(systemName: "list.bullet")
                Text("记录")
            }
            
            // 预算页面
            NavigationView {
                VStack {
                    Text("预算管理")
                        .font(.title)
                        .padding()
                    
                    Text("暂未设置预算")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .navigationTitle("预算")
            }
            .tabItem {
                Image(systemName: "chart.pie.fill")
                Text("预算")
            }
            
            // 统计页面
            NavigationView {
                VStack {
                    Text("数据统计")
                        .font(.title)
                        .padding()
                    
                    Text("暂无数据")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .navigationTitle("统计")
            }
            .tabItem {
                Image(systemName: "chart.bar.fill")
                Text("统计")
            }
            
            // 设置页面
            NavigationView {
                List {
                    Section("应用设置") {
                        HStack {
                            Image(systemName: "mic.fill")
                            Text("语音识别")
                            Spacer()
                            Text("中文")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "paintbrush.fill")
                            Text("主题")
                            Spacer()
                            Text("自动")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section("关于") {
                        HStack {
                            Image(systemName: "info.circle.fill")
                            Text("版本")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .navigationTitle("设置")
            }
            .tabItem {
                Image(systemName: "gear")
                Text("设置")
            }
        }
        .accentColor(.blue)
    }
}

struct SimpleTabView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleTabView()
    }
}