# 组件地图（Java 模块地图）

> 本文档记录项目中所有模块/类的层级关系和用途，由 Planner/Developer 持续维护。
> **Demo 写法**：以 Spring Boot 订单模块为例。

---

## 模块树（包结构）

```
com.example.app
├── controller/                    # 接口层
│   ├── OrderController            # 订单相关接口（创建、查询、取消）
│   └── HealthController           # 健康检查接口（可选）
│
├── service/                       # 业务层（接口）
│   └── OrderService               # 订单业务接口
│
├── service/impl/                  # 业务层（实现）
│   └── OrderServiceImpl           # 订单业务实现
│
├── repository/                    # 数据层
│   └── OrderRepository            # 订单数据访问（JpaRepository）
│
├── entity/                        # JPA 实体
│   └── Order                      # 订单实体（映射 orders 表）
│
├── dto/                           # 数据传输对象
│   ├── request/
│   │   └── CreateOrderRequest     # 创建订单请求 DTO
│   └── response/
│       ├── OrderDTO               # 订单详情 DTO
│       └── OrderSummaryDTO        # 订单列表 DTO（精简字段）
│
├── exception/                     # 异常处理
│   ├── BusinessException          # 业务异常基类
│   ├── ErrorCode                  # 错误码枚举（含 HTTP 状态码 + 错误描述）
│   └── GlobalExceptionHandler     # @ControllerAdvice 全局捕获
│
├── config/                        # 配置类
│   ├── SwaggerConfig              # OpenAPI / Swagger UI 配置
│   ├── SecurityConfig             # Spring Security 配置（若需要）
│   └── JacksonConfig              # JSON 序列化配置（日期格式等）
│
├── common/                        # 通用工具
│   ├── ApiResponse                # 统一响应体包装
│   └── PageResult                 # 分页结果包装
│
└── AppApplication                 # Spring Boot 入口类
```

---

## 组件清单

| 类名 | 包路径 | 类型 | 用途 | 状态 |
|------|--------|------|------|------|
| `OrderController` | `controller` | `@RestController` | 订单 CRUD HTTP 入口 | 示例 |
| `OrderService` | `service` | `interface` | 订单业务接口定义 | 示例 |
| `OrderServiceImpl` | `service.impl` | `@Service` | 订单业务逻辑实现 | 示例 |
| `OrderRepository` | `repository` | `interface` | 订单数据库访问 | 示例 |
| `Order` | `entity` | `@Entity` | 订单 JPA 实体 | 示例 |
| `CreateOrderRequest` | `dto.request` | `@Data` | 创建订单入参 DTO | 示例 |
| `OrderDTO` | `dto.response` | `@Data` | 订单出参 DTO | 示例 |
| `BusinessException` | `exception` | `RuntimeException` | 业务异常基类 | 示例 |
| `ErrorCode` | `exception` | `enum` | 错误码枚举 | 示例 |
| `GlobalExceptionHandler` | `exception` | `@ControllerAdvice` | 全局异常处理 | 示例 |
| `ApiResponse<T>` | `common` | `class` | 统一响应体 | 示例 |
| `PageResult<T>` | `common` | `class` | 分页结果体 | 示例 |

> 状态说明：`示例（待替换）` / `开发中` / `已完成` / `已废弃`

---

## 依赖关系图

```
OrderController
    │  @Autowired
    ▼
OrderService（接口）
    │  实现
    ▼
OrderServiceImpl
    │  @Autowired
    ├──▶ OrderRepository
    │        │  操作
    │        ▼
    │       Order（Entity）
    │
    └──▶ InventoryClient（外部服务 / Feign Client）
```

---

## 数据库表清单

| 表名 | 对应 Entity | 说明 | 状态 |
|------|------------|------|------|
| `orders` | `Order` | 订单主表 | 示例 |

> 详细字段定义见 `src/main/resources/db/migration/` 下的 Flyway 脚本。

---

## 外部依赖清单

| 依赖名称 | 类型 | 用途 | 超时配置 | 降级策略 |
|----------|------|------|----------|----------|
| InventoryService | HTTP / Feign | 库存查询 | 3s | 返回库存不足 |

---

## 关键枚举

### OrderStatus

| 值 | 说明 | 允许跳转到 |
|----|------|-----------|
| `PENDING` | 待支付 | `PAID`, `CANCELLED` |
| `PAID` | 已支付 | `SHIPPED` |
| `SHIPPED` | 已发货 | `COMPLETED` |
| `CANCELLED` | 已取消 | — |
| `COMPLETED` | 已完成 | — |

```java
public enum OrderStatus {
    PENDING, PAID, SHIPPED, CANCELLED, COMPLETED
}
```

---

<!-- Planner/Developer：每次新增模块后更新上表 -->
