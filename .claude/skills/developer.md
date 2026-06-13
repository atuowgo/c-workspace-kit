# Developer — TDD 驱动开发

## 职责

按 `requirements/dev-plan.md` 逐任务实现，每个任务经过「红灯 → 绿灯 → 重构」的 TDD 循环，自检通过后方可标记完成。

---

## 前置条件（不满足则停止并告知用户）

- [ ] `requirements/dev-plan.md` 已存在且用户已确认
- [ ] `requirements/tech-design.md` 已存在
- [ ] 已读取 `.workspace/coding-standards.md`
- [ ] 已读取 `.workspace/architecture.md` 了解层次边界

---

## 工作流程

### 对每个任务的执行步骤

#### Step 1：读取上下文

```
必读：
- requirements/dev-plan.md        # 当前任务描述
- requirements/tech-design.md     # 数据模型/接口设计
- requirements/acceptance-criteria.md  # 验收标准
- 涉及修改的源文件（先读后改，严禁盲改）
```

#### Step 2：红灯 — 先写测试

按层次顺序写测试：

**数据层测试（Repository）**
```java
// Java + JUnit 5 + Spring Data JPA
@DataJpaTest
class OrderRepositoryTest {

    @Autowired
    private OrderRepository repository;

    @Test
    void findByUserId_withExistingOrders_returnsOrderList() {
        // Arrange
        Order order = Order.builder().userId(1L).status(OrderStatus.PENDING).build();
        repository.save(order);

        // Act
        List<Order> result = repository.findByUserId(1L);

        // Assert
        assertThat(result).hasSize(1);
        assertThat(result.get(0).getStatus()).isEqualTo(OrderStatus.PENDING);
    }

    @Test
    void findByUserId_withNoOrders_returnsEmptyList() {
        List<Order> result = repository.findByUserId(999L);
        assertThat(result).isEmpty();
    }
}
```

**业务层测试（Service）**
```java
// 纯单元测试，Mock 所有依赖
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock
    private OrderRepository orderRepository;

    @Mock
    private InventoryClient inventoryClient;

    @InjectMocks
    private OrderServiceImpl orderService;

    @Test
    void createOrder_withSufficientStock_returnsCreatedOrder() {
        // Arrange
        CreateOrderRequest request = CreateOrderRequest.builder()
            .productId(1L).quantity(2).build();
        given(inventoryClient.checkStock(1L, 2)).willReturn(true);
        given(orderRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

        // Act
        OrderDTO result = orderService.createOrder(request);

        // Assert
        assertThat(result.getStatus()).isEqualTo(OrderStatus.PENDING);
        then(orderRepository).should().save(any(Order.class));
    }

    @Test
    void createOrder_withInsufficientStock_throwsBusinessException() {
        given(inventoryClient.checkStock(anyLong(), anyInt())).willReturn(false);

        assertThatThrownBy(() -> orderService.createOrder(new CreateOrderRequest()))
            .isInstanceOf(BusinessException.class)
            .hasMessageContaining("库存不足");
    }
}
```

**接口层测试（Controller）**
```java
// MockMvc 集成测试
@WebMvcTest(OrderController.class)
class OrderControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private OrderService orderService;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void createOrder_withValidRequest_returns201() throws Exception {
        CreateOrderRequest request = new CreateOrderRequest(1L, 2);
        OrderDTO response = OrderDTO.builder().id(1L).status(OrderStatus.PENDING).build();
        given(orderService.createOrder(any())).willReturn(response);

        mockMvc.perform(post("/api/v1/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.data.id").value(1L))
            .andExpect(jsonPath("$.data.status").value("PENDING"));
    }

    @Test
    void createOrder_withMissingField_returns400() throws Exception {
        mockMvc.perform(post("/api/v1/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.code").value(400));
    }
}
```

运行测试，**确认失败**（红灯）后再进行下一步：

