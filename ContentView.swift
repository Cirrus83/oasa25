//
//  ContentView.swift
//  oasa25
//
//  Created by Cirrus on 2025/11/12.
//

import Combine
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 游戏阶段枚举
enum GamePhase: Int, Codable {
    case selectPiece = 0
    case movePiece = 1
    case placeArrow = 2
}

// MARK: - 历史记录条目（修复版）
struct HistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let action: String

    init(action: String) {
        self.id = UUID()
        self.action = action
    }

    // 为了兼容现有代码的描述
    var description: String { action }
}

// MARK: - 存档文件结构（修复版）
struct GameData: Codable {
    let chessBoard: [[Int]]
    let blackRound: Bool
    let history: [HistoryEntry]  // 修改为HistoryEntry数组
    let selectedPieceRow: Int?
    let selectedPieceCol: Int?
    let gamePhase: GamePhase
    let availableMoves: [[Int]]
    let isGameOver: Bool  // 新增：游戏结束状态
    let blackStrategy: String
    let whiteStrategy: String
    let roundNum: Int
    let mcList: [Int]
    let blackControlFactor: Double
    let blackSafetyFactor: Double
    let blackSurroundFactor: Double
    let blackCenterFactor: Double
    let whiteControlFactor: Double
    let whiteSafetyFactor: Double
    let whiteSurroundFactor: Double
    let whiteCenterFactor: Double
}

// MARK: - 游戏状态环境对象
class GameState: ObservableObject {
    @Published var withFile = false
    @Published var chessBoard = Array(
        repeating: Array(repeating: 0, count: 8),
        count: 8
    )
    @Published var currentUrl: String = ""
    @Published var unsavable = true
    @Published var isPlaying = false
    @Published var blackRound = true
    @Published var history: [HistoryEntry] = []  // 修改为HistoryEntry数组
    @Published var availableMoves: [[Int]] = Array(
        repeating: Array(repeating: 0, count: 8),
        count: 8
    )
    @Published var selectedPiece: (Int, Int)? = nil
    @Published var gamePhase: GamePhase = .selectPiece
    @Published var whiteAutoOperate = false
    @Published var blackAutoOperate = false
    @Published var isGameOver: Bool = false  // 新增：游戏结束状态
    @Published var blackStrategy: String = "纯随机下棋"
    @Published var whiteStrategy: String = "纯随机下棋"
    @Published var roundNum: Int = 0
    @Published var mcList: [Int] = []  // 结构：[当前回合数,是否为黑方行动,选择棋子行坐标,选择棋子列坐标,移动棋子行坐标,移动棋子列坐标,放置障碍物行坐标,放置障碍物列坐标]
    @Published var blackControlFactor: Double = 1
    @Published var blackSafetyFactor: Double = 1
    @Published var blackSurroundFactor: Double = 10
    @Published var blackCenterFactor: Double = 1
    @Published var whiteControlFactor: Double = 1
    @Published var whiteSafetyFactor: Double = 1
    @Published var whiteSurroundFactor: Double = 10
    @Published var whiteCenterFactor: Double = 1
}

// MARK: - 游戏逻辑管理器
struct GameManager {
    let gameState: GameState

