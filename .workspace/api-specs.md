# API 规范

> 本文档记录项目的所有 API 接口定义，由 Planner 在技术设计阶段创建/更新。
> **Demo 写法**：以 RESTful JSON API 为基础模板。

---

## 通用约定

### Base URL

```
开发环境：http://localhost:8080
测试环境：https://api-test.example.com
生产环境：https://api.example.com
```

### 请求格式

- `Content-Type: application/json`
- 认证方式：`Authorization: Bearer <JWT Token>`（无鉴权接口除外）
- 编码：UTF-8

### 统一响应体

所有接口返回统一的 `ApiResponse<T>` 结构：

```json
{
  "code": 0,
  "message": "success",
  "data": {}
}
```

对应 Java 实现：

```java
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ApiResponse<T> {

    private int code;
    private String message;
    private T data;

    public static <T> ApiResponse<T> success(T data) {
        return ApiResponse.<T>builder()
            .code(0).message("success").data(data).build();
    }

    public static <T> ApiResponse<T> success() {
        return success(null);
    }

    public static ApiResponse<Void> error(int code, String message) {
        return ApiResponse.<Void>builder()
            .code(code).message(message).build();
    }
}
```

### 分页响应体

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "total": 100,
    "page": 1,
    "size": 20,
    "list": []
  }
}
```

对应 Java 实现：

```java
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PageResult<T> {
    private long total;
    private int page;
    private int size;
    private List<T> list;

    public static <T> PageResult<T> from(Page<T> page) {
        return PageResult.<T>builder()
            .total(page.getTotalElements())
            .page(page.getNumber() + 1)
            .size(page.getSize())
            .list(page.getContent())
            .build();
    }
}
```

### 错误码

| code | HTTP Status | 说明 |
|------|------------|------|
| 0 | 200/201 | 成功 |
| 400 | 400 | 参数错误（缺少必填、格式不对） |
| 401 | 401 | 未认证（Token 缺失或过期） |
| 403 | 403 | 无权限 |
| 404 | 404 | 资源不存在 |
| 409 | 409 | 资源冲突（重复提交、状态冲突） |
| 500 | 500 | 服务器内部错误 |

---

## 接口列表

> 以下为 Demo 接口，Planner 根据实际需求替换/扩充。

---

### POST /api/v1/orders — 创建订单

**请求头**：`Authorization: Bearer <token>`

**请求体**：
```json
{
  "productId": 1,
  "quantity": 2,
  "remark": "备注（可选）"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| productId | Long | ✅ | 商品 ID |
| quantity | Integer | ✅ | 数量，范围 [1, 999] |
| remark | String | ❌ | 备注，最长 200 字 |

**响应**：`201 Created`
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 1001,
    "productId": 1,
    "quantity": 2,
    "status": "PENDING",
    "createdAt": "2024-01-15T10:30:00"
  }
}
```

**异常响应**：
```json
// 400 参数错误
{ "code": 400, "message": "quantity: quantity 最小为 1", "data": null }

// 400 库存不足
{ "code": 400, "message": "库存不足", "data": null }
```

**Java Controller 示例**：
```java
@PostMapping
@ResponseStatus(HttpStatus.CREATED)
public ApiResponse<OrderDTO> createOrder(@Valid @RequestBody CreateOrderRequest request) {
    return ApiResponse.success(orderService.createOrder(request));
}
```

---

### GET /api/v1/orders/{id} — 查询订单详情

**路径参数**：
| 参数 | 类型 | 说明 |
|------|------|------|
| id | Long | 订单 ID |

**响应**：`200 OK`
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 1001,
    "productId": 1,
    "quantity": 2,
    "status": "PAID",
    "createdAt": "2024-01-15T10:30:00"
  }
}
```

**异常响应**：`404 Not Found`
```json
{ "code": 404, "message": "订单不存在", "data": null }
```

---

### GET /api/v1/orders — 分页查询订单列表

**请求参数（Query String）**：
| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| page | Integer | ❌ | 1 | 页码，从 1 开始 |
| size | Integer | ❌ | 20 | 每页条数，最大 100 |
| status | String | ❌ | - | 订单状态筛选 |

**响应**：`200 OK`
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "total": 58,
    "page": 1,
    "size": 20,
    "list": [
      { "id": 1001, "status": "PAID", "createdAt": "2024-01-15T10:30:00" }
    ]
  }
}
```

**Java Controller 示例**：
```java
@GetMapping
public ApiResponse<PageResult<OrderDTO>> listOrders(
        @RequestParam(defaultValue = "1") @Min(1) Integer page,
        @RequestParam(defaultValue = "20") @Min(1) @Max(100) Integer size,
        @RequestParam(required = false) OrderStatus status) {
    Pageable pageable = PageRequest.of(page - 1, size, Sort.by("createdAt").descending());
    return ApiResponse.success(orderService.listOrders(status, pageable));
}
```

---

### PUT /api/v1/orders/{id}/cancel — 取消订单

**路径参数**：`id`（Long，订单 ID）

**响应**：`200 OK`
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 1001,
    "status": "CANCELLED"
  }
}
```

**异常响应**：
```json
// 409 状态冲突（已支付的订单不能取消）
{ "code": 409, "message": "订单已支付，无法取消", "data": null }
```

---

## Swagger 集成

在 Spring Boot 项目中添加 Springdoc OpenAPI，自动生成 Swagger UI：

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.x.x</version>
</dependency>
```

```java
// Controller 上添加接口描述
@Operation(summary = "创建订单", description = "创建新订单，需要库存充足")
@ApiResponses({
    @ApiResponse(responseCode = "201", description = "创建成功"),
    @ApiResponse(responseCode = "400", description = "参数错误或库存不足")
})
@PostMapping
public ApiResponse<OrderDTO> createOrder(...) { ... }
```

访问地址：`http://localhost:8080/swagger-ui.html`

---

<!-- Planner：以下为新接口添加位置，按上述格式扩充 -->