```bash
# Maven
mvn test -pl . -Dtest=OrderServiceTest -q

# Gradle
./gradlew test --tests "*.OrderServiceTest" --info
```

#### Step 3：绿灯 — 最小实现

用最小代码使测试通过，不过度设计：

```java
// Service 实现示例
@Service
@RequiredArgsConstructor
@Transactional
public class OrderServiceImpl implements OrderService {

    private final OrderRepository orderRepository;
    private final InventoryClient inventoryClient;

    @Override
    public OrderDTO createOrder(CreateOrderRequest request) {
        if (!inventoryClient.checkStock(request.getProductId(), request.getQuantity())) {
            throw new BusinessException(ErrorCode.INSUFFICIENT_STOCK);
        }
        Order order = Order.builder()
            .productId(request.getProductId())
            .quantity(request.getQuantity())
            .status(OrderStatus.PENDING)
            .build();
        return OrderDTO.from(orderRepository.save(order));
    }
}
```

运行测试，**确认全部通过**（绿灯）：

```bash
mvn test -q                  # Maven 全量
./gradlew test               # Gradle 全量
```

#### Step 4：重构

在测试保护下优化：
- 消除重复代码（抽取私有方法，不超过 3 行重复）
- 统一错误处理（使用 `@ControllerAdvice`）
- 检查方法是否超过 30 行
- 再次运行测试，**确认仍然全部通过**

#### Step 5：自检清单

完成每个任务前，逐项确认：

```
[ ] mvn test / ./gradlew test 全部通过，0 失败
[ ] mvn checkstyle:check 无 violation（或项目等效 lint）
[ ] 新增方法均有对应测试（正常路径 + 至少 1 个异常场景）
[ ] 未修改任务范围外的文件
[ ] 无 System.out.println / TODO 残留
[ ] 边界条件已覆盖（null、空集合、超长字符串、负数等）
[ ] 异常使用业务异常类，不吞 catch
[ ] 日志使用 @Slf4j + log.info/warn/error，不用 System.out
[ ] 事务边界在 Service 层，Controller 不含事务注解
```

#### Step 6：标记完成

在 `requirements/dev-plan.md` 中将任务标记为 `[x]`，并附一行实现要点：

```markdown
- [x] Task 2：业务层 — OrderService
  > 实现：createOrder 含库存检查，BusinessException 统一错误码，单元测试覆盖 3 场景
```

---

## 常用命令速查

| 操作 | Maven | Gradle |
|------|-------|--------|
| 编译 | `mvn compile -q` | `./gradlew classes` |
| 全量测试 | `mvn test -q` | `./gradlew test` |
| 单个测试类 | `mvn test -Dtest=FooTest` | `./gradlew test --tests "*.FooTest"` |
| 跳过测试打包 | `mvn package -DskipTests` | `./gradlew jar -x test` |
| 代码风格检查 | `mvn checkstyle:check` | `./gradlew checkstyleMain` |
| 覆盖率报告 | `mvn verify` (JaCoCo) | `./gradlew jacocoTestReport` |
| 启动应用 | `mvn spring-boot:run` | `./gradlew bootRun` |

---

## 执行规则

- **一次只处理一个任务**，不跨任务合并修改
- **修改前必须先读取文件**，严禁盲改
- **不修改与任务无关的文件**（包括格式调整）
- 遇到阻塞时，将问题记录到 `requirements/blockers.md`，格式：

```markdown
## [日期] Task N 阻塞

- 问题：...
- 影响：...
- 需要用户决策的内容：...
```

- 若当前任务依赖尚未完成的 Task，停止并告知用户

---

## 输出物

| 输出 | 说明 |
|------|------|
| 源文件（`src/main/`） | 按 dev-plan 逐任务实现 |
| 测试文件（`src/test/`） | 每个功能至少 1 个测试类 |
| `requirements/dev-plan.md` | 任务状态更新（[x]） |
| `requirements/blockers.md` | 阻塞记录（仅遇到阻塞时创建） |
