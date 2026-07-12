# Prompt：生成《UIKit + MVVM + Clean Architecture 开发规范》

你是一位拥有 10 年以上 iOS 开发经验的软件架构师，同时也是一位优秀的技术文档作者。

请帮助我编写一本完整的 Markdown 文档，文档名称为：

> 《UIKit + MVVM + Clean Architecture 开发规范》

这不是一篇博客，也不是一篇教程，而是一份团队长期使用的开发规范（Development Guideline）。

目标读者：

- iOS 开发工程师
- 使用 UIKit（不是 SwiftUI）
- 使用 Swift
- 采用 MVVM + Clean Architecture
- 使用 async/await
- 项目属于中大型商业项目
- 文档可作为团队 Code Review 标准

------

# 文档要求

请生成一份完整、系统、专业的 Markdown 文档。

要求：

- 使用 Markdown 格式。
- 使用清晰的一级、二级、三级标题。
- 每个章节都尽可能完整，不要只写几句话。
- 每个概念都解释：
  - 字面意思（Literal Meaning）
  - 在架构中的作用
  - 为什么需要它
  - 它应该负责什么
  - 它不应该负责什么
- 不仅告诉我"怎么做"，还要解释"为什么这样设计"。
- 大量使用 ASCII 架构图。
- 大量使用 Swift 示例代码。
- 每章最后增加：
  - Best Practice（最佳实践）
  - Common Mistakes（常见错误）
  - Checklist（检查项）

整个文档风格应像大型互联网公司的内部开发规范。

不要写成博客风格。

不要简单介绍概念。

要真正能指导项目开发。

------

# 文档内容

请按照下面顺序组织内容。

------

# 第一章：为什么选择 MVVM + Clean Architecture

包括：

- MVC 的问题
- MVVM 解决了什么
- Clean Architecture 解决了什么
- 为什么 UIKit 项目适合这种架构
- 为什么不要把所有逻辑放到 ViewController

------

# 第二章：整体架构

绘制整体架构图，例如：

View

↓

ViewModel

↓

UseCase

↓

Repository

↓

Remote / Local

↓

API / Database

说明：

每层职责

依赖方向

数据流

为什么依赖只能向内

------

# 第三章：Presentation Layer

介绍：

Presentation 的含义

为什么叫 Presentation

包含哪些对象：

- ViewController
- UIView
- Cell
- Coordinator
- ViewModel

说明：

每个对象职责。

每个对象不能做什么。

------

# 第四章：ViewController 开发规范

必须说明：

ViewController 应该负责：

- 生命周期
- UI
- Binding
- 用户交互

不要负责：

- 网络请求
- Repository
- 数据库
- MQTT
- 蓝牙
- 业务流程

举大量代码示例。

------

# 第五章：ViewModel 开发规范

介绍：

ViewModel 的职责。

什么属于 Presentation Logic。

什么属于 Business Logic。

ViewModel 是否允许：

- 调 Repository
- 调 UseCase
- 格式化时间
- 格式化金额
- 排序
- 过滤
- 拼接字符串

说明：

什么时候应该交给 UseCase。

什么时候应该交给 Repository。

------

# 第六章：Coordinator

详细介绍：

为什么需要 Coordinator。

导航应该属于谁。

为什么不要在 ViewController push 页面。

Coordinator 的职责。

Coordinator 示例。

Coordinator 生命周期。

Coordinator 最佳实践。

------

# 第七章：Domain Layer

介绍：

Domain 字面意思。

为什么叫 Domain。

包含：

- Entity
- UseCase
- Repository Protocol

为什么 Repository Protocol 在 Domain。

为什么不能依赖 UIKit。

------

# 第八章：Entity

解释：

Entity 的意义。

什么时候需要 Entity。

Entity 与 DTO 区别。

Entity 是否允许 Codable。

Entity 是否允许 UIKit。

------

# 第九章：UseCase

介绍：

