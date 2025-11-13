//
//  ContentView.swift
//  oasa25
//
//  Created by 陈奕辰 on 2025/11/12.
//

import SwiftUI
import UniformTypeIdentifiers

//MARK: - 存档文件结构
struct gameData:Codable
{
    let chessBoard:[[Int]]
    let blackRound:Bool
    let history:[String]
}
// MARK: - 扩展：棋局存取功能
extension ContentView
{
    private func saveGame()
    {
        let savePanel = NSSavePanel()
        savePanel.title = "保存游戏"
        savePanel.message = "选择保存游戏的目录和文件名"
        savePanel.allowedContentTypes = [UTType.json]
        savePanel.nameFieldStringValue = "新游戏.json"
        savePanel.allowsOtherFileTypes = false
        
        savePanel.begin
        {
            response in
            if response == .OK
            {
                if let url = savePanel.url
                {
                    currentUrl=url.path
                    if saveChessBoardToJSON(url: url)// 保存到 JSON 文件
                    {
                        print("新游戏已保存到: \(url.path)")
                        unsavable=true
                        withFile=true
                    }
                    else
                    {
                        print("保存失败")
                    }
                }
            }
        }
    }
    private func loadGame()
    {
        let openPanel = NSOpenPanel()
        openPanel.title = "读取游戏"
        openPanel.message = "选择游戏存档文件"
        openPanel.allowedContentTypes = [UTType.json]
        openPanel.allowsMultipleSelection = false

        openPanel.begin
        {
            response in
            if response == .OK, let url = openPanel.url
            {
                if loadChessBoardFromJSON(url: url)
                {
                    currentUrl = url.path
                    withFile = true
                    isPlaying = true
                    unsavable = true
                    print("游戏已从 \(url.path) 加载")
                }
                else
                {
                    print("读取失败")
                }
            }
        }
    }
    
    private func initializeChessBoard()
    {
        history = []
        //初始化所有格子为0（空）
        chessBoard = Array(repeating: Array(repeating: 0, count: 8), count: 8)
        //设置初始棋子位置（根据Amazon棋规则）
        //1黑方Amazon 2白方Amazon 3黑方障碍物 4白方障碍物
        //黑方Amazon初始位置
        chessBoard[0][2] = 1
        chessBoard[0][5] = 1
        chessBoard[3][0] = 1
        chessBoard[3][7] = 1
        //白方Amazon初始位置
        chessBoard[7][2] = 2
        chessBoard[7][5] = 2
        chessBoard[4][0] = 2
        chessBoard[4][7] = 2
    }
    
    private func saveChessBoardToJSON(url: URL) -> Bool
    {
        do
        {
            let encoder = JSONEncoder()
            let gameData = gameData(chessBoard: chessBoard, blackRound: blackRound,history: history)
            let data = try encoder.encode(gameData)
            try data.write(to: url)
            return true
        } catch
        {
            print("保存JSON失败: \(error)")
            return false
        }
    }
    private func loadChessBoardFromJSON(url: URL) -> Bool
    {
        do
        {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let gameData = try decoder.decode(gameData.self, from: data)
            
            chessBoard = gameData.chessBoard
            blackRound = gameData.blackRound
            history = gameData.history // 加载历史记录
            return true
        } catch
        {
            print("读取JSON失败: \(error)")
            return false
        }
    }
    // 添加历史记录
    private func addHistory(_ action: String)
    {
        let player = blackRound ? "黑方" : "白方"
        let historyEntry = "\(player) \(action)"
        history.insert(historyEntry, at: 0) // 添加到开头，最新的在最上面
    }
}
// MARK: - 棋盘格子视图
struct ChessSquareView: View
{
    let row: Int
    let column: Int
    let value: Int
    let action: () -> Void
    let blackRound:Bool
    
