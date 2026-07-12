# UIKit + MVVM + Clean Architecture 开发规范
# Objective-C 与 Swift 差异说明

> 版本：v1.0.0 | 适用项目：UIKit + MVVM + Clean Architecture（Objective-C） | 更新日期：2026-07
>
> 本文档是《UIKit + MVVM + Clean Architecture 开发规范》的补充说明，专门描述 **Objective-C 项目** 与 **Swift 项目** 在架构实现上的差异。
>
> 架构分层、职责划分、依赖方向 **完全一致**，变化主要集中在 **语言特性与实现方式**。

---

## 目录

1. [核心差异总览](#chapter-1)
2. [异步方案：Block 回调替代 async/await](#chapter-2)
3. [Entity：class 替代 struct](#chapter-3)
4. [ViewModel 绑定：Block / KVO / Delegate 替代 AsyncStream](#chapter-4)
5. [错误处理：NSError 替代 throws](#chapter-5)
6. [Coordinator：基类替代 Protocol Extension](#chapter-6)
7. [Dependency Injection：DIContainer 的 OC 实现](#chapter-7)
8. [DTO 与 Mapper：手动 JSON 解析替代 Codable](#chapter-8)
9. [命名规范差异](#chapter-9)
10. [架构层面：什么不变，什么要调整](#chapter-10)
11. [OC 项目 Checklist](#chapter-11)

---

<a name="chapter-1"></a>
# 第一章：核心差异总览

## 1.1 语言特性对比

| 能力 | Swift | Objective-C | 架构影响 |
|------|-------|-------------|---------|
| `async/await` | ✅ 原生支持 | ❌ 不支持 | 异步方案改用 Block 回调 |
| `struct` 值类型 | ✅ | ❌ 只有 class | Entity 只能用 class |
| `enum` 关联值 | ✅ | ❌ | State / Error 枚举需变通 |
| `AsyncStream` | ✅ | ❌ | ViewModel → VC 绑定改用 Block / KVO / Delegate |
| `throws` | ✅ | ❌ | 错误处理使用 `NSError **` |
| `@MainActor` | ✅ | ❌ | 需手动 `dispatch_async(main_queue)` |
| Protocol Extension | ✅ | ❌ | Coordinator 默认实现需用基类 |
| Generics | ✅ 强泛型 | ⚠️ 弱泛型 | Repository 返回类型受限 |
| `.h / .m` 分离 | ❌ | ✅ | Protocol 定义放 `.h`，实现放 `.m` |
| `Codable` | ✅ | ❌ | DTO 需手动 JSON 解析 |

## 1.2 架构原则：不变

```
✅ 以下原则在 OC 与 Swift 中完全一致

├── 分层结构：Presentation / Domain / Data
├── 依赖方向：外层依赖内层，Domain 零依赖
├── Repository Pattern：Protocol 在 Domain，Impl 在 Data
├── UseCase 职责：承载业务流程，不承载数据存储
├── DTO ↔ Entity：通过 Mapper 隔离
├── Coordinator：统一管理导航
└── DIContainer：集中组装依赖
```

## 1.3 实现方式：需要调整

```
⚠️ 以下实现方式在 OC 中需要替换

├── async/await          → Block 回调 + GCD
├── struct Entity        → readonly class Entity
├── AsyncStream 绑定     → Block / KVO / Delegate
├── throws               → NSError ** 传出参数
├── Codable              → 手动 JSON 解析（dtoFromDictionary:）
├── Protocol Extension   → 基类（BaseCoordinator）
└── @MainActor           → dispatch_async(dispatch_get_main_queue())
```

### Best Practice

- 先按 Swift 规范理解分层与职责，再按本文档替换实现方式
- OC 项目不要因语言限制而放松架构边界
- 多步骤异步流程务必拆分私有方法，避免 Block 嵌套过深

### Common Mistakes

- 因为 OC 没有 `async/await`，就把网络请求直接写进 ViewController
- Entity 使用可变属性，导致引用类型被多处意外修改
- Block 回调未切回主线程，导致 UI 更新异常

### Checklist

- [ ] 是否已明确：架构不变，只是实现工具不同？
- [ ] 是否已统一团队异步方案（Block + GCD）？
- [ ] Domain 层是否仍然保持零 UIKit 依赖？

---

<a name="chapter-2"></a>
# 第二章：异步方案：Block 回调替代 async/await

## 2.1 为什么变化

Swift 规范推荐使用 `async/await`，因为：

- 代码线性，易读
- 错误处理统一
- 便于并发控制

Objective-C 没有 `async/await`，因此异步操作统一采用 **Block 回调 + GCD**。

## 2.2 Repository Protocol（OC）

```objc
// DeviceRepositoryProtocol.h

typedef void(^FetchDevicesCompletion)(NSArray<DeviceEntity *> * _Nullable devices,
                                      NSError * _Nullable error);

@protocol DeviceRepositoryProtocol <NSObject>

- (void)fetchDevicesWithCompletion:(FetchDevicesCompletion)completion;

- (void)addDeviceWithSerialNumber:(NSString *)serialNumber
                       completion:(void(^)(DeviceEntity * _Nullable device,
                                           NSError * _Nullable error))completion;

@end
```

## 2.3 UseCase（OC）

```objc
// FetchDevicesUseCase.h

@protocol FetchDevicesUseCaseProtocol <NSObject>
- (void)executeWithCompletion:(FetchDevicesCompletion)completion;
@end

@interface FetchDevicesUseCase : NSObject <FetchDevicesUseCaseProtocol>

- (instancetype)initWithDeviceRepository:(id<DeviceRepositoryProtocol>)repository;
- (void)executeWithCompletion:(FetchDevicesCompletion)completion;

@end
```

```objc
// FetchDevicesUseCase.m

@implementation FetchDevicesUseCase

- (void)executeWithCompletion:(FetchDevicesCompletion)completion {
    [self.deviceRepository fetchDevicesWithCompletion:^(NSArray<DeviceEntity *> *devices, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        completion(devices, nil);
    }];
}

@end
```

## 2.4 多步骤业务流程示例

```objc
// LoginUseCase.m

- (void)executeWithCredentials:(LoginCredentials *)credentials
                    completion:(void(^)(UserEntity * _Nullable, NSError * _Nullable))completion {

    [self.authRepository loginWithCredentials:credentials
                                 completion:^(AuthToken *token, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }

        [self.tokenStorage saveToken:token completion:^(NSError *saveError) {
            if (saveError) {
                completion(nil, saveError);
                return;
            }

            [self.userRepository fetchCurrentUserWithCompletion:^(UserEntity *user, NSError *fetchError) {
                completion(user, fetchError);
            }];
        }];
    }];
}
```

## 2.5 主线程切换规范

OC 没有 `@MainActor`，所有 UI 状态更新必须显式切回主线程：

```objc
dispatch_async(dispatch_get_main_queue(), ^{
    self.state = DeviceListStateLoaded;
    if (self.onStateChanged) {
        self.onStateChanged(self.state);
    }
});
```

### Best Practice

- 所有跨层异步接口统一使用 `completion` Block
- Repository / UseCase 不强制切主线程，由 ViewModel 或 ViewController 负责 UI 更新
- 多步骤流程拆成私有方法，避免三层以上 Block 嵌套

### Common Mistakes

- 在 ViewController 中直接写 `NSURLSession` 回调
- Block 内强引用 `self`，导致循环引用
- 忘记 `dispatch_async(main_queue)` 更新 UI

### Checklist

- [ ] Repository Protocol 是否统一使用 completion Block？
- [ ] 多步骤 UseCase 是否拆分了私有方法？
- [ ] UI 更新是否都在主线程执行？
- [ ] Block 中是否正确使用 `__weak typeof(self) weakSelf`？

---

<a name="chapter-3"></a>
# 第三章：Entity：class 替代 struct

## 3.1 为什么变化

Swift 推荐使用 `struct` 作为 Entity，因为：

- 值语义，线程安全
- 避免共享状态

Objective-C 没有值类型，Entity 只能使用 `class`。

## 3.2 标准 Entity 定义

```objc
// DeviceEntity.h

typedef NS_ENUM(NSInteger, DeviceStatus) {
    DeviceStatusOnline,
    DeviceStatusOffline,
    DeviceStatusError
};

@interface DeviceEntity : NSObject

@property (nonatomic, copy, readonly) NSString *deviceId;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSString *serialNumber;
@property (nonatomic, assign, readonly) DeviceStatus status;
@property (nonatomic, strong, readonly) NSDate *lastSeenAt;

- (instancetype)initWithId:(NSString *)deviceId
                      name:(NSString *)name
              serialNumber:(NSString *)serialNumber
                    status:(DeviceStatus)status
                lastSeenAt:(NSDate *)lastSeenAt;

@end
```

```objc
// DeviceEntity.m

@implementation DeviceEntity

- (instancetype)initWithId:(NSString *)deviceId
                      name:(NSString *)name
              serialNumber:(NSString *)serialNumber
                    status:(DeviceStatus)status
                lastSeenAt:(NSDate *)lastSeenAt {
    self = [super init];
    if (self) {
        _deviceId = [deviceId copy];
        _name = [name copy];
        _serialNumber = [serialNumber copy];
        _status = status;
        _lastSeenAt = lastSeenAt;
    }
    return self;
}

@end
```

## 3.3 关键约束

由于 OC Entity 是引用类型，必须遵守：

1. 所有业务字段使用 `readonly`
2. 只在 `init` 中赋值
3. 禁止提供 `setter`
4. 不把 Entity 当作可变状态容器

### Best Practice

- Entity 保持不可变对象
- 枚举使用 `NS_ENUM`
- 不在 Entity 中引入 UIKit 类型

### Common Mistakes

- Entity 属性可写，导致多处共享后被意外修改
- 把 DTO 直接当 Entity 使用
- Entity 中写展示逻辑（如 `displayName` 拼接）

### Checklist

- [ ] Entity 属性是否全部为 `readonly`？
- [ ] Entity 是否没有 `import UIKit`？
- [ ] Entity 是否没有 JSON 解析逻辑？

---

<a name="chapter-4"></a>
# 第四章：ViewModel 绑定：Block / KVO / Delegate 替代 AsyncStream

## 4.1 为什么变化

Swift 规范推荐使用 `AsyncStream` 向 ViewController 推送状态。

Objective-C 没有 `AsyncStream`，常见替代方案有三种：

| 方案 | 适用场景 | 推荐度 |
|------|---------|--------|
| Block 回调 | 页面状态整体变化 | ⭐⭐⭐ 推荐 |
| KVO | 监听单个属性变化 | ⭐⭐ 谨慎使用 |
| Delegate | ViewModel 与 VC 强约束通信 | ⭐⭐ 可用 |

## 4.2 推荐方案：Block 回调

```objc
// DeviceListViewModel.h

typedef NS_ENUM(NSInteger, DeviceListState) {
    DeviceListStateIdle,
    DeviceListStateLoading,
    DeviceListStateLoaded,
    DeviceListStateError
};

@interface DeviceListViewModel : NSObject

@property (nonatomic, copy, readonly) NSArray<DeviceViewItem *> *deviceItems;
@property (nonatomic, assign, readonly) DeviceListState state;
@property (nonatomic, copy, nullable, readonly) NSString *errorMessage;

@property (nonatomic, copy) void(^onStateChanged)(DeviceListState state);

- (instancetype)initWithUseCase:(id<FetchDevicesUseCaseProtocol>)useCase;
- (void)loadDevices;
- (void)refreshDevices;

@end
```

```objc
// DeviceListViewModel.m

- (void)loadDevices {
    _state = DeviceListStateLoading;
    if (self.onStateChanged) {
        self.onStateChanged(_state);
    }

    __weak typeof(self) weakSelf = self;
    [self.useCase executeWithCompletion:^(NSArray<DeviceEntity *> *devices, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                strongSelf->_state = DeviceListStateError;
                strongSelf->_errorMessage = error.localizedDescription;
            } else {
                strongSelf->_deviceItems = [strongSelf mapToViewItems:devices];
                strongSelf->_state = DeviceListStateLoaded;
            }

            if (strongSelf.onStateChanged) {
                strongSelf.onStateChanged(strongSelf->_state);
            }
        });
    }];
}
```

## 4.3 ViewController 绑定

```objc
// DeviceListViewController.m

- (void)bindViewModel {
    __weak typeof(self) weakSelf = self;
    self.viewModel.onStateChanged = ^(DeviceListState state) {
        [weakSelf renderState:state];
    };
}

- (void)renderState:(DeviceListState)state {
    switch (state) {
        case DeviceListStateLoading:
            [self.loadingIndicator startAnimating];
            break;
        case DeviceListStateLoaded:
            [self.loadingIndicator stopAnimating];
            [self.tableView reloadData];
            break;
        case DeviceListStateError:
            [self.loadingIndicator stopAnimating];
            [self showErrorWithMessage:self.viewModel.errorMessage];
            break;
        default:
            break;
    }
}
```

## 4.4 备选方案：KVO

```objc
- (void)bindViewModel {
    [self.viewModel addObserver:self
                     forKeyPath:@"state"
                        options:NSKeyValueObservingOptionNew
                        context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"state"]) {
        [self renderState:self.viewModel.state];
    }
}

- (void)dealloc {
    [self.viewModel removeObserver:self forKeyPath:@"state"];
}
```

> KVO 容易因忘记 `removeObserver` 导致 crash，优先使用 Block。

### Best Practice

- 页面级状态变化优先使用 `onStateChanged` Block
- ViewModel 不持有 ViewController
- ViewModel 不返回 `UIColor`、`UIFont`、`UIImage`

### Common Mistakes

- ViewModel 直接持有 `UIViewController`
- 使用 KVO 但未在 `dealloc` 中移除监听
- ViewModel 中直接操作 UI 控件

### Checklist

- [ ] ViewModel 是否通过 Block / Delegate 通知状态变化？
- [ ] ViewModel 是否没有 UIKit 类型？
- [ ] ViewController 是否在 `dealloc` 中清理监听？

---

<a name="chapter-5"></a>
# 第五章：错误处理：NSError 替代 throws

## 5.1 为什么变化

Swift 使用 `throws` / `catch` 统一处理错误。

Objective-C 使用 `NSError **` 或 completion Block 中的 `NSError *` 参数传递错误。

## 5.2 分层错误设计

```objc
// AddDeviceError.h

extern NSErrorDomain const AddDeviceErrorDomain;

typedef NS_ERROR_ENUM(AddDeviceErrorDomain, AddDeviceErrorCode) {
    AddDeviceErrorCodeInvalidSerialNumber = 1001,
    AddDeviceErrorCodeDeviceAlreadyRegistered = 1002,
    AddDeviceErrorCodeLicenseQuotaExceeded = 1003,
    AddDeviceErrorCodeNetworkUnavailable = 1004
};
```

```objc
// AddDeviceError.m

NSErrorDomain const AddDeviceErrorDomain = @"com.myapp.error.adddevice";

NSError *AddDeviceMakeError(AddDeviceErrorCode code, NSString *message) {
    return [NSError errorWithDomain:AddDeviceErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @""}];
}
```

## 5.3 UseCase 中抛出业务错误

```objc
- (void)executeWithSerialNumber:(NSString *)serialNumber
                      completion:(void(^)(DeviceEntity * _Nullable, NSError * _Nullable))completion {

    if (![self isValidSerialNumber:serialNumber]) {
        completion(nil, AddDeviceMakeError(AddDeviceErrorCodeInvalidSerialNumber,
                                           @"序列号格式不正确，请检查后重试"));
        return;
    }

    [self.licenseRepository fetchCurrentLicenseWithCompletion:^(LicenseEntity *license, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }

        if (license.remainingSlots <= 0) {
            completion(nil, AddDeviceMakeError(AddDeviceErrorCodeLicenseQuotaExceeded,
                                               @"已达到设备上限，请升级您的套餐"));
            return;
        }

        [self.deviceRepository addDeviceWithSerialNumber:serialNumber completion:completion];
    }];
}
```

## 5.4 ViewModel 中映射为用户可读错误

```objc
- (void)handleError:(NSError *)error {
    if ([error.domain isEqualToString:AddDeviceErrorDomain]) {
        switch (error.code) {
            case AddDeviceErrorCodeLicenseQuotaExceeded:
                self.errorAction = DeviceListErrorActionUpgradePlan;
                break;
            case AddDeviceErrorCodeInvalidSerialNumber:
                self.errorAction = DeviceListErrorActionNone;
                break;
            default:
                self.errorAction = DeviceListErrorActionRetry;
                break;
        }
    } else {
        self.errorAction = DeviceListErrorActionRetry;
    }

    self.errorMessage = error.localizedDescription;
    self.state = DeviceListStateError;

    if (self.onStateChanged) {
        self.onStateChanged(self.state);
    }
}
```

### Best Practice

- 每层定义自己的错误 Domain
- 技术错误在 Repository 层转换
- ViewModel 将错误映射为 UI 可展示状态

### Common Mistakes

- 直接把 `URLError` 展示给用户
- 用 `NSLog` 打印错误但不更新 UI
- 所有错误都用一个 Domain

### Checklist

- [ ] 业务错误是否定义了独立 Domain？
- [ ] 错误信息是否用户可读？
- [ ] ViewModel 是否将错误转换为 UI 状态？

---

<a name="chapter-6"></a>
# 第六章：Coordinator：基类替代 Protocol Extension

## 6.1 为什么变化

Swift 可以为 `Coordinator` Protocol 提供默认实现：

```swift
extension Coordinator {
    func addChild(_ coordinator: Coordinator) { ... }
    func removeChild(_ coordinator: Coordinator) { ... }
}
```

Objective-C 没有 Protocol Extension，因此需要使用 **基类** 提供默认实现。

## 6.2 BaseCoordinator

```objc
// BaseCoordinator.h

@interface BaseCoordinator : NSObject

@property (nonatomic, strong) NSMutableArray<BaseCoordinator *> *childCoordinators;
@property (nonatomic, strong) UINavigationController *navigationController;

- (instancetype)initWithNavigationController:(UINavigationController *)navigationController;
- (void)start;
- (void)addChild:(BaseCoordinator *)coordinator;
- (void)removeChild:(BaseCoordinator *)coordinator;

@end
```

```objc
// BaseCoordinator.m

@implementation BaseCoordinator

- (instancetype)initWithNavigationController:(UINavigationController *)navigationController {
    self = [super init];
    if (self) {
        _navigationController = navigationController;
        _childCoordinators = [NSMutableArray array];
    }
    return self;
}

- (void)start {
    NSAssert(NO, @"Subclasses must override -start");
}

- (void)addChild:(BaseCoordinator *)coordinator {
    [self.childCoordinators addObject:coordinator];
}

- (void)removeChild:(BaseCoordinator *)coordinator {
    [self.childCoordinators removeObject:coordinator];
}

@end
```

## 6.3 LoginCoordinator 示例

```objc
// LoginCoordinator.h

@protocol LoginCoordinatorDelegate <NSObject>
- (void)loginCoordinatorDidFinish:(LoginCoordinator *)coordinator;
@end

@interface LoginCoordinator : BaseCoordinator

@property (nonatomic, weak) id<LoginCoordinatorDelegate> delegate;

- (instancetype)initWithNavigationController:(UINavigationController *)navigationController
                                 diContainer:(DIContainer *)diContainer;
- (void)loginDidSucceed;
- (void)showForgotPassword;

@end
```

```objc
// LoginCoordinator.m

- (void)start {
    LoginViewModel *viewModel = [self.diContainer makeLoginViewModel];
    LoginViewController *vc = [[LoginViewController alloc] initWithViewModel:viewModel
                                                                  coordinator:self];
    [self.navigationController setViewControllers:@[vc] animated:NO];
}

- (void)loginDidSucceed {
    [self.delegate loginCoordinatorDidFinish:self];
}
```

### Best Practice

- 所有 Coordinator 继承 `BaseCoordinator`
- 子 Coordinator 完成后必须 `removeChild`
- delegate 使用 `weak`

### Common Mistakes

- 每个 Coordinator 自己维护 child 数组，逻辑重复
- Coordinator 中写业务逻辑
- ViewController 直接 `pushViewController`

### Checklist

- [ ] 是否所有 Coordinator 继承 BaseCoordinator？
- [ ] 子 Coordinator 完成后是否 removeChild？
- [ ] 导航是否都通过 Coordinator 发起？

---

<a name="chapter-7"></a>
# 第七章：Dependency Injection：DIContainer 的 OC 实现

## 7.1 为什么仍然需要 DI

OC 同样不应在 ViewModel / UseCase 内部直接创建依赖：

```objc
// ❌ 错误：内部自行创建依赖
@implementation LoginViewModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _useCase = [[LoginUseCase alloc] initWithAuthRepository:[[AuthRepositoryImpl alloc] init]];
    }
    return self;
}

@end
```

## 7.2 DIContainer 示例

```objc
// DIContainer.h

@interface DIContainer : NSObject

- (id<DeviceRemoteDataSourceProtocol>)deviceRemoteDataSource;
- (id<DeviceLocalDataSourceProtocol>)deviceLocalDataSource;
- (id<DeviceRepositoryProtocol>)deviceRepository;
- (id<AuthRepositoryProtocol>)authRepository;
- (id<FetchDevicesUseCaseProtocol>)fetchDevicesUseCase;
- (id<LoginUseCaseProtocol>)loginUseCase;
- (DeviceListViewModel *)makeDeviceListViewModel;
- (LoginViewModel *)makeLoginViewModel;

@end
```

```objc
// DIContainer.m

@interface DIContainer ()
@property (nonatomic, strong) id<DeviceRepositoryProtocol> deviceRepository;
@property (nonatomic, strong) id<AuthRepositoryProtocol> authRepository;
@property (nonatomic, strong) APIClient *apiClient;
@end

@implementation DIContainer

- (id<DeviceRepositoryProtocol>)deviceRepository {
    if (!_deviceRepository) {
        _deviceRepository = [[DeviceRepositoryImpl alloc]
            initWithRemoteDataSource:[self deviceRemoteDataSource]
                   localDataSource:[self deviceLocalDataSource]
                            mapper:[DeviceMapper new]];
    }
    return _deviceRepository;
}

- (id<FetchDevicesUseCaseProtocol>)fetchDevicesUseCase {
    return [[FetchDevicesUseCase alloc] initWithDeviceRepository:[self deviceRepository]];
}

- (DeviceListViewModel *)makeDeviceListViewModel {
    return [[DeviceListViewModel alloc] initWithUseCase:[self fetchDevicesUseCase]];
}

@end
```

## 7.3 Singleton 的处理方式

OC 中常见 `+sharedInstance`，规范要求：

- 可以保留单例行为
- 但必须通过 DIContainer 暴露为 Protocol
- 业务层不直接调用 `SomeManager.shared`

```objc
// ✅ 可接受：单例由 DIContainer 管理
- (id<NetworkServiceProtocol>)networkService {
    if (!_networkService) {
        _networkService = [NetworkService sharedInstance];
    }
    return _networkService;
}
```

### Best Practice

- 构造函数注入优先
- Repository 使用懒加载缓存
- UseCase 每次返回新实例

### Common Mistakes

- ViewModel 内部 `alloc/init` RepositoryImpl
- 到处直接调用 `+sharedInstance`
- DIContainer 变成 God Object

### Checklist

- [ ] 是否所有依赖都通过 DIContainer 创建？
- [ ] 业务代码是否避免直接调用 Singleton？
- [ ] 单元测试是否可以注入 Mock 对象？

---

<a name="chapter-8"></a>
# 第八章：DTO 与 Mapper：手动 JSON 解析替代 Codable

## 8.1 为什么变化

Swift 中 DTO 通常实现 `Codable`：

```swift
struct DeviceDTO: Codable {
    let device_name: String
}
```

Objective-C 没有 `Codable`，需要手动解析 JSON。

## 8.2 DTO 定义

```objc
// DeviceDTO.h

@interface DeviceDTO : NSObject

@property (nonatomic, copy) NSString *deviceId;
@property (nonatomic, copy) NSString *device_name;
@property (nonatomic, copy) NSString *serial_number;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, assign) NSTimeInterval last_seen_at;

+ (nullable instancetype)dtoFromDictionary:(NSDictionary *)dictionary;
+ (NSArray<DeviceDTO *> *)dtosFromArray:(NSArray *)array;

@end
```

```objc
// DeviceDTO.m

+ (nullable instancetype)dtoFromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    DeviceDTO *dto = [DeviceDTO new];
    dto.deviceId = dictionary[@"id"];
    dto.device_name = dictionary[@"device_name"];
    dto.serial_number = dictionary[@"serial_number"];
    dto.status = dictionary[@"status"];
    dto.last_seen_at = [dictionary[@"last_seen_at"] doubleValue];
    return dto;
}

+ (NSArray<DeviceDTO *> *)dtosFromArray:(NSArray *)array {
    NSMutableArray<DeviceDTO *> *result = [NSMutableArray array];
    for (id item in array) {
        DeviceDTO *dto = [self dtoFromDictionary:item];
        if (dto) {
            [result addObject:dto];
        }
    }
    return result.copy;
}
```

## 8.3 Mapper 示例

```objc
// DeviceMapper.h

@interface DeviceMapper : NSObject
- (DeviceEntity *)toEntityFromDTO:(DeviceDTO *)dto;
- (NSArray<DeviceEntity *> *)toEntitiesFromDTOs:(NSArray<DeviceDTO *> *)dtos;
@end
```

```objc
// DeviceMapper.m

- (DeviceEntity *)toEntityFromDTO:(DeviceDTO *)dto {
    return [[DeviceEntity alloc] initWithId:dto.deviceId
                                       name:dto.device_name
                               serialNumber:dto.serial_number
                                     status:[self mapStatus:dto.status]
                                 lastSeenAt:[NSDate dateWithTimeIntervalSince1970:dto.last_seen_at]];
}

- (DeviceStatus)mapStatus:(NSString *)raw {
    if ([raw isEqualToString:@"online"]) return DeviceStatusOnline;
    if ([raw isEqualToString:@"offline"]) return DeviceStatusOffline;
    return DeviceStatusError;
}
```

## 8.4 RemoteDataSource 示例

```objc
- (void)fetchDevicesWithCompletion:(void(^)(NSArray<DeviceDTO *> * _Nullable, NSError * _Nullable))completion {
    [self.apiClient requestWithPath:@"/devices"
                         completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }

        NSArray *list = response[@"data"];
        completion([DeviceDTO dtosFromArray:list], nil);
    }];
}
```

### Best Practice

- DTO 只存在于 Data 层
- Mapper 只做字段映射，不写业务逻辑
- API 字段变化只影响 DTO 和 Mapper

### Common Mistakes

- DTO 泄漏到 ViewModel / ViewController
- 在 Cell 中直接使用 `device_name`
- Mapper 中写网络请求或缓存逻辑

### Checklist

- [ ] DTO 是否只在 Data 层使用？
- [ ] Repository 是否返回 Entity 而不是 DTO？
- [ ] JSON 解析是否集中在 DTO 中？

---

<a name="chapter-9"></a>
# 第九章：命名规范差异

## 9.1 类型命名对照

| 类型 | Swift | Objective-C |
|------|-------|-------------|
| ViewController | `LoginViewController` | `LoginViewController` |
| ViewModel | `LoginViewModel` | `LoginViewModel` |
| UseCase Protocol | `LoginUseCaseProtocol` | `LoginUseCaseProtocol` |
| UseCase 实现 | `LoginUseCase` | `LoginUseCase` |
| Repository Protocol | `DeviceRepositoryProtocol` | `DeviceRepositoryProtocol` |
| Repository 实现 | `DeviceRepositoryImpl` | `DeviceRepositoryImpl` |
| DTO | `DeviceDTO` | `DeviceDTO` |
| Entity | `DeviceEntity` | `DeviceEntity` |
| Mapper | `DeviceMapper` | `DeviceMapper` |
| Coordinator | `LoginCoordinator` | `LoginCoordinator` |

## 9.2 方法命名差异

| 场景 | Swift | Objective-C |
|------|-------|-------------|
| UseCase 执行 | `execute()` | `executeWithCompletion:` |
| 获取列表 | `fetchDevices()` | `fetchDevicesWithCompletion:` |
| 添加设备 | `addDevice(serialNumber:)` | `addDeviceWithSerialNumber:completion:` |
| 页面跳转 | `showDeviceDetail(deviceId:)` | `showDeviceDetailWithDeviceId:` |

## 9.3 枚举与错误命名

```objc
// 状态枚举
typedef NS_ENUM(NSInteger, DeviceListState) {
    DeviceListStateIdle,
    DeviceListStateLoading,
    DeviceListStateLoaded,
    DeviceListStateError
};

// 错误枚举
typedef NS_ERROR_ENUM(AddDeviceErrorDomain, AddDeviceErrorCode) {
    AddDeviceErrorCodeInvalidSerialNumber = 1001
};
```

## 9.4 Block 类型命名

```objc
typedef void(^FetchDevicesCompletion)(NSArray<DeviceEntity *> * _Nullable devices,
                                      NSError * _Nullable error);

typedef void(^LoginCompletion)(UserEntity * _Nullable user,
                               NSError * _Nullable error);
```

### Best Practice

- OC 方法名应完整表达参数含义
- 枚举值带类型前缀，如 `DeviceStatusOnline`
- completion Block 使用 `typedef` 统一定义

### Common Mistakes

- 方法名过短，参数语义不清
- 枚举值命名冲突
- 每个文件重复定义相同 Block 类型

### Checklist

- [ ] UseCase 是否统一使用 `executeWithCompletion:`？
- [ ] Repository 方法是否带 `WithCompletion:` 后缀？
- [ ] Block 类型是否通过 `typedef` 复用？

---

<a name="chapter-10"></a>
# 第十章：架构层面：什么不变，什么要调整

## 10.1 完全不变的部分

```
架构思想
├── Presentation / Domain / Data 三层划分
├── 依赖只能由外向内
├── Domain 不依赖 UIKit
├── Repository Protocol 在 Domain
├── RepositoryImpl 在 Data
├── UseCase 承载业务流程
├── Coordinator 管理导航
└── DIContainer 管理依赖
```

## 10.2 需要调整的部分

| Swift 实现 | Objective-C 替代方案 |
|-----------|---------------------|
| `async/await` | Block 回调 + GCD |
| `struct` Entity | `readonly class` Entity |
| `AsyncStream` | Block / KVO / Delegate |
| `throws` | `NSError **` |
| `Codable` | `dtoFromDictionary:` |
| Protocol Extension | `BaseCoordinator` |
| `@MainActor` | `dispatch_async(main_queue)` |

## 10.3 各层职责对照

```
Presentation（OC）
├── ViewController   → 生命周期、UI、绑定 ViewModel
├── UIView / Cell    → 纯展示
├── ViewModel        → 状态管理、展示逻辑、调用 UseCase
└── Coordinator      → 页面导航

Domain（OC）
├── Entity           → 不可变 class
├── UseCase          → executeWithCompletion:
└── Repository Protocol

Data（OC）
├── RepositoryImpl
├── RemoteDataSource
├── LocalDataSource
├── DTO
└── Mapper
```

## 10.4 OC 项目的最大挑战

> **Block 嵌套导致可读性下降（回调地狱）**

应对策略：

1. 多步骤 UseCase 拆私有方法
2. 使用 `typedef` 明确 completion 类型
3. 复杂流程考虑 Promise/Future 轻量封装（可选）
4. 严格控制每层职责，避免把流程又写回 ViewController

### Best Practice

- 坚持「架构不变，工具替换」
- 不为语言限制降低分层标准
- 把 Block 管理规范写入 Code Review 清单

### Common Mistakes

- 认为 OC 做不了 Clean Architecture，于是退回 Massive ViewController
- 用 Notification 在 VC 之间传业务数据
- 用 Singleton 替代 DI

### Checklist

- [ ] 是否仍保持三层架构？
- [ ] 是否没有把网络请求写回 ViewController？
- [ ] 是否建立了 OC 版异步与错误处理规范？

---

<a name="chapter-11"></a>
# 第十一章：OC 项目 Checklist

## 11.1 Architecture

- [ ] ViewController 是否超过 400 行？
- [ ] ViewController 是否直接调用 `NSURLSession`？
- [ ] ViewController 是否直接 `pushViewController`？
- [ ] ViewModel 是否包含 UIKit 类型？
- [ ] Domain 层是否零 UIKit 依赖？

## 11.2 Async / Block

- [ ] 是否统一使用 completion Block？
- [ ] Block 中是否使用 `__weak / __strong self`？
- [ ] UI 更新是否切回主线程？
- [ ] 多步骤流程是否避免三层以上嵌套？

## 11.3 Entity / DTO

- [ ] Entity 是否全部为 `readonly`？
- [ ] DTO 是否只在 Data 层？
- [ ] Repository 是否返回 Entity？
- [ ] Mapper 是否只做字段映射？

## 11.4 Error

- [ ] 是否定义了业务错误 Domain？
- [ ] 技术错误是否转换为用户可读信息？
- [ ] ViewModel 是否将错误映射为 UI 状态？

## 11.5 Coordinator / DI

- [ ] 导航是否都通过 Coordinator？
- [ ] 子 Coordinator 是否 removeChild？
- [ ] 是否避免直接调用 `+sharedInstance`？
- [ ] 是否可以通过 Mock 注入依赖？

## 11.6 Memory

- [ ] delegate 是否 `weak`？
- [ ] KVO 是否在 `dealloc` 中移除？
- [ ] Block 是否造成循环引用？

---

## 附录：Swift ↔ Objective-C 快速对照表

| 主题 | Swift | Objective-C |
|------|-------|-------------|
| 异步 | `async/await` | Block + GCD |
| 状态推送 | `AsyncStream` | `onStateChanged` Block |
| 实体 | `struct` | `readonly class` |
| 错误 | `throws` | `NSError **` |
| JSON | `Codable` | `dtoFromDictionary:` |
| 主线程 | `@MainActor` | `dispatch_async(main_queue)` |
| Coordinator 默认实现 | Protocol Extension | `BaseCoordinator` |
| 架构分层 | Presentation / Domain / Data | **完全相同** |

---

## 核心结论

> **Objective-C 项目与 Swift 项目在架构上没有本质区别。**
>
> 差异不在「怎么分层」，而在「怎么实现」：
>
> - 用 Block 回调替代 `async/await`
> - 用 `readonly class` 替代 `struct`
> - 用 Block / KVO / Delegate 替代 `AsyncStream`
> - 用 `NSError **` 替代 `throws`
>
> 只要坚持相同的分层与职责边界，Objective-C 项目同样可以长期维护、可测试、可扩展。

---

> 本文档版本：v1.0.0 | 最后更新：2026-07
>
> 关联文档：《UIKit + MVVM + Clean Architecture 开发规范》（Swift 主规范）
