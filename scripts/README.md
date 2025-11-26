# API Endpoint Git Tracker

<p align="left">
  <img src="https://img.shields.io/github/last-commit/detectviz/api-endpoint-git-tracker?style=flat">
  <img src="https://img.shields.io/github/languages/top/detectviz/api-endpoint-git-tracker?style=flat">
  <img src="https://img.shields.io/github/stars/detectviz/api-endpoint-git-tracker?style=flat">
  <img src="https://img.shields.io/badge/status-active-brightgreen?style=flat">
</p>

這個工具用於分析 Swagger/OpenAPI 文件，追蹤所有 API endpoint 的首次出現日期，並生成詳細的統計報告。

## 功能特點

- **自動化分析**: 從 Swagger/OpenAPI 文件中提取所有 API endpoints
- **日期追蹤**: 使用 git blame 找到每個 API endpoint 的首次提交日期
- **統計匯總**: 生成按日期聚合的統計數據
- **多格式輸出**: 同時生成詳細和摘要的 CSV 文件
- **工具整合**: 支持與 [api-endpoint-git-tracker-go](https://github.com/detectviz/api-endpoint-git-tracker-go) 配合提供即時可視化，以及 Grafana Infinity Plugin 直接讀取數據

## 安裝需求

- bash shell
- git
- grep, sed, awk 等標準 Unix 工具

## 基本指令測試

如果專案維護 `openapi.yaml` 或 `swagger.yaml` 文件，可以直接使用 Git 命令比較歷史版本：

```bash
# 搜尋特定 API 路徑的歷史變更
git log -S "path: /api/v1/orders" docs/swagger.yaml

# 查看特定 API endpoint 的變更歷史
git log -p --follow -S "/api/v1/orders" docs/swagger.yaml

# 比較兩個版本之間的差異
git diff HEAD~1 HEAD -- docs/swagger.yaml

# 統計 API endpoint 的變更次數
git log --oneline -- docs/swagger.yaml | wc -l

# 查找新增的 API endpoint
git log --diff-filter=A --name-only --oneline docs/swagger.yaml
```

## 使用方法

### 基本用法（使用默認文件）

```bash
./analyze_api_endpoints.sh
```

這會自動使用 `../docs/swagger.yaml` 作為輸入文件（相對於腳本所在目錄）。

### 指定自定義文件

```bash
./analyze_api_endpoints.sh path/to/your/swagger.yaml
```

### 範例

```bash
# 使用默認 swagger 文件
./analyze_api_endpoints.sh

# 使用自定義路徑
./analyze_api_endpoints.sh docs/api.yaml

# 使用絕對路徑
./analyze_api_endpoints.sh /path/to/project/swagger.yaml
```

## 輸出文件

腳本會生成兩個主要的 CSV 文件：

### 1. `endpoints_with_summary.csv`

包含每個 API endpoint 的詳細信息：

```csv
date,summary,api
"2022-06-10","取得資源群組 (ResourceGroup)","/get-server-group"
"2022-06-10","N/A","/get-system-metric"
"2023-05-22","Web 上傳檔案","/user/file-upload"
```

### 2. `endpoints_daily_summary.csv`

按日期聚合的統計信息：

```csv
date,count,summary
"2022-06-10",2,"取得資源群組 (ResourceGroup)"
"2023-05-22",2,"Web 上傳檔案,Get Grafana URL"
```

## 工作原理

1. **提取 Endpoints**: 從 Swagger 文件中解析所有 API 路徑
2. **查找提交歷史**: 使用 `git blame` 找到每個 endpoint 的首次出現
3. **生成詳細報告**: 為每個 endpoint 添加摘要信息
4. **聚合統計**: 按日期統計 API 數量和摘要

## 錯誤處理

- 如果指定的文件不存在，腳本會顯示錯誤並退出
- 如果 git 倉庫不存在或無法訪問，會相應報錯
- 對於沒有摘要的 API，會標記為 "N/A"

## 應用場景

- **API 發展趨勢分析**: 了解不同時期 API 的開發情況
- **文檔維護**: 追蹤 API 的歷史變更
- **專案統計**: 生成 API 相關的統計報告
- **代碼審計**: 分析 API 的發展歷史

## 技術細節

- 使用 `git blame` 進行精確的行級歷史追蹤
- 支持標準的 Swagger/OpenAPI YAML 格式
- 兼容性考慮：避免使用 bash 關聯數組，改用文件處理
- 錯誤恢復：對缺失的摘要信息進行適當處理

---

*這個工具幫助開發團隊更好地理解 API 的演進歷史，為專案管理和決策提供數據支持。*