    // MARK: - 文件操作与游戏初始化
    func saveGame() {
        let savePanel = NSSavePanel()
        savePanel.title = "保存游戏"
        savePanel.message = "选择保存游戏的目录和文件名"
        savePanel.allowedContentTypes = [UTType.json]
        savePanel.nameFieldStringValue = "新游戏.json"
        savePanel.allowsOtherFileTypes = false

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                self.gameState.currentUrl = url.path
                if self.saveChessBoardToJSON(url: url) {
                    self.gameState.unsavable = true
                    self.gameState.withFile = true
                }
            }
        }
    }

    func loadGame() {
        let openPanel = NSOpenPanel()
        openPanel.title = "读取游戏"
        openPanel.message = "选择游戏存档文件"
        openPanel.allowedContentTypes = [UTType.json]
        openPanel.allowsMultipleSelection = false

        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                if self.loadChessBoardFromJSON(url: url) {
                    self.gameState.currentUrl = url.path
                    self.gameState.withFile = true
                    self.gameState.isPlaying = true
                    self.gameState.unsavable = true
                }
            }
        }
    }

    func saveChessBoardToJSON(url: URL) -> Bool {
        do {
            let encoder = JSONEncoder()
            // 使用新的GameData结构
            let gameData = GameData(
                chessBoard: gameState.chessBoard,
                blackRound: gameState.blackRound,
                history: gameState.history,  // 现在类型匹配了
                selectedPieceRow: gameState.selectedPiece?.0,
                selectedPieceCol: gameState.selectedPiece?.1,
                gamePhase: gameState.gamePhase,
                availableMoves: gameState.availableMoves,
                isGameOver: gameState.isGameOver,  // 新增：保存游戏结束状态
                blackStrategy: gameState.blackStrategy,
                whiteStrategy: gameState.whiteStrategy,
                roundNum: gameState.roundNum,
                mcList: gameState.mcList,
                blackControlFactor: gameState.blackControlFactor,
                blackSafetyFactor: gameState.blackSafetyFactor,
                blackSurroundFactor: gameState.blackSurroundFactor,
                blackCenterFactor: gameState.blackSafetyFactor,
                whiteControlFactor: gameState.whiteControlFactor,
                whiteSafetyFactor: gameState.whiteSafetyFactor,
                whiteSurroundFactor: gameState.whiteSurroundFactor,
                whiteCenterFactor: gameState.whiteCenterFactor
            )
            let data = try encoder.encode(gameData)
            try data.write(to: url)
            return true
        } catch {
            print("保存JSON失败: \(error)")
            return false
        }
    }

    func loadChessBoardFromJSON(url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let loadedData = try decoder.decode(GameData.self, from: data)

            gameState.chessBoard = loadedData.chessBoard
            gameState.blackRound = loadedData.blackRound
            gameState.history = loadedData.history  // 现在类型匹配了

            if let row = loadedData.selectedPieceRow,
                let col = loadedData.selectedPieceCol
            {
                gameState.selectedPiece = (row, col)
            } else {
                gameState.selectedPiece = nil
            }

            gameState.gamePhase = loadedData.gamePhase
            gameState.availableMoves = loadedData.availableMoves
            gameState.isGameOver = loadedData.isGameOver  // 新增：加载游戏结束状态

            return true
        } catch {
            print("读取JSON失败: \(error)")
            return false
        }
    }
    func initializeChessBoard() {
        gameState.history = []
        gameState.selectedPiece = nil
        gameState.gamePhase = .selectPiece
        gameState.availableMoves = Array(
            repeating: Array(repeating: 0, count: 8),
            count: 8
        )
        gameState.chessBoard = Array(
            repeating: Array(repeating: 0, count: 8),
            count: 8
        )
        gameState.isGameOver = false  // 新增：重置游戏结束状态
        gameState.blackAutoOperate = false  // 重置自动下棋
        gameState.whiteAutoOperate = false  // 重置自动下棋

        // 设置初始棋子位置（根据Amazon棋规则）
        // 1黑方Amazon 2白方Amazon 3黑方障碍物 4白方障碍物
        gameState.chessBoard[0][2] = 1
        gameState.chessBoard[0][5] = 1
        gameState.chessBoard[2][0] = 1
        gameState.chessBoard[2][7] = 1
        gameState.chessBoard[7][2] = 2
        gameState.chessBoard[7][5] = 2
        gameState.chessBoard[5][0] = 2
        gameState.chessBoard[5][7] = 2
    }

    func addHistory(_ action: String) {
        let player = gameState.blackRound ? "黑方" : "白方"
        let historyEntry = HistoryEntry(
            action: "\(player) 第\(gameState.roundNum)回合 \(action)"
        )
        gameState.history.insert(historyEntry, at: 0)
    }
    // MARK: - 算法部分
    func calculateAvailableMoves(from position: (Int, Int)) {
        gameState.availableMoves = Array(
            repeating: Array(repeating: 0, count: 8),
            count: 8
        )
        let (row, col) = position
        let directions = [
            (-1, -1), (-1, 0), (-1, 1),
            (0, -1), (0, 1),
            (1, -1), (1, 0), (1, 1),
        ]

        for direction in directions {
            var currentRow = row + direction.0
            var currentCol = col + direction.1
            var foundObstacle = false

            while currentRow >= 0 && currentRow < 8 && currentCol >= 0
                && currentCol < 8
            {
                if !foundObstacle {
                    if gameState.chessBoard[currentRow][currentCol] != 0 {
                        foundObstacle = true
                        gameState.availableMoves[currentRow][currentCol] = 2
                    } else {
                        gameState.availableMoves[currentRow][currentCol] = 1
                    }
                } else {
                    gameState.availableMoves[currentRow][currentCol] = 2
                }
                currentRow += direction.0
                currentCol += direction.1
            }
        }
    }

    func getAllAvailablePieces() -> [(Int, Int)] {
        let currentPlayer = gameState.blackRound ? 1 : 2
        var availablePieces: [(Int, Int)] = []

        for row in 0..<8 {
            for col in 0..<8 {
                if gameState.chessBoard[row][col] == currentPlayer {
                    availablePieces.append((row, col))
                }
            }
        }
        return availablePieces
    }

    func getAllCounterPieces() -> [(Int, Int)] {
        let currentPlayer = gameState.blackRound ? 2 : 1
        var availablePieces: [(Int, Int)] = []

        for row in 0..<8 {
            for col in 0..<8 {
                if gameState.chessBoard[row][col] == currentPlayer {
                    availablePieces.append((row, col))
                }
            }
        }
        return availablePieces
    }

    func getAllAvailableMoves() -> [(Int, Int)] {
        var availableMovesList: [(Int, Int)] = []

        for row in 0..<8 {
            for col in 0..<8 {
                if gameState.availableMoves[row][col] == 1 {
                    availableMovesList.append((row, col))
                }
            }
        }
        return availableMovesList
    }

    func checkWinCondition() -> (isGameOver: Bool, winner: String?) {
        // 如果游戏已经结束，直接返回结果
        if gameState.isGameOver {
            let winner = gameState.blackRound ? "黑方" : "白方"
            return (true, winner)
        }

        // 获取对方所有棋子
        let opponentPieces = getAllCounterPieces()

        // 检查对方是否有任何一个棋子能移动
        for piece in opponentPieces {
            // 计算该棋子的可移动位置
            calculateAvailableMoves(from: piece)
            let availableMoves = getAllAvailableMoves()

            // 如果有任何可移动位置，游戏继续
            if !availableMoves.isEmpty {
                return (false, nil)
            }
        }

        // 对方所有棋子都无法移动，当前玩家获胜！
        let winner = gameState.blackRound ? "黑方" : "白方"
        return (true, winner)
    }
    func checkAndHandleWinCondition() -> Bool {
        let winResult = checkWinCondition()

        if winResult.isGameOver && !gameState.isGameOver {
            // 设置游戏结束状态
            gameState.isGameOver = true

            // 显示胜利消息
            addHistory("获胜")
            // 关闭双方的自动下棋
            gameState.blackAutoOperate = false
            gameState.whiteAutoOperate = false
            return true
        }
        return false
    }
    func handleSquareTap(row: Int, column: Int) {// 处理点击事件
        // 如果游戏已结束，禁止操作
        if gameState.isGameOver {
            return
        }

        let currentPlayer = gameState.blackRound ? 1 : 2
        if (gameState.blackRound && gameState.blackAutoOperate)
            || (!gameState.blackRound && gameState.whiteAutoOperate)
        {
            return
        }

        switch gameState.gamePhase {
        case .selectPiece:
            if gameState.blackRound {
                gameState.roundNum += 1
            }
            if gameState.chessBoard[row][column] == currentPlayer {
                gameState.selectedPiece = (row, column)
                calculateAvailableMoves(from: (row, column))
                gameState.gamePhase = .movePiece
                addHistory("选择了棋子 (\(row),\(column))")
            }

        case .movePiece:
            guard let selected = gameState.selectedPiece else { return }
            if gameState.availableMoves[row][column] == 1 {
                gameState.chessBoard[row][column] =
                    gameState.chessBoard[selected.0][selected.1]
                gameState.chessBoard[selected.0][selected.1] = 0
                gameState.selectedPiece = (row, column)

                calculateAvailableMoves(from: (row, column))
                gameState.gamePhase = .placeArrow
                addHistory("移动棋子到 (\(row),\(column))")

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self.gameState.blackRound
                        && self.gameState.blackAutoOperate
                    {
                        self.autoOperate(player: true)
                    } else if !self.gameState.blackRound
                        && self.gameState.whiteAutoOperate
                    {
                        self.autoOperate(player: false)
                    }
                }
            } else if gameState.chessBoard[row][column] == currentPlayer {
                gameState.selectedPiece = (row, column)
                calculateAvailableMoves(from: (row, column))
                addHistory("重新选择了棋子 (\(row),\(column))")
            }

        case .placeArrow:
            if gameState.availableMoves[row][column] == 1 {
                gameState.chessBoard[row][column] = gameState.blackRound ? 3 : 4

                addHistory("放置障碍物在 (\(row),\(column))")

                // 🎯 在放置障碍物后立即检查胜利条件
                let isGameOver = checkAndHandleWinCondition()

                if isGameOver {
                    // 游戏结束，清理状态但不切换回合
                    gameState.selectedPiece = nil
                    gameState.availableMoves = Array(
                        repeating: Array(repeating: 0, count: 8),
                        count: 8
                    )
                    gameState.gamePhase = .selectPiece
                    gameState.unsavable = false
                    // 注意：这里不切换 blackRound，因为游戏已结束
                } else {
                    // 游戏继续，正常切换回合
                    gameState.selectedPiece = nil
                    gameState.availableMoves = Array(
                        repeating: Array(repeating: 0, count: 8),
                        count: 8
                    )
                    gameState.gamePhase = .selectPiece
                    gameState.blackRound.toggle()
                    gameState.unsavable = false

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if self.gameState.blackRound
                            && self.gameState.blackAutoOperate
                        {
                            self.autoOperate(player: true)
                        } else if !self.gameState.blackRound
                            && self.gameState.whiteAutoOperate
                        {
                            self.autoOperate(player: false)
                        }
                    }
                }
            }
        }
    }
    // MARK: - 蒙特卡洛算法实现
    private func generateMcListForCurrentTurn() {
        let currentBoard = gameState.chessBoard
        let isBlack = gameState.blackRound

        // 清空之前的列表
        gameState.mcList = []

        // 添加回合数和玩家信息
        gameState.mcList.append(gameState.roundNum)
        gameState.mcList.append(isBlack ? 1 : 0)  // 1:黑方, 0:白方

        // 生成最佳走法
        if let bestMove = findBestMoveWithMonteCarlo(
            board: currentBoard,
            isBlack: isBlack
        ) {
            // 添加走法到列表
            gameState.mcList.append(bestMove.piece.0)
            gameState.mcList.append(bestMove.piece.1)
            gameState.mcList.append(bestMove.target.0)
            gameState.mcList.append(bestMove.target.1)
            gameState.mcList.append(bestMove.arrow.0)
            gameState.mcList.append(bestMove.arrow.1)

            print(
                "\(isBlack ? "黑" : "白")方蒙特卡洛生成走法: 棋子(\(bestMove.piece)) -> 移动(\(bestMove.target)) -> 箭(\(bestMove.arrow))"
            )
        } else {
            // 如果没有找到走法，使用随机走法
            generateRandomMcList()
        }
    }
    private func findBestMoveWithMonteCarlo(board: [[Int]], isBlack: Bool) -> (
        piece: (Int, Int), target: (Int, Int), arrow: (Int, Int)
    )? {
        let allMoves = getAllPossibleMoves(board: board, isBlack: isBlack)

        if allMoves.isEmpty {
            return nil
        }

        var bestMove:
            (piece: (Int, Int), target: (Int, Int), arrow: (Int, Int))?
        var bestScore: Double = -Double.infinity
        let simulationsPerMove = 30  // 每个走法的模拟次数

        // 并行处理以提高速度
        DispatchQueue.concurrentPerform(iterations: min(10, allMoves.count)) {
            index in
            guard index < allMoves.count else { return }
            let move = allMoves[index]

            var totalScore: Double = 0.0
            for _ in 0..<simulationsPerMove {
                let score = simulateRandomGame(
                    from: move,
                    board: board,
                    isBlack: isBlack
                )
                totalScore += score
            }

            let averageScore = totalScore / Double(simulationsPerMove)
            // 使用锁保护共享资源
            if averageScore > bestScore {
                bestScore = averageScore
                bestMove = move
            }

        }
        print("\(isBlack ? "黑" : "白")方分数：\(bestScore)")
        return bestMove
    }
    private func getAllPossibleMoves(board: [[Int]], isBlack: Bool) -> [(
        piece: (Int, Int), target: (Int, Int), arrow: (Int, Int)
    )] {
        var allMoves:
            [(piece: (Int, Int), target: (Int, Int), arrow: (Int, Int))] = []
        let playerPiece = isBlack ? 1 : 2

        // 获取所有己方棋子
        for row in 0..<8 {
            for col in 0..<8 {
                if board[row][col] == playerPiece {
                    // 获取该棋子的所有移动位置
                    let movePositions = calculateSimuMoves(
                        from: (row, col),
                        board: board
                    )

                    for movePos in movePositions {
                        // 模拟移动后的棋盘
                        var tempBoard = board
                        tempBoard[movePos.0][movePos.1] = playerPiece
                        tempBoard[row][col] = 0

                        // 获取所有可能的箭位置
                        let arrowPositions = calculateSimuMoves(
                            from: movePos,
                            board: tempBoard
                        )

                        for arrowPos in arrowPositions {
                            allMoves.append(
                                (
                                    piece: (row, col), target: movePos,
                                    arrow: arrowPos
                                )
                            )
                        }
                    }
                }
            }
        }

        return allMoves
    }
    private func simulateRandomGame(
        from move: (piece: (Int, Int), target: (Int, Int), arrow: (Int, Int)),
        board: [[Int]],
        isBlack: Bool
    ) -> Double {
        // 1. 应用第一步走法
        var simBoard = board
        let playerPiece = isBlack ? 1 : 2
        let arrowType = isBlack ? 3 : 4

        // 移动棋子
        simBoard[move.target.0][move.target.1] = playerPiece
        simBoard[move.piece.0][move.piece.1] = 0

        // 放置箭
        simBoard[move.arrow.0][move.arrow.1] = arrowType

        // 2. 继续随机模拟若干步
        var currentIsBlack = !isBlack  // 切换到对方回合
        let maxSimulationSteps = 8  // 模拟8步

        for _ in 0..<maxSimulationSteps {
            // 检查游戏是否结束
            if isGameOver(board: simBoard, isBlackTurn: currentIsBlack) {
                // 游戏结束，返回分数
                return calculateFinalScore(
                    board: simBoard,
                    originalIsBlack: isBlack
                )
            }

            // 随机选择一步走法
            guard
                let randomMove = getRandomMove(
                    board: simBoard,
                    isBlack: currentIsBlack
                )
            else {
                break
            }

            // 执行随机走法
            let currentPiece = currentIsBlack ? 1 : 2
            let currentArrow = currentIsBlack ? 3 : 4

            simBoard[randomMove.target.0][randomMove.target.1] = currentPiece
            simBoard[randomMove.piece.0][randomMove.piece.1] = 0
            simBoard[randomMove.arrow.0][randomMove.arrow.1] = currentArrow

            // 切换玩家
            currentIsBlack.toggle()
        }

        // 3. 模拟结束，评估局面
        return evaluateBoard(board: simBoard, originalIsBlack: isBlack)
    }
    private func getRandomMove(board: [[Int]], isBlack: Bool) -> (
        piece: (Int, Int), target: (Int, Int), arrow: (Int, Int)
    )? {
        let allMoves = getAllPossibleMoves(board: board, isBlack: isBlack)
        return allMoves.randomElement()
    }

    // 检查游戏是否结束（模拟途中版）
    private func isGameOver(board: [[Int]], isBlackTurn: Bool) -> Bool {
        let opponentIsBlack = !isBlackTurn
        let opponentPiece = opponentIsBlack ? 1 : 2

        // 检查对方是否有棋子可以移动
        for row in 0..<8 {
            for col in 0..<8 {
                if board[row][col] == opponentPiece {
                    let moves = calculateSimuMoves(
                        from: (row, col),
                        board: board
                    )
                    if !moves.isEmpty {
                        return false  // 对方有棋子可以移动
                    }
                }
            }
        }

        return true  // 对方无法移动
    }
    private func calculateFinalScore(board: [[Int]], originalIsBlack: Bool)
        -> Double
    {
        // 如果对方无法移动，我方获胜
        let currentPlayerCanMove =
            getRandomMove(board: board, isBlack: originalIsBlack) != nil
        let opponentCanMove =
            getRandomMove(board: board, isBlack: !originalIsBlack) != nil

        if !opponentCanMove && currentPlayerCanMove {
            return 1.0  // 我方获胜
        } else if opponentCanMove && !currentPlayerCanMove {
            return -1.0  // 对方获胜
        }

        // 否则返回评估分数
        return evaluateBoard(board: board, originalIsBlack: originalIsBlack)
    }
    // 生成随机走法列表（备用）
    private func generateRandomMcList() {
        let availablePieces = getAllAvailablePieces()
        guard let randomPiece = availablePieces.randomElement() else { return }

        calculateAvailableMoves(from: randomPiece)
        let availableMovesList = getAllAvailableMoves()
        guard let randomMove = availableMovesList.randomElement() else {
            return
        }

        // 模拟移动以获取箭的位置
        var tempBoard = gameState.chessBoard
        let playerPiece = gameState.blackRound ? 1 : 2

        tempBoard[randomMove.0][randomMove.1] = playerPiece
        tempBoard[randomPiece.0][randomPiece.1] = 0

        let arrowMoves = calculateSimuMoves(from: randomMove, board: tempBoard)
        guard let randomArrow = arrowMoves.randomElement() else { return }

        // 构建mcList
        gameState.mcList = [
            gameState.roundNum,
            gameState.blackRound ? 1 : 0,
            randomPiece.0, randomPiece.1,
            randomMove.0, randomMove.1,
            randomArrow.0, randomArrow.1,
        ]
    }
    private func evaluateBoard(board: [[Int]], originalIsBlack: Bool) -> Double
    {
        // 使用你的评估函数
        let blackScore =
            controlScore(
                forBlack: true,
                board: board,
                factor: gameState.blackControlFactor
            )
            + safetyScore(
                forBlack: true,
                board: board,
                factor: gameState.blackSafetyFactor,
                factor_surround: gameState.blackSurroundFactor
            )
            + centerScore(
                forBlack: true,
                board: board,
                factor: gameState.blackCenterFactor
            )

        let whiteScore =
            controlScore(
                forBlack: false,
                board: board,
                factor: gameState.whiteControlFactor
            )
            + safetyScore(
                forBlack: false,
                board: board,
                factor: gameState.whiteSafetyFactor,
                factor_surround: gameState.whiteSurroundFactor
            )
            + centerScore(
                forBlack: false,
                board: board,
                factor: gameState.whiteCenterFactor
            )

        let diff = Double(blackScore - whiteScore)
        let normalized = tanh(diff / 100.0)  // 归一化到[-1, 1]

        return originalIsBlack ? normalized : -normalized
    }
    // 模拟移动（无GameState版）
    private func calculateSimuMoves(from: (Int, Int), board: [[Int]]) -> [(
        Int, Int
    )] {
        var moves: [(Int, Int)] = []
        let (row, col) = from
        let directions = [
            (-1, -1), (-1, 0), (-1, 1),
            (0, -1), (0, 1),
            (1, -1), (1, 0), (1, 1),
        ]

        for direction in directions {
            var currentRow = row + direction.0
            var currentCol = col + direction.1

            while currentRow >= 0 && currentRow < 8 && currentCol >= 0
                && currentCol < 8
            {
                if board[currentRow][currentCol] != 0 {
                    break  // 遇到障碍或棋子
                }
                moves.append((currentRow, currentCol))
                currentRow += direction.0
                currentCol += direction.1
            }
        }

        return moves
    }
    private func mcSelect() {
        // 如果mcList为空或者回合不匹配，重新生成
        if gameState.mcList.isEmpty || gameState.mcList[0] != gameState.roundNum
        {
            generateMcListForCurrentTurn()
        }

        // 检查mcList是否有效
        guard gameState.mcList.count >= 8,
            gameState.mcList[1] == (gameState.blackRound ? 1 : 0)
        else {
            // 如果无效，使用随机选择
            randomSelect()
            return
        }

        // 从mcList中读取棋子位置
        let pieceRow = gameState.mcList[2]
        let pieceCol = gameState.mcList[3]

        // 选择棋子
        gameState.selectedPiece = (pieceRow, pieceCol)
        calculateAvailableMoves(from: (pieceRow, pieceCol))
        gameState.gamePhase = .movePiece

        addHistory("蒙特卡洛方法 选择了棋子 (\(pieceRow),\(pieceCol))")
    }
    private func mcMove(availableMovesList: [(Int, Int)], selected: (Int, Int))
    {
        // 检查mcList是否有效
        guard gameState.mcList.count >= 8,
            gameState.mcList[0] == gameState.roundNum,
            gameState.mcList[2] == selected.0,
            gameState.mcList[3] == selected.1
        else {
            // 如果无效，使用随机移动
            randomMove(
                availableMovesList: availableMovesList,
                selected: selected
            )
            return
        }

        // 从mcList中读取目标位置
        let targetRow = gameState.mcList[4]
        let targetCol = gameState.mcList[5]

        // 检查目标位置是否合法
        if availableMovesList.contains(where: { $0 == (targetRow, targetCol) })
        {
            // 执行移动
            gameState.chessBoard[targetRow][targetCol] =
                gameState.chessBoard[selected.0][selected.1]
            gameState.chessBoard[selected.0][selected.1] = 0
            gameState.selectedPiece = (targetRow, targetCol)

            calculateAvailableMoves(from: (targetRow, targetCol))
            gameState.gamePhase = .placeArrow

            addHistory("蒙特卡洛方法 移动棋子到 (\(targetRow),\(targetCol))")
        } else {
            // 如果不合法，使用随机移动
            randomMove(
                availableMovesList: availableMovesList,
                selected: selected
            )
        }
    }
    private func mcPlace(obstacleType: Int) {
        // 检查mcList是否有效
        guard gameState.mcList.count >= 8,
            gameState.mcList[0] == gameState.roundNum
        else {
            // 如果无效，使用随机放置
            randomPlace(obstacleType: obstacleType)
            return
        }

        // 从mcList中读取箭的位置
        let arrowRow = gameState.mcList[6]
        let arrowCol = gameState.mcList[7]

        // 检查箭位置是否合法
        let availableArrows = getAllAvailableMoves()
        if availableArrows.contains(where: { $0 == (arrowRow, arrowCol) }) {
            // 放置障碍物
            gameState.chessBoard[arrowRow][arrowCol] = obstacleType
            addHistory("蒙特卡洛方法 放置障碍物在 (\(arrowRow),\(arrowCol))")
        } else {
            // 如果不合法，使用随机放置
            randomPlace(obstacleType: obstacleType)
        }

    }
    // MARK: - 自动下棋（第三版）（已修复）
    func autoOperate(player isBlack: Bool) {
        if gameState.isGameOver || isBlack != gameState.blackRound {
            return
        }
        guard
            gameState.blackRound == isBlack
                && (isBlack
                    ? gameState.blackAutoOperate : gameState.whiteAutoOperate)
        else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let obstacleType = isBlack ? 3 : 4

            switch self.gameState.gamePhase {
            case .selectPiece:
                // 根据策略执行自动下棋
                if gameState.blackRound {
                    gameState.roundNum += 1
                }
                switch isBlack
                    ? self.gameState.blackStrategy
                    : self.gameState.whiteStrategy
                {
                case "纯随机下棋":
                    randomSelect()
                case "蒙特卡洛方法":
                    mcSelect()
                default:
                    print("未选中策略，棋局冻结")
                    return
                }
                // 延迟。。
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // 在继续前检查是否游戏结束
                    if self.gameState.isGameOver {
                        return
                    }
                    self.autoOperate(
                        player: self.gameState.blackRound
                    )
                }

            //冗余            if !foundValidPiece {
            //                    // 这里实际上就是胜利条件，直接处理胜利
            //                    let winner = isBlack ? "白方" : "黑方"
            //                    self.addHistory("自动随机下棋 无有效棋子可移动，\(winner)胜利")// 最老的判断胜利条件
            //                    _ = self.checkAndHandleWinCondition()
            //                }

            case .movePiece:
                guard let selected = self.gameState.selectedPiece else {
                    return
                }

                let availableMovesList = self.getAllAvailableMoves()
                switch isBlack
                    ? self.gameState.blackStrategy
                    : self.gameState.whiteStrategy
                {
                case "纯随机下棋":
                    randomMove(
                        availableMovesList: availableMovesList,
                        selected: selected
                    )
                case "蒙特卡洛方法":
                    mcMove(
                        availableMovesList: availableMovesList,
                        selected: selected
                    )
                default:
                    print("未选中策略，棋局冻结")
                    return
                }
                // 延迟。。。
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // 在继续前检查是否游戏结束
                    if self.gameState.isGameOver {
                        return
                    }
                    self.autoOperate(player: isBlack)
                }
            case .placeArrow:
                switch isBlack
                    ? self.gameState.blackStrategy
                    : self.gameState.whiteStrategy
                {
                case "纯随机下棋":
                    randomPlace(obstacleType: obstacleType)
                case "蒙特卡洛方法":
                    mcPlace(obstacleType: obstacleType)
                default:
                    print("未选中策略，棋局冻结")
                    return
                }
                // 🎯 在放置障碍物后立即检查胜利条件
                let isGameOver = self.checkAndHandleWinCondition()

                if isGameOver {
                    // 游戏结束，清理状态但不切换回合
                    self.gameState.selectedPiece = nil
                    self.gameState.availableMoves = Array(
                        repeating: Array(repeating: 0, count: 8),
                        count: 8
                    )
                    self.gameState.gamePhase = .selectPiece
                    self.gameState.unsavable = false
                    // 注意：这里不切换 blackRound，因为游戏已结束
                } else {
                    // 游戏继续，正常切换回合
                    self.gameState.selectedPiece = nil
                    self.gameState.availableMoves = Array(
                        repeating: Array(repeating: 0, count: 8),
                        count: 8
                    )
                    self.gameState.gamePhase = .selectPiece
                    self.gameState.blackRound.toggle()
                    self.gameState.unsavable = false
                    // 又是延迟。。
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + 0.3
                    ) {
                        // 在继续前检查是否游戏结束
                        if self.gameState.isGameOver {
                            return
                        }
                        if self.gameState.blackRound
                            && self.gameState.blackAutoOperate
                        {
                            self.autoOperate(player: true)
                        } else if !self.gameState.blackRound
                            && self.gameState.whiteAutoOperate
                        {
                            self.autoOperate(player: false)
                        }
                    }
                }
            }
        }
    }
    // MARK: 随机3步骤（第四版）（已修复）（稳定版）
    private func randomSelect() {
        // 注意：下方代码可替换
        let availablePieces = self.getAllAvailablePieces()
        let shuffledPieces = availablePieces.shuffled()
        for piece in shuffledPieces {
            self.calculateAvailableMoves(from: piece)
            let availableMovesList = self.getAllAvailableMoves()

            if !availableMovesList.isEmpty {
                self.gameState.selectedPiece = piece  // 必须要有！！！！！
                self.gameState.gamePhase = .movePiece  // 必须要有！！！！！
                self.addHistory(
                    "自动随机下棋 选择了棋子 (\(piece.0),\(piece.1))"
                )
                break
            }
        }
        // 注意：上方代码可替换
    }
    private func randomMove(
        availableMovesList: [(Int, Int)],
        selected: (Int, Int)
    ) {
        // 注意：以下代码可替换
        if let randomMove = availableMovesList.randomElement() {
            self.gameState.chessBoard[randomMove.0][randomMove.1] =
                self.gameState.chessBoard[selected.0][selected.1]  // 必须要有！！！！！复制棋子到目标位置
            self.gameState.chessBoard[selected.0][selected.1] = 0  // 必须要有！！！！！移除原位的棋子
            self.gameState.selectedPiece = (
                randomMove.0, randomMove.1
            )  // 必须要有！！！！！选中移动后到棋子

            self.calculateAvailableMoves(
                from: (randomMove.0, randomMove.1)
            )
            self.gameState.gamePhase = .placeArrow
            self.addHistory(
                "自动随机下棋 移动棋子到 (\(randomMove.0),\(randomMove.1))"
            )
        } else {
            self.addHistory("自动随机下棋 当前棋子无有效移动，重新选择")
            self.gameState.gamePhase = .selectPiece
            self.gameState.selectedPiece = nil
            self.gameState.availableMoves = Array(
                repeating: Array(repeating: 0, count: 8),
                count: 8
            )

        }
        // 注意：以上代码可替换
    }
    private func randomPlace(obstacleType: Int) {
        // 注意：以下代码可替换
        let availableArrows = self.getAllAvailableMoves()

        if let randomArrow = availableArrows.randomElement() {
            self.gameState.chessBoard[randomArrow.0][
                randomArrow.1
            ] =
                obstacleType

            self.addHistory(
                "自动随机下棋 放置障碍物在 (\(randomArrow.0),\(randomArrow.1))"
            )

        }
        // 注意：以上代码可替换
    }
    // MARK: 局势评估（关键）
    private func controlScore(forBlack: Bool, board: [[Int]], factor: Double)
        -> Double
    {  // 进程管理（并发运行）、设备管理、存储管理、文件管理、用户界面
        let targetPiece = forBlack ? 1 : 2
        var score = 0.0
        // 计算每个棋子的控制区域
        for row in 0..<8 {
            for col in 0..<8 {
                if board[row][col] == targetPiece {
                    score +=
                        factor
                        * Double(
                            calculateSimuMoves(from: (row, col), board: board)
                                .count
                        )
                }
            }
        }
        return score
    }
    private func safetyScore(
        forBlack: Bool,
        board: [[Int]],
        factor: Double,
        factor_surround: Double
    ) -> Double {
        let targetPiece = forBlack ? 1 : 2
        var safety = 0.0

        for row in 0..<8 {
            for col in 0..<8 {
                if board[row][col] == targetPiece {
                    // 检查棋子周围是否有出路
                    let moves = calculateSimuMoves(
                        from: (row, col),
                        board: board
                    )
                    if moves.isEmpty {
                        safety -= factor_surround  // 棋子被困住
                    } else {
                        safety += factor * Double(moves.count)
                    }

                    // 检查是否靠近棋盘边缘（不利位置）
                    let edgeDistance = min(row, 7 - row, col, 7 - col)
                    safety += factor * Double(edgeDistance)  // 距离边缘越远越安全
                }
            }
        }
        return safety
    }
    private func centerScore(forBlack: Bool, board: [[Int]], factor: Double)
        -> Double
    {
        let targetPiece = forBlack ? 1 : 2
        var centerScore = 0.0
        let centerCells = [(3, 3), (3, 4), (4, 3), (4, 4)]

        // 检查是否控制中心
        for center in centerCells {
            if board[center.0][center.1] == targetPiece {
                centerScore += factor * 5
            }
        }

        // 计算棋子距离中心的远近
        for row in 0..<8 {
            for col in 0..<8 {
                if board[row][col] == targetPiece {
                    let dx = abs(Double(row) - 3.5)
                    let dy = abs(Double(col) - 3.5)
                    let distance = sqrt(dx * dx + dy * dy)
                    centerScore += factor * (10 - distance)  // 越靠近中心得分越高
                }
            }
        }

        return centerScore
    }
}

// MARK: - 棋盘格子视图
struct ChessSquareView: View {
    let row: Int
    let column: Int
    let value: Int
    let action: () -> Void
    let blackRound: Bool
    let gamePhase: GamePhase
    let availableMoves: [[Int]]

    @State private var showContent = true

    var body: some View {
        ZStack {
            Rectangle()
                .fill(getSquareColor())
                .frame(width: 80, height: 80)
                .overlay(
                    Rectangle().stroke(Color.black.opacity(0.2), lineWidth: 1)
                )

            Button(action: action) {
                ZStack {
                    Rectangle()
                        .fill(Color.blue.opacity(0.01))
                        .frame(width: 75, height: 75)

                    if value == 1 {
                        Image(systemName: "person.fill")
                            .font(.system(size: 30))
                            .opacity(showContent ? 1 : 0)
                    } else if value == 2 {
                        Image(systemName: "person")
                            .font(.system(size: 30))
                            .opacity(showContent ? 1 : 0)
                    } else if value == 3 {
                        Image(systemName: "nosign.app.fill")
                            .font(.system(size: 30))
                            .opacity(showContent ? 1 : 0)
                    } else if value == 4 {
                        Image(systemName: "nosign.app")
                            .font(.system(size: 30))
                            .opacity(showContent ? 1 : 0)
                    }
                }
            }
            .disabled(!isInteractive())
            .buttonStyle(PlainButtonStyle())
        }
        .onChange(of: value) { _, _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showContent = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showContent = true
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                showContent = true
            }
        }
    }

    private func getSquareColor() -> Color {
        if availableMoves[row][column] == 1 {
            return Color.green.opacity(0.5)
        } else if availableMoves[row][column] == 2 {
            return Color.red.opacity(0.5)
        } else {
            return (row + column) % 2 == 0
                ? Color.white : Color.gray.opacity(0.3)
        }
    }

    private func isInteractive() -> Bool {
        let currentPlayer = blackRound ? 1 : 2

        switch gamePhase {
        case .selectPiece:
            return value == currentPlayer
        case .movePiece:
            return availableMoves[row][column] == 1 || value == currentPlayer
        case .placeArrow:
            return availableMoves[row][column] == 1
        }
    }
}

// MARK: - 棋盘行视图
struct ChessBoardRowView: View {
    let row: Int
    let chessBoard: [[Int]]
    let onSquareTap: (Int, Int) -> Void
    let blackRound: Bool
    let gamePhase: GamePhase
    let availableMoves: [[Int]]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { column in
                ChessSquareView(
                    row: row,
                    column: column,
                    value: chessBoard[row][column],
                    action: { onSquareTap(row, column) },
                    blackRound: blackRound,
                    gamePhase: gamePhase,
                    availableMoves: availableMoves
                )
            }
        }
    }
}

// MARK: - 棋盘视图
struct ChessBoardView: View {
    let chessBoard: [[Int]]
    let onSquareTap: (Int, Int) -> Void
    let blackRound: Bool
    let gamePhase: GamePhase
    let availableMoves: [[Int]]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)

                ForEach(0..<8, id: \.self) { column in
                    Text(String(column))
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 80, height: 30)
                        .foregroundColor(.primary)
                }
            }

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { row in
                        Text(String(row))
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 30, height: 80)
                            .foregroundColor(.primary)
                    }
                }

                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { row in
                        ChessBoardRowView(
                            row: row,
                            chessBoard: chessBoard,
                            onSquareTap: onSquareTap,
                            blackRound: blackRound,
                            gamePhase: gamePhase,
                            availableMoves: availableMoves
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
struct MenuButtonView: View {
    let title: String
    let icon: String
    let action: () -> Void
    let disabled: Bool

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 15))
                .frame(maxWidth: 150)
        }
        .disabled(disabled)
        .buttonStyle(.bordered)
    }
}

