# 编码规范

## 通用原则

1. **简单优先**：三行重复好过一次过早抽象
2. **不求未来**：不为"可能"的需求写代码
3. **先读后写**：修改文件前必须读取当前内容
4. **单一职责**：每次提交只做一件事

## 命名规范

- 文件：kebab-case（`user-profile.tsx`）
- 组件：PascalCase（`UserProfile`）
- 函数/变量：camelCase（`getUserById`）
- 常量：UPPER_SNAKE_CASE（`MAX_RETRY_COUNT`）
- 类型/接口：PascalCase，接口不加 I 前缀

## 代码结构

### 组件
```tsx
// 1. imports
// 2. types
// 3. component
// 4. exports
```

### 函数
- 单一职责，不超过 30 行
- 参数不超过 3 个，超过用对象
- 避免嵌套超过 3 层

## 测试规范

- 单元测试覆盖所有公开 API
- 测试文件与源文件同目录或 tests/unit/ 下
- 测试命名：`describe('模块名', () => { it('应做什么', () => {}) })`
- TDD：先写测试，确认失败，再写实现

## Git 规范

### Commit Message
格式：`[#AI commit#][Claude Code]type(scope): 描述`
- type: feat / fix / refactor / docs / test / chore / style / perf / build / ci / revert
- scope: 影响模块
- 描述：中文，≤50字，说明做了什么及为什么

## 禁止事项

- 禁止 console.log 残留
- 禁止注释掉的代码
- 禁止硬编码敏感信息
- 禁止不做错误处理的异步调用