    var body: some View
    {
        ZStack
        {
            Rectangle()
                .fill((row + column) % 2 == 0 ? Color.white : Color.gray.opacity(0.3))
                .frame(width: 80, height: 80)
                .overlay(Rectangle().stroke(Color.black.opacity(0.2), lineWidth: 1))
            
            Button(action: action)
            {
                ZStack
                {
                    Rectangle()
                        .fill(Color.red.opacity(0.5)) // 半透明(调试完改成0)(.green与.red)
                        .frame(width: 75, height: 75) // 稍小于格子
                    if value == 1
                    {
                        Image(systemName: "person.fill")
                            .font(.system(size: 30))
                    }
                    else if value == 2
                    {
                        Image(systemName: "person")
                            .font(.system(size: 30))
                    }
                    else if value == 3
                    {
                        Image(systemName: "nosign.app.fill")
                            .font(.system(size: 30))
                    }
                    else if value == 4
                    {
                        Image(systemName: "nosign.app")
                            .font(.system(size: 30))
                    }
                }
            }
            .disabled(value == 0||value==1 && !blackRound||value==2 && blackRound||value == 3||value == 4)
            .buttonStyle(PlainButtonStyle()) // 使用无样式按钮
        }
    }
}

// MARK: - 棋盘行视图
struct ChessBoardRowView: View
{
    let row: Int
    let chessBoard: [[Int]]
    let onSquareTap: (Int, Int) -> Void
    let blackRound:Bool
    
    var body: some View
    {
        HStack(spacing: 0)
        {
            ForEach(0..<8, id: \.self)
            {
                column in
                ChessSquareView(
                    row: row,
                    column: column,
                    value: chessBoard[row][column],
                    action: { onSquareTap(row, column) },
                    blackRound: blackRound
                )
            }
        }
    }
}

// MARK: - 棋盘视图
struct ChessBoardView: View
{
    let chessBoard: [[Int]]
    let onSquareTap: (Int, Int) -> Void
    let blackRound:Bool
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            // 列标签 (0,1,2...)
            HStack(spacing: 0)
            {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
                
                ForEach(0..<8, id: \.self)
                {
                    column in
                    Text(String(column))
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 80, height: 30)
                        .foregroundColor(.primary)
                }
            }
            
            HStack(spacing: 0)
            {
                // 行标签 (0,1,2...)
                VStack(spacing: 0)
                {
                    ForEach(0..<8, id: \.self)
                    {
                        row in
                        Text(String(row))
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 30, height: 80)
                            .foregroundColor(.primary)
                    }
                }
                
                // 棋盘主体
                VStack(spacing: 0)
                {
                    ForEach(0..<8, id: \.self)
                    {
                        row in
                        ChessBoardRowView(
                            row: row,
                            chessBoard: chessBoard,
                            onSquareTap: onSquareTap,
                            blackRound: blackRound
                        )
                    }
                }
                .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
                .padding()
            }
        }
        .frame(width: 800)
    }
}

// MARK: - 菜单按钮视图
struct MenuButtonView: View
{
    let title: String
    let icon: String
    let action: () -> Void
    let disabled: Bool
    
    var body: some View
    {
        Button(action: action)
        {
            Label(title, systemImage: icon)
                .font(.system(size: 15))
                .frame(maxWidth: 150)
        }
        .disabled(disabled)
        .buttonStyle(.bordered)
    }
}

// MARK: - 侧边栏视图
struct SidebarView: View
{
    let withFile: Bool
    let currentUrl:String
    let blackRound:Bool
    let isPlaying:Bool
    let history: [String]
    var body: some View
    {
        VStack
        {
            Spacer()
                .frame(height: 10)
            
            if isPlaying
            {
                gameInfoView
            }
            else
            {
                welcomeView
            }
        }
        .frame(width: 320)
    }
    
    private var gameInfoView: some View
    {
        VStack
        {
            if withFile
            {
                Text("当前存档文件：\(currentUrl)")
                    .font(.system(size: 10))
            }
            else
            {
                Text("新游戏：尚未存档")
                    .font(.system(size: 10))
            }
            if blackRound
            {
                Text("当前回合：黑方")
                    .font(.system(size: 25, weight: .medium))
            }
            else
            {
                Text("当前回合：白方")
                    .font(.system(size: 25, weight: .medium))
            }
            Text("历史操作：")
                .font(.system(size: 15))
                
            List(history, id: \.self)
            {
                item in
                Text(item)
                    .font(.system(size: 12))
            }
            .frame(height: 320)
        }
    }
    
