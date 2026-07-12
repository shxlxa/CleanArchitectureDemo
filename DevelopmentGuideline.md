# UIKit + MVVM + Clean Architecture 开发规范

> 版本：v1.0.0 | 适用项目：中大型 UIKit 商业项目 | 更新日期：2026-07

---

## 目录

1. [为什么选择 MVVM + Clean Architecture](#chapter-1)
2. [整体架构](#chapter-2)
3. [Presentation Layer](#chapter-3)
4. [ViewController 开发规范](#chapter-4)
5. [ViewModel 开发规范](#chapter-5)
6. [Coordinator](#chapter-6)
7. [Domain Layer](#chapter-7)
8. [Entity](#chapter-8)
9. [UseCase](#chapter-9)
10. [Repository](#chapter-10)
11. [Data Layer](#chapter-11)
12. [DTO 与 Mapper](#chapter-12)
13. [Dependency Injection](#chapter-13)
14. [async/await 与 Combine](#chapter-14)
15. [错误处理](#chapter-15)
16. [项目目录规范](#chapter-16)
17. [命名规范](#chapter-17)
18. [完整页面示例](#chapter-18)
19. [Code Review Checklist](#chapter-19)
20. [常见反模式（Anti-Patterns）](#chapter-20)

---

<a name="chapter-1"></a>
# 第一章：为什么选择 MVVM + Clean Architecture

## 1.1 MVC 的问题

MVC（Model-View-Controller）是 Apple 为 UIKit 设计的原生架构模式。在小型项目中，MVC 简单、直接、上手快。但在中大型商业项目中，MVC 会暴露出以下问题：

### 问题一：Massive View Controller（胖控制器）

ViewController 在 MVC 中承担了过多职责：

```
UIViewController（MVC 中的现实）
├── UI 布局
├── 生命周期管理
├── 网络请求
├── 数据库读写
├── 业务逻辑
├── 格式化展示
├── 页面跳转
├── 错误处理
└── 通知监听
```

一个「登录页面」的 ViewController 在 MVC 下动辄超过 800 行，团队成员不敢改，不会改，最终只能加。

### 问题二：不可测试

ViewController 耦合了 UIKit，无法在 Xcode Unit Test 中独立运行，所有逻辑只能靠手动点击来验证。

### 问题三：代码复用困难

业务逻辑写在 ViewController A 里，ViewController B 需要相同逻辑，只能 Copy-Paste，导致多份重复代码。

### 问题四：依赖不清晰

ViewController 直接依赖 `URLSession`、`CoreData`、第三方 SDK，当需要替换实现时，修改成本极高。

---

## 1.2 MVVM 解决了什么

MVVM（Model-View-ViewModel）的核心思想是：**将展示逻辑从 ViewController 中抽离出来**。

```
┌─────────────────────────────────────┐
│           Presentation              │
│                                     │
│  ┌──────────┐       ┌────────────┐  │
│  │   View   │◄──────│ ViewModel  │  │
│  │    +     │       │            │  │
│  │  ViewCtrl│──────►│ (No UIKit) │  │
│  └──────────┘       └────────────┘  │
└─────────────────────────────────────┘
```

MVVM 带来的好处：

| 问题 | MVVM 的解法 |
|------|------------|
| ViewController 太胖 | 将展示逻辑移入 ViewModel |
| 不可测试 | ViewModel 不依赖 UIKit，可纯 Swift 单测 |
| 格式化逻辑散落各处 | 集中在 ViewModel 中处理 |

**MVVM 的局限**：MVVM 只解决了展示层问题，它没有规定业务逻辑应该放在哪里，也没有规定数据访问应该如何组织。

---

## 1.3 Clean Architecture 解决了什么

Clean Architecture（整洁架构）由 Robert C. Martin（Uncle Bob）提出，核心思想是：**将软件分层，依赖只能由外向内，内层对外层一无所知**。

在 iOS 项目中，Clean Architecture 解决：

1. **业务逻辑的归宿**：UseCase 承载业务流程
2. **数据访问的隔离**：Repository 隐藏数据来源（API / 数据库 / 缓存）
3. **依赖方向的控制**：通过 Protocol 反转依赖
4. **可替换性**：轻松替换 API 实现、数据库实现，无需改动业务逻辑

---

## 1.4 为什么 UIKit 项目适合这种架构

SwiftUI 提供了响应式 UI 更新机制（`@State`, `@ObservedObject`），与数据绑定天然结合。

UIKit 没有这套机制，开发者必须**手动管理状态同步**，这正是 MVVM + Clean Architecture 能发挥价值的地方：

- ViewModel 统一管理状态，ViewController 只负责把状态渲染成 UI
- UseCase 管理业务流程，ViewModel 不需要知道"钱从哪里来"
- Repository 管理数据，UseCase 不需要知道"数据从 API 来还是从缓存来"

---

## 1.5 为什么不要把所有逻辑放到 ViewController

**类比**：一家餐厅，如果服务员（ViewController）同时负责：
- 接待客人（UI 交互）
- 亲自下厨（业务逻辑）
- 去仓库取货（数据访问）
- 记账管理（缓存管理）

那这家餐厅效率极低，无法扩张。

正确做法是分工：服务员只接待客人，厨师只做菜，仓库管理只管存货。

### Best Practice

- 每次写代码前问自己：「这段逻辑属于哪一层？」
- ViewController 中若出现 `URLSession`、`UserDefaults`、`CoreData` 的直接调用，立即重构

### Common Mistakes

- 「先写在 VC 里，以后再抽」——以后永远不会抽
- 「这个项目不大，不需要分层」——架构是为未来的自己服务的

### Checklist

- [ ] ViewController 是否超过 300 行？若是，检查是否承担了不属于它的职责
- [ ] 是否存在直接在 ViewController 里调用网络请求的代码？
- [ ] 是否存在业务逻辑散落在多个 ViewController 中的情况？

---

<a name="chapter-2"></a>
# 第二章：整体架构

## 2.1 架构总览

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│                                                          │
│   ┌───────────┐   ┌──────────────┐   ┌──────────────┐  │
│   │   UIView  │   │ViewController│   │  Coordinator │  │
│   │   + Cell  │   │              │   │              │  │
│   └─────┬─────┘   └──────┬───────┘   └──────┬───────┘  │
│         │                │                  │           │
│         └────────────────┼──────────────────┘           │
│                          │                               │
│                   ┌──────▼───────┐                       │
│                   │  ViewModel   │                       │
│                   └──────┬───────┘                       │
└──────────────────────────┼──────────────────────────────┘
                           │
┌──────────────────────────┼──────────────────────────────┐
│                    Domain Layer                          │
│                          │                               │
│                   ┌──────▼───────┐                       │
│                   │   UseCase    │                       │
│                   └──────┬───────┘                       │
│                          │                               │
│                   ┌──────▼───────┐                       │
│                   │  Repository  │  ← Protocol only      │
│                   │  (Protocol)  │                       │
│                   └──────┬───────┘                       │
│                          │                               │
│                   ┌──────▼───────┐                       │
│                   │    Entity    │                       │
│                   └──────────────┘                       │
└──────────────────────────┼──────────────────────────────┘
                           │
┌──────────────────────────┼──────────────────────────────┐
│                     Data Layer                           │
│                          │                               │
│              ┌───────────▼──────────────┐               │
│              │     RepositoryImpl       │               │
│              └───────┬──────────┬───────┘               │
│                      │          │                        │
│          ┌───────────▼──┐   ┌───▼──────────────┐        │
│          │ RemoteDataSrc│   │  LocalDataSource  │        │
│          └───────┬───────┘   └──────┬───────────┘        │
│                  │                  │                     │
│          ┌───────▼───────┐   ┌──────▼───────────┐        │
│          │  API Client   │   │  CoreData/Realm   │        │
│          └───────────────┘   └──────────────────┘        │
└─────────────────────────────────────────────────────────┘
```

## 2.2 各层职责一览

| 层级 | 包含内容 | 核心职责 |
|------|---------|---------|
| Presentation | ViewController, UIView, ViewModel, Coordinator | 展示 UI，响应用户操作，驱动导航 |
| Domain | UseCase, Entity, Repository Protocol | 业务规则，数据模型，接口定义 |
| Data | RepositoryImpl, DataSource, DTO, Mapper | 数据获取，数据转换，缓存管理 |

## 2.3 依赖方向

```
Presentation ──依赖──► Domain ◄──依赖── Data
                │
                └── Domain 不知道 Presentation 和 Data 的存在
```

**依赖只能向内**：
- Presentation 依赖 Domain（调用 UseCase、持有 Entity）
- Data 依赖 Domain（实现 Repository Protocol、使用 Entity）
- Domain **不依赖任何层**，它是系统的核心

**为什么依赖只能向内？**

Domain 层包含业务规则，是最有价值、最稳定的代码。UI 框架会变（UIKit → SwiftUI），API 会变，数据库会变，但业务规则相对稳定。通过让外层依赖内层，当外层变化时，内层不需要修改。

## 2.4 数据流

```
用户操作
    │
    ▼
ViewController.buttonTapped()
    │
    ▼
ViewModel.login(username:password:)
    │
    ▼
LoginUseCase.execute(credentials:)
    │
    ▼
AuthRepository.login(credentials:)  ← 调用 Protocol
    │
    ▼
AuthRepositoryImpl.login(credentials:)  ← 真正实现
    │
    ▼
RemoteDataSource.loginRequest(dto:)
    │
    ▼
API Response (DTO)
    │
    ▼
Mapper.toEntity(dto:)
    │
    ▼
User (Entity) 一路向上返回
    │
    ▼
ViewModel 更新状态
    │
    ▼
ViewController 渲染 UI
```

### Best Practice

- 严格遵守依赖方向，Domain 层绝不 `import UIKit`
- 数据模型在层之间传递时使用对应的类型（DTO → Entity → ViewModel State）

### Common Mistakes

- 直接把 DTO 传到 ViewModel 或 ViewController
- ViewModel 直接持有 RepositoryImpl 而不是 Repository Protocol
- UseCase 中直接调用 URLSession

### Checklist

- [ ] Domain 层是否有 `import UIKit`？
- [ ] Data 层的 DTO 是否泄漏到 Presentation 层？
- [ ] 所有跨层依赖是否通过 Protocol 实现？

---

<a name="chapter-3"></a>
# 第三章：Presentation Layer

## 3.1 什么是 Presentation

**字面意思**：Presentation = 展示。这一层负责将数据「展示」给用户，并将用户的操作「传递」给下层。

**在架构中的作用**：Presentation 层是用户唯一能直接接触的层。它接收来自 Domain 层的数据，将其渲染为可视化 UI；它接收用户的操作，将其转换为 Domain 层能理解的指令。

**为什么独立成一层**：UI 变化频繁（改版、A/B 测试、适配不同设备），将 UI 逻辑隔离在 Presentation 层，可以在不影响 Domain 和 Data 层的情况下随意改动 UI。

## 3.2 Presentation 层包含的对象

```
Presentation Layer
├── ViewController      ← 生命周期 + UI 渲染 + 事件传递
├── UIView / Cell       ← 纯展示组件
├── ViewModel           ← 展示逻辑 + 状态管理
└── Coordinator         ← 导航管理
```

## 3.3 各对象职责

### ViewController

**负责**：
- 管理视图生命周期（`viewDidLoad`, `viewWillAppear` 等）
- 初始化并布局 UI 组件
- 绑定 ViewModel（监听状态变化，更新 UI）
- 将用户操作传递给 ViewModel
- 调用 Coordinator 进行导航

**不负责**：
- 不写任何业务逻辑
- 不直接调用网络 / 数据库 / 蓝牙 / MQTT
- 不做数据格式化（这是 ViewModel 的事）
- 不直接 `push` / `present` 其他 ViewController

### UIView / Cell

**负责**：
- 渲染 UI
- 提供配置接口（`configure(with:)` 方法）

**不负责**：
- 不持有 ViewModel
- 不发起任何业务操作
- 不直接处理数据转换

### ViewModel

**负责**：
- 持有并管理 UI 状态（`@Published` 或 `AsyncStream`）
- 展示逻辑（格式化、排序、过滤）
- 调用 UseCase 执行业务流程
- 将 UseCase 返回的 Entity 转换为 UI 可用的 ViewState

**不负责**：
- 不持有任何 UIKit 类型
- 不负责导航
- 不直接调用 API

### Coordinator

**负责**：
- 页面跳转逻辑
- 持有并管理子 Coordinator
- 根据业务状态决定导航路径

**不负责**：
- 不处理业务逻辑
- 不直接操作数据

### Best Practice

- ViewModel 中绝不出现 `UIColor`, `UIFont`, `UIImage` 等 UIKit 类型
- View 只通过 `configure(with: ViewModel.ViewState)` 接收数据
- Coordinator 承担所有的页面跳转，ViewController 通过 delegate / closure 通知 Coordinator

### Common Mistakes

- ViewModel 返回 `UIColor`（正确做法：返回枚举或字符串，在 View 层映射为颜色）
- Cell 持有 ViewModel 引用并直接调用方法
- ViewController 在 `didSelectRow` 中 `push` 下一个页面

### Checklist

- [ ] ViewModel 是否有 `import UIKit`？
- [ ] Cell 是否只有 `configure(with:)` 接口？
- [ ] 所有的 `push`/`present` 是否都通过 Coordinator 发起？

---

<a name="chapter-4"></a>
# 第四章：ViewController 开发规范

## 4.1 职责定义

ViewController 是 Presentation 层的「导演」：它不亲自表演（不写业务逻辑），只负责协调各个角色（UI 组件、ViewModel、Coordinator）。

```
ViewController 应该负责
├── 生命周期管理
│   ├── viewDidLoad: 初始化 UI + 绑定 ViewModel
│   ├── viewWillAppear: 触发数据刷新（如需）
│   └── deinit: 取消异步任务
│
├── UI 初始化与布局
│   ├── 创建 UIView 实例
│   └── 使用 Auto Layout 或 frame 布局
│
├── ViewModel 绑定
│   ├── 监听 ViewModel 状态变化
│   └── 将状态映射为 UI 更新
│
└── 用户交互响应
    ├── 按钮点击 → 调用 ViewModel 方法
    └── 页面跳转 → 通知 Coordinator
```

## 4.2 标准 ViewController 模板

```swift
final class DeviceListViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: DeviceListViewModel
    private let coordinator: DeviceListCoordinator
    private var tasks: [Task<Void, Never>] = []

    // MARK: - UI Components

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(DeviceCell.self, forCellReuseIdentifier: DeviceCell.reuseIdentifier)
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }()

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(refreshTriggered), for: .valueChanged)
        return control
    }()

    // MARK: - Init

    init(viewModel: DeviceListViewModel, coordinator: DeviceListCoordinator) {
        self.viewModel = viewModel
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(viewModel:coordinator:)")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        Task { await viewModel.loadDevices() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.title = "我的设备"
    }

    deinit {
        tasks.forEach { $0.cancel() }
    }
}

// MARK: - UI Setup

private extension DeviceListViewController {

    func setupUI() {
        view.backgroundColor = .systemBackground
        view.addSubview(tableView)
        view.addSubview(loadingIndicator)
        tableView.addSubview(refreshControl)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

// MARK: - ViewModel Binding

private extension DeviceListViewController {

    func bindViewModel() {
        let task = Task { [weak self] in
            guard let self else { return }
            for await state in viewModel.stateStream {
                await MainActor.run {
                    self.render(state: state)
                }
            }
        }
        tasks.append(task)
    }

    func render(state: DeviceListViewModel.State) {
        switch state {
        case .idle:
            break
        case .loading:
            loadingIndicator.startAnimating()
            tableView.isHidden = true
        case .loaded:
            loadingIndicator.stopAnimating()
            refreshControl.endRefreshing()
            tableView.isHidden = false
            tableView.reloadData()
        case .error(let message):
            loadingIndicator.stopAnimating()
            refreshControl.endRefreshing()
            showError(message: message)
        }
    }
}

// MARK: - User Actions

private extension DeviceListViewController {

    @objc func refreshTriggered() {
        Task { await viewModel.refreshDevices() }
    }
}

// MARK: - UITableViewDataSource

extension DeviceListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: DeviceCell.reuseIdentifier,
            for: indexPath
        ) as? DeviceCell else {
            return UITableViewCell()
        }
        cell.configure(with: viewModel.devices[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension DeviceListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let device = viewModel.devices[indexPath.row]
        coordinator.showDeviceDetail(deviceId: device.id)
    }
}

// MARK: - Error Handling

private extension DeviceListViewController {

    func showError(message: String) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
```

## 4.3 ViewController 绝对禁止的代码

```swift
// ❌ 错误：直接在 ViewController 中发起网络请求
func viewDidLoad() {
    super.viewDidLoad()
    URLSession.shared.dataTask(with: url) { data, _, _ in
        // 处理数据...
    }.resume()
}

// ❌ 错误：在 ViewController 中写业务判断
func loginButtonTapped() {
    if username.isEmpty || password.isEmpty {
        showError("请填写账号密码")
        return
    }
    if password.count < 6 {
        showError("密码不能少于6位")
        return
    }
    // 继续...
}

// ❌ 错误：直接 push 下一个页面
func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let vc = DeviceDetailViewController(deviceId: devices[indexPath.row].id)
    navigationController?.pushViewController(vc, animated: true)
}

// ❌ 错误：持有 Repository 或 UseCase 的实现
class UserProfileViewController: UIViewController {
    private let repository = UserRepositoryImpl()  // 直接持有实现
}
```

### Best Practice

- ViewController 方法平均不超过 20 行
- 使用 `// MARK: -` 明确分区
- 所有 UI 组件使用 `lazy var` 并在初始化时完成配置
- 用 `deinit` 取消 `Task`，防止内存泄漏

### Common Mistakes

- `viewDidLoad` 超过 50 行
- 使用 `NotificationCenter` 在 ViewController 间直接传递业务数据
- 在 ViewController 中做条件判断决定「是否登录成功」

### Checklist

- [ ] ViewController 是否超过 400 行？
- [ ] `viewDidLoad` 中是否有业务逻辑？
- [ ] 是否存在 `URLSession`、`Alamofire` 的直接调用？
- [ ] 是否有 `UserDefaults` 的直接读写？
- [ ] 所有 `push`/`present` 是否通过 Coordinator？
- [ ] `Task` 是否在 `deinit` 中取消？

---

<a name="chapter-5"></a>
# 第五章：ViewModel 开发规范

## 5.1 ViewModel 的本质

ViewModel 是 Presentation Layer 的「大脑」：它持有 UI 状态，处理展示逻辑，调用 UseCase 执行业务流程，但它对 UIKit **一无所知**。

```
ViewModel 在整体架构中的位置

ViewController ◄──── 状态/数据 ────── ViewModel
     │                                    │
     │── 用户操作 ──────────────────────►  │
                                          │
                               ◄── Entity ─ UseCase
                                          │
                                          └── (或直接调用 Repository，见 5.4)
```

## 5.2 展示逻辑 vs 业务逻辑

这是 ViewModel 设计中最容易混淆的概念。

| 类型 | 定义 | 示例 | 属于哪里 |
|------|------|------|---------|
| 展示逻辑 | 数据如何展示给用户 | 日期格式化、金额格式化、文字拼接 | ViewModel |
| 业务逻辑 | 业务规则和流程 | 下单扣库存、登录后写 Token、满减计算 | UseCase |

```swift
// ✅ 展示逻辑：属于 ViewModel
func formattedDate(from date: Date) -> String {
    DateFormatter.shared.string(from: date)
}

func formattedPrice(amount: Decimal, currency: String) -> String {
    "\(currency) \(amount.formatted(.number.precision(.fractionLength(2))))"
}

// ✅ 业务逻辑：属于 UseCase，ViewModel 只负责调用
func checkout() async {
    let result = await checkoutUseCase.execute(cart: currentCart)
    // ...
}
```

## 5.3 ViewModel 允许的操作

| 操作 | 是否允许 | 说明 |
|------|---------|------|
| 调用 UseCase | ✅ 推荐 | 复杂业务流程必须走 UseCase |
| 直接调用 Repository | ⚠️ 谨慎 | 简单 CRUD 可以，见下文 |
| 格式化时间/金额 | ✅ | 展示逻辑，属于 ViewModel |
| 排序/过滤列表 | ✅ | 展示逻辑（无业务含义） |
| 拼接字符串 | ✅ | 展示逻辑 |
| 条件判断业务规则 | ❌ | 属于 UseCase |
| 直接访问网络 | ❌ | 必须通过 Repository |
| 持有 UIKit 类型 | ❌ | 破坏可测试性 |

### 关于 ViewModel 是否可以直接调用 Repository

```
简单场景：ViewModel → Repository（可以）
    例：读取用户资料，无任何业务规则

复杂场景：ViewModel → UseCase → Repository（必须）
    例：支付流程（验证、扣款、通知、日志），存在多步业务规则
```

**判断标准**：如果操作涉及多个步骤、多个数据源、或有业务规则判断，必须引入 UseCase。

## 5.4 标准 ViewModel 模板

```swift
@MainActor
final class DeviceListViewModel {

    // MARK: - State

    enum State {
        case idle
        case loading
        case loaded
        case error(String)
    }

    // MARK: - ViewState（传给 Cell 的数据结构）

    struct DeviceViewState {
        let id: String
        let name: String
        let statusText: String
        let statusColor: String    // 注意：返回 String 而非 UIColor
        let lastSeenText: String
    }

    // MARK: - Output

    private(set) var devices: [DeviceViewState] = []
    private let stateContinuation: AsyncStream<State>.Continuation
    let stateStream: AsyncStream<State>

    // MARK: - Dependencies

    private let fetchDevicesUseCase: FetchDevicesUseCaseProtocol
    private let dateFormatter: DateFormatterProtocol

    // MARK: - Init

    init(
        fetchDevicesUseCase: FetchDevicesUseCaseProtocol,
        dateFormatter: DateFormatterProtocol = DateFormatterImpl()
    ) {
        self.fetchDevicesUseCase = fetchDevicesUseCase
        self.dateFormatter = dateFormatter

        var continuation: AsyncStream<State>.Continuation!
        stateStream = AsyncStream { continuation = $0 }
        stateContinuation = continuation
    }

    // MARK: - Input

    func loadDevices() async {
        stateContinuation.yield(.loading)
        do {
            let entities = try await fetchDevicesUseCase.execute()
            devices = entities.map { mapToViewState($0) }
            stateContinuation.yield(.loaded)
        } catch {
            stateContinuation.yield(.error(error.localizedDescription))
        }
    }

    func refreshDevices() async {
        await loadDevices()
    }
}

// MARK: - Mapping（展示逻辑）

private extension DeviceListViewModel {

    func mapToViewState(_ entity: DeviceEntity) -> DeviceViewState {
        DeviceViewState(
            id: entity.id,
            name: entity.name,
            statusText: statusText(for: entity.status),
            statusColor: statusColorName(for: entity.status),
            lastSeenText: dateFormatter.relativeString(from: entity.lastSeenAt)
        )
    }

    func statusText(for status: DeviceStatus) -> String {
        switch status {
        case .online:  return "在线"
        case .offline: return "离线"
        case .error:   return "故障"
        }
    }

    func statusColorName(for status: DeviceStatus) -> String {
        switch status {
        case .online:  return "green"
        case .offline: return "gray"
        case .error:   return "red"
        }
    }
}
```

## 5.5 @MainActor 使用规范

```swift
// ✅ 在类级别标记 @MainActor，确保所有 UI 状态更新在主线程
@MainActor
final class LoginViewModel {
    // 所有属性和方法自动在主线程运行
}

// ✅ 在 Task 中调用 non-isolated 异步方法
func login() async {
    // 当前在 MainActor 上
    state = .loading
    
    // 网络请求自动切换到合适的线程
    let result = try await loginUseCase.execute(credentials)
    
    // 回到 MainActor 更新状态
    state = .loaded(result)
}
```

### Best Practice

- ViewModel 使用 `@MainActor` 修饰，避免手动切换线程
- 通过 `AsyncStream` 向 ViewController 推送状态变化
- ViewState 使用值类型（struct），避免共享状态问题
- ViewModel 不持有 ViewController 的强引用

### Common Mistakes

- ViewModel 中 `import UIKit`（破坏可测试性）
- ViewModel 直接调用 `URLSession`（应通过 Repository）
- ViewModel 在后台线程更新 `@Published` 属性而不切换到主线程
- 把所有逻辑都放在 ViewModel，UseCase 形同虚设

### Checklist

- [ ] ViewModel 是否有 `import UIKit`？
- [ ] ViewModel 是否可以在不启动 App 的情况下进行单元测试？
- [ ] 展示逻辑（格式化）是否在 ViewModel，业务逻辑是否在 UseCase？
- [ ] ViewState 是否使用 struct？
- [ ] 状态更新是否在 `@MainActor` 上进行？

---

<a name="chapter-6"></a>
# 第六章：Coordinator

## 6.1 为什么需要 Coordinator

**问题**：在没有 Coordinator 的项目中：

```swift
// ❌ ViewController 直接负责导航
func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let device = devices[indexPath.row]
    let detailVC = DeviceDetailViewController(deviceId: device.id)
    detailVC.delegate = self
    navigationController?.pushViewController(detailVC, animated: true)
}
```

这带来的问题：
1. **ViewController 之间强耦合**：A 直接创建 B，A 必须知道 B 的初始化参数
2. **导航逻辑散落各处**：修改导航流程需要改多个 ViewController
3. **无法复用**：同一个页面在不同入口显示不同的导航流程
4. **测试困难**：ViewController 依赖 `navigationController`，不易单测

**Coordinator 解法**：

```
ViewController A ──通知──► Coordinator ──创建并展示──► ViewController B
                              │
                              └── 持有 navigationController
                              └── 持有所有子页面的创建逻辑
```

## 6.2 导航应该属于谁

**导航是业务流程的一部分**，不是 UI 的一部分。

- 用户点击「登录」→ 登录成功 → 进入首页，还是进入引导页？这是**业务决策**
- Coordinator 根据业务状态（是否完成引导、是否有权限）决定跳转目标

## 6.3 Coordinator 标准实现

```swift
// MARK: - Protocol

protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    var navigationController: UINavigationController { get }
    func start()
}

extension Coordinator {
    func addChild(_ coordinator: Coordinator) {
        childCoordinators.append(coordinator)
    }

    func removeChild(_ coordinator: Coordinator) {
        childCoordinators.removeAll { $0 === coordinator }
    }
}

// MARK: - AppCoordinator

final class AppCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController
    private let diContainer: DIContainer

    init(navigationController: UINavigationController, diContainer: DIContainer) {
        self.navigationController = navigationController
        self.diContainer = diContainer
    }

    func start() {
        if diContainer.authService.isLoggedIn {
            showMain()
        } else {
            showLogin()
        }
    }

    private func showLogin() {
        let coordinator = LoginCoordinator(
            navigationController: navigationController,
            diContainer: diContainer
        )
        coordinator.delegate = self
        addChild(coordinator)
        coordinator.start()
    }

    private func showMain() {
        let coordinator = MainCoordinator(
            navigationController: navigationController,
            diContainer: diContainer
        )
        addChild(coordinator)
        coordinator.start()
    }
}

extension AppCoordinator: LoginCoordinatorDelegate {
    func loginCoordinatorDidFinish(_ coordinator: LoginCoordinator) {
        removeChild(coordinator)
        showMain()
    }
}

// MARK: - LoginCoordinator

protocol LoginCoordinatorDelegate: AnyObject {
    func loginCoordinatorDidFinish(_ coordinator: LoginCoordinator)
}

final class LoginCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController
    weak var delegate: LoginCoordinatorDelegate?
    private let diContainer: DIContainer

    init(navigationController: UINavigationController, diContainer: DIContainer) {
        self.navigationController = navigationController
        self.diContainer = diContainer
    }

    func start() {
        let viewModel = LoginViewModel(loginUseCase: diContainer.loginUseCase)
        let vc = LoginViewController(viewModel: viewModel, coordinator: self)
        navigationController.setViewControllers([vc], animated: false)
    }

    func loginDidSucceed() {
        delegate?.loginCoordinatorDidFinish(self)
    }

    func showForgotPassword() {
        let vc = ForgotPasswordViewController(coordinator: self)
        navigationController.pushViewController(vc, animated: true)
    }

    func showRegister() {
        let coordinator = RegisterCoordinator(
            navigationController: navigationController,
            diContainer: diContainer
        )
        coordinator.delegate = self
        addChild(coordinator)
        coordinator.start()
    }
}
```

## 6.4 Coordinator 生命周期管理

```
AppCoordinator（根，生命周期 = App 生命周期）
    │
    ├── LoginCoordinator（登录流程结束后 removeChild）
    │
    └── MainCoordinator
            │
            ├── DeviceListCoordinator
            │       └── DeviceDetailCoordinator（返回时 removeChild）
            │
            └── ProfileCoordinator
```

**规则**：
- 父 Coordinator 通过 `delegate` 接收子 Coordinator 的完成通知
- 子 Coordinator 完成任务后，父 Coordinator 调用 `removeChild`
- 避免循环引用：delegate 使用 `weak`

## 6.5 ViewController 如何通知 Coordinator

```swift
// ✅ 方式一：直接持有 Coordinator（推荐，简单直接）
final class LoginViewController: UIViewController {
    private let coordinator: LoginCoordinator
    
    @objc func forgotPasswordTapped() {
        coordinator.showForgotPassword()
    }
}

// ✅ 方式二：Delegate 模式（当 VC 不直接依赖具体 Coordinator 时）
protocol LoginViewControllerDelegate: AnyObject {
    func loginViewControllerDidSucceed(_ vc: LoginViewController)
}

final class LoginViewController: UIViewController {
    weak var delegate: LoginViewControllerDelegate?
}
```

### Best Practice

- 每个功能流程对应一个 Coordinator
- Coordinator 持有 `DIContainer`，负责创建所有子页面的 ViewModel 和 ViewController
- 使用 `delegate` 通知父 Coordinator，避免强引用

### Common Mistakes

- Coordinator 中写了业务逻辑（「登录成功后同步设备」应在 UseCase 里）
- 忘记 `removeChild`，导致内存泄漏
- 一个 Coordinator 管理了太多不相关的页面（上帝 Coordinator）

### Checklist

- [ ] Coordinator 是否持有 `childCoordinators` 数组？
- [ ] 子 Coordinator 完成后是否调用了 `removeChild`？
- [ ] Coordinator 中是否有业务逻辑？
- [ ] ViewController 是否通过 Coordinator 或 delegate 发起导航？

---

<a name="chapter-7"></a>
# 第七章：Domain Layer

## 7.1 什么是 Domain

**字面意思**：Domain = 领域。在软件中，「领域」指的是软件要解决的问题所在的现实世界领域。

对于一个 IoT 设备管理 App：
- 领域概念：设备（Device）、用户（User）、分组（Group）、报警（Alert）
- 领域规则：设备离线超过 24 小时触发报警、同一用户最多绑定 50 台设备

**Domain 层的作用**：将这些现实世界的概念和规则，用代码精确表达，与任何技术实现（数据库、API、UI 框架）解耦。

## 7.2 Domain 层包含的内容

```
Domain Layer
├── Entity/          ← 领域模型（业务对象）
│   ├── User.swift
│   ├── Device.swift
│   └── Alert.swift
│
├── UseCase/         ← 业务用例（业务流程）
│   ├── LoginUseCase.swift
│   ├── AddDeviceUseCase.swift
│   └── FetchDevicesUseCase.swift
│
└── Repository/      ← 数据仓库协议（抽象接口）
    ├── AuthRepositoryProtocol.swift
    ├── DeviceRepositoryProtocol.swift
    └── UserRepositoryProtocol.swift
```

## 7.3 为什么 Repository Protocol 在 Domain 层

Repository Protocol 定义了「业务层需要什么数据接口」。这个需求属于 Domain，而不是 Data。

```
Domain 定义：我需要能够获取设备列表
    → DeviceRepositoryProtocol.fetchDevices() -> [Device]

Data 实现：我用 API 来满足这个需求
    → DeviceRepositoryImpl: DeviceRepositoryProtocol
```

如果 Repository Protocol 放在 Data 层，Domain 就会反向依赖 Data，违反依赖方向原则。

## 7.4 为什么不能依赖 UIKit

Domain 层代表纯粹的业务价值，它应该：
- 可以被用于 iOS App
- 可以被用于 macOS App
- 可以被用于命令行工具
- 可以在没有任何 UI 的情况下运行单元测试

如果 Domain 层 `import UIKit`，以上任何一条都将无法实现。

```swift
// ❌ 错误：Domain 中出现 UIKit
import UIKit

struct DeviceEntity {
    let id: String
    let statusColor: UIColor  // ❌ UIKit 类型
}

// ✅ 正确：Domain 只用基础类型或自定义枚举
struct DeviceEntity {
    let id: String
    let status: DeviceStatus  // ✅ 纯 Swift 枚举
}

enum DeviceStatus {
    case online, offline, error
}
```

### Best Practice

- Domain 层零依赖：不依赖任何第三方库，不依赖 UIKit / AppKit
- Entity 使用 struct（值类型），确保数据安全
- Repository Protocol 用 `async throws` 定义接口

### Common Mistakes

- Entity 直接使用 `Codable`（DTO 的职责）
- UseCase 中直接实例化 Repository 的 Impl（应通过 Protocol 注入）
- Domain 层引入 Alamofire、Realm 等库

### Checklist

- [ ] Domain 层是否有 `import UIKit`？
- [ ] Domain 层是否有第三方库依赖？
- [ ] Repository Protocol 是否在 Domain 层定义？
- [ ] Entity 是否只使用基础 Swift 类型？

---

<a name="chapter-8"></a>
# 第八章：Entity

## 8.1 什么是 Entity

**字面意思**：Entity = 实体。在 Clean Architecture 中，Entity 是对现实世界「业务对象」的代码表达。

**与 DTO 的核心区别**：

```
DTO（Data Transfer Object）
    └── 描述「数据如何在网络上传输」（服务器的格式）
    └── 由 API 合同决定，可能随时变化
    └── 可以丑陋（下划线命名、null 字段）

Entity（领域实体）
    └── 描述「业务对象在代码中的形状」（你的语言）
    └── 由业务规则决定，相对稳定
    └── 应该优雅（符合 Swift 命名规范、非空字段）
```

## 8.2 Entity 示例

```swift
// ✅ 正确的 Entity 定义

struct UserEntity {
    let id: String
    let username: String
    let email: String
    let avatarURL: URL?
    let role: UserRole
    let createdAt: Date
}

enum UserRole {
    case admin
    case member
    case guest
}

struct DeviceEntity {
    let id: String
    let name: String
    let serialNumber: String
    let status: DeviceStatus
    let lastSeenAt: Date
    let location: LocationEntity?
}

struct LocationEntity {
    let latitude: Double
    let longitude: Double
    let address: String?
}
```

## 8.3 Entity 是否允许 Codable

**不推荐**，原因：

1. `Codable` 的目的是序列化/反序列化，属于数据传输关注点
2. 为了适配 JSON，Entity 可能需要加 `CodingKeys`，破坏了 Entity 的纯粹性
3. API 字段改变时，会影响到 Entity

```swift
// ❌ 不推荐：Entity 实现 Codable
struct UserEntity: Codable {
    let user_id: String      // 为了匹配 JSON 而用下划线命名
    let user_name: String
}

// ✅ 正确：DTO 实现 Codable，通过 Mapper 转换为 Entity
struct UserDTO: Codable {
    let user_id: String
    let user_name: String
}

struct UserEntity {
    let id: String          // 符合 Swift 命名规范
    let username: String
}
```

**例外情况**：如果项目极其简单，且 API 合同极为稳定，可以合并 DTO 和 Entity，但需要团队明确约定。

## 8.4 Entity 是否允许 UIKit

**绝对不允许**。原因参见第七章第 7.4 节。

### Best Practice

- Entity 使用 `struct`（值语义，天然线程安全）
- 所有字段使用 Swift 命名规范（camelCase）
- 能非空的字段就非空（使用 `let` 而非 `var?`）

### Common Mistakes

- 把 API 返回的 JSON 直接当 Entity 使用
- Entity 中包含 UI 相关逻辑（如 `var displayName: String` 调用格式化逻辑）
- Entity 使用 class（引用语义）导致意外共享状态

### Checklist

- [ ] Entity 是否使用 struct？
- [ ] Entity 是否有 `import UIKit`？
- [ ] Entity 字段是否遵循 Swift 命名规范？
- [ ] Entity 是否混入了 DTO 的字段（下划线命名、optional 滥用）？

---

<a name="chapter-9"></a>
# 第九章：UseCase

## 9.1 什么是 UseCase

**字面意思**：Use Case = 用例。在软件工程中，用例描述「系统为了满足某个用户目标而执行的一系列操作」。

**更直白的理解**：UseCase = 一个完整的业务动作。

| 用户目标 | UseCase |
|---------|---------|
| 用户登录 | `LoginUseCase` |
| 用户添加设备 | `AddDeviceUseCase` |
| 用户发起支付 | `PaymentUseCase` |
| 系统同步数据 | `SyncDataUseCase` |

## 9.2 什么时候需要 UseCase

UseCase 不是必须的，引入 UseCase 的条件是：

1. **多步骤业务流程**：步骤 A → 步骤 B → 步骤 C
2. **多个 Repository 参与**：同时操作用户数据 + 设备数据
3. **有业务规则判断**：满足条件 X 才能执行操作 Y
4. **需要被多个 ViewModel 复用**

```
需要 UseCase 的场景：
    登录：验证格式 → 调用 API → 保存 Token → 同步用户信息
    支付：验证余额 → 创建订单 → 扣款 → 更新库存 → 发送通知
    添加设备：验证序列号 → 调用 API → 刷新本地缓存

不需要 UseCase 的场景：
    获取用户资料（单纯读取，无业务规则）
    获取设备列表（单纯读取，无业务规则）
```

## 9.3 UseCase 标准实现

```swift
// MARK: - Protocol

protocol LoginUseCaseProtocol {
    func execute(credentials: LoginCredentials) async throws -> UserEntity
}

// MARK: - Entity

struct LoginCredentials {
    let username: String
    let password: String
}

// MARK: - Implementation

final class LoginUseCase: LoginUseCaseProtocol {

    private let authRepository: AuthRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let tokenStorage: TokenStorageProtocol

    init(
        authRepository: AuthRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        tokenStorage: TokenStorageProtocol
    ) {
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.tokenStorage = tokenStorage
    }

    func execute(credentials: LoginCredentials) async throws -> UserEntity {
        // Step 1: 调用认证 API
        let authToken = try await authRepository.login(credentials: credentials)

        // Step 2: 保存 Token
        try await tokenStorage.save(token: authToken)

        // Step 3: 获取用户信息
        let user = try await userRepository.fetchCurrentUser()

        // Step 4: 返回用户实体
        return user
    }
}
```

```swift
// MARK: - 复杂业务流程示例：添加设备

final class AddDeviceUseCase: AddDeviceUseCaseProtocol {

    private let deviceRepository: DeviceRepositoryProtocol
    private let licenseRepository: LicenseRepositoryProtocol

    init(
        deviceRepository: DeviceRepositoryProtocol,
        licenseRepository: LicenseRepositoryProtocol
    ) {
        self.deviceRepository = deviceRepository
        self.licenseRepository = licenseRepository
    }

    func execute(serialNumber: String) async throws -> DeviceEntity {
        // Step 1: 验证序列号格式（业务规则）
        guard isValidSerialNumber(serialNumber) else {
            throw AddDeviceError.invalidSerialNumber
        }

        // Step 2: 检查 License 是否还有名额（业务规则）
        let license = try await licenseRepository.fetchCurrentLicense()
        guard license.remainingSlots > 0 else {
            throw AddDeviceError.licenseQuotaExceeded
        }

        // Step 3: 注册设备
        let device = try await deviceRepository.addDevice(serialNumber: serialNumber)

        // Step 4: 更新本地缓存
        try await deviceRepository.refreshLocalCache()

        return device
    }

    private func isValidSerialNumber(_ sn: String) -> Bool {
        // 业务规则：序列号必须是16位字母数字
        let pattern = "^[A-Z0-9]{16}$"
        return sn.range(of: pattern, options: .regularExpression) != nil
    }
}

enum AddDeviceError: LocalizedError {
    case invalidSerialNumber
    case licenseQuotaExceeded

    var errorDescription: String? {
        switch self {
        case .invalidSerialNumber: return "序列号格式不正确"
        case .licenseQuotaExceeded: return "License 已达上限，无法添加更多设备"
        }
    }
}
```

## 9.4 UseCase 设计原则

1. **单一职责**：一个 UseCase 只做一件事
2. **无状态**：UseCase 不保存状态，每次 `execute` 都是独立的
3. **可测试**：所有依赖通过 Protocol 注入，方便 mock

```swift
// ✅ 单一职责
class FetchDevicesUseCase { ... }
class AddDeviceUseCase { ... }
class RemoveDeviceUseCase { ... }

// ❌ 职责混乱
class DeviceUseCase {
    func fetchAll() { ... }
    func add() { ... }
    func remove() { ... }
    func syncWithServer() { ... }
    func sendAlert() { ... }
}
```

### Best Practice

- UseCase 的 `execute` 方法使用 `async throws`
- UseCase 不做 UI 操作，不 import UIKit
- 对外只暴露 Protocol，便于 Mock 测试

### Common Mistakes

- UseCase 泛滥：每个 Repository 方法都套一层 UseCase（简单读取不需要 UseCase）
- UseCase 中直接 `import UIKit` 并操作 UI
- UseCase 保存了业务状态（应该是无状态的）
- UseCase 直接实例化 Repository（应通过 DI 注入）

### Checklist

- [ ] 这个 UseCase 是否真的有业务逻辑，还是只是一个空壳转发？
- [ ] UseCase 是否通过 Protocol 注入所有依赖？
- [ ] UseCase 是否有 `import UIKit`？
- [ ] UseCase 的单元测试是否可以在不启动 App 的情况下运行？

---

<a name="chapter-10"></a>
# 第十章：Repository

## 10.1 什么是 Repository

**字面意思**：Repository = 仓库/存储库。Repository 模式的核心思想是：**为业务层提供一个统一的数据访问接口，屏蔽数据的具体来源（API、数据库、缓存）**。

**类比**：超市货架。你去超市买矿泉水，你不需要知道水是从哪个工厂来的，哪个仓库取出来的，你只需要从货架上取。Repository 就是这个货架。

## 10.2 Repository 的职责

```
Repository 负责
├── 决定数据从哪里取（Remote / Local / Cache）
├── 协调多个 DataSource
├── 管理缓存策略（先读缓存，缓存过期再请求 API）
├── 数据持久化（写入数据库）
└── 数据聚合（合并多个来源的数据）

Repository 不负责
├── 业务规则（那是 UseCase 的事）
├── UI 操作（那是 Presentation 的事）
└── 网络请求的具体实现（那是 DataSource 的事）
```

## 10.3 Repository Protocol（Domain 层）

```swift
// 在 Domain 层定义接口
protocol DeviceRepositoryProtocol {
    func fetchDevices() async throws -> [DeviceEntity]
    func fetchDevice(id: String) async throws -> DeviceEntity
    func addDevice(serialNumber: String) async throws -> DeviceEntity
    func removeDevice(id: String) async throws
    func refreshLocalCache() async throws
}
```

## 10.4 Repository 实现（Data 层）

```swift
// 在 Data 层实现
final class DeviceRepositoryImpl: DeviceRepositoryProtocol {

    private let remoteDataSource: DeviceRemoteDataSourceProtocol
    private let localDataSource: DeviceLocalDataSourceProtocol
    private let mapper: DeviceMapperProtocol

    init(
        remoteDataSource: DeviceRemoteDataSourceProtocol,
        localDataSource: DeviceLocalDataSourceProtocol,
        mapper: DeviceMapperProtocol
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
        self.mapper = mapper
    }

    func fetchDevices() async throws -> [DeviceEntity] {
        // 缓存策略：优先从本地读取，若为空则从远端拉取
        let localDevices = try await localDataSource.fetchDevices()
        if !localDevices.isEmpty {
            return localDevices.map { mapper.toEntity($0) }
        }

        let remoteDevices = try await remoteDataSource.fetchDevices()
        try await localDataSource.saveDevices(remoteDevices)
        return remoteDevices.map { mapper.toEntity($0) }
    }

    func addDevice(serialNumber: String) async throws -> DeviceEntity {
        let dto = try await remoteDataSource.addDevice(serialNumber: serialNumber)
        try await localDataSource.saveDevice(dto)
        return mapper.toEntity(dto)
    }

    func removeDevice(id: String) async throws {
        try await remoteDataSource.removeDevice(id: id)
        try await localDataSource.removeDevice(id: id)
    }

    func fetchDevice(id: String) async throws -> DeviceEntity {
        let dto = try await remoteDataSource.fetchDevice(id: id)
        return mapper.toEntity(dto)
    }

    func refreshLocalCache() async throws {
        let remoteDevices = try await remoteDataSource.fetchDevices()
        try await localDataSource.replaceAll(remoteDevices)
    }
}
```

## 10.5 Repository 是否允许缓存

**允许，且推荐**。Repository 是管理缓存策略的最佳位置：

```swift
// 缓存策略示例
func fetchDevices() async throws -> [DeviceEntity] {
    // 策略1：Cache-First（先读缓存）
    if let cached = cache.get(key: "devices"), !cache.isExpired(key: "devices") {
        return cached
    }

    // 策略2：Network-First（先请求网络）
    let remote = try await remoteDataSource.fetchDevices()
    cache.set(key: "devices", value: remote, ttl: 300)  // 5分钟过期
    return remote.map { mapper.toEntity($0) }
}
```

### Best Practice

- Repository Protocol 在 Domain 层，RepositoryImpl 在 Data 层
- 使用 Protocol 定义接口，方便 Mock 测试
- Repository 管理数据来源决策，UseCase 管理业务规则

### Common Mistakes

- Repository 中写了业务逻辑（如「添加设备前先检查 License」）
- Repository 直接操作 UI（如显示 loading）
- Repository 返回 DTO 而非 Entity（违反了 Domain 层的纯粹性）
- 在 Domain 层的 UseCase 中直接持有 RepositoryImpl（应持有 Protocol）

### Checklist

- [ ] Repository Protocol 是否在 Domain 层？
- [ ] RepositoryImpl 是否只依赖 DataSource（不直接使用 URLSession）？
- [ ] Repository 是否返回 Entity 而非 DTO？
- [ ] 缓存逻辑是否在 Repository 中，而非 UseCase 中？

---

<a name="chapter-11"></a>
# 第十一章：Data Layer

## 11.1 Data 层架构

```
Data Layer
├── DataSource/
│   ├── Remote/
│   │   ├── DeviceRemoteDataSource.swift      ← Protocol
│   │   └── DeviceRemoteDataSourceImpl.swift  ← 实现
│   └── Local/
│       ├── DeviceLocalDataSource.swift       ← Protocol
│       └── DeviceLocalDataSourceImpl.swift   ← 实现（CoreData/Realm）
│
├── Repository/
│   └── DeviceRepositoryImpl.swift
│
├── DTO/
│   ├── DeviceDTO.swift
│   └── UserDTO.swift
│
└── Mapper/
    ├── DeviceMapper.swift
    └── UserMapper.swift
```

## 11.2 RemoteDataSource

**职责**：封装网络请求，将 HTTP 调用转换为 Swift 函数调用。

```swift
protocol DeviceRemoteDataSourceProtocol {
    func fetchDevices() async throws -> [DeviceDTO]
    func addDevice(serialNumber: String) async throws -> DeviceDTO
    func removeDevice(id: String) async throws
}

final class DeviceRemoteDataSourceImpl: DeviceRemoteDataSourceProtocol {

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func fetchDevices() async throws -> [DeviceDTO] {
        try await apiClient.request(DeviceListRequest())
    }

    func addDevice(serialNumber: String) async throws -> DeviceDTO {
        try await apiClient.request(AddDeviceRequest(serialNumber: serialNumber))
    }

    func removeDevice(id: String) async throws {
        try await apiClient.request(RemoveDeviceRequest(id: id))
    }
}
```

## 11.3 LocalDataSource

**职责**：封装本地数据库操作（CoreData / Realm / SQLite）。

```swift
protocol DeviceLocalDataSourceProtocol {
    func fetchDevices() async throws -> [DeviceDTO]
    func saveDevice(_ dto: DeviceDTO) async throws
    func saveDevices(_ dtos: [DeviceDTO]) async throws
    func removeDevice(id: String) async throws
    func replaceAll(_ dtos: [DeviceDTO]) async throws
}

final class DeviceLocalDataSourceImpl: DeviceLocalDataSourceProtocol {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchDevices() async throws -> [DeviceDTO] {
        try await context.perform {
            let request = NSFetchRequest<DeviceMO>(entityName: "Device")
            let managedObjects = try self.context.fetch(request)
            return managedObjects.map { $0.toDTO() }
        }
    }

    func saveDevices(_ dtos: [DeviceDTO]) async throws {
        try await context.perform {
            dtos.forEach { dto in
                let mo = DeviceMO(context: self.context)
                mo.configure(with: dto)
            }
            try self.context.save()
        }
    }

    func replaceAll(_ dtos: [DeviceDTO]) async throws {
        try await context.perform {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Device")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try self.context.execute(deleteRequest)
            dtos.forEach { dto in
                let mo = DeviceMO(context: self.context)
                mo.configure(with: dto)
            }
            try self.context.save()
        }
    }

    func removeDevice(id: String) async throws {
        try await context.perform {
            let request = NSFetchRequest<DeviceMO>(entityName: "Device")
            request.predicate = NSPredicate(format: "id == %@", id)
            if let mo = try self.context.fetch(request).first {
                self.context.delete(mo)
                try self.context.save()
            }
        }
    }

    func saveDevice(_ dto: DeviceDTO) async throws {
        try await saveDevices([dto])
    }
}
```

## 11.4 Mapper

**职责**：将 DTO 转换为 Entity，或反向转换。

```swift
protocol DeviceMapperProtocol {
    func toEntity(_ dto: DeviceDTO) -> DeviceEntity
    func toDTO(_ entity: DeviceEntity) -> DeviceDTO
}

final class DeviceMapper: DeviceMapperProtocol {

    func toEntity(_ dto: DeviceDTO) -> DeviceEntity {
        DeviceEntity(
            id: dto.id,
            name: dto.device_name,
            serialNumber: dto.serial_number,
            status: mapStatus(dto.status),
            lastSeenAt: Date(timeIntervalSince1970: dto.last_seen_timestamp),
            location: dto.location.map { mapLocation($0) }
        )
    }

    func toDTO(_ entity: DeviceEntity) -> DeviceDTO {
        DeviceDTO(
            id: entity.id,
            device_name: entity.name,
            serial_number: entity.serialNumber,
            status: entity.status.rawValue,
            last_seen_timestamp: entity.lastSeenAt.timeIntervalSince1970,
            location: nil
        )
    }

    private func mapStatus(_ raw: String) -> DeviceStatus {
        switch raw {
        case "online":  return .online
        case "offline": return .offline
        default:        return .error
        }
    }

    private func mapLocation(_ dto: LocationDTO) -> LocationEntity {
        LocationEntity(
            latitude: dto.lat,
            longitude: dto.lng,
            address: dto.address
        )
    }
}
```

### Best Practice

- DataSource 只处理单一数据源（Remote 或 Local），不做聚合
- Mapper 是纯函数，无状态，无副作用
- RepositoryImpl 依赖 DataSource 的 Protocol，而不是具体实现

### Common Mistakes

- DataSource 直接返回 Entity（应返回 DTO，由 Repository 通过 Mapper 转换）
- Mapper 中有业务逻辑（Mapper 只做字段映射）
- Repository 直接使用 `URLSession`（应通过 DataSource 封装）

### Checklist

- [ ] RemoteDataSource 是否只负责网络请求，不做缓存？
- [ ] LocalDataSource 是否只负责数据库操作？
- [ ] Mapper 是否只做字段映射，无业务逻辑？
- [ ] DataSource 是否返回 DTO 而非 Entity？

---

<a name="chapter-12"></a>
# 第十二章：DTO 与 Mapper

## 12.1 为什么需要 DTO

**DTO（Data Transfer Object）**：数据传输对象，专门用于与外部系统（API、数据库）交换数据。

**为什么不直接使用 API Model？**

| 问题 | 描述 |
|------|------|
| 命名不一致 | API 用 `user_name`，Swift 应用 `username` |
| 字段可能为 null | API 返回的数据可能有 null，但业务上某字段不应为空 |
| 类型不匹配 | API 返回时间戳（`Int`），业务层需要 `Date` |
| API 变动影响业务 | API 改字段名，不应影响业务代码 |
| 安全性 | 防止把 `password`、`token` 等字段暴露到 UI 层 |

## 12.2 DTO 定义示例

```swift
// DTO：完全匹配 API 返回格式
struct UserDTO: Codable {
    let id: String
    let user_name: String            // 下划线命名（匹配 API）
    let email_address: String
    let avatar_url: String?          // 可为 null
    let created_at: Int              // Unix 时间戳
    let user_role: String            // "admin" / "member"
    let access_token: String?        // 只在登录响应中有
}

// Entity：业务层使用，符合 Swift 规范
struct UserEntity {
    let id: String
    let username: String             // camelCase
    let email: String                // 简洁命名
    let avatarURL: URL?
    let createdAt: Date              // Swift Date 类型
    let role: UserRole               // 强类型枚举
    // 注意：没有 accessToken，Token 单独存储，不在 Entity 中
}
```

## 12.3 Mapper 示例

```swift
final class UserMapper {

    func toEntity(_ dto: UserDTO) -> UserEntity {
        UserEntity(
            id: dto.id,
            username: dto.user_name,
            email: dto.email_address,
            avatarURL: dto.avatar_url.flatMap { URL(string: $0) },
            createdAt: Date(timeIntervalSince1970: TimeInterval(dto.created_at)),
            role: mapRole(dto.user_role)
        )
    }

    private func mapRole(_ raw: String) -> UserRole {
        switch raw {
        case "admin":  return .admin
        case "member": return .member
        default:       return .guest
        }
    }
}
```

## 12.4 什么时候可以不要 Mapper

如果满足以下**所有**条件，可以考虑合并 DTO 和 Entity：

1. API 字段命名完全符合 Swift 规范
2. 所有字段类型直接可用（不需要转换）
3. API 极为稳定，不会变动
4. 项目规模小，团队明确接受这个 trade-off

```swift
// 极简场景：直接使用，无需 Mapper
struct TagEntity: Codable {
    let id: String
    let name: String
    let color: String
}
```

### Best Practice

- DTO 和 Entity 分离，用 Mapper 连接
- Mapper 是无状态的纯函数，可放在 extension 中
- 一个 Mapper 对应一个 Entity 类型

### Common Mistakes

- DTO 直接传到 ViewModel（DTO 泄漏）
- Entity 上加 `Codable` 承担 DTO 的职责
- Mapper 中有网络请求或数据库操作（Mapper 只做转换）

### Checklist

- [ ] Presentation 层是否有任何 DTO 类型的引用？
- [ ] Mapper 是否只做字段映射，没有副作用？
- [ ] DTO 是否只在 Data 层使用？
- [ ] API 字段变化是否只影响 DTO 和 Mapper，不影响 Entity？

---

<a name="chapter-13"></a>
# 第十三章：Dependency Injection

## 13.1 什么是 DI

**Dependency Injection（依赖注入）**：不在类内部自己创建依赖，而是从外部传入。

```swift
// ❌ 没有 DI：内部自己创建依赖（强耦合）
final class LoginViewModel {
    private let useCase = LoginUseCase(
        authRepository: AuthRepositoryImpl(
            remote: AuthRemoteDataSourceImpl(apiClient: APIClient.shared),
            local: AuthLocalDataSourceImpl()
        ),
        tokenStorage: TokenStorageImpl()
    )
}

// ✅ 有 DI：依赖从外部注入（松耦合）
final class LoginViewModel {
    private let useCase: LoginUseCaseProtocol

    init(useCase: LoginUseCaseProtocol) {
        self.useCase = useCase
    }
}
```

## 13.2 Constructor Injection（推荐）

通过构造函数注入，是最推荐的方式：

```swift
final class FetchDevicesUseCase: FetchDevicesUseCaseProtocol {

    private let deviceRepository: DeviceRepositoryProtocol
    private let cacheRepository: CacheRepositoryProtocol

    // 所有依赖在初始化时必须提供
    init(
        deviceRepository: DeviceRepositoryProtocol,
        cacheRepository: CacheRepositoryProtocol
    ) {
        self.deviceRepository = deviceRepository
        self.cacheRepository = cacheRepository
    }
}
```

**优点**：
- 依赖明确（一眼看出这个类需要什么）
- 编译器强制（缺少依赖编译不通过）
- 易于测试（直接传 Mock 对象）

## 13.3 Property Injection（谨慎使用）

```swift
final class AnalyticsManager {
    var logger: LoggerProtocol?  // 可选依赖
}
```

**使用场景**：可选依赖（如 Analytics，不影响核心功能）。不推荐用于核心依赖。

## 13.4 DIContainer

在 App 级别统一创建和管理所有依赖：

```swift
final class DIContainer {

    // MARK: - Core

    lazy var apiClient: APIClientProtocol = {
        APIClient(baseURL: AppConfig.apiBaseURL)
    }()

    lazy var coreDataStack: CoreDataStack = {
        CoreDataStack(modelName: "AppModel")
    }()

    // MARK: - DataSource

    lazy var deviceRemoteDataSource: DeviceRemoteDataSourceProtocol = {
        DeviceRemoteDataSourceImpl(apiClient: apiClient)
    }()

    lazy var deviceLocalDataSource: DeviceLocalDataSourceProtocol = {
        DeviceLocalDataSourceImpl(context: coreDataStack.mainContext)
    }()

    // MARK: - Repository

    lazy var deviceRepository: DeviceRepositoryProtocol = {
        DeviceRepositoryImpl(
            remoteDataSource: deviceRemoteDataSource,
            localDataSource: deviceLocalDataSource,
            mapper: DeviceMapper()
        )
    }()

    lazy var authRepository: AuthRepositoryProtocol = {
        AuthRepositoryImpl(
            remoteDataSource: AuthRemoteDataSourceImpl(apiClient: apiClient),
            tokenStorage: tokenStorage
        )
    }()

    // MARK: - Storage

    lazy var tokenStorage: TokenStorageProtocol = {
        KeychainTokenStorage()
    }()

    // MARK: - UseCase

    var loginUseCase: LoginUseCaseProtocol {
        LoginUseCase(
            authRepository: authRepository,
            userRepository: userRepository,
            tokenStorage: tokenStorage
        )
    }

    var fetchDevicesUseCase: FetchDevicesUseCaseProtocol {
        FetchDevicesUseCase(deviceRepository: deviceRepository)
    }

    // MARK: - ViewModel

    func makeDeviceListViewModel() -> DeviceListViewModel {
        DeviceListViewModel(fetchDevicesUseCase: fetchDevicesUseCase)
    }

    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(loginUseCase: loginUseCase)
    }
}
```

## 13.5 为什么不要 Singleton

```swift
// ❌ Singleton 的问题
class NetworkManager {
    static let shared = NetworkManager()
    // 全局状态，难以测试，难以替换
}

// 某个地方
class LoginViewModel {
    func login() async {
        await NetworkManager.shared.request(...)  // 强耦合
    }
}
```

**Singleton 的问题**：
1. 测试时无法替换（不能注入 Mock）
2. 隐式依赖（看不出这个类依赖了什么）
3. 全局状态导致测试顺序影响结果
4. 多线程竞争问题

**解决方案**：将 Singleton 注册在 `DIContainer` 中，以 Protocol 形式注入：

```swift
// ✅ 正确做法：看起来像 Singleton，但通过 DI 管理
protocol NetworkServiceProtocol { ... }
final class NetworkService: NetworkServiceProtocol { ... }  // 仍然只有一个实例

// DIContainer 中只创建一次（单例行为），但通过注入使用
lazy var networkService: NetworkServiceProtocol = NetworkService()
```

### Best Practice

- 优先使用 Constructor Injection
- 使用 `DIContainer` 在 App 级别组装依赖
- 核心依赖使用 `lazy var`（懒加载），避免启动时间过长
- UseCase 使用 `var`（非 lazy），每次创建新实例（无状态）

### Common Mistakes

- 到处使用 `SomeClass.shared`
- ViewModel 内部直接 `init()` 创建 UseCase
- DIContainer 中的依赖创建顺序错误导致循环引用

### Checklist

- [ ] 是否有 `SomeClass.shared` 被直接调用（非 DIContainer 管理）？
- [ ] ViewModel / UseCase 是否在内部自行创建依赖？
- [ ] 单元测试中是否可以通过注入 Mock 来替换所有依赖？
- [ ] DIContainer 是否集中管理了所有依赖的创建？

---

<a name="chapter-14"></a>
# 第十四章：async/await 与 Combine

## 14.1 2026 年的推荐实践

自 Swift Concurrency 成熟以来，`async/await` 已成为 iOS 开发的主流异步方案。在 2026 年的中大型项目中：

- **async/await**：用于一次性异步操作（网络请求、数据库读写、文件操作）
- **AsyncStream / AsyncThrowingStream**：用于持续的数据流（实时数据、WebSocket、传感器数据）
- **Combine**：仍有价值，但主要用于 UI 绑定场景或遗留代码

## 14.2 为什么推荐 async/await

```swift
// ❌ 回调地狱（Callback Hell）
func login(username: String, password: String) {
    authRepository.login(username: username, password: password) { [weak self] result in
        switch result {
        case .success(let token):
            self?.tokenStorage.save(token: token) { [weak self] in
                self?.userRepository.fetchCurrentUser { [weak self] result in
                    switch result {
                    case .success(let user):
                        DispatchQueue.main.async {
                            self?.state = .loggedIn(user)
                        }
                    case .failure(let error):
                        // 错误处理...
                    }
                }
            }
        case .failure(let error):
            // 错误处理...
        }
    }
}

// ✅ async/await（清晰线性）
func login(username: String, password: String) async throws -> UserEntity {
    let token = try await authRepository.login(username: username, password: password)
    try await tokenStorage.save(token: token)
    return try await userRepository.fetchCurrentUser()
}
```

**async/await 的优势**：
- 代码线性，易读易维护
- 错误处理统一用 `try/catch`
- 配合 `Task`、`async let`、`withTaskGroup` 支持并发
- Swift Concurrency 的 actor 模型解决数据竞争

## 14.3 什么时候使用 AsyncStream

**AsyncStream 适用于持续产生值的数据源**：

```swift
// 场景：MQTT 消息流
final class MQTTClient {
    func messageStream() -> AsyncStream<MQTTMessage> {
        AsyncStream { continuation in
            onMessageReceived = { message in
                continuation.yield(message)
            }
            onDisconnect = {
                continuation.finish()
            }
        }
    }
}

// 场景：蓝牙设备状态更新流
final class BluetoothManager {
    func deviceStatusStream(deviceId: String) -> AsyncStream<DeviceStatus> {
        AsyncStream { continuation in
            // 监听蓝牙状态变化，持续 yield
        }
    }
}

// 场景：ViewModel 状态流（向 ViewController 推送状态）
@MainActor
final class DeviceListViewModel {
    private let stateContinuation: AsyncStream<State>.Continuation
    let stateStream: AsyncStream<State>

    init() {
        var continuation: AsyncStream<State>.Continuation!
        stateStream = AsyncStream { continuation = $0 }
        stateContinuation = continuation
    }
}

// ViewController 消费
func bindViewModel() {
    Task { [weak self] in
        guard let self else { return }
        for await state in viewModel.stateStream {
            await MainActor.run { self.render(state: state) }
        }
    }
}
```

## 14.4 什么时候适合 Combine

Combine 在以下场景仍有价值：

```swift
// 场景1：UIControl 事件绑定（UIKit 原生不支持 async/await）
loginButton.publisher(for: .touchUpInside)
    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
    .sink { [weak self] _ in
        Task { await self?.viewModel.login() }
    }
    .store(in: &cancellables)

// 场景2：文本输入实时搜索
searchTextField.textPublisher
    .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
    .removeDuplicates()
    .sink { [weak self] query in
        Task { await self?.viewModel.search(query: query) }
    }
    .store(in: &cancellables)

// 场景3：多个信号合并
Publishers.CombineLatest(
    viewModel.$isUsernameValid,
    viewModel.$isPasswordValid
)
.map { $0 && $1 }
.assign(to: \.isEnabled, on: loginButton)
.store(in: &cancellables)
```

## 14.5 什么时候不要引入 Combine

```swift
// ❌ 为了 MVVM 而强行用 Combine（AsyncStream 更简洁）
@Published var state: State = .idle
// ViewController 需要 import Combine，使用 sink，管理 cancellables

// ✅ 用 AsyncStream 替代
let stateStream: AsyncStream<State>
// ViewController 用 for await 消费，更简洁

// ❌ 把简单的 async/await 操作强行包成 Publisher
func fetchData() -> AnyPublisher<[Item], Error> {
    Future { promise in
        Task {
            do {
                let items = try await self.repository.fetchItems()
                promise(.success(items))
            } catch {
                promise(.failure(error))
            }
        }
    }.eraseToAnyPublisher()
}

// ✅ 直接用 async throws
func fetchData() async throws -> [Item] {
    try await repository.fetchItems()
}
```

**判断原则**：
- 一次性操作 → `async/await`
- 持续数据流 → `AsyncStream`
- UIControl 事件 + 操作符（debounce, merge, combineLatest）→ Combine

### Best Practice

- 新代码优先使用 `async/await`
- ViewModel → ViewController 的状态推送使用 `AsyncStream`
- 使用 `withTaskCancellationHandler` 在 Task 取消时释放资源
- 使用 `async let` 并行执行独立的异步任务

### Common Mistakes

- 在 `async` 函数中仍然使用 `DispatchQueue.main.async`（应用 `@MainActor`）
- Task 没有在 deinit 中取消
- 混合使用 completion handler 和 async/await（应统一）

### Checklist

- [ ] 是否有 `DispatchQueue.main.async` 嵌套在 async 函数中？
- [ ] 所有 `Task` 是否被正确取消？
- [ ] 是否引入了不必要的 Combine，应该用 AsyncStream 替代？
- [ ] Repository 和 DataSource 接口是否都是 `async throws`？

---

<a name="chapter-15"></a>
# 第十五章：错误处理

## 15.1 错误处理的分层原则

```
API Error (HTTP 4xx/5xx)
    │
    ▼
RemoteDataSource.mapNetworkError()  ← 转换为 DataError
    │
    ▼
RepositoryImpl                      ← 可选：进一步转换或直接传递
    │
    ▼
UseCase                             ← 可选：包装为业务错误
    │
    ▼
ViewModel.handleError()             ← 将错误转换为 UI 状态
    │
    ▼
ViewController.render(error:)       ← 展示给用户
```

## 15.2 分层错误类型设计

```swift
// MARK: - Data Layer 错误

enum NetworkError: Error {
    case noInternet
    case timeout
    case serverError(statusCode: Int, message: String?)
    case decodingFailed(underlying: Error)
    case unauthorized
}

// MARK: - Domain Layer 错误（业务错误）

enum AddDeviceError: LocalizedError {
    case invalidSerialNumber
    case deviceAlreadyRegistered
    case licenseQuotaExceeded
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidSerialNumber:     return "序列号格式不正确，请检查后重试"
        case .deviceAlreadyRegistered: return "该设备已被注册"
        case .licenseQuotaExceeded:    return "已达到设备上限，请升级您的套餐"
        case .networkUnavailable:      return "网络不可用，请检查网络连接"
        }
    }
}
```

## 15.3 Repository 是否转换 Error

**Repository 应转换 Network 错误为业务无关的 Repository 错误**：

```swift
final class DeviceRepositoryImpl: DeviceRepositoryProtocol {

    func fetchDevices() async throws -> [DeviceEntity] {
        do {
            let dtos = try await remoteDataSource.fetchDevices()
            return dtos.map { mapper.toEntity($0) }
        } catch let networkError as NetworkError {
            // 将网络错误转换为 Repository 错误
            switch networkError {
            case .unauthorized:
                throw RepositoryError.unauthorized
            case .noInternet:
                // 降级到本地缓存
                let localDtos = try await localDataSource.fetchDevices()
                return localDtos.map { mapper.toEntity($0) }
            default:
                throw RepositoryError.fetchFailed(underlying: networkError)
            }
        }
    }
}
```

## 15.4 ViewModel 如何处理 Error

```swift
@MainActor
final class AddDeviceViewModel {

    enum State {
        case idle
        case loading
        case success(DeviceEntity)
        case error(ErrorState)
    }

    struct ErrorState {
        let title: String
        let message: String
        let action: ErrorAction?
    }

    enum ErrorAction {
        case retry
        case upgradePlan
        case contactSupport
    }

    func addDevice(serialNumber: String) async {
        stateContinuation.yield(.loading)
        do {
            let device = try await addDeviceUseCase.execute(serialNumber: serialNumber)
            stateContinuation.yield(.success(device))
        } catch let error as AddDeviceError {
            stateContinuation.yield(.error(mapToErrorState(error)))
        } catch {
            stateContinuation.yield(.error(ErrorState(
                title: "操作失败",
                message: error.localizedDescription,
                action: .retry
            )))
        }
    }

    private func mapToErrorState(_ error: AddDeviceError) -> ErrorState {
        switch error {
        case .licenseQuotaExceeded:
            return ErrorState(title: "设备已满", message: error.errorDescription ?? "", action: .upgradePlan)
        case .invalidSerialNumber:
            return ErrorState(title: "序列号错误", message: error.errorDescription ?? "", action: nil)
        default:
            return ErrorState(title: "添加失败", message: error.errorDescription ?? "", action: .retry)
        }
    }
}
```

## 15.5 UI 如何展示 Error

```swift
// ViewController 渲染错误
private func render(state: AddDeviceViewModel.State) {
    switch state {
    case .error(let errorState):
        showErrorView(errorState)
    // ...其他状态
    }
}

private func showErrorView(_ errorState: AddDeviceViewModel.ErrorState) {
    let alert = UIAlertController(
        title: errorState.title,
        message: errorState.message,
        preferredStyle: .alert
    )

    if let action = errorState.action {
        switch action {
        case .retry:
            alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
                Task { await self?.viewModel.retry() }
            })
        case .upgradePlan:
            alert.addAction(UIAlertAction(title: "升级套餐", style: .default) { [weak self] _ in
                self?.coordinator.showUpgradePlan()
            })
        case .contactSupport:
            alert.addAction(UIAlertAction(title: "联系客服", style: .default) { [weak self] _ in
                self?.coordinator.showSupport()
            })
        }
    }

    alert.addAction(UIAlertAction(title: "关闭", style: .cancel))
    present(alert, animated: true)
}
```

### Best Practice

- 使用 `LocalizedError` 提供用户友好的错误信息
- ViewModel 将技术错误转换为 UI 可展示的 `ErrorState`
- Repository 在合适的地方做错误降级（如网络不可用时用缓存）

### Common Mistakes

- 将底层技术错误（`URLError.timedOut`）直接展示给用户
- 在 ViewController 中写 `try/catch` 处理业务错误
- 忽略错误，只打印 `print(error)` 而不更新 UI 状态

### Checklist

- [ ] 用户看到的所有错误信息是否人类可读？
- [ ] 技术错误（URLError、CoreData Error）是否在适当层级被转换？
- [ ] ViewModel 中的错误处理是否更新了 UI 状态？
- [ ] 是否所有 `async throws` 调用都有对应的错误处理？

---

<a name="chapter-16"></a>
# 第十六章：项目目录规范

## 16.1 推荐目录结构

```
MyApp/
├── Application/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   └── AppCoordinator.swift
│
├── DI/
│   └── DIContainer.swift
│
├── Presentation/
│   ├── Login/
│   │   ├── LoginViewController.swift
│   │   ├── LoginViewModel.swift
│   │   ├── LoginCoordinator.swift
│   │   └── Views/
│   │       └── LoginFormView.swift
│   │
│   ├── DeviceList/
│   │   ├── DeviceListViewController.swift
│   │   ├── DeviceListViewModel.swift
│   │   ├── DeviceListCoordinator.swift
│   │   └── Views/
│   │       └── DeviceCell.swift
│   │
│   └── DeviceDetail/
│       ├── DeviceDetailViewController.swift
│       ├── DeviceDetailViewModel.swift
│       └── DeviceDetailCoordinator.swift
│
├── Domain/
│   ├── Entity/
│   │   ├── UserEntity.swift
│   │   ├── DeviceEntity.swift
│   │   └── AlertEntity.swift
│   │
│   ├── UseCase/
│   │   ├── LoginUseCase.swift
│   │   ├── FetchDevicesUseCase.swift
│   │   └── AddDeviceUseCase.swift
│   │
│   └── Repository/
│       ├── AuthRepositoryProtocol.swift
│       ├── DeviceRepositoryProtocol.swift
│       └── UserRepositoryProtocol.swift
│
├── Data/
│   ├── Repository/
│   │   ├── AuthRepositoryImpl.swift
│   │   └── DeviceRepositoryImpl.swift
│   │
│   ├── DataSource/
│   │   ├── Remote/
│   │   │   ├── DeviceRemoteDataSource.swift
│   │   │   └── DeviceRemoteDataSourceImpl.swift
│   │   └── Local/
│   │       ├── DeviceLocalDataSource.swift
│   │       └── DeviceLocalDataSourceImpl.swift
│   │
│   ├── DTO/
│   │   ├── UserDTO.swift
│   │   └── DeviceDTO.swift
│   │
│   └── Mapper/
│       ├── UserMapper.swift
│       └── DeviceMapper.swift
│
├── Network/
│   ├── APIClient.swift
│   ├── APIClientProtocol.swift
│   ├── Request/
│   │   ├── APIRequest.swift
│   │   └── Requests/
│   │       ├── LoginRequest.swift
│   │       └── FetchDevicesRequest.swift
│   └── Interceptor/
│       ├── AuthInterceptor.swift
│       └── LoggingInterceptor.swift
│
├── Storage/
│   ├── CoreData/
│   │   ├── CoreDataStack.swift
│   │   └── ManagedObjects/
│   │       └── DeviceMO.swift
│   ├── Keychain/
│   │   └── KeychainTokenStorage.swift
│   └── UserDefaults/
│       └── AppPreferences.swift
│
├── Core/
│   ├── Extensions/
│   │   ├── Date+Extensions.swift
│   │   ├── String+Extensions.swift
│   │   └── UIView+Extensions.swift
│   ├── Utilities/
│   │   ├── DateFormatterUtil.swift
│   │   └── ImageLoader.swift
│   └── Constants/
│       └── AppConstants.swift
│
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.strings
    └── Info.plist
```

## 16.2 目录设计原则

| 目录 | 说明 |
|------|------|
| `Application/` | App 入口，AppDelegate/SceneDelegate，根 Coordinator |
| `DI/` | DIContainer，全局依赖组装 |
| `Presentation/` | 按功能模块组织，每个模块一个文件夹 |
| `Domain/` | 纯业务代码，无任何外部依赖 |
| `Data/` | 数据层实现，对应 Domain 的每个 Repository Protocol |
| `Network/` | 网络层封装，独立于业务逻辑 |
| `Storage/` | 本地存储（CoreData、Keychain、UserDefaults） |
| `Core/` | 基础设施：Extension、工具类、常量 |
| `Resources/` | 资源文件 |

**为什么按功能模块组织 Presentation，而不按类型？**

```
❌ 按类型组织（VC 多时难以找到对应文件）
ViewControllers/
    LoginViewController.swift
    DeviceListViewController.swift
ViewModels/
    LoginViewModel.swift
    DeviceListViewModel.swift

✅ 按功能模块组织（相关文件在一起，便于维护）
Login/
    LoginViewController.swift
    LoginViewModel.swift
    LoginCoordinator.swift
DeviceList/
    DeviceListViewController.swift
    DeviceListViewModel.swift
    DeviceListCoordinator.swift
```

### Checklist

- [ ] `Domain/` 是否零依赖（无 `import UIKit`，无第三方库）？
- [ ] 每个功能模块的 ViewController、ViewModel、Coordinator 是否在同一目录？
- [ ] `DI/` 目录是否集中了所有依赖的创建？

---

<a name="chapter-17"></a>
# 第十七章：命名规范

## 17.1 各类型命名规则

| 类型 | 后缀规则 | 示例 |
|------|---------|------|
| ViewController | `ViewController` | `LoginViewController` |
| UIView 子类 | `View` | `LoginFormView`, `DeviceStatusView` |
| UITableViewCell | `Cell` | `DeviceCell`, `AlertCell` |
| UICollectionViewCell | `Cell` | `PhotoCell` |
| ViewModel | `ViewModel` | `LoginViewModel` |
| UseCase（Protocol） | `UseCaseProtocol` | `LoginUseCaseProtocol` |
| UseCase（实现） | `UseCase` | `LoginUseCase` |
| Repository（Protocol） | `RepositoryProtocol` | `DeviceRepositoryProtocol` |
| Repository（实现） | `RepositoryImpl` | `DeviceRepositoryImpl` |
| DataSource（Protocol） | `DataSourceProtocol` | `DeviceRemoteDataSourceProtocol` |
| DataSource（实现） | `DataSourceImpl` | `DeviceRemoteDataSourceImpl` |
| DTO | `DTO` | `UserDTO`, `DeviceDTO` |
| Entity | `Entity` | `UserEntity`, `DeviceEntity` |
| Mapper | `Mapper` | `UserMapper`, `DeviceMapper` |
| Coordinator | `Coordinator` | `LoginCoordinator` |
| Error 枚举 | `Error` | `LoginError`, `AddDeviceError` |

## 17.2 方法命名规范

```swift
// UseCase 统一使用 execute
protocol LoginUseCaseProtocol {
    func execute(credentials: LoginCredentials) async throws -> UserEntity
}

// Repository 使用 fetch/save/remove/update
protocol DeviceRepositoryProtocol {
    func fetchDevices() async throws -> [DeviceEntity]
    func fetchDevice(id: String) async throws -> DeviceEntity
    func saveDevice(_ entity: DeviceEntity) async throws
    func removeDevice(id: String) async throws
    func updateDevice(_ entity: DeviceEntity) async throws
}

// DataSource 使用与 Repository 类似，但返回 DTO
protocol DeviceRemoteDataSourceProtocol {
    func fetchDevices() async throws -> [DeviceDTO]
    func fetchDevice(id: String) async throws -> DeviceDTO
    func addDevice(serialNumber: String) async throws -> DeviceDTO
    func deleteDevice(id: String) async throws
}

// ViewModel 方法使用动词，描述用户行为或数据操作
class DeviceListViewModel {
    func loadDevices() async { }
    func refreshDevices() async { }
    func deleteDevice(id: String) async { }
    func searchDevices(query: String) async { }
}

// Coordinator 方法使用 show/present/dismiss
class DeviceListCoordinator {
    func showDeviceDetail(deviceId: String) { }
    func showAddDevice() { }
    func dismissAddDevice() { }
}
```

## 17.3 属性命名规范

```swift
// State 枚举统一用 State
enum State {
    case idle
    case loading
    case loaded
    case error(String)
}

// ViewState（传给 Cell 的数据）统一用类型名+ViewState 或在 ViewModel 内嵌
struct DeviceViewState {
    let id: String
    let name: String
    let statusText: String
}

// 内嵌在 ViewModel 中（推荐）
extension DeviceListViewModel {
    struct DeviceItem {
        let id: String
        let name: String
        let statusText: String
    }
}
```

### Checklist

- [ ] 所有 Protocol 是否有对应的 `Protocol` 后缀？
- [ ] Repository 实现是否使用 `Impl` 后缀？
- [ ] UseCase 执行方法是否统一为 `execute`？
- [ ] DTO/Entity/Mapper 命名是否清晰区分？

---

<a name="chapter-18"></a>
# 第十八章：完整页面示例

以「设备列表页面」为例，展示完整的从 API 到 UI 的代码链路。

## 18.1 Domain Layer

```swift
// MARK: - Entity

struct DeviceEntity {
    let id: String
    let name: String
    let serialNumber: String
    let status: DeviceStatus
    let lastSeenAt: Date
}

enum DeviceStatus {
    case online, offline, error
}

// MARK: - Repository Protocol

protocol DeviceRepositoryProtocol {
    func fetchDevices() async throws -> [DeviceEntity]
}

// MARK: - UseCase Protocol

protocol FetchDevicesUseCaseProtocol {
    func execute() async throws -> [DeviceEntity]
}

// MARK: - UseCase Implementation

final class FetchDevicesUseCase: FetchDevicesUseCaseProtocol {

    private let deviceRepository: DeviceRepositoryProtocol

    init(deviceRepository: DeviceRepositoryProtocol) {
        self.deviceRepository = deviceRepository
    }

    func execute() async throws -> [DeviceEntity] {
        try await deviceRepository.fetchDevices()
    }
}
```

## 18.2 Data Layer

```swift
// MARK: - DTO

struct DeviceDTO: Codable {
    let id: String
    let device_name: String
    let serial_number: String
    let status: String
    let last_seen_at: TimeInterval
}

// MARK: - Mapper

final class DeviceMapper {

    func toEntity(_ dto: DeviceDTO) -> DeviceEntity {
        DeviceEntity(
            id: dto.id,
            name: dto.device_name,
            serialNumber: dto.serial_number,
            status: mapStatus(dto.status),
            lastSeenAt: Date(timeIntervalSince1970: dto.last_seen_at)
        )
    }

    private func mapStatus(_ raw: String) -> DeviceStatus {
        switch raw {
        case "online":  return .online
        case "offline": return .offline
        default:        return .error
        }
    }
}

// MARK: - Remote DataSource

protocol DeviceRemoteDataSourceProtocol {
    func fetchDevices() async throws -> [DeviceDTO]
}

final class DeviceRemoteDataSourceImpl: DeviceRemoteDataSourceProtocol {

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func fetchDevices() async throws -> [DeviceDTO] {
        try await apiClient.request(FetchDevicesRequest())
    }
}

// MARK: - Repository Implementation

final class DeviceRepositoryImpl: DeviceRepositoryProtocol {

    private let remoteDataSource: DeviceRemoteDataSourceProtocol
    private let mapper: DeviceMapper

    init(
        remoteDataSource: DeviceRemoteDataSourceProtocol,
        mapper: DeviceMapper = DeviceMapper()
    ) {
        self.remoteDataSource = remoteDataSource
        self.mapper = mapper
    }

    func fetchDevices() async throws -> [DeviceEntity] {
        let dtos = try await remoteDataSource.fetchDevices()
        return dtos.map { mapper.toEntity($0) }
    }
}
```

## 18.3 Presentation Layer - ViewModel

```swift
@MainActor
final class DeviceListViewModel {

    // MARK: - State

    enum State {
        case idle
        case loading
        case loaded
        case error(String)
    }

    struct DeviceItem {
        let id: String
        let name: String
        let statusText: String
        let statusColorName: String
        let lastSeenText: String
    }

    // MARK: - Output

    private(set) var deviceItems: [DeviceItem] = []
    private let stateContinuation: AsyncStream<State>.Continuation
    let stateStream: AsyncStream<State>

    // MARK: - Dependencies

    private let fetchDevicesUseCase: FetchDevicesUseCaseProtocol

    // MARK: - Init

    init(fetchDevicesUseCase: FetchDevicesUseCaseProtocol) {
        self.fetchDevicesUseCase = fetchDevicesUseCase

        var continuation: AsyncStream<State>.Continuation!
        stateStream = AsyncStream { continuation = $0 }
        stateContinuation = continuation
    }

    // MARK: - Input

    func loadDevices() async {
        stateContinuation.yield(.loading)
        do {
            let entities = try await fetchDevicesUseCase.execute()
            deviceItems = entities.map { mapToItem($0) }
            stateContinuation.yield(.loaded)
        } catch {
            stateContinuation.yield(.error(error.localizedDescription))
        }
    }

    func refreshDevices() async {
        await loadDevices()
    }
}

// MARK: - Mapping

private extension DeviceListViewModel {

    func mapToItem(_ entity: DeviceEntity) -> DeviceItem {
        DeviceItem(
            id: entity.id,
            name: entity.name,
            statusText: statusText(for: entity.status),
            statusColorName: statusColorName(for: entity.status),
            lastSeenText: relativeTimeString(from: entity.lastSeenAt)
        )
    }

    func statusText(for status: DeviceStatus) -> String {
        switch status {
        case .online:  return "在线"
        case .offline: return "离线"
        case .error:   return "故障"
        }
    }

    func statusColorName(for status: DeviceStatus) -> String {
        switch status {
        case .online:  return "systemGreen"
        case .offline: return "systemGray"
        case .error:   return "systemRed"
        }
    }

    func relativeTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
```

## 18.4 Presentation Layer - ViewController

```swift
final class DeviceListViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: DeviceListViewModel
    private let coordinator: DeviceListCoordinator
    private var tasks: [Task<Void, Never>] = []

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(DeviceCell.self, forCellReuseIdentifier: DeviceCell.reuseIdentifier)
        tv.delegate = self
        tv.dataSource = self
        tv.refreshControl = refreshControl
        return tv
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        return rc
    }()

    private lazy var loadingView: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .large)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.hidesWhenStopped = true
        return v
    }()

    // MARK: - Init

    init(viewModel: DeviceListViewModel, coordinator: DeviceListCoordinator) {
        self.viewModel = viewModel
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        Task { await viewModel.loadDevices() }
    }

    deinit {
        tasks.forEach { $0.cancel() }
    }
}

// MARK: - Setup

private extension DeviceListViewController {

    func setupUI() {
        title = "我的设备"
        view.backgroundColor = .systemBackground
        view.addSubview(tableView)
        view.addSubview(loadingView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

// MARK: - Binding

private extension DeviceListViewController {

    func bindViewModel() {
        let task = Task { [weak self] in
            guard let self else { return }
            for await state in viewModel.stateStream {
                await MainActor.run { self.render(state: state) }
            }
        }
        tasks.append(task)
    }

    func render(state: DeviceListViewModel.State) {
        switch state {
        case .idle:
            break
        case .loading:
            loadingView.startAnimating()
        case .loaded:
            loadingView.stopAnimating()
            refreshControl.endRefreshing()
            tableView.reloadData()
        case .error(let message):
            loadingView.stopAnimating()
            refreshControl.endRefreshing()
            showErrorAlert(message: message)
        }
    }
}

// MARK: - Actions

private extension DeviceListViewController {

    @objc func handleRefresh() {
        Task { await viewModel.refreshDevices() }
    }
}

// MARK: - UITableViewDataSource

extension DeviceListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.deviceItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: DeviceCell.reuseIdentifier,
            for: indexPath
        ) as? DeviceCell else { return UITableViewCell() }
        cell.configure(with: viewModel.deviceItems[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension DeviceListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = viewModel.deviceItems[indexPath.row]
        coordinator.showDeviceDetail(deviceId: item.id)
    }
}

// MARK: - Alert

private extension DeviceListViewController {

    func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "加载失败", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
            Task { await self?.viewModel.loadDevices() }
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
}
```

## 18.5 Presentation Layer - Cell

```swift
final class DeviceCell: UITableViewCell {

    static let reuseIdentifier = "DeviceCell"

    // MARK: - UI

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let lastSeenLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Configure

    func configure(with item: DeviceListViewModel.DeviceItem) {
        nameLabel.text = item.name
        statusLabel.text = item.statusText
        statusLabel.textColor = UIColor(named: item.statusColorName) ?? .label
        lastSeenLabel.text = item.lastSeenText
    }
}

// MARK: - Setup

private extension DeviceCell {

    func setupUI() {
        let stack = UIStackView(arrangedSubviews: [nameLabel, statusLabel, lastSeenLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
}
```

## 18.6 Coordinator

```swift
final class DeviceListCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController
    private let diContainer: DIContainer

    init(navigationController: UINavigationController, diContainer: DIContainer) {
        self.navigationController = navigationController
        self.diContainer = diContainer
    }

    func start() {
        let viewModel = diContainer.makeDeviceListViewModel()
        let vc = DeviceListViewController(viewModel: viewModel, coordinator: self)
        navigationController.pushViewController(vc, animated: true)
    }

    func showDeviceDetail(deviceId: String) {
        let coordinator = DeviceDetailCoordinator(
            navigationController: navigationController,
            deviceId: deviceId,
            diContainer: diContainer
        )
        coordinator.delegate = self
        addChild(coordinator)
        coordinator.start()
    }
}

extension DeviceListCoordinator: DeviceDetailCoordinatorDelegate {
    func deviceDetailCoordinatorDidFinish(_ coordinator: DeviceDetailCoordinator) {
        removeChild(coordinator)
    }
}
```

---

<a name="chapter-19"></a>
# 第十九章：Code Review Checklist

## 19.1 Architecture（架构）

- [ ] ViewController 是否超过 400 行？
- [ ] ViewController 中是否有业务逻辑（if/else 的业务判断）？
- [ ] ViewController 是否直接调用网络 / 数据库 / 蓝牙 / MQTT？
- [ ] ViewController 是否直接持有 Repository 或 UseCase 的 Impl？
- [ ] ViewModel 是否有 `import UIKit`？
- [ ] ViewModel 是否返回 `UIColor`、`UIFont`、`UIImage` 等 UIKit 类型？
- [ ] ViewModel 是否直接持有 ViewController 的引用？
- [ ] ViewModel 是否直接调用 URLSession 或第三方网络库？
- [ ] Domain 层（Entity、UseCase、Repository Protocol）是否有任何框架依赖？
- [ ] Domain 层是否有 `import UIKit`、`import CoreData` 等？

## 19.2 UseCase（用例）

- [ ] 是否真的需要这个 UseCase（是否只是一个空壳转发）？
- [ ] UseCase 是否只有一个职责？
- [ ] UseCase 是否通过 Protocol 注入所有依赖？
- [ ] UseCase 是否有业务逻辑，还是纯粹的数据操作（纯数据操作可以直接调用 Repository）？
- [ ] UseCase 是否保存了状态（UseCase 应该是无状态的）？

## 19.3 Repository（数据仓库）

- [ ] Repository Protocol 是否在 Domain 层？
- [ ] RepositoryImpl 是否在 Data 层？
- [ ] Repository 是否返回 Entity 而非 DTO？
- [ ] Repository 中是否有业务逻辑（应该在 UseCase 中）？
- [ ] Repository 是否直接使用 URLSession（应通过 DataSource 封装）？

## 19.4 DTO 与 Mapper（数据传输）

- [ ] DTO 是否泄漏到 Domain 或 Presentation 层？
- [ ] ViewModel 或 ViewController 中是否出现了 DTO 类型？
- [ ] Mapper 中是否有业务逻辑（Mapper 只做字段映射）？
- [ ] Entity 是否实现了 Codable（应该由 DTO 实现）？
- [ ] API 字段变化是否只需修改 DTO 和 Mapper，不影响 Entity？

## 19.5 Dependency Injection（依赖注入）

- [ ] 是否有 `SomeClass.shared` 被直接使用（非 DIContainer 管理）？
- [ ] ViewModel 是否在内部自行 `init()` 创建 UseCase 或 Repository？
- [ ] 是否可以在单元测试中通过注入 Mock 替换所有依赖？
- [ ] DIContainer 是否集中管理了所有对象的创建？
- [ ] 是否使用了 Singleton 替代 DI（`static let shared`）？

## 19.6 Coordinator（导航）

- [ ] 是否所有 `push`/`present` 都通过 Coordinator 发起？
- [ ] ViewController 是否直接创建了另一个 ViewController 的实例？
- [ ] 子 Coordinator 完成后是否调用了 `removeChild`？
- [ ] Coordinator 中是否有业务逻辑？
- [ ] Coordinator 的 delegate 是否使用了 `weak` 修饰？

## 19.7 async/await（异步）

- [ ] 是否在 `async` 函数中混用了 `DispatchQueue` 切换线程？
- [ ] 所有创建的 `Task` 是否在 `deinit` 中被取消？
- [ ] 是否有数据竞争（多个 Task 同时修改同一属性而没有 actor 保护）？
- [ ] `@MainActor` 是否正确标注在 ViewModel 上？
- [ ] 是否有 `async` 函数没有对应的 `try/catch` 错误处理？

## 19.8 Error Handling（错误处理）

- [ ] 是否有 `try!`（强制解包 throws）？
- [ ] 是否有错误被 `_` 忽略（`let _ = try? ...`）而没有任何处理？
- [ ] 技术错误（URLError、CoreData Error）是否被转换为用户可读信息？
- [ ] ViewModel 错误处理是否更新了 UI 状态？
- [ ] 错误类型是否实现了 `LocalizedError` 提供用户友好信息？

## 19.9 Code Quality（代码质量）

- [ ] 是否有重复代码（DRY 原则）？
- [ ] 函数是否超过 30 行（需要考虑是否拆分）？
- [ ] 是否有 Magic Number / Magic String（应定义为常量）？
- [ ] 是否有强制解包 `!`（除非 100% 确定不会 nil）？
- [ ] 是否有 `guard let self = self else { return }` 的正确使用（防止循环引用）？

## 19.10 Memory Management（内存管理）

- [ ] 闭包中是否正确使用了 `[weak self]` 或 `[unowned self]`？
- [ ] Delegate 是否使用了 `weak` 修饰？
- [ ] ViewModel 和 Coordinator 之间是否存在循环引用？
- [ ] `NotificationCenter.removeObserver` 是否被正确调用？
- [ ] Task 是否在 `deinit` 中被取消？

## 19.11 Testing（测试）

- [ ] ViewModel 是否有对应的单元测试？
- [ ] UseCase 是否有对应的单元测试？
- [ ] 是否可以在不启动 App 的情况下运行 Domain 层的所有测试？
- [ ] Mock 对象是否实现了对应的 Protocol？
- [ ] 测试是否覆盖了错误场景（网络失败、数据为空等）？

---

<a name="chapter-20"></a>
# 第二十章：常见反模式（Anti-Patterns）

## 20.1 Fat ViewController（胖控制器）

**症状**：ViewController 超过 800 行，包含网络请求、业务逻辑、格式化代码。

```swift
// ❌ 典型胖 VC
class OrderListViewController: UIViewController {
    func viewDidLoad() {
        super.viewDidLoad()
        URLSession.shared.dataTask(with: orderURL) { [weak self] data, _, error in
            guard let data = data else { return }
            let orders = try? JSONDecoder().decode([Order].self, from: data)
            let filteredOrders = orders?.filter { $0.status == "active" }
            let sortedOrders = filteredOrders?.sorted { $0.createdAt > $1.createdAt }
            let formattedOrders = sortedOrders?.map { order in
                "订单 #\(order.id) - ¥\(String(format: "%.2f", order.amount))"
            }
            DispatchQueue.main.async {
                self?.orderItems = formattedOrders ?? []
                self?.tableView.reloadData()
            }
        }.resume()
    }
}
```

**正确做法**：网络请求 → RemoteDataSource，解析 → DTO + Mapper，过滤排序 → ViewModel 或 UseCase，格式化 → ViewModel。

---

## 20.2 Fat ViewModel（胖 ViewModel）

**症状**：ViewModel 包含了所有逻辑：网络、缓存、业务、格式化，UseCase 形同虚设。

```swift
// ❌ 胖 ViewModel
class OrderViewModel {
    func placeOrder(items: [CartItem]) async {
        // 验证购物车
        guard !items.isEmpty else { return }
        guard items.allSatisfy({ $0.quantity > 0 }) else { return }
        
        // 计算总价（业务逻辑）
        let total = items.reduce(0) { $0 + $1.price * Decimal($1.quantity) }
        guard total > 0 else { return }
        
        // 检查库存（业务逻辑）
        for item in items {
            let stock = try? await inventoryRepository.checkStock(productId: item.id)
            guard let stock, stock >= item.quantity else { return }
        }
        
        // 扣款（业务逻辑）
        try? await paymentRepository.charge(amount: total)
        
        // 创建订单
        try? await orderRepository.create(items: items)
        
        // 发通知（业务逻辑）
        notificationService.send(OrderPlacedNotification(total: total))
    }
}
```

**正确做法**：将 `placeOrder` 的所有步骤提取到 `PlaceOrderUseCase`，ViewModel 只负责调用 UseCase 并处理返回结果。

---

## 20.3 God Repository（上帝仓库）

**症状**：单个 Repository 处理多种不相关的数据，变成了「数据上帝」。

```swift
// ❌ God Repository
protocol AppRepositoryProtocol {
    func fetchUser() async throws -> UserEntity
    func fetchDevices() async throws -> [DeviceEntity]
    func fetchOrders() async throws -> [OrderEntity]
    func fetchPaymentMethods() async throws -> [PaymentMethod]
    func sendMessage(content: String) async throws
    func uploadImage(data: Data) async throws -> URL
}
```

**正确做法**：按领域拆分 Repository：`UserRepository`、`DeviceRepository`、`OrderRepository`、`PaymentRepository`、`MessageRepository`、`StorageRepository`。

---

## 20.4 UseCase 泛滥

**症状**：每个 Repository 方法都套一层 UseCase，UseCase 没有任何逻辑。

```swift
// ❌ 无意义的 UseCase（只是转发，没有业务逻辑）
final class FetchUserNameUseCase {
    func execute(userId: String) async throws -> String {
        try await userRepository.fetchUserName(userId: userId)  // 直接转发
    }
}

// ✅ 直接在 ViewModel 中调用 Repository
class ProfileViewModel {
    func loadProfile() async {
        let name = try? await userRepository.fetchUserName(userId: currentUserId)
        // ...
    }
}
```

**判断标准**：UseCase 里只有一行代码，且没有任何业务判断 → 删掉 UseCase，直接调用 Repository。

---

## 20.5 DTO 泄漏（DTO Leakage）

**症状**：DTO 被直接传递到 ViewModel 或 ViewController。

```swift
// ❌ DTO 泄漏到 ViewModel
class DeviceListViewModel {
    private(set) var devices: [DeviceDTO] = []  // ❌ 应该是 [DeviceEntity]
    
    func loadDevices() async {
        devices = try await deviceRepository.fetchDevices()  // Repository 直接返回 DTO
    }
}

// ❌ DTO 出现在 Cell
class DeviceCell {
    func configure(with dto: DeviceDTO) {  // ❌
        nameLabel.text = dto.device_name  // 下划线命名出现在 UI 层
    }
}
```

**正确做法**：Repository 通过 Mapper 将 DTO 转为 Entity 后返回，ViewModel 将 Entity 映射为 ViewState，Cell 只接收 ViewState。

---

## 20.6 Singleton 滥用

**症状**：到处是 `NetworkManager.shared`、`DatabaseManager.shared`、`UserManager.shared`。

```swift
// ❌ Singleton 滥用
class LoginViewModel {
    func login() async {
        let token = await NetworkManager.shared.post(path: "/login")  // 强耦合
        UserManager.shared.currentUser = DatabaseManager.shared.fetchUser()  // 全局状态
    }
}

// 后果：单元测试中无法替换 NetworkManager，无法验证登录流程
```

**正确做法**：将 Singleton 的单例行为保留在 `DIContainer` 中（只创建一次），但通过 Protocol 注入，消除强耦合。

---

## 20.7 Repository 操作 UI

**症状**：Repository 或 DataSource 直接弹 Alert、显示 HUD、发 Notification。

```swift
// ❌ Repository 操作 UI
final class DeviceRepositoryImpl {
    func addDevice(serialNumber: String) async throws -> DeviceEntity {
        do {
            let dto = try await remoteDataSource.addDevice(serialNumber: serialNumber)
            DispatchQueue.main.async {
                SVProgressHUD.showSuccess(withStatus: "添加成功")  // ❌ UI 操作
            }
            return mapper.toEntity(dto)
        } catch {
            NotificationCenter.default.post(name: .deviceAddFailed, object: error)  // ❌
            throw error
        }
    }
}
```

**正确做法**：Repository 只抛出或返回结果，UI 操作全部由 ViewModel → ViewController 处理。

---

## 20.8 ViewModel 持有 UIView

**症状**：ViewModel 持有对 UIView、UIViewController 的强引用。

```swift
// ❌ ViewModel 持有 UIView
class LoginViewModel {
    weak var loginButton: UIButton?  // ❌ UIKit 类型
    var viewController: UIViewController?  // ❌ 更严重
    
    func onLoginSuccess() {
        loginButton?.isEnabled = false  // ViewModel 直接操作 UI
        viewController?.navigationController?.pushViewController(...)  // ViewModel 负责导航
    }
}
```

**正确做法**：ViewModel 只发布状态变化（`stateStream.yield(.loginSuccess)`），ViewController 监听状态并更新 UI，Coordinator 负责导航。

---

## 20.9 Coordinator 包含业务逻辑

**症状**：Coordinator 中有业务判断，而不只是决定导航路径。

```swift
// ❌ Coordinator 包含业务逻辑
class DeviceCoordinator: Coordinator {
    func userTappedAddDevice(serialNumber: String) {
        // ❌ 业务逻辑不应该在 Coordinator 中
        guard serialNumber.count == 16 else {
            showAlert(message: "序列号格式错误")
            return
        }
        Task {
            let license = await licenseRepository.fetchCurrentLicense()
            guard license.remainingSlots > 0 else {
                showAlert(message: "License 已达上限")
                return
            }
            // ...
        }
    }
}
```

**正确做法**：Coordinator 只决定「跳转到哪里」，业务逻辑全部在 UseCase 中，失败/成功后由 ViewModel 通知 ViewController，ViewController 再通知 Coordinator 决定导航。

---

## 20.10 忽略错误（Swallowing Errors）

**症状**：用 `try?` 吞掉错误，或者只 `print(error)` 而不更新 UI 状态。

```swift
// ❌ 吞掉错误
func loadDevices() async {
    devices = (try? await fetchDevicesUseCase.execute()) ?? []
    tableView.reloadData()
    // 如果失败，用户看到空列表，不知道为什么
}

// ❌ 只打印
func loadDevices() async {
    do {
        devices = try await fetchDevicesUseCase.execute()
    } catch {
        print("Error: \(error)")  // 用户完全不知道发生了什么
    }
}

// ✅ 正确处理
func loadDevices() async {
    stateContinuation.yield(.loading)
    do {
        let entities = try await fetchDevicesUseCase.execute()
        deviceItems = entities.map { mapToItem($0) }
        stateContinuation.yield(.loaded)
    } catch {
        stateContinuation.yield(.error(error.localizedDescription))
    }
}
```

---

## 20.11 Combine + UIKit 过度绑定

**症状**：为了实现 MVVM 的「双向绑定」，引入大量 Combine，代码比解决的问题还复杂。

```swift
// ❌ 过度复杂的 Combine 绑定
class LoginViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isLoginEnabled = false
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Publishers.CombineLatest($username, $password)
            .map { u, p in !u.isEmpty && p.count >= 6 }
            .assign(to: &$isLoginEnabled)
    }
}

// ViewController 需要 import Combine，维护 cancellables
// 对于简单的「按钮是否可点击」判断，用 Combine 过于复杂

// ✅ 简单场景用函数直接计算
extension LoginViewModel {
    var isLoginEnabled: Bool {
        !username.isEmpty && password.count >= 6
    }
}
```

---

## Anti-Patterns 速查表

| 反模式 | 症状 | 修复方向 |
|--------|------|---------|
| Fat ViewController | VC > 800 行，包含业务逻辑 | 抽取 ViewModel + UseCase |
| Fat ViewModel | VM 包含所有逻辑，UseCase 是空壳 | 将业务逻辑移入 UseCase |
| God Repository | 单个 Repository 处理多种领域 | 按领域拆分 Repository |
| UseCase 泛滥 | UseCase 只有一行转发代码 | 删除空壳 UseCase，ViewModel 直调 Repository |
| DTO 泄漏 | ViewModel/ViewController 使用 DTO | 统一在 Repository 转换为 Entity |
| Singleton 滥用 | 到处 `.shared`，无法测试 | 通过 DIContainer + Protocol 注入 |
| Repository 操作 UI | Repository 弹 Alert / 发通知 | Repository 只抛出错误，UI 操作在 VC |
| ViewModel 持有 UIView | VM 有 `UIButton?` / `weak var vc` | VM 只发布状态，不持有 UI 引用 |
| Coordinator 含业务逻辑 | Coordinator 调 Repository | 业务逻辑移入 UseCase |
| 吞掉错误 | `try?` 忽略，或只 `print` | 捕获错误并更新 UI 状态 |

---

## 附录：快速参考

### 层级 → 对象 → 职责

```
Presentation
    ├── ViewController   → 生命周期、UI 渲染、绑定 ViewModel
    ├── UIView/Cell      → 纯展示，configure(with:) 接口
    ├── ViewModel        → 状态管理、展示逻辑、调用 UseCase
    └── Coordinator      → 页面导航

Domain
    ├── Entity           → 业务对象（纯 Swift struct）
    ├── UseCase          → 业务流程（execute() async throws）
    └── Repository Protocol → 数据访问抽象接口

Data
    ├── RepositoryImpl   → Repository Protocol 的实现，协调 DataSource
    ├── RemoteDataSource → 网络请求，返回 DTO
    ├── LocalDataSource  → 数据库操作，返回 DTO
    ├── DTO              → 匹配 API/DB 格式的数据对象
    └── Mapper           → DTO ↔ Entity 转换
```

### 依赖关系速查

```
允许的依赖：
✅ ViewController → ViewModel
✅ ViewController → Coordinator
✅ ViewModel → UseCase Protocol
✅ ViewModel → Repository Protocol（简单 CRUD）
✅ UseCase → Repository Protocol
✅ RepositoryImpl → DataSource Protocol
✅ DataSource → APIClient / NSManagedObjectContext

禁止的依赖：
❌ Domain → Presentation
❌ Domain → Data
❌ Domain → UIKit
❌ ViewModel → RepositoryImpl（应持有 Protocol）
❌ UseCase → RepositoryImpl（应持有 Protocol）
❌ ViewController → Repository/UseCase（应通过 ViewModel）
```

---

> 本文档版本：v1.0.0 | 最后更新：2026-07
>
> 如有疑问或建议，请通过 Code Review 或团队内部讨论渠道反馈。
