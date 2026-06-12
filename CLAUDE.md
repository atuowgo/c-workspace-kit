# C-Workspace-Kit

## 知识索引

- 架构：[.workspace/architecture.md](.workspace/architecture.md)
- 编码规范：[.workspace/coding-standards.md](.workspace/coding-standards.md)
- API 规范：[.workspace/api-specs.md](.workspace/api-specs.md)
- 组件地图：[.workspace/component-map.md](.workspace/component-map.md)
- 品质锚定：[.claude/memory/quality-vision.md](.claude/memory/quality-vision.md)
- 知识地图：[.claude/memory/knowledge-map.md](.claude/memory/knowledge-map.md)

## 工作流程

本项目使用 Harness Engineering 方法论，采用三阶段 Agent 协作模式：

```
/plan → /develop → /evaluate
```

- **/plan**：需求澄清 → PRD → 技术设计 → 开发计划
- **/develop**：逐任务 TDD 实现，每个任务自检通过后方可标记完成
- **/evaluate**：Rubric 四层评分（功能正确性 / 鲁棒性 / UI呈现 / 交互体验）

## 品质标准

所有代码必须通过 Evaluator 的评分阈值（综合 >= 0.80）方可合入。

## 注意事项

- 没有用户明确允许，不执行 git commit 或 push
- 每个 Agent 获得独立上下文，通过文件交接
- 先读文件再修改，禁止盲改