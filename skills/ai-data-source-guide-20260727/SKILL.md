---
description: 指导AI知识摄入的两种路径：预训练用海量公开数据(Common Crawl/GitHub/arXiv)，RAG用私有文档和指定数据源。涉及数据集平台(Kaggle/HuggingFace/OpenDataLab)、学术库(CNKI/Zenodo)、中文语料等。当用户需要给AI补充知识、做RAG检索增强、训练领域模型或数据收集时触发。
name: ai-data-source-guide-20260727
---

---
name: ai-data-source-guide-20260727
description: 指导AI知识摄入的两种路径：预训练用海量公开数据(Common Crawl/GitHub/arXiv)，RAG用私有文档和指定数据源。涉及数据集平台(Kaggle/HuggingFace/OpenDataLab)、学术库(CNKI/Zenodo)、中文语料等。当用户需要给AI补充知识、做RAG检索增强、训练领域模型或数据收集时触发。
---

# AI Knowledge Ingestion Guide

## 核心原则

给 AI"喂"知识分两条路，先想清楚是哪种：

1. **预训练通用模型** — 要海量、多样、高质量
2. **RAG 构建专属知识库** — 要精准、权威、强相关

---

## 场景一：预训练大模型（从零开始）

目标：学习语言结构和世界知识

**数据源：**

| 类别 | 来源 | 规模 |
|------|------|------|
| 网络文本 | Common Crawl → C4 / The Pile / OpenWebText | 3000亿+网页, 60亿文档, ~10PB |
| 书籍 | BookCorpus | - |
| 学术论文 | arXiv, PubMed | - |
| 代码 | GitHub | - |
| 综合平台 | Hugging Face Datasets, OpenDataLab | 一站式 |

---

## 场景二：RAG 构建专属知识库

目标：精准、权威、场景相关

**数据源：**

- **自有数据** — PDF, Word, Confluence, Salesforce 等企业系统
- **特定网站** — 指定域名或 URL
- **开放 API** — Twitter API, News API（结构化实时数据）
- **权威数据库** — Data.gov, Caselaw Access Project

---

## 高质量数据平台汇总

### 通用平台
- **Kaggle Datasets** — 数百万数据集
- **Google Dataset Search** — 跨仓库搜索
- **UCI ML Repository** — 经典教学数据
- **Papers with Code** — 论文关联数据

### 学术研究
- **Zenodo** — CERN支持
- **Figshare** — 研究成果分享
- **OpenML** — 可复现研究

### 专业领域
- **ImageNet** — 图像分类
- **COCO** — 目标检测
- **Open Images** — 超大规模标注

### 中文 & 多语言
- 国内平台：阿里云天池、百度 AI Studio、DataFountain
- 聚合平台：HyperAI超神经、遇见数据集搜索
- 高质量语料：Ultra-FineWeb-L3（6000亿 Token）、万卷·丝路

---

## 获取方式优先级

1. 有官方 API → 优先调用
2. 无 API → 爬虫抓取（遵守 robots.txt）
3. 高质量数据 → 购买或授权

## 决策流程

```
明确需求
├─ 通用能力？ → 预训练 → Common Crawl + GitHub + arXiv
└─ 专业知识？ → RAG → 自有文档 + 指定URL + 行业数据库
```