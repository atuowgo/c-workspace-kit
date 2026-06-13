# 编码规范（Java）

> Demo 写法：以 Java 17 + Spring Boot 3.x 为基准，实际项目按需调整。

---

## 通用原则

1. **简单优先**：三行重复好过一次过早抽象
2. **不求未来**：不为"可能"的需求写代码
3. **先读后写**：修改文件前必须读取当前内容
4. **单一职责**：每次提交只做一件事
5. **接口隔离**：Service 层必须有接口，方便 Mock 测试

---

## 命名规范

| 场景 | 规则 | 示例 |
|------|------|------|
| 类名 | PascalCase | `OrderService`, `CreateOrderRequest` |
| 方法名/变量名 | camelCase | `createOrder`, `orderId` |
| 常量 | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT`, `DEFAULT_PAGE_SIZE` |
| 包名 | 全小写，无下划线 | `com.example.app.service` |
| 数据库表名 | snake_case | `order_item`, `user_profile` |
| 数据库字段 | snake_case | `created_at`, `user_id` |
| 枚举值 | UPPER_SNAKE_CASE | `OrderStatus.PENDING` |

**接口命名**：动词开头，不加 I 前缀

```java
// ✅ 正确
public interface OrderService { ... }
public class OrderServiceImpl implements OrderService { ... }

// ❌ 错误
public interface IOrderService { ... }
```

---

## 分层职责规范

### Controller 层

```java
@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
@Validated
public class OrderController {

    private final OrderService orderService;

    // ✅ Controller 只做：参数接收、校验、调用 Service、包装响应
    @PostMapping
    public ResponseEntity<ApiResponse<OrderDTO>> createOrder(
            @Valid @RequestBody CreateOrderRequest request) {
        OrderDTO order = orderService.createOrder(request);
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(ApiResponse.success(order));
    }

    // ❌ 禁止在 Controller 写业务逻辑
    // if (inventory < request.getQuantity()) { ... }  // 这是 Service 的职责
}
```

### Service 层

```java
@Service
@RequiredArgsConstructor
@Transactional  // 类级别默认事务；只读方法用 @Transactional(readOnly = true)
@Slf4j
public class OrderServiceImpl implements OrderService {

    private final OrderRepository orderRepository;
    private final InventoryClient inventoryClient;

    // ✅ 读操作加 readOnly=true，提升性能
    @Override
    @Transactional(readOnly = true)
    public OrderDTO getOrder(Long id) {
        return orderRepository.findById(id)
            .map(OrderDTO::from)
            .orElseThrow(() -> new BusinessException(ErrorCode.ORDER_NOT_FOUND));
    }

    // ✅ 日志记录关键业务节点，不记录无意义的进入/退出
    @Override
    public OrderDTO createOrder(CreateOrderRequest request) {
        if (!inventoryClient.checkStock(request.getProductId(), request.getQuantity())) {
            log.warn("库存不足，productId={}, quantity={}", request.getProductId(), request.getQuantity());
            throw new BusinessException(ErrorCode.INSUFFICIENT_STOCK);
        }
        Order order = Order.builder()
            .productId(request.getProductId())
            .quantity(request.getQuantity())
            .status(OrderStatus.PENDING)
            .build();
        Order saved = orderRepository.save(order);
        log.info("订单创建成功，orderId={}", saved.getId());
        return OrderDTO.from(saved);
    }
}
```

### Repository 层

```java
// ✅ 继承 JpaRepository，复杂查询用 @Query
public interface OrderRepository extends JpaRepository<Order, Long> {

    List<Order> findByUserId(Long userId);

    @Query("SELECT o FROM Order o WHERE o.status = :status AND o.createdAt >= :since")
    List<Order> findRecentByStatus(@Param("status") OrderStatus status,
                                   @Param("since") LocalDateTime since);

    // ✅ 分页查询必须返回 Page<T>，不返回全量 List
    Page<Order> findByUserId(Long userId, Pageable pageable);
}
```

---

## 实体规范

```java
@Entity
@Table(name = "orders")
@Getter                         // Lombok：只生成 getter，不生成 setter（防止意外修改）
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private Long productId;

    @Column(nullable = false)
    private Integer quantity;

    @Enumerated(EnumType.STRING)    // ✅ 枚举存字符串，不存数字（可读性、扩展性）
    @Column(nullable = false, length = 20)
    private OrderStatus status;

    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;
}
```

---

## DTO 规范

```java
// Request DTO：包含参数校验注解
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateOrderRequest {

    @NotNull(message = "productId 不能为空")
    private Long productId;

    @NotNull(message = "quantity 不能为空")
    @Min(value = 1, message = "quantity 最小为 1")
    @Max(value = 999, message = "quantity 最大为 999")
    private Integer quantity;

    private String remark;  // 可选字段无需 @NotNull
}

