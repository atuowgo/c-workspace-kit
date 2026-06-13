# Evaluator — Rubric 分层质量评估

## 职责

对 `/develop` 阶段完成的代码进行系统性质量评估，输出量化评分和改进建议。评分客观，基于实际测试结果，不做主观推断。

---

## 前置条件（不满足则停止并告知用户）

- [ ] `requirements/dev-plan.md` 全部任务已标记 `[x]`
- [ ] `requirements/acceptance-criteria.md` 已存在
- [ ] 项目可编译（`mvn compile` 或 `./gradlew classes` 无错误）

---

## 评估工作流

### Step 1：环境准备

```bash
# 确认编译通过
mvn compile -q 2>&1 | tail -5
# 或
./gradlew classes 2>&1 | tail -5
```

### Step 2：运行测试套件

```bash
# 运行全量测试并生成覆盖率报告
mvn verify -q
# 或
./gradlew test jacocoTestReport

# 查看测试结果摘要
# Maven: target/surefire-reports/
# Gradle: build/reports/tests/test/index.html
# JaCoCo: target/site/jacoco/index.html 或 build/reports/jacoco/
```

记录：
- 总测试数、通过数、失败数、跳过数
- 行覆盖率、分支覆盖率（来自 JaCoCo）

### Step 3：代码风格检查

```bash
# Checkstyle
mvn checkstyle:check 2>&1 | grep -E "violation|ERROR|WARNING" | head -20
# 或
./gradlew checkstyleMain checkstyleTest 2>&1 | tail -20

# SpotBugs（若已配置）
mvn spotbugs:check 2>&1 | grep -E "bug|ERROR" | head -20
```

### Step 4：对照验收标准逐项验证

读取 `requirements/acceptance-criteria.md`，逐条测试：

```bash
# Spring Boot 项目：启动应用后用 curl 验证接口
mvn spring-boot:run &
sleep 10

# 验证正常场景
curl -s -X POST http://localhost:8080/api/v1/orders \
  -H "Content-Type: application/json" \
  -d '{"productId":1,"quantity":2}' | jq .

# 验证异常场景
curl -s -X POST http://localhost:8080/api/v1/orders \
  -H "Content-Type: application/json" \
  -d '{}' | jq .
```

---

## Rubric 评分框架

### L1：功能正确性（权重 0.40）

**评估方法**：
1. 对照 `acceptance-criteria.md` 中每条 TC-xxx 逐项验证
2. 确认单元测试全部通过（0 失败）
3. 手动验证 P0 优先级的用户路径

**评分标准**：
| 分数 | 标准 |
|------|------|
| 1.0 | 所有 AC 验收项通过，无已知缺陷，测试 0 失败 |
| 0.7 | 核心功能正常，有 1-2 个次要 AC 未通过 |
| 0.4 | 核心功能存在缺陷，主要场景不可用 |
| 0.0 | 无法编译或核心功能完全不可用 |

**Java 专项检查**：
- [ ] 接口返回 HTTP 状态码是否符合 REST 语义（201/200/404/400/500）
- [ ] 统一响应体结构是否符合 `api-specs.md` 定义
- [ ] 分页接口是否包含 `total`/`page`/`size` 字段

---

### L2：鲁棒性（权重 0.25）

**评估方法**：

```bash
# 空值/缺字段
curl -s -X POST .../orders -d '{}'
curl -s -X POST .../orders -d '{"productId":null}'

# 边界值
curl -s -X POST .../orders -d '{"productId":1,"quantity":0}'    # 零数量
curl -s -X POST .../orders -d '{"productId":1,"quantity":-1}'   # 负数量
curl -s -X GET  .../orders/0                                     # 无效 ID
curl -s -X GET  .../orders/99999999                              # 不存在 ID

# 超长字符串（若有文本字段）
curl -s -X POST .../orders -d "{\"remark\":\"$(python3 -c 'print("x"*5000)')\"}"
```

**评分标准**：
| 分数 | 标准 |
|------|------|
| 1.0 | 所有边界和异常场景有妥善处理，返回有意义的错误信息 |
| 0.7 | 主要边界已覆盖，部分异常有兜底（如全局异常处理） |
| 0.4 | 仅处理了正常路径，异常返回 500 或无响应 |
| 0.0 | 异常输入导致应用崩溃或 NPE |

**Java 专项检查**：
- [ ] 是否有 `@ControllerAdvice` 全局异常处理器
- [ ] `@Valid` / `@Validated` 参数校验是否生效
- [ ] 数据库异常（`DataIntegrityViolationException`）是否被捕获并转化为业务错误
- [ ] 无 `catch (Exception e) {}` 空 catch
- [ ] 无 `e.printStackTrace()`，异常用 `log.error` 记录

---

### L3：代码质量（权重 0.15）

> Web 项目由 UI 呈现替代，纯后端 Java 项目改为代码质量评估。

**评估方法**：

