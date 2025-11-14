//
//  ContentView.swift
//  oasa25
//
//  Created by 陈奕辰 on 2025/11/12.
//

import SwiftUI
import UniformTypeIdentifiers
// MARK: - 游戏阶段枚举
enum GamePhase: Int, Codable
{
    case selectPiece = 0
    case movePiece = 1
    case placeArrow = 2
}
//MARK: - 存档文件结构
struct gameData: Codable
{
    let chessBoard: [[Int]]
    let blackRound: Bool
    let history: [String]
    let selectedPieceRow: Int?
    let selectedPieceCol: Int?
    let gamePhase: GamePhase
    let availableMoves: [[Int]]
}
// MARK: - 扩展
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
                    currentUrl = url.path
                    if saveChessBoardToJSON(url: url)
                    {
                        unsavable = true
                        withFile = true
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
                }
            }
        }
    }
    private func initializeChessBoard()
    {
        history = []
        selectedPiece = nil
        gamePhase = .selectPiece
        availableMoves = Array(repeating: Array(repeating: 0, count: 8),count: 8)
        chessBoard = Array(repeating: Array(repeating: 0, count: 8), count: 8)// 初始化所有格子为0，设置初始棋子位置（根据Amazon棋规则）
        chessBoard[0][2] = 1//1黑方Amazon 2白方Amazon 3黑方障碍物 4白方障碍物
        chessBoard[0][5] = 1
        chessBoard[2][0] = 1
        chessBoard[2][7] = 1
        chessBoard[7][2] = 2
        chessBoard[7][5] = 2
        chessBoard[5][0] = 2
        chessBoard[5][7] = 2
    }
    private func saveChessBoardToJSON(url: URL) -> Bool
    {
        do
        {
            let encoder = JSONEncoder()
            let gameData = gameData(chessBoard: chessBoard,blackRound: blackRound,history: history,selectedPieceRow: selectedPiece?.0,selectedPieceCol: selectedPiece?.1,gamePhase: gamePhase,availableMoves: availableMoves)
            let data = try encoder.encode(gameData)
            try data.write(to: url)
            return true
        }
        catch
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
            let loadedData = try decoder.decode(gameData.self, from: data)
            
            chessBoard = loadedData.chessBoard
            blackRound = loadedData.blackRound
            history = loadedData.history
            
            if let row = loadedData.selectedPieceRow, let col = loadedData.selectedPieceCol
            {
                selectedPiece = (row, col)
            }
            else
            {
                selectedPiece = nil
            }
            
            gamePhase = loadedData.gamePhase
            availableMoves = loadedData.availableMoves
            
            return true
        }
        catch
        {
            return false
        }
    }
    private func addHistory(_ action: String)
    {
        let player = blackRound ? "黑方" : "白方"
        let historyEntry = "\(player) \(action)"
        history.insert(historyEntry, at: 0)
    }
    private func calculateAvailableMoves(from position: (Int, Int))//修复版
    {
        availableMoves = Array(repeating: Array(repeating: 0, count: 8),count: 8)// 重置所有可移动位置
        let (row, col) = position
        let directions = [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)]
        for direction in directions
        {
            var currentRow = row + direction.0
            var currentCol = col + direction.1
            var foundObstacle = false
            while currentRow >= 0 && currentRow < 8 && currentCol >= 0 && currentCol < 8// 沿着该方向一直检查直到边界
            {
                if !foundObstacle// 如果还没有遇到障碍物
                {
                    if chessBoard[currentRow][currentCol] != 0// 遇到棋子或障碍物，后续标记为红色 2
                    {
                        foundObstacle = true
                        availableMoves[currentRow][currentCol] = 2
                    }
                    else// 空位置，标记为绿色 1
                    {
                        availableMoves[currentRow][currentCol] = 1
                    }
                }
                else// 已经遇到障碍物，后面的位置都标记为红色 2
                {
                    availableMoves[currentRow][currentCol] = 2
                }
                currentRow += direction.0//行坐标
                currentCol += direction.1//列坐标
            }
        }
    }
    private func getAllAvailablePieces() -> [(Int, Int)]
    {
        let currentPlayer = blackRound ? 1 : 2
        var availablePieces: [(Int, Int)] = []
        
        for row in 0..<8
        {
            for col in 0..<8
            {
                if chessBoard[row][col] == currentPlayer
                {
                    availablePieces.append((row, col))
                }
            }
        }
        return availablePieces
    }
    private func getAllAvailableMoves() -> [(Int, Int)]
    {
        var availableMovesList: [(Int, Int)] = []
        
        for row in 0..<8
        {
            for col in 0..<8
            {
                if availableMoves[row][col] == 1
                {
                    availableMovesList.append((row, col))
                }
            }
        }
        return availableMovesList
    }
    private func getAllAvailableArrowPositions() -> [(Int, Int)]
    {
        var availableArrows: [(Int, Int)] = []
        
        for row in 0..<8
        {
            for col in 0..<8
            {
                if availableMoves[row][col] == 1
                {
                    availableArrows.append((row, col))
                }
            }
        }
        return availableArrows
    }
    // 白方随机下棋
    private func performRandomWhiteMove()//修复版
    {
        guard !blackRound && whiteAutoOperate else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)// 添加延迟，让玩家能看到AI的操作
        {
            switch gamePhase
            {
            case .selectPiece:
                // 获取所有可用的白方棋子
                let availablePieces = getAllAvailablePieces()
                // 先打乱再遍历，比反复取random更好
                let shuffledPieces = availablePieces.shuffled()
                var foundValidPiece = false
                for piece in shuffledPieces
                {
                    // 计算该棋子的可移动位置
                    calculateAvailableMoves(from: piece)
                    let availableMovesList = getAllAvailableMoves()
                    
                    // 如果这个棋子有可移动的位置，选择它
                    if !availableMovesList.isEmpty
                    {
                        selectedPiece = piece
                        gamePhase = .movePiece
                        addHistory("自动随机下棋 选择了棋子 (\(piece.0),\(piece.1))")
                        foundValidPiece = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
                        {
                            if blackRound && blackAutoOperate
                            {
                                performRandomBlackMove()
                            }
                            else if !blackRound && whiteAutoOperate
                            {
                                performRandomWhiteMove()
                            }
                        }
                        break
                    }
                }
                
                // 如果没有找到可以移动的棋子，说明游戏可能结束了
                if !foundValidPiece
                {
                    addHistory("自动随机下棋 无有效棋子可移动，黑方胜利")
                    // 这里可以添加游戏结束的逻辑
                }
                
            case .movePiece:
                guard let selected = selectedPiece else { return }
                
                // 获取所有可移动的位置
                let availableMovesList = getAllAvailableMoves()
                
                if let randomMove = availableMovesList.randomElement()
                {
                    // 移动棋子
                    chessBoard[randomMove.0][randomMove.1] = chessBoard[selected.0][selected.1]
                    chessBoard[selected.0][selected.1] = 0
                    selectedPiece = (randomMove.0, randomMove.1)
                    
                    // 重新计算可放置障碍物的位置
                    calculateAvailableMoves(from: (randomMove.0, randomMove.1))
                    gamePhase = .placeArrow
                    addHistory("自动随机下棋 移动棋子到 (\(randomMove.0),\(randomMove.1))")
                    
                    // 继续下一步
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
                    {
                        performRandomWhiteMove()
                    }
                }
                else
                {
                    // 如果没有可移动的位置，回到选择棋子阶段
                    addHistory("自动随机下棋 当前棋子无有效移动，重新选择")
                    gamePhase = .selectPiece
                    selectedPiece = nil
                    availableMoves = Array(repeating: Array(repeating: 0, count: 8),count: 8)
                    // 重新尝试选择棋子
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
                    {
                        performRandomWhiteMove()
                    }
                }
                
            case .placeArrow:
                // 获取所有可放置障碍物的位置
                let availableArrows = getAllAvailableArrowPositions()
                
                if let randomArrow = availableArrows.randomElement() {
                    // 放置障碍物
                    chessBoard[randomArrow.0][randomArrow.1] = 4 // 白方障碍物
                    
                    addHistory("自动随机下棋 放置障碍物在 (\(randomArrow.0),\(randomArrow.1))")
                    // 重置状态，切换回合
                    selectedPiece = nil
                    availableMoves = Array(repeating: Array(repeating: 0, count: 8),count: 8)
                    gamePhase = .selectPiece
                    blackRound.toggle()
                    unsavable = false
                    
                    // 检查切换回合后是否需要自动下棋
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
                    {
                        if blackRound && blackAutoOperate
                        {
                            performRandomBlackMove()
                        }
                        else if !blackRound && whiteAutoOperate
                        {
                            performRandomWhiteMove()
                        }
                    }
                }
                else
                {
                    // 如果没有可放置障碍物的位置，这通常不应该发生，但为了安全处理
                    addHistory("自动随机下棋 无有效障碍物位置，黑方胜利")
                    selectedPiece = nil
                    availableMoves = Array(repeating: Array(repeating: 0, count: 8),count: 8)
                    gamePhase = .selectPiece
                    blackRound.toggle()
                    unsavable = false
                }
            }
        }
    }
    // 黑方随机下棋
    private func performRandomBlackMove()
    {
        guard blackRound && blackAutoOperate else { return }
        
        // 添加延迟，让玩家能看到AI的操作
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
        {
            switch gamePhase
            {
            case .selectPiece:
                // 获取所有可用的黑方棋子
                let availablePieces = getAllAvailablePieces()
                
                // 随机打乱棋子顺序，尝试找到可以移动的棋子
                let shuffledPieces = availablePieces.shuffled()
                var foundValidPiece = false
                
                for piece in shuffledPieces
                {
                    // 计算该棋子的可移动位置
                    calculateAvailableMoves(from: piece)
                    let availableMovesList = getAllAvailableMoves()
                    
                    // 如果这个棋子有可移动的位置，选择它
                    if !availableMovesList.isEmpty
                    {
                        selectedPiece = piece
                        gamePhase = .movePiece
                        addHistory("自动随机下棋 选择了棋子 (\(piece.0),\(piece.1))")
                        foundValidPiece = true
                        
                        // 继续下一步
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
                        {
                            performRandomBlackMove()
                        }
                        break
                    }
                }
                
                // 如果没有找到可以移动的棋子，说明游戏可能结束了
                if !foundValidPiece
                {
                    addHistory("自动随机下棋 无有效棋子可移动，白方胜利")
                }
                
            case .movePiece:
                guard let selected = selectedPiece else { return }
                
                // 获取所有可移动的位置
                let availableMovesList = getAllAvailableMoves()
                
                if let randomMove = availableMovesList.randomElement()
                {
                    // 移动棋子
                    chessBoard[randomMove.0][randomMove.1] = chessBoard[selected.0][selected.1]
                    chessBoard[selected.0][selected.1] = 0
                    selectedPiece = (randomMove.0, randomMove.1)
                    
                    // 重新计算可放置障碍物的位置
                    calculateAvailableMoves(from: (randomMove.0, randomMove.1))
                    gamePhase = .placeArrow
                    addHistory("自动随机下棋 移动棋子到 (\(randomMove.0),\(randomMove.1))")
                    
                    // 继续下一步
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
                    {
                        performRandomBlackMove()
                    }
                }
                else
                {
                    // 如果没有可移动的位置，回到选择棋子阶段
                    addHistory("自动随机下棋 当前棋子无有效移动，重新选择")
                    gamePhase = .selectPiece
                    selectedPiece = nil
                    availableMoves = Array(repeating: Array(repeating: 0, count: 8),count: 8)
                    
                    // 重新尝试选择棋子
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
                    {
                        performRandomBlackMove()
                    }
                }
                
            case .placeArrow:
                // 获取所有可放置障碍物的位置
                let availableArrows = getAllAvailableArrowPositions()
                
                if let randomArrow = availableArrows.randomElement()
                {
                    // 放置障碍物
                    chessBoard[randomArrow.0][randomArrow.1] = 3 // 黑方障碍物
                    
                    addHistory("自动随机下棋 放置障碍物在 (\(randomArrow.0),\(randomArrow.1))")
                    // 重置状态，切换回合
                    selectedPiece = nil
                    availableMoves = Array(repeating: Array(repeating: 0, count: 8),count: 8)
                    gamePhase = .selectPiece
                    blackRound.toggle()
                    unsavable = false
                    // 检查切换回合后是否需要自动下棋
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
                    {
                        if blackRound && blackAutoOperate
                        {
                            performRandomBlackMove()
                        }
                        else if !blackRound && whiteAutoOperate
                        {
                            performRandomWhiteMove()
                        }
                    }
                }
                else
                {
                    // 如果没有可放置障碍物的位置，这通常不应该发生，但为了安全处理
                    addHistory("自动随机下棋 无有效障碍物位置，白方胜利")
                    selectedPiece = nil
                    availableMoves = Array(repeating: Array(repeating: 0, count: 8),count: 8)
                    gamePhase = .selectPiece
                    blackRound.toggle()
                    unsavable = false
                }
            }
        }
    }
    private func handleSquareTap(row: Int, column: Int)//修复版
    {
        let currentPlayer = blackRound ? 1 : 2
        if (blackRound && blackAutoOperate) || (!blackRound && whiteAutoOperate)
        {
            return// 如果是自动下棋回合，忽略玩家点击
        }
        switch gamePhase
        {
        case .selectPiece:
            // 选择棋子阶段：点击己方棋子
            if chessBoard[row][column] == currentPlayer
            {
                selectedPiece = (row, column)
                calculateAvailableMoves(from: (row, column))
                gamePhase = .movePiece
                addHistory("选择了棋子 (\(row),\(column))")
            }
            
        case .movePiece:
            guard let selected = selectedPiece else { return }
            if availableMoves[row][column] == 1
            {
                // 移动棋子到绿色位置
                chessBoard[row][column] = chessBoard[selected.0][selected.1]
                chessBoard[selected.0][selected.1] = 0
                selectedPiece = (row, column)
                
                // 重新计算可放置障碍物的位置
                calculateAvailableMoves(from: (row, column))
                gamePhase = .placeArrow
                addHistory("移动棋子到 (\(row),\(column))")
                
                // 如果是自动下棋回合，继续自动放置障碍物
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
                {
                    if blackRound && blackAutoOperate
                    {
                        performRandomBlackMove()
                    }
                    else if !blackRound && whiteAutoOperate
                    {
                        performRandomWhiteMove()
                    }
                }
            }
            else if chessBoard[row][column] == currentPlayer
            {
                // 重新选择其他棋子
                selectedPiece = (row, column)
                calculateAvailableMoves(from: (row, column))
                addHistory("重新选择了棋子 (\(row),\(column))")
            }
            
        case .placeArrow:
            if availableMoves[row][column] == 1
            {
                // 放置障碍物
                chessBoard[row][column] = blackRound ? 3 : 4
                
                addHistory("放置障碍物在 (\(row),\(column))")
                // 重置状态，切换回合
                selectedPiece = nil
                availableMoves = Array(repeating: Array(repeating: 0, count: 8),count: 8)
                gamePhase = .selectPiece
                blackRound.toggle()
                
                unsavable = false
                
                // 检查切换回合后是否需要自动下棋
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
                {
                    if blackRound && blackAutoOperate
                    {
                        performRandomBlackMove()
                    }
                    else if !blackRound && whiteAutoOperate
                    {
                        performRandomWhiteMove()
                    }
                }
            }
        }
    }
}
// MARK: - 棋盘格子视图 - 修复版
struct ChessSquareView: View
{
    let row: Int
    let column: Int
    let value: Int
    let action: () -> Void
    let blackRound: Bool
    let gamePhase: GamePhase
    let availableMoves: [[Int]]
    var body: some View
    {
        ZStack
        {
            Rectangle()
                .fill(getSquareColor())
                .frame(width: 80, height: 80)
                .overlay(Rectangle().stroke(Color.black.opacity(0.2), lineWidth: 1))
            Button(action: action)
            {
                ZStack
                {
                    Rectangle()
                        .fill(Color.blue.opacity(0.01))
                        .frame(width: 75, height: 75)
                    
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
            .disabled(!isInteractive())
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func getSquareColor() -> Color
    {
        if availableMoves[row][column] == 1
        {
            return Color.green.opacity(0.5) // 可移动位置显示绿色
        }
        else if availableMoves[row][column] == 2
        {
            return Color.red.opacity(0.5) // 不可移动位置显示红色
        }
        else
        {
            return (row + column) % 2 == 0 ? Color.white : Color.gray
                .opacity(0.3)
        }
    }
    
    private func isInteractive() -> Bool
    {
        let currentPlayer = blackRound ? 1 : 2
        
        switch gamePhase
        {
        case .selectPiece:
            // 只能点击己方棋子
            return value == currentPlayer
            
        case .movePiece:
            // 可以点击可移动位置（绿色）或己方棋子（重新选择）
            return availableMoves[row][column] == 1 || value == currentPlayer
            
        case .placeArrow:
            // 只能点击可放置障碍物的位置（绿色）
            return availableMoves[row][column] == 1
        }
    }
}
// MARK: - 棋盘行视图
struct ChessBoardRowView: View
{
    let row: Int
    let chessBoard: [[Int]]
    let onSquareTap: (Int, Int) -> Void
    let blackRound: Bool
    let gamePhase: GamePhase
    let availableMoves: [[Int]]
    
    var body: some View
    {
        HStack(spacing: 0)
        {
            ForEach(0..<8, id: \.self)
            {
                column in
                ChessSquareView(row: row,column: column,value: chessBoard[row][column],action:{onSquareTap(row, column)},blackRound: blackRound,gamePhase: gamePhase,availableMoves: availableMoves)
            }
        }
    }
}
// MARK: - 棋盘视图
struct ChessBoardView: View
{
    let chessBoard: [[Int]]
    let onSquareTap: (Int, Int) -> Void
    let blackRound: Bool
    let gamePhase: GamePhase
    let availableMoves: [[Int]]
    
    var body: some View
    {
        VStack(spacing: 0)// 列标签 (0,1,2...)
        {
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
            
            HStack(spacing: 0)// 行标签 (0,1,2...)
            {
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
                        ChessBoardRowView(row: row,chessBoard: chessBoard,onSquareTap: onSquareTap,blackRound: blackRound,gamePhase: gamePhase,availableMoves: availableMoves)
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
    let currentUrl: String
    let blackRound: Bool
    let isPlaying: Bool
    let history: [String]
    let gamePhase: GamePhase
    let whiteAutoOperate: Bool
    
    
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
            Spacer()
                .frame(height: 25)
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
            
            Text("当前阶段：\(phaseDescription)")
                .font(.system(size: 15))
                .padding(.bottom, 5)
            
            Text("历史操作：")
                .font(.system(size: 15))
            
            List(history,id:\.self)
            {
                item in
                Text(item)
                    .font(.system(size: 12))
            }
            .frame(height: 240)
        }
    }
    
    private var phaseDescription: String
    {
        switch gamePhase
        {
        case .selectPiece:
            return "选择棋子"
        case .movePiece:
            return "移动棋子"
        case .placeArrow:
            return "放置障碍物"
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
    let onQuickSave: () -> Void
    let onQuit: () -> Void
    let unsavable: Bool
    let isPlaing: Bool//我保留了部分拼写错误，以表示这个程序有我自己写的代码
    let withFile:Bool
    @State private var showNewGameDoubleCheck = false
    @State private var showLoadDoubleCheck = false
    @State private var showQuitDoubleCheck = false
    
    var body: some View
    {
        VStack
        {
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
            
            Text("Cirrus")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            
            Spacer()
                .frame(height: 15)
            if unsavable
            {
                MenuButtonView(title: "新游戏",icon: "plus",action: onNewGame,disabled: false)
            }
            else
            {
                MenuButtonView(title: "新游戏",icon: "plus",action:{showNewGameDoubleCheck=true},disabled: false)
            }
            Spacer().frame(height: 15)
            
            if isPlaing
            {
                if unsavable
                {
                    MenuButtonView(title: "已保存",icon: "square.and.arrow.down",action: onQuickSave,disabled: true)
                }
                else
                {
                    MenuButtonView(title: "快速保存",icon: "square.and.arrow.down",action: onQuickSave,disabled: !withFile)
                    Spacer().frame(height: 15)
                    MenuButtonView(title: "另存为",icon: "document.badge.plus",action: onSave,disabled: false)
                }
                Spacer().frame(height: 15)
            }
            if unsavable
            {
                MenuButtonView(title: "读取",icon: "folder",action: onLoad,disabled: false)
                Spacer().frame(height: 15)
                MenuButtonView(title: "退出全部",icon: "xmark",action:onQuit,disabled: false)
            }
            else
            {
                MenuButtonView(title: "读取",icon: "folder",action:{showLoadDoubleCheck=true},disabled: false)
                Spacer().frame(height: 15)
                MenuButtonView(title: "退出全部",icon: "xmark",action:{showQuitDoubleCheck=true},disabled: false)
            }
        }
        .alert("舍弃当前棋局并创建新棋局？", isPresented: $showNewGameDoubleCheck)
        {
            Button("返回", role: .cancel) { }
            Button("继续", role: .destructive)
            {
                onNewGame()
            }
        }
        message:
        {
            Text("当前棋局尚未保存，是否继续创建新游戏？")
        }
        .alert("舍弃当前棋局并读取？", isPresented: $showLoadDoubleCheck)
        {
            Button("返回", role: .cancel) { }
            Button("继续", role: .destructive)
            {
                onLoad()
            }
        }
        message:
        {
            Text("当前棋局尚未保存，是否继续读取其他棋局？")
        }
        .alert("舍弃当前棋局并退出？", isPresented: $showQuitDoubleCheck)
        {
            Button("返回", role: .cancel) { }
            Button("继续", role: .destructive)
            {
                onQuit()
            }
        }
        message:
        {
            Text("当前棋局尚未保存，是否继续退出？")
        }
        Spacer().frame(height: 20)
    }
}
// MARK: - 主视图
struct ContentView: View
{
    @State var withFile = false
    @State var chessBoard = Array(repeating: Array(repeating: 0, count: 8),count: 8)
    @State var currentUrl: String = ""
    @State var unsavable = true
    @State var isPlaying = false
    @State var blackRound = true
    @State var history: [String] = []
    @State var availableMoves: [[Int]] = Array(repeating: Array(repeating: 0, count: 8),count: 8)
    @State var selectedPiece: (Int, Int)? = nil
    @State var gamePhase: GamePhase = .selectPiece
    @State var whiteAutoOperate = false
    @State var blackAutoOperate = false
    
    var body: some View
    {
        HStack(spacing: 0)
        {
            // 左侧区域
            VStack
            {
                SidebarView(withFile: withFile,currentUrl: currentUrl,blackRound: blackRound,isPlaying: isPlaying,history: history,gamePhase: gamePhase,whiteAutoOperate: whiteAutoOperate)
                if isPlaying
                {
                    Toggle("黑方自动下棋", isOn: $blackAutoOperate)
                        .onChange(of: blackAutoOperate)
                    {
                        newValue in
                        if newValue && blackRound// 当开启自动下棋且是黑方回合时，立即开始自动操作
                        {
                            performRandomBlackMove()
                        }
                    }
                    Toggle("白方自动下棋", isOn: $whiteAutoOperate)
                        .onChange(of: whiteAutoOperate)
                    {
                        newValue in
                        if newValue && !blackRound// 当开启自动下棋且是白方回合时，立即开始自动操作
                        {
                            performRandomWhiteMove()
                        }
                    }
                }
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                MainMenuView(//设置各个主菜单按钮的效果
                    onNewGame:
                        {
                            initializeChessBoard()
                            isPlaying = true
                            unsavable = false
                            withFile = false
                            blackRound = true
                        },
                    onSave: { saveGame() },
                    onLoad: { loadGame() },
                    onQuickSave:
                        {
                            let url=URL(fileURLWithPath: currentUrl)
                            saveChessBoardToJSON(url: url)
                            unsavable=true
                        },
                    onQuit:
                        {
                            NSApplication.shared.terminate(nil)
                        },
                    unsavable: unsavable,
                    isPlaing: isPlaying,
                    withFile: withFile
                )
            }
            
            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)
                .padding()
            
            // 棋盘区域
            ChessBoardView(chessBoard: chessBoard,onSquareTap: handleSquareTap,blackRound: blackRound,gamePhase: gamePhase,availableMoves: availableMoves)
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