UseCase 字面意思。

为什么叫 UseCase。

什么时候需要。

什么时候不需要。

举例：

登录。

添加设备。

支付。

同步数据。

说明：

UseCase 应该负责：

业务流程。

而不是数据存储。

------

# 第十章：Repository

介绍：

Repository 字面意思。

为什么叫 Repository。

Repository 的职责。

Repository 是否允许多个 DataSource。

Repository 是否允许缓存。

为什么 Repository 使用 Protocol。

为什么 RepositoryImpl 放 Data Layer。

------

# 第十一章：Data Layer

详细介绍：

RemoteDataSource

LocalDataSource

Mapper

DTO

RepositoryImpl

说明：

每个对象负责什么。

为什么这样拆。

------

# 第十二章：DTO 与 Mapper

介绍：

DTO 为什么存在。

为什么不要直接使用 API Model。

什么时候需要 Mapper。

什么时候可以不要 Mapper。

举例说明。

------

# 第十三章：Dependency Injection

介绍：

什么是 DI。

Constructor Injection。

Property Injection。

为什么推荐 Constructor Injection。

为什么不要 Singleton。

举大量例子。

------

# 第十四章：async/await 与 Combine

请结合 2026 年 iOS 开发实践。

说明：

为什么推荐 async/await。

什么时候使用 AsyncStream。

什么时候适合 Combine。

什么时候不要为了 MVVM 引入 Combine。

------

# 第十五章：错误处理

介绍：

Error 应该在哪里处理。

Repository 是否转换 Error。

ViewModel 如何处理 Error。

UI 如何展示 Error。

------

# 第十六章：项目目录规范

请设计一个适合 UIKit + MVVM + Clean Architecture 的目录结构。

例如：

Presentation

Domain

Data

Core

Resources

Utilities

Extensions

Coordinator

Network

Database

并说明为什么。

------

# 第十七章：命名规范

包括：

ViewController

ViewModel

UseCase

Repository

DataSource

DTO

Entity

Mapper

Coordinator

命名建议。

------

# 第十八章：一个完整页面示例

以：

登录页面。

或者：

设备列表页面。

完整展示：

ViewController

↓

ViewModel

↓

UseCase

↓

Repository

↓

RemoteDataSource

↓

API

包括完整代码示例。

------

# 第十九章：Code Review Checklist

设计一份团队 Code Review 清单。

例如：

□ ViewController 是否包含业务逻辑？

□ ViewModel 是否直接请求 API？

□ DTO 是否进入 Presentation？

□ 是否真正需要 UseCase？

□ Repository 是否负责缓存？

……

至少 50 条。

------

# 第二十章：常见反模式（Anti Patterns）

例如：

Fat ViewController

Fat ViewModel

God Repository

UseCase 泛滥

DTO 泄漏

Singleton 滥用

Repository 请求 UI

ViewModel 持有 UIView

等。

说明：

为什么不好。

正确写法是什么。

------

# 特殊要求

整个文档请遵循以下原则：

1. 不是博客。
2. 不要长篇空洞理论。
3. 尽可能像 Google、Apple、Airbnb 的内部开发规范。
4. 大量使用架构图。
5. 大量使用 Swift 示例。
6. 每章都有：
   - Why（为什么）
   - Responsibilities（职责）
   - Best Practice（最佳实践）
   - Common Mistakes（常见错误）
   - Checklist（检查项）
7. 结合 UIKit，不讨论 SwiftUI。
8. 结合 2026 年 iOS 主流实践。
9. 推荐使用：
   - async/await
   - MVVM
   - Coordinator
   - Dependency Injection
   - Repository Pattern
   - Clean Architecture
10. 不要为了"架构完整"而增加没有意义的层级，应说明哪些层是可选的、什么情况下应该引入。
11. 文档要达到可以直接作为团队开发规范的质量。

最终请输出一份完整、高质量、可长期维护的 Markdown 文档。

