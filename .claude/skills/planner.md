# Planner — 需求分析与计划制定

## 职责

将模糊的用户需求转化为结构化、可执行的开发计划。

## 工作流程

### 阶段1：需求理解
1. 阅读 CLAUDE.md 加载知识索引和品质锚定
2. 阅读 .workspace/ 下的架构、编码规范、API规范、组件地图
3. 阅读 .claude/memory/knowledge-map.md 了解现有模块
4. 若需求描述不清晰，主动向用户提问澄清

### 阶段2：需求澄清（必须确认项）
- [ ] 功能边界：做什么 / 不做什么
- [ ] 用户场景：谁在什么情况下使用
- [ ] 非功能需求：性能、安全、兼容性
- [ ] 与现有系统的关系：新增 / 修改 / 替换

### 阶段3：编写需求文档

按顺序输出以下文件到 requirements/ 目录：

#### PRD（requirements/prd.md）
```markdown
# PRD — 产品需求文档

## 背景与目标
## 用户故事
## 功能清单
## 非功能需求
## 验收标准
```

#### 技术设计（requirements/tech-design.md）
```markdown
# 技术设计

## 架构概览
## 数据模型
## 接口设计
## 关键流程
## 技术选型与理由
```

#### 开发计划（requirements/dev-plan.md）
```markdown
# 开发计划

## 任务拆分
- [ ] Task 1: ...
- [ ] Task 2: ...
## 依赖关系
## 预估工作量
```

#### 验收用例（requirements/acceptance-criteria.md）
```markdown
# 验收用例

## 功能验收
## 异常场景验收
## E2E 测试用例
```

### 阶段4：用户审核
- 将所有文档呈现给用户
- 等待用户确认后方可进入 /develop 阶段
- 用户提出修改意见时，仅修改对应文档

## 输出物清单
| 文件 | 用途 |
|------|------|
| requirements/prd.md | 产品需求 |
| requirements/tech-design.md | 技术方案 |
| requirements/dev-plan.md | 任务拆分 |
| requirements/acceptance-criteria.md | 验收标准 |