// MARK: - 左侧栏视图
struct SidebarView: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        VStack {
            if gameState.isPlaying {
                gameInfoView
            } else {
                Text("请先打开一个存档，或开启新游戏……")
                    .font(.system(size: 25, weight: .medium))
                Spacer()
            }
        }
        .frame(width: 320)
    }

    private var gameInfoView: some View {
        VStack {
            Spacer()
                .frame(height: 5)
            HStack {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                if gameState.withFile {
                    Text("当前存档文件：\(gameState.currentUrl)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else {
                    Text("新游戏：尚未存档")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Image(systemName: "flag.filled.and.flag.crossed")
                    .font(.system(size: 25))
                    .foregroundStyle(.primary)
                Text("当前行动方：")
                    .font(.system(size: 25, weight: .medium))
                if gameState.blackRound {
                    HStack {
                        Image(systemName: "person.fill")
                            .font(.system(size: 25))
                            .foregroundStyle(.primary)
                        Text("黑方")
                            .font(.system(size: 25, weight: .medium))
                    }
                } else {
                    HStack {
                        Image(systemName: "person")
                            .font(.system(size: 25))
                            .foregroundStyle(.primary)
                        Text("白方")
                            .font(.system(size: 25, weight: .medium))
                    }
                }
            }
            HStack {
                Image(systemName: "number")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
                Text("当前回合数：\(gameState.roundNum)")
                    .font(.system(size: 20, weight: .medium))
            }
            HStack {
                Image(systemName: "flag.circle")
                    .font(.system(size: 15))
                Text("当前行动阶段：")
                    .font(.system(size: 15))

                switch gameState.gamePhase {
                case .selectPiece:
                    HStack {
                        if gameState.blackRound {
                            Image(systemName: "person.fill")
                                .font(.system(size: 15))
                        } else {
                            Image(systemName: "person")
                                .font(.system(size: 15))
                        }
                        Text("选择棋子")
                            .font(.system(size: 15))
                    }
                case .movePiece:
                    HStack {
                        if gameState.blackRound {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 15))
                        } else {
                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: 15))
                        }
                        Text("移动棋子")
                            .font(.system(size: 15))
                    }
                case .placeArrow:
                    HStack {
                        if gameState.blackRound {
                            Image(systemName: "nosign.app.fill")
                                .font(.system(size: 15))
                        } else {
                            Image(systemName: "nosign.app")
                                .font(.system(size: 15))
                        }
                        Text("放置障碍物")
                            .font(.system(size: 15))
                    }
                }
            }
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 15))
                Text("历史操作：")
                    .font(.system(size: 15))
            }

            // 修复List使用方式
            List(gameState.history) { entry in
                Text(entry.description)
                    .font(.system(size: 12))
            }
            .frame(height: 240)
        }
    }
}
// 独立的滑块组件，可复用
struct ParameterSliderView: View {
    @Binding var value: Double
    let title: String
    let description: String
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题和当前值
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(value, specifier: "%.1f")")
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            // 滑块
            Slider(value: $value, in: range, step: step)
                .accentColor(.blue)