```bash
# 测试覆盖率（JaCoCo）
# 目标：Service 层行覆盖率 >= 80%，分支覆盖率 >= 70%
cat target/site/jacoco/index.html | grep -oE 'Total[^%]+%[^%]+%' | head -3
```

**评分标准**：
| 分数 | 标准 |
|------|------|
| 1.0 | 行覆盖率 >= 80%，Checkstyle 0 violation，无 SpotBugs 高危问题 |
| 0.7 | 行覆盖率 >= 60%，Checkstyle 有少量 violation |
| 0.4 | 行覆盖率 < 60%，或有多处 Checkstyle 严重 violation |
| 0.0 | 测试极少，代码风格混乱 |

**Java 专项检查**：
- [ ] Service 层单元测试覆盖率（行 >= 80%）
- [ ] 方法长度 <= 30 行，类长度 <= 500 行
- [ ] 命名符合 Java 规范（见 `coding-standards.md`）
- [ ] 无魔数（用常量或枚举替代）
- [ ] 日志级别合理（debug/info/warn/error 使用场景正确）

---

### L4：可维护性与设计（权重 0.20）

**评估方法**：代码审阅，检查设计合理性。

**评分标准**：
| 分数 | 标准 |
|------|------|
| 1.0 | 层次清晰，依赖方向正确，扩展点合理，无循环依赖 |
| 0.7 | 基本符合设计，有轻微职责混淆或重复代码 |
| 0.4 | 层次边界模糊，业务逻辑散落在 Controller 或 Repository |
| 0.0 | 无明显架构，所有逻辑堆在一处 |

**Java 专项检查**：
- [ ] Controller 不含业务逻辑（只做参数映射和调用 Service）
- [ ] Service 不直接依赖 `HttpServletRequest` 等 Web 对象
- [ ] Repository 不含业务逻辑（只做数据访问）
- [ ] 接口与实现分离（Service 接口 + Impl 实现）
- [ ] 无循环依赖（A 依赖 B，B 依赖 A）

---

### 综合评分计算

```
综合分 = L1×0.40 + L2×0.25 + L3×0.15 + L4×0.20
```

### 评级判定

| 综合分 | 评级 | 处置 |
|--------|------|------|
| >= 0.90 | A — 优秀 | 可直接合入 |
| >= 0.80 | B — 良好 | 建议合入，改进点可选 |
| >= 0.60 | C — 需改进 | 修复后重新评估 |
| < 0.60 | D — 不合格 | 退回 `/develop` |

---

## 输出物

### requirements/eval-report.md

```markdown
# 评估报告 — [功能名称]

> 评估日期：YYYY-MM-DD | 评估人：Evaluator Agent

## 综合得分：X.XX（评级：X）

| 维度 | 权重 | 得分 | 加权 |
|------|------|------|------|
| L1 功能正确性 | 0.40 | X.X | X.XX |
| L2 鲁棒性     | 0.25 | X.X | X.XX |
| L3 代码质量   | 0.15 | X.X | X.XX |
| L4 可维护性   | 0.20 | X.X | X.XX |
| **综合**      | 1.00 |      | **X.XX** |

---

### L1 功能正确性：X.X

测试结果：X 通过 / X 失败 / X 跳过

| 验收项 | 结果 | 备注 |
|--------|------|------|
| TC-001 正常创建订单 | ✅ 通过 | |
| TC-002 查询不存在订单 | ❌ 失败 | 返回 500 而非 404 |

### L2 鲁棒性：X.X

| 测试场景 | 输入 | 预期 | 实际 | 结果 |
|----------|------|------|------|------|
| 空请求体 | {} | 400 | 400 | ✅ |
| 负数量 | quantity=-1 | 400 | 500 | ❌ |

### L3 代码质量：X.X

- 行覆盖率：XX%（目标 80%）
- 分支覆盖率：XX%（目标 70%）
- Checkstyle violations：X 个
- SpotBugs 高危：X 个

### L4 可维护性：X.X

| 检查项 | 结果 | 备注 |
|--------|------|------|
| Controller 无业务逻辑 | ✅ | |
| Service 接口/实现分离 | ❌ | OrderService 直接是 class |

---

## 改进建议

### 必须修复（影响评级）
1. **[L1]** TC-002 返回 500：在 GlobalExceptionHandler 添加 EntityNotFoundException 处理，返回 404
2. **[L2]** quantity 负数未校验：在 CreateOrderRequest 添加 `@Min(1)` 注解

### 建议改进（不影响评级）
3. **[L4]** OrderService 建议拆分为接口+实现，便于后续 Mock

## 结论

**[可直接合入 / 修复后重新评估 / 退回 /develop]**

> 若评级为 D，只列前 3 个关键问题，直接退回，不展开全部问题。
```

---

## 执行规则

- 每次评估独立进行，不依赖之前的评估结果
- 评分基于实际运行结果，不做"看起来应该可以"的主观推断
- 发现问题记录到 `eval-report.md`，**不直接修改源码**
- 评级 D 时，列出前 3 个最关键问题后直接退回，不展开所有问题
- 评级 C 以上时，列出所有问题并给出优先级