    private var welcomeView: some View
    {
        Text("请先打开一个存档，或开启新游戏……")
            .font(.system(size: 25, weight: .medium))
    }
}

// MARK: - 主菜单视图
struct MainMenuView: View
{
    let onNewGame: () -> Void
    let onSave: () -> Void
    let onLoad: () -> Void
    let onCommand: () -> Void
    let onQuit: () -> Void
    let unsavable:Bool
    let withCommandline:Bool
    let isPlaing:Bool
    
    var body: some View
    {
        VStack {
            Spacer()
                .frame(height: 50)
            
            Image(systemName: "list.bullet")
                .font(.system(size: 20))
                .foregroundStyle(.primary)
            
            Text("Amazon棋 菜单")
                .font(.system(size: 20))
                .foregroundStyle(.primary)
            
            Text("2025秋 计算概论A 大作业")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            
            Text("陈奕辰 数学科学学院 2500010834")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            
            Spacer()
                .frame(height: 15)
            
            MenuButtonView(title: "新游戏", icon: "plus", action: onNewGame,disabled: false)
            Spacer().frame(height: 15)
            if isPlaing
            {
                if unsavable
                {
                    MenuButtonView(title: "已保存", icon: "square.and.arrow.down", action: onSave,disabled: unsavable)
                    Spacer().frame(height: 15)
                }
                else
                {
                    MenuButtonView(title: "另存为", icon: "square.and.arrow.down", action: onSave,disabled: unsavable)
                    Spacer().frame(height: 15)
                }
            }
            
            MenuButtonView(title: "读取", icon: "folder", action: onLoad,disabled: false)
            Spacer().frame(height: 15)
            if isPlaing
            {
                if withCommandline
                {
                    MenuButtonView(title: "关闭命令行", icon: "text.and.command.macwindow", action: onCommand,disabled: false)
                    Spacer().frame(height: 15)
                }
                else
                {
                    MenuButtonView(title: "以命令行输入", icon: "text.and.command.macwindow", action: onCommand,disabled: false)
                    Spacer().frame(height: 15)
                }
            }
            
            MenuButtonView(title: "退出全部", icon: "xmark", action: onQuit,disabled: false)
            Spacer().frame(height: 15)
        }
        .padding()
    }
}

// MARK: - 主视图
struct ContentView: View
{
    @State private var withFile = false
    @State var chessBoard = Array(repeating: Array(repeating: 0, count: 8), count: 8)
    @State var currentUrl:String="0"
    @State var unsavable=true
    @State var withCommandline=false
    @State var isPlaying=false
    @State var blackRound=true
    @State var history: [String]=[]
    
    var body: some View
    {
        HStack(spacing: 0)
        {
            // 左侧区域
            VStack
            {
                SidebarView(withFile: withFile,currentUrl: currentUrl,blackRound:blackRound,isPlaying: isPlaying,history: history)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                MainMenuView(
                    onNewGame: {initializeChessBoard();isPlaying = true;unsavable=false;withFile=false;blackRound=true},
                    // 初始化棋盘状态：Amazon棋的初始布局
                    onSave: {saveGame()},
                    onLoad: {loadGame()},
                    onCommand: {print("command");withCommandline = !withCommandline},
                    onQuit: {NSApplication.shared.terminate(nil)},
                    unsavable: unsavable,
                    withCommandline: withCommandline,
                    isPlaing: isPlaying
                )
            }
            
            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)
                .padding()
            
            // 棋盘区域
            ChessBoardView(chessBoard: chessBoard,onSquareTap:
                            {
                                row, column in
                                print("点击了格子(\(row),\(column))")
                                // 在这里处理棋盘点击逻辑
                                addHistory("点击 (\(row),\(column))")
                                blackRound = !blackRound
                                unsavable=false
                            }
                           ,blackRound: blackRound)
            
        }
        .onAppear
        {
            setWindowTitle()
        }
    }
    
    private func setWindowTitle()
    {
        if let window = NSApplication.shared.windows.first
        {
            window.title = "这个大アサ的作者数分I期中考了25分高分"
        }
    }
}

#Preview
{
    ContentView()
}