// Response DTO：包含静态工厂方法，隔离 Entity
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OrderDTO {

    private Long id;
    private Long productId;
    private Integer quantity;
    private String status;
    private LocalDateTime createdAt;

    // ✅ 从 Entity 转 DTO 的逻辑放在 DTO 类，不放在 Service
    public static OrderDTO from(Order order) {
        return OrderDTO.builder()
            .id(order.getId())
            .productId(order.getProductId())
            .quantity(order.getQuantity())
            .status(order.getStatus().name())
            .createdAt(order.getCreatedAt())
            .build();
    }
}
```

---

## 异常处理规范

```java
// ✅ 业务异常类（区别于技术异常）
@Getter
public class BusinessException extends RuntimeException {

    private final ErrorCode errorCode;

    public BusinessException(ErrorCode errorCode) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
    }
}

// ✅ 错误码枚举（统一管理所有业务错误）
@Getter
@RequiredArgsConstructor
public enum ErrorCode {
    ORDER_NOT_FOUND(404, "订单不存在"),
    INSUFFICIENT_STOCK(400, "库存不足"),
    DUPLICATE_ORDER(409, "重复提交"),
    ;

    private final int httpStatus;
    private final String message;
}

// ✅ 全局异常处理器（唯一捕获点）
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<Void>> handleBusiness(BusinessException ex) {
        return ResponseEntity.status(ex.getErrorCode().getHttpStatus())
            .body(ApiResponse.error(ex.getErrorCode().getHttpStatus(), ex.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Void>> handleValidation(MethodArgumentNotValidException ex) {
        String message = ex.getBindingResult().getFieldErrors().stream()
            .map(e -> e.getField() + ": " + e.getDefaultMessage())
            .collect(Collectors.joining("; "));
        return ResponseEntity.badRequest().body(ApiResponse.error(400, message));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleUnexpected(Exception ex) {
        log.error("未预期异常", ex);    // ✅ 记录完整堆栈
        return ResponseEntity.internalServerError()
            .body(ApiResponse.error(500, "系统内部错误"));
    }
}
```

---

## 日志规范

```java
@Slf4j  // Lombok 注解，等价于 private static final Logger log = LoggerFactory.getLogger(...)
public class OrderServiceImpl {

    // ✅ 正确用法
    log.debug("查询订单参数：userId={}, status={}", userId, status);    // 调试细节
    log.info("订单创建成功：orderId={}", saved.getId());                // 关键业务事件
    log.warn("库存不足，降级处理：productId={}", productId);             // 需要关注但不影响主流程
    log.error("调用支付服务失败：orderId={}", orderId, exception);       // 异常，最后一个参数传 Throwable

    // ❌ 禁止
    System.out.println("orderId: " + orderId);          // 禁止 sysout
    log.info("进入 createOrder 方法");                   // 无意义日志
    log.error("发生错误: " + ex.getMessage());           // 不传 Throwable，丢失堆栈
    log.info("result: " + someObject.toString());        // 字符串拼接，性能差
}
```

---

## 测试规范

```java
// ✅ 测试方法命名：方法名_场景_预期结果
@Test
void createOrder_withInsufficientStock_throwsBusinessException() { ... }

@Test
void getOrder_withNonExistentId_returnsNotFound() { ... }

// ✅ AAA 结构（Arrange / Act / Assert）
@Test
void createOrder_withValidRequest_returnsCreatedOrder() {
    // Arrange
    CreateOrderRequest request = CreateOrderRequest.builder()
        .productId(1L).quantity(2).build();
    given(inventoryClient.checkStock(1L, 2)).willReturn(true);
    given(orderRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

    // Act
    OrderDTO result = orderService.createOrder(request);

    // Assert
    assertThat(result.getStatus()).isEqualTo("PENDING");
    then(orderRepository).should(times(1)).save(any());
}
```

测试覆盖率目标：
- Service 层：行覆盖率 >= 80%，分支覆盖率 >= 70%
- Controller 层：主要场景 + 参数校验场景
- Repository 层：自定义查询方法必须有测试

---

## Git 提交规范

格式：`type(scope): 描述`（中文，不超过 50 字）

- `feat(order): 新增创建订单接口`
- `fix(order): 修复库存校验逻辑未处理负数的问题`
- `test(order): 补充 OrderService 边界条件测试`
- `refactor(common): 提取 ApiResponse 工具类`
- `docs(api): 更新订单接口文档`

---

## 禁止事项

- 禁止 `System.out.println` 残留
- 禁止注释掉的代码提交（删除即可，git 有历史）
- 禁止硬编码密码/密钥（用 `application.yml` + 环境变量）
- 禁止空 catch：`catch (Exception e) {}`
- 禁止在 catch 中只 `e.printStackTrace()`，必须用 log.error
- 禁止 Service 依赖 `HttpServletRequest` 等 Web 层对象
- 禁止在 Repository 写业务逻辑
- 禁止 `@Transactional` 注解在 Controller 上
- 禁止返回 Entity 类给前端（必须转 DTO）
