# 架构文档

> 本文档描述项目的整体架构设计，由 Planner 在需求分析阶段创建/更新。
> **Demo 写法**：以 Spring Boot 单体应用为基础模板，实际项目按需调整。

---

## 技术栈

| 类别 | 选型 | 版本 | 备注 |
|------|------|------|------|
| 语言 | Java | 17 | LTS |
| 框架 | Spring Boot | 3.x | |
| 构建 | Maven / Gradle | | 二选一 |
| ORM | Spring Data JPA | | Hibernate 实现 |
| 数据库 | MySQL 8.x | | 生产；H2 用于测试 |
| 缓存 | Redis | | 可选 |
| 测试 | JUnit 5 + Mockito + AssertJ | | |
| 覆盖率 | JaCoCo | | 集成到构建 |
| 代码风格 | Checkstyle / Spotless | | |
| API 文档 | Springdoc OpenAPI (Swagger 3) | | |
| 日志 | Logback + SLF4J | | Spring Boot 默认 |

<!-- Planner：根据实际项目替换上表内容 -->

---

## 目录结构

```
project/
├── src/
│   ├── main/
│   │   ├── java/com/example/app/
│   │   │   ├── controller/        # 接口层：HTTP 入口，参数校验，调用 Service
│   │   │   │   └── OrderController.java
│   │   │   ├── service/           # 业务层：核心业务逻辑，事务边界
│   │   │   │   ├── OrderService.java          # 接口
│   │   │   │   └── impl/
│   │   │   │       └── OrderServiceImpl.java  # 实现
│   │   │   ├── repository/        # 数据层：Spring Data JPA Repository
│   │   │   │   └── OrderRepository.java
│   │   │   ├── entity/            # JPA 实体：与数据库表映射
│   │   │   │   └── Order.java
│   │   │   ├── dto/               # 数据传输对象：Request/Response DTO
│   │   │   │   ├── request/
│   │   │   │   │   └── CreateOrderRequest.java
│   │   │   │   └── response/
│   │   │   │       └── OrderDTO.java
│   │   │   ├── exception/         # 自定义异常与全局处理器
│   │   │   │   ├── BusinessException.java
│   │   │   │   ├── ErrorCode.java
│   │   │   │   └── GlobalExceptionHandler.java
│   │   │   ├── config/            # 配置类（Security、Cache、Swagger 等）
│   │   │   └── common/            # 通用工具（响应体封装、常量等）
│   │   │       └── ApiResponse.java
│   │   └── resources/
│   │       ├── application.yml        # 主配置
│   │       ├── application-dev.yml    # 开发环境
│   │       ├── application-prod.yml   # 生产环境
│   │       └── db/migration/          # Flyway 数据库迁移脚本（可选）
│   └── test/
│       ├── java/com/example/app/
│       │   ├── controller/        # MockMvc 集成测试
│       │   ├── service/           # Service 单元测试（Mock Repository）
│       │   └── repository/        # @DataJpaTest 数据层测试
│       └── resources/
│           └── application-test.yml   # 测试配置（H2 内存库）
├── pom.xml / build.gradle
└── README.md
```

---

## 分层架构与依赖规则

```
┌─────────────────────────────────────────┐
│           Controller（接口层）            │
│  职责：HTTP 解析、参数校验、DTO 映射       │
│  禁止：业务逻辑、直接访问 Repository      │
└───────────────────┬─────────────────────┘
                    │ 调用（向下依赖）
┌───────────────────▼─────────────────────┐
│             Service（业务层）             │
│  职责：业务规则、事务管理、编排多个 Repo   │
│  禁止：依赖 HttpServletRequest 等 Web 对象│
└───────────────────┬─────────────────────┘
                    │ 调用（向下依赖）
┌───────────────────▼─────────────────────┐
│           Repository（数据层）            │
│  职责：数据库 CRUD、自定义 JPQL/SQL 查询  │
│  禁止：业务逻辑、调用其他 Service         │
└─────────────────────────────────────────┘
```

**依赖方向**：Controller → Service → Repository → Entity（单向，禁止反向依赖）

---

## 数据流（典型写操作）

```
HTTP Request
    │
    ▼
Controller.createOrder(request)
    │  @Valid 参数校验
    │  request → CreateOrderRequest DTO
    ▼
Service.createOrder(request)
    │  业务规则校验（库存、权限等）
    │  Entity 组装
    │  @Transactional 事务边界
    ▼
Repository.save(entity)
    │
    ▼
Database (MySQL)
    │
    ▼
Entity → OrderDTO（返回值映射）
    │
    ▼
Controller 包装为 ApiResponse<OrderDTO>
    │
    ▼
HTTP Response 201 Created
```

---

## 关键设计决策

<!-- Planner 在每次需求分析后更新此处 -->

| 决策 | 方案 | 理由 |
|------|------|------|
| 统一响应体 | `ApiResponse<T>` 包装 | 前后端约定，见 api-specs.md |
| 异常处理 | `@ControllerAdvice` 全局捕获 | 避免在每个 Controller 重复 try-catch |
| 事务粒度 | Service 方法级 `@Transactional` | Controller 不含事务，Repository 不含业务 |
| DTO 与 Entity 分离 | 独立 DTO 类 | 隔离数据库结构变更对 API 的影响 |
| 分页 | `Pageable` + `Page<T>` | Spring Data 标准，避免全量加载 |

---

## 部署架构

<!-- Planner 按实际情况填充 -->

```
[开发] 本地启动：mvn spring-boot:run
[测试] CI 运行：mvn verify（含单元+集成测试）
[生产] 打包为 Fat JAR：mvn package -DskipTests
       启动：java -jar app.jar --spring.profiles.active=prod
```

---

## 模块划分（多模块项目扩展）

<!-- 若为单模块，忽略此节；若为多模块 Maven 项目，按如下结构扩充 -->

```
parent-project/
├── app-api/          # DTO、接口定义（可供其他模块依赖）
├── app-service/      # 业务逻辑实现
├── app-web/          # Controller、Spring Boot 入口
└── app-common/       # 工具类、异常、常量
```
