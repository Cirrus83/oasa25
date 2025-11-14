# oasa25 程序说明
提示：下载源码后，请把oasa25.xcodeproj.zip在相同目录解压再打开（GitHub为什么不能直接上传这个文件……）
## 基本信息
- 程序名称：oasa25
- 编写语言：Swift 5
- 编译环境：
  - IDE：Xcode Version 26.0.1 (17A400)
  - macOS：Tahoe 26.0.1 (25A362)
  - 设备：MacBook Air (13英寸, M3, 2024年)
- 借助AI：DeepSeek
  - 主要用途：
    - 在原来代码的基础上进行优化；
    - 讲解Swift语法；
    - 修复语法错误；
    - 协助给程序取名。
      - "oasa"(“おアサ”)是“大きいアサインメント”（“大作业”）的缩略；
      - "25"是我的数分I期中考试成绩。
- 程序特色：
  - 使用上：
    - 友好的GUI界面；
      - 包含分栏显示；
    - 二次确认，防止误操作；
    - 完善的存档保存/另存为/读取功能；
    - 清晰的状态显示；
    - 支持历史记录查看；
    - 合法路径绿色高亮显示，被阻挡的路径红色高亮显示；
    - 利用⌘+N进行多窗口同时操作。
  - 技术上：
    - 使用SwiftUI的现成控件实现GUI界面，减少所需代码；
    - 使用多个状态变量，状态划分清晰；
    - 代码分成不同`struct`，分工实现不同功能；
    - 变量名、函数名等清晰易读（感谢DeepSeek）；
## 文件组成
- `Assets.xcassets`：存储程序的图标；
  - 来自教学网上“我的成绩”界面的截图；
- `ContentView.swift`：存储程序的主要源代码；
- `oasa25.app`：macOS的应用程序包；
- `oasa25.xcodeproj`：Xcode的项目文件；
- `oasa25App.swift`：程序主结构（实际代码较少，仅调用`ContentView()`，不涉及具体实现）；
- `oasa25_README.md`：程序说明（本文件）。

下面重点解说`ContentView.swift`的有关内容：
## 程序结构
- `import`阶段：
  - `SwiftUI`：提供程序各个UI控件；
  - `UniformTypeIdentifiers`：用于存取文件时对文件类型的规定；
- `enum GamePhase:`：设定三个游戏阶段的值（相当于C++的`#define`）；
  - 选择棋子阶段`selectPiece`；
  - 移动棋子阶段`movePiece`；
  - 放置障碍物阶段`placeArrow`；
- `struct gameData`：规定游戏存档的结构；
  - 棋盘数据`chessBoard`（二维数组）；
  - 回合数据`blackRound`（布尔值）；
  - 历史记录数据`history`（字符串数组）；
  - 选中棋子位置`selectedPieceRow`和`selectedPieceCol`（整数）；
  - 阶段数据`gamePhase`；
  - 上次计算的可用路径`availableMoves`（二维数组）；
    - 读档后无需再次计算；
- `extension ContentView`：主视图结构的扩展；
  - 不实现UI，而是进行存档的储存与读取，以及交互操作等；
  - `private func saveGame`：借助Swift的`NSSavePanel()`功能进行存档的保存（同时会调用自定义的`saveChessBoardToJSON()`）；
  - `private func loadGame`：借助Swift的`NSOpenPanel()`功能进行存档的读取（同时会调用自定义的`loadChessBoardFromJSON()`）；
  - `private func initializeChessBoard`：新建游戏时的棋盘初始化；
  - `private func saveChessBoardToJSON`：借助Swift的`JSONEncoder()`，保存当前棋局为`.json`存档；
  - `private func loadChessBoardFromJSON`：借助Swift的`JSONDecoder()`，从`.json`存档中读取各个变量，还原棋局；
  - `private func addHistory`：将最近一步操作插入到`history`字符串组的索引`0`位置的一个简单函数；
  - `private func calculateAvailableMoves`：计算可移动的位置，用于给设定按钮状态和染色提供数据；
  - `private func getAllAvailablePieces`：获取所有可用的棋子位置，用于设定按钮状态；
  - `private func getAllAvailableMoves`和`private func getAllAvailableArrowPositions`：获取所有可移动/可放置障碍物的位置，染色；
  - `private func performRandomWhiteMove`和`private func performRandomBlackMove`：结构相同，用于自动操作；
  - `private func handleSquareTap`：处理格子点击；
- `struct ChessSquareView`：棋盘格子视图；
  - 实现单个棋盘格子的显示；
  - `private func getSquareColor`：染色；
  - `private func isInteractive`：设定按钮状态；
- `struct ChessBoardRowView`：棋盘行视图；
  - 实现棋盘单行的显示；
  - 调用`struct ChessSquareView`；
- `struct ChessBoardView`：棋盘视图；
  - 实现棋盘的完整显示；
  - 调用`struct ChessBoardRowView`；
- `struct MenuButtonView`：菜单按钮视图；
  - 作为定义主菜单按钮的模板，避免代码的大量重复；
- `struct SidebarView`：侧边栏视图；
  - `private var gameInfoView`：显示当前存档路径、当前回合、当前阶段、历史操作；
  - `private var phaseDescription`：把阶段的代号转换成文字描述；
  - `private var welcomeView`：显示第一局游戏开始前的引导信息；
- `struct MainMenuView`：主菜单视图；
  - 实现主菜单的显示；
  - 多次调用`struct MenuButtonView`，实现各个菜单按钮；
  - 依据状态变量的不同，显示不同的按钮；
- `struct ContentView`：主视图。
  - 定义各个变量；
  - 划分窗口结构：
    - 调用`SidebarView`，实现左侧栏的状态显示；
    - 调用`MainMenuView`，实现左下角的菜单控制；
    - 调用`ChessBoardView`，实现右侧的棋盘显示。
  - 定义函数`private func setWindowTitle`
    - 使用`.onAppear`在程序启动时设置窗口标题。
## 状态变量
`ContentView`中的变量声明：
```swift
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
```
- `withfile`：标记当前程序是否选定了存档目录：
  - 若为`0`：未选中存档，左侧栏第一行显示“新游戏：尚未保存”，“快速保存”不可用；
  - 若为`1`：已选中存档，对应显示存档目录；
- `chessBoard`：二维数组，标记棋子位置；
- `currentUrl`：
  - 标记存档目录，和`withfile`配合，也是用于实现左侧栏存档目录的显示；
  - 用于快速存档；
- `unsavable`：标记存档是否已保存：
  - 读取存档会使其为`1`，“保存”按钮变灰，显示“已保存”；
  - 移动棋子/开启新游戏会使其变为`0`；
- `isPlaying`：标记是否处于棋局中：
  - 启动程序时为`0`，此时菜单栏只显示3项；
  - 读取存档或创建新游戏，会变成`1`，显示完整的菜单栏；
- `blackRound`：标记当前回合方：
  - 默认为`0`；
  - 为`0`表示是黑方，否则为白方；
- `history`：历史记录：
- `availableMoves`：可用移动位置的计算结果，作用如上述，可设定按钮状态、染色；
- `selectedPiece`：是否已选中棋子，决定下面的`gamePhase`；
- `gamePhase`：游戏阶段：
  - 在侧边栏显示；
  - 自动下棋函数会用到这个变量，通过`switch`语句来区分行为；
- `whiteAutoOperate`和`blackAutoOperate`：标记白/黑方是否在自动下棋。
