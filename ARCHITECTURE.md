# MVVM + Clean Architecture 架构说明

本文档以本工程（wanandroid Banner Demo）为例，介绍 MVVM + Clean Architecture 的分层结构、调用关系、好处、适用范围，以及"是不是每一层都一定需要"的取舍建议。

---

## 一、整体分层与调用关系

### 1.1 分层结构

```
CleanArchitectureDemo/
├── Application/                 组装层（Composition Root）
│   ├── DIContainer.swift        依赖注入容器，组装各层
│   └── SceneDelegate.swift      代码启动，创建根 VC
│
├── Presentation/                表现层（MVVM 中的 V + VM）
│   └── Home/
│       ├── HomeViewController.swift   View：只负责展示与用户交互
│       ├── HomeViewModel.swift        ViewModel：持有 UI 状态，调用 UseCase
│       └── BannerCell.swift           View：列表 Cell
│
├── Domain/                      领域层（业务核心，最稳定）
│   ├── Entities/Banner.swift            业务实体（纯 Swift，无框架依赖）
│   ├── Interfaces/BannerRepository.swift 仓库协议（抽象，不含实现）
│   └── UseCases/GetBannersUseCase.swift  用例：封装单一业务动作
│
├── Data/                        数据层（Domain 抽象的具体实现）
│   ├── DTOs/BannerDTO.swift             网络模型 + toDomain() 映射
│   └── Repositories/BannerRepositoryImpl.swift 仓库实现（网络版）
│
└── Network/                     基础设施层
    ├── NetworkService.swift     URLSession + async/await 泛型请求
    ├── APIEndpoint.swift        接口定义
    └── NetworkError.swift       错误类型
```

### 1.2 调用链（运行时数据流）

```
HomeViewController          用户下拉刷新 / 页面加载
        │  viewModel.loadBanners()
        ▼
HomeViewModel               state = .loading，发起异步任务
        │  getBannersUseCase.execute()
        ▼
GetBannersUseCase           业务用例（此处直接透传，复杂业务在这里编排）
        │  repository.fetchBanners()
        ▼
BannerRepository (协议)      ◄─── Domain 层只认识这个抽象
        │  由 BannerRepositoryImpl 实现
        ▼
BannerRepositoryImpl        请求网络 → 校验 errorCode → DTO 转 Domain 实体
        │  networkService.request(.banner, as:)
        ▼
NetworkService              URLSession 发请求、解码 JSON
        │
        ▼
wanandroid API              https://www.wanandroid.com/banner/json
```

响应沿原路返回：`[BannerDTO]` 在 Repository 中被映射为 `[Banner]`，ViewModel 将其包装为 `state = .loaded(banners)`，VC 通过 Combine 订阅 `$state` 刷新 UITableView。

### 1.3 依赖方向（编译期依赖）

依赖方向与调用方向不完全相同，这是 Clean Architecture 的关键：

```
Presentation ──► Domain ◄── Data ──► Network
```

- **Presentation 依赖 Domain**：ViewModel 持有 `GetBannersUseCase`，使用 `Banner` 实体。
- **Data 依赖 Domain**：`BannerRepositoryImpl` 实现 Domain 定义的 `BannerRepository` 协议 —— 这就是**依赖倒置（DIP）**。不是 Domain 依赖 Data，而是 Data 反过来依赖 Domain 的抽象。
- **Domain 不依赖任何人**：`Banner`、`BannerRepository`、`GetBannersUseCase` 是纯 Swift，不 import UIKit，不认识 URLSession，不知道 JSON 长什么样。

各层的连接由 `DIContainer` 在组装层完成：

```swift
// DIContainer.swift
let useCase = GetBannersUseCase(repository: bannerRepository)  // 注入实现
let viewModel = HomeViewModel(getBannersUseCase: useCase)
return HomeViewController(viewModel: viewModel)
```

### 1.4 各层职责一句话总结

| 层 | 职责 | 本工程对应 | 不允许做的事 |
|---|---|---|---|
| View (VC) | 展示 UI、转发用户事件 | `HomeViewController` | 不写业务逻辑，不直接发请求 |
| ViewModel | 持有 UI 状态、调用 UseCase | `HomeViewModel` | 不 import UIKit，不知道数据来源 |
| UseCase | 封装单一业务动作、编排多个 Repository | `GetBannersUseCase` | 不关心 UI，不关心网络细节 |
| Repository | 提供数据、屏蔽来源（网络/缓存/数据库） | `BannerRepositoryImpl` | 不向上暴露 DTO，必须转成 Domain 实体 |
| Network | 纯粹的 HTTP 通信与解码 | `NetworkService` | 不含任何业务判断 |

---

## 二、MVVM + Clean Architecture 的好处

### 2.1 UI 不关心数据来源

`HomeViewModel` 只知道 `getBannersUseCase.execute()` 返回 `[Banner]`。数据是来自网络、本地缓存还是 Mock，对 ViewModel 完全透明。数据来源变更（比如加一层磁盘缓存）不需要动 Presentation 层任何一行代码。

### 2.2 数据来源可自由切换

因为上层只依赖 `BannerRepository` 协议，切换实现只需在 `DIContainer` 改一行：

```swift
// 网络版
lazy var bannerRepository: BannerRepository = BannerRepositoryImpl(networkService: networkService)

// 换成本地缓存版 / 离线版，上层无感知
lazy var bannerRepository: BannerRepository = LocalBannerRepository()
```

### 2.3 测试方便

每一层都可以被单独测试，依赖全部通过初始化器注入：