            // 说明文字
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }
}

// 游戏中的参数调节面板优化
struct ParameterSettingsView: View {
    @Binding var controlFactor: Double
    @Binding var safetyFactor: Double
    @Binding var surroundFactor: Double
    @Binding var centerFactor: Double
    let isBlack: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(
                    systemName: isBlack
                        ? "arrowshape.left.arrowshape.right.fill"
                        : "arrowshape.left.arrowshape.right"
                )
                .font(.system(size: 16))
                Text("\(isBlack ? "黑方" : "白方")蒙特卡洛参数")
                    .font(.headline)
            }
            .padding(.bottom, 8)

            // 滑块组
            ParameterSliderView(
                value: $controlFactor,
                title: "控制分数倍率",
                description: "调高使算法更重视可用移动数目",
                range: 1...10,
                step: 0.1
            )

            ParameterSliderView(
                value: $safetyFactor,
                title: "安全分数倍率",
                description: "调高使算法更重视不被困住",
                range: 1...10,
                step: 0.1
            )

            ParameterSliderView(
                value: $surroundFactor,
                title: "包围惩罚系数",
                description: "棋子被完全包围时的惩罚值",
                range: 5...100,
                step: 0.5
            )

            ParameterSliderView(
                value: $centerFactor,
                title: "中心分数倍率",
                description: "调高使算法更重视占领棋盘中心",
                range: 1...10,
                step: 0.1
            )

            // 快速设置按钮
            HStack(spacing: 12) {
                Button("均衡型") {
                    controlFactor = 1.0
                    safetyFactor = 1.0
                    surroundFactor = 10.0
                    centerFactor = 1.0
                }
                .buttonStyle(.bordered)
                .font(.caption)

                Button("进攻型") {
                    controlFactor = 1.6
                    safetyFactor = 0.6
                    surroundFactor = 6.0
                    centerFactor = 1.6
                }
                .buttonStyle(.bordered)
                .font(.caption)

                Button("防守型") {
                    controlFactor = 0.6
                    safetyFactor = 1.6
                    surroundFactor = 16.0
                    centerFactor = 0.6
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}
// MARK: - 右侧栏视图
struct RightView: View {
    @EnvironmentObject var gameState: GameState
    let gameManager: GameManager
    let options = ["纯随机下棋", "蒙特卡洛方法"]

    var body: some View {
        VStack {
            Spacer()
                .frame(height: 5)

            if gameState.isPlaying {
                // 标题栏（固定）
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "command")
                            .font(.system(size: 25))
                            .foregroundStyle(.primary)
                        Text("自动下棋控制面板")
                            .font(.system(size: 25))
                            .foregroundStyle(.primary)
                    }
                    .padding(.top, 12)

                    Divider()
                        .padding(.horizontal)
                }
                .background(Color(nsColor: .windowBackgroundColor))
                ScrollView {
                    // 黑方设置
                    HStack {
                        Image(systemName: "command.circle.fill")
                            .font(.system(size: 15))
                        Toggle("黑方自动下棋", isOn: $gameState.blackAutoOperate)
                            .disabled(gameState.isGameOver)
                            .onChange(of: gameState.blackAutoOperate) {
                                _,
                                newValue in
                                if newValue && gameState.blackRound {
                                    gameManager.autoOperate(player: true)
                                }
                            }
                    }
                    .padding(.horizontal)

                    HStack {
                        Image(systemName: "gear.circle.fill")
                            .font(.system(size: 15))
                        Picker("自动下棋策略", selection: $gameState.blackStrategy) {
                            ForEach(options, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .disabled(gameState.isGameOver)
                        .frame(maxWidth: 250)
                    }
                    .padding(.horizontal)

                    // 只有当选择蒙特卡洛时才显示参数
                    if gameState.blackStrategy == "蒙特卡洛方法"
                        && !gameState.isGameOver
                    {
                        ParameterSettingsView(
                            controlFactor: $gameState.blackControlFactor,
                            safetyFactor: $gameState.blackSafetyFactor,
                            surroundFactor: $gameState.blackSurroundFactor,
                            centerFactor: $gameState.blackCenterFactor,
                            isBlack: true
                        )
                        .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    // 白方设置
                    HStack {
                        Image(systemName: "command.circle")
                            .font(.system(size: 15))
                        Toggle("白方自动下棋", isOn: $gameState.whiteAutoOperate)
                            .disabled(gameState.isGameOver)
                            .onChange(of: gameState.whiteAutoOperate) {
                                _,
                                newValue in
                                if newValue && !gameState.blackRound {
                                    gameManager.autoOperate(player: false)
                                }
                            }
                    }
                    .padding(.horizontal)

                    HStack {
                        Image(systemName: "gear.circle")
                        Picker("自动下棋策略", selection: $gameState.whiteStrategy) {
                            ForEach(options, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .disabled(gameState.isGameOver)
                        .frame(maxWidth: 250)
                    }
                    .padding(.horizontal)

                    // 只有当选择蒙特卡洛时才显示参数
                    if gameState.whiteStrategy == "蒙特卡洛方法"
                        && !gameState.isGameOver
                    {
                        ParameterSettingsView(
                            controlFactor: $gameState.whiteControlFactor,
                            safetyFactor: $gameState.whiteSafetyFactor,
                            surroundFactor: $gameState.whiteSurroundFactor,
                            centerFactor: $gameState.whiteCenterFactor,
                            isBlack: false
                        )
                        .padding(.horizontal)
                    }

                    Spacer()
                }
            } else {
                Text("开始游戏以展示自动操作选项……")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }
        }

        .frame(width: 280)
    }
}

// MARK: - 主菜单视图
struct MainMenuView: View {
    @EnvironmentObject var gameState: GameState
    let gameManager: GameManager

    @State private var showNewGameDoubleCheck = false
    @State private var showLoadDoubleCheck = false
    @State private var showQuitDoubleCheck = false

    var body: some View {
        VStack {
            Spacer()
                .frame(height: 50)
            HStack {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)

                Text("Amazon棋 菜单")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }
            HStack {
                Image(systemName: "info")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                VStack {
                    Text("2025秋 计算概论A 大作业")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("陈奕辰 数学科学学院 2500010834")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
                .frame(height: 15)

            if gameState.unsavable {
                MenuButtonView(
                    title: "新游戏",
                    icon: "plus",
                    action: newGame,
                    disabled: false
                )
            } else {
                MenuButtonView(
                    title: "新游戏",
                    icon: "plus",
                    action: { showNewGameDoubleCheck = true },
                    disabled: false
                )
            }

            Spacer().frame(height: 15)

            if gameState.isPlaying {
                if gameState.unsavable {
                    MenuButtonView(
                        title: "已保存",
                        icon: "square.and.arrow.down",
                        action: quickSave,
                        disabled: true
                    )
                } else {
                    MenuButtonView(
                        title: "快速保存",
                        icon: "square.and.arrow.down",
                        action: quickSave,
                        disabled: !gameState.withFile
                    )
                    Spacer().frame(height: 15)
                    MenuButtonView(
                        title: "另存为",
                        icon: "document.badge.plus",
                        action: saveGame,
                        disabled: false
                    )
                }
                Spacer().frame(height: 15)
            }

            if gameState.unsavable {
                MenuButtonView(
                    title: "读取",
                    icon: "folder",
                    action: loadGame,
                    disabled: false
                )
                Spacer().frame(height: 15)
                MenuButtonView(
                    title: "退出全部",
                    icon: "xmark",
                    action: quitGame,
                    disabled: false
                )
            } else {
                MenuButtonView(
                    title: "读取",
                    icon: "folder",
                    action: { showLoadDoubleCheck = true },
                    disabled: false
                )
                Spacer().frame(height: 15)
                MenuButtonView(
                    title: "退出全部",
                    icon: "xmark",
                    action: { showQuitDoubleCheck = true },
                    disabled: false
                )
            }
        }
        .alert("舍弃当前棋局并创建新棋局？", isPresented: $showNewGameDoubleCheck) {
            Button("返回", role: .cancel) {}
            Button("继续", role: .destructive) { newGame() }
        } message: {
            Text("当前棋局尚未保存，是否继续创建新游戏？")
        }
        .alert("舍弃当前棋局并读取？", isPresented: $showLoadDoubleCheck) {
            Button("返回", role: .cancel) {}
            Button("继续", role: .destructive) { loadGame() }
        } message: {
            Text("当前棋局尚未保存，是否继续读取其他棋局？")
        }
        .alert("舍弃当前棋局并退出？", isPresented: $showQuitDoubleCheck) {
            Button("返回", role: .cancel) {}
            Button("继续", role: .destructive) { quitGame() }
        } message: {
            Text("当前棋局尚未保存，是否继续退出？")
        }
        Spacer().frame(height: 20)
    }

    private func newGame() {
        gameManager.initializeChessBoard()
        gameState.isPlaying = true
        gameState.unsavable = false
        gameState.withFile = false
        gameState.blackRound = true
    }

    private func saveGame() {
        gameManager.saveGame()
    }

    private func loadGame() {
        gameManager.loadGame()
    }

    private func quickSave() {
        let url = URL(fileURLWithPath: gameState.currentUrl)
        _ = gameManager.saveChessBoardToJSON(url: url)
        gameState.unsavable = true
    }

    private func quitGame() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - 主视图
struct ContentView: View {
    @StateObject private var gameState = GameState()
    private var gameManager: GameManager {
        GameManager(gameState: gameState)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack {
                SidebarView()
                    .environmentObject(gameState)

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)

                MainMenuView(gameManager: gameManager)
                    .environmentObject(gameState)
            }

            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)
                .padding()

            ChessBoardView(
                chessBoard: gameState.chessBoard,
                onSquareTap: { row, column in
                    gameManager.handleSquareTap(row: row, column: column)
                },
                blackRound: gameState.blackRound,
                gamePhase: gameState.gamePhase,
                availableMoves: gameState.availableMoves
            )

            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)
                .padding()
            RightView(gameManager: gameManager)
                .environmentObject(gameState)
        }
        .onAppear {
            setWindowTitle()
        }
    }

    private func setWindowTitle() {
        if let window = NSApplication.shared.windows.first {
            window.title = "这个大アサ的作者数分I期中考了25分高分"
        }
    }
}

#Preview {
    ContentView()
}