```swift
// 测试 ViewModel：注入 Mock Repository，不发真实网络请求
final class MockBannerRepository: BannerRepository {
    var result: Result<[Banner], Error> = .success([])
    func fetchBanners() async throws -> [Banner] { try result.get() }
}

let useCase = GetBannersUseCase(repository: MockBannerRepository())
let viewModel = HomeViewModel(getBannersUseCase: useCase)
viewModel.loadBanners()
// 断言 viewModel.state == .loaded(...)
```

- 测 ViewModel → Mock UseCase / Repository
- 测 UseCase → Mock Repository
- 测 Repository → Mock NetworkService（返回本地 JSON）

全程不需要启动 UI，不需要真实网络。

### 2.4 网络模型与业务模型隔离（DTO 映射）

`BannerDTO` 与后端 JSON 一一对应，`Banner` 只保留业务需要的字段（并把 `String` 转成了 `URL?`）。后端加字段、改字段名，只影响 DTO 和 `toDomain()` 一处；几十个用到 `Banner` 的 UI 页面不受波及。

### 2.5 业务逻辑集中、可复用

UseCase 是业务动作的唯一入口。今天"获取 Banner"只是透传，明天需求变成"获取 Banner 并过滤不可见项、按 order 排序、最多取 5 条"，这些规则都写在 `GetBannersUseCase` 里 —— 首页、搜索页、Widget 复用同一个 UseCase，规则只写一遍。

### 2.6 团队协作友好

层与层之间以协议为契约，前后端联调未完成时，可以先用 Mock Repository 把 UI 做完；多人并行开发互不阻塞。

---

## 三、适用范围

### 3.1 适合的场景

- **中大型项目**：模块多、业务规则复杂、生命周期长（一两年以上持续迭代）。
- **多人团队**：需要明确的分层契约来划分职责、并行开发。
- **重测试的项目**：需要给业务逻辑写单元测试（金融、交易、健康类 App）。
- **数据来源多样/易变**：同一份数据可能来自网络、数据库、缓存，或者后端接口频繁变动。
- **多端复用业务逻辑**：App + Widget + App Clip 共享同一套 Domain 层。

### 3.2 不太适合的场景

- **一次性 Demo、活动页、原型验证**：架构成本大于收益，直接 VC 里发请求反而更快。
- **纯展示型页面**（如静态 H5 容器、说明页）：没有业务逻辑可言，没必要为一个页面建 5 个文件。
- **极小团队 + 极简 App**：1 个人维护的 3 个页面小工具，MVVM 单层就够了。

### 3.3 经验法则

> 架构解决的是"规模"和"变化"的问题。项目越大、活得越久、改动越频繁，分层收益越大；反之，分层就是负担。

---

## 四、是不是每一层都一定需要？

**不是。** Clean Architecture 的核心只有一条原则：**依赖指向业务核心（Domain），业务核心不依赖任何框架和实现细节**。层数本身可以按项目规模伸缩。

### 4.1 各层的取舍建议

| 层 | 是否可省 | 说明 |
|---|---|---|
| ViewModel | 基本不可省 | MVVM 的核心。省掉它 UI 状态和业务调用会重新混进 VC，回到 Massive View Controller |
| Repository 协议 | 强烈建议保留 | 依赖倒置的支点，是"可测试、可换源"这两个好处的来源，成本极低（一个 protocol） |
| UseCase | 可省 | 业务只是透传时（如本 Demo），ViewModel 直接调 Repository 完全可以。等业务规则出现（过滤、排序、多接口聚合）再补 UseCase 也不迟 |
| DTO 映射 | 可省 | 后端字段与业务模型几乎一致且稳定时，直接让 Entity 实现 Codable 也能接受；但接口易变时 DTO 层非常值 |
| 独立 Network 层 | 可省 | 小项目里 Repository 直接用 URLSession 即可；接口一多，统一的请求/解码/错误处理就有价值 |
| DIContainer | 可简化 | 小项目手动在 SceneDelegate 里 new 也行；页面多了再引入容器或 DI 框架 |

### 4.2 常见的渐进式演化路径

```
阶段一（小项目）    VC → ViewModel → URLSession
                          页面能跑、状态分离，够用

阶段二（中型）      VC → ViewModel → Repository(协议) → Network
                          可测试、可换数据源

阶段三（大型）      VC → ViewModel → UseCase → Repository(协议) → Network + 本地存储
                          业务规则集中，多页面/多端复用（即本 Demo 的完整形态）
```

建议**按需演进**而不是一步到位：先保证 ViewModel 和 Repository 协议这两个最有性价比的抽象，UseCase、DTO、DI 容器在复杂度真正出现时再引入。

### 4.3 反过来的警告

省层可以，但**不要跨层**：

- VC 直接调 Repository / 发网络请求 —— UI 和数据耦合，测试无从下手；
- Repository 向上返回 DTO —— 网络模型渗透进 UI，后端一改全线崩；
- ViewModel import UIKit —— ViewModel 变得不可脱离 UI 测试。

省掉的层是"合并职责"，跨掉的层是"破坏依赖方向"，前者可接受，后者会让架构逐渐失效。

---

## 五、本 Demo 快速索引

| 关注点 | 文件 |
|---|---|
| 调用链入口 | `Presentation/Home/HomeViewController.swift` |
| UI 状态管理 | `Presentation/Home/HomeViewModel.swift` |
| 业务用例 | `Domain/UseCases/GetBannersUseCase.swift` |
| 依赖倒置的协议 | `Domain/Interfaces/BannerRepository.swift` |
| 数据实现 + DTO 映射 | `Data/Repositories/BannerRepositoryImpl.swift` |
| 网络封装 | `Network/NetworkService.swift` |
| 依赖组装 | `Application/DIContainer.swift` |
