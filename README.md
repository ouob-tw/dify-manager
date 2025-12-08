# Dify Manager

Dify 部署管理工具，提供自動化的升級與備份功能。

## 版本

- **當前版本**: 2.0.0
- **更新日期**: 2025/12/08

## 功能特色

- 🔍 **自動掃描部署**：自動掃描並識別所有 Dify 部署目錄
- 📦 **多部署支持**：支持管理多個 Dify 部署實例
- 🔄 **靈活版本控制**：支持升級到最新版本、指定版本或特定 commit
- 💾 **完整備份**：自動備份配置文件和數據卷
- ✅ **版本驗證**：自動檢查版本是否在 GitHub 正式發布
- 🛡️ **安全保護**：升級前完整備份，支持快速回滾

## 目錄結構

```
dify-manager/
├── README.md              # 使用說明文檔
├── update_script.sh       # 升級腳本（主腳本）
├── dify/                  # Dify Git 倉庫（必需）
│   ├── .git/
│   └── docker/
│       ├── docker-compose.yaml
│       └── ...

├── docker/                # 部署實例 1（示例）
│   ├── docker-compose.yaml
│   ├── .env
│   ├── volumes/
│   ├── pgvector/
│   ├── nginx/
└── [其他部署目錄]/        # 部署實例 2, 3...（可選）
    ├── docker-compose.yaml
    ├── .env
    ├── volumes/
    ├── pgvector/
    ├── nginx/
    └── ssrf_proxy/
```

## 前置要求

### 系統要求

- Linux 操作系統
- Bash Shell
- sudo 權限（用於備份 volumes）

### 必需工具

確保系統已安裝以下工具：

```bash
# 檢查必需工具
command -v git >/dev/null 2>&1 || echo "需要安裝 git"
command -v docker >/dev/null 2>&1 || echo "需要安裝 docker"
command -v rsync >/dev/null 2>&1 || echo "需要安裝 rsync"
command -v realpath >/dev/null 2>&1 || echo "需要安裝 coreutils"
command -v curl >/dev/null 2>&1 || echo "需要安裝 curl"
```

## 安裝步驟

1. **下載管理工具**

```bash
git clone <repo-url> dify-manager
cd dify-manager
```

2. **設置 Dify Git 倉庫**

```bash
git clone https://github.com/langgenius/dify.git
```

3. **賦予執行權限**

```bash
chmod +x update_script.sh
```

4. **準備部署目錄**

確保你的 Dify 部署目錄包含所需部屬檔案

## 初次部屬

初次建立部署目錄時，需要從 Dify Git 倉庫手動複製以下目錄：

**必需複製的檔案與目錄**：

- docker-compose.yaml
- .env.example
- `volumes/` - 包含 sandbox 等初始配置
- `pgvector/` - PostgreSQL 向量擴展配置
- `nginx/` - Nginx 反向代理配置
- `ssrf_proxy/` - SSRF 防護代理配置

**複製方法**：

```bash
# 進入你的部署目錄
cd /path/to/dify-manager/docker

# 從 Dify Git 倉庫複製所需檔案與目錄
cp ../dify/docker/docker-compose.yaml .
cp ../dify/docker/.env.example .env
cp -r ../dify/docker/volumes ./
cp -r ../dify/docker/pgvector ./
cp -r ../dify/docker/nginx ./
cp -r ../dify/docker/ssrf_proxy ./
```

**注意**：

- 升級腳本會自動更新 `nginx/` 和 `ssrf_proxy/` 目錄
- 其餘設定檔源碼有變更後續需自行手動複製

## 使用方法

### 基本使用

在主目錄執行升級腳本：

```bash
./update_script.sh
```

### 升級流程

腳本會自動引導你完成以下步驟：

#### 步驟 1: 選擇部署目錄

```
找到 2 個 Dify 部署目錄
請選擇要升級的 Dify 部署目錄：

  [1] docker (版本: 1.10.1)
  [2] production (版本: 1.9.2)

  [0] 取消操作

請輸入選項編號 [0-2]:
```

- 輸入對應的編號選擇要升級的部署
- 如果只有一個部署，會自動選擇

#### 步驟 2: 選擇版本

```
最新版本: 1.10.2

是否要升級到最新版本 1.10.2?
輸入 'yes' 使用最新版本
或輸入指定版本號 (例如: 1.10.0 或 1.10.1-fix.1)
或輸入 commit ID (例如: abc1234 或完整 SHA)

>
```

**選項說明**：

- 輸入 `yes`：升級到最新版本
- 輸入版本號：升級到指定版本（如 `1.10.0` 或 `1.10.1-fix.1`）
- 輸入 commit ID：升級到特定 commit（如 `e83099e`）

#### 步驟 3: 版本驗證

腳本會自動檢查版本是否在 GitHub 正式發布：

- ✓ 已發布：繼續升級
- ⚠ 未發布：顯示警告，需確認是否繼續

#### 步驟 4: 自動備份

腳本會自動執行：

- 停止當前服務
- 備份配置文件（`.env`、`docker-compose.yaml`）
- 備份數據卷（`volumes/`）

備份位置：`backups/<版本號>/`

#### 步驟 5: 更新配置

腳本會提示你使用 VSCode 對比配置文件：

```
請打開 vscode 對比以下檔案，並把要保留的設定移至新的設定檔
.old_env -> .env
old_docker-compose.yaml -> docker-compose.yaml

當完成以上操作後，輸入 yes 來繼續...
```

**重要**：仔細對比新舊配置，確保重要設定不會丟失

#### 步驟 6: 啟動服務

確認配置無誤後，腳本會：

- 刪除舊配置文件
- 啟動新版本服務

## 詳細功能說明

### 自動掃描

- 掃描主目錄下 1 層深度的子目錄
- 自動識別包含 Dify 部署的目錄
- 檢測條件：
  - 存在 `docker-compose.yaml` 文件
  - 文件包含 `image: langgenius/dify-api:` 字段

### 版本管理

支持三種版本指定方式：

1. **最新版本**：輸入 `yes`
2. **指定版本**：輸入版本號（支持預發布版本）
   - 格式：`X.Y.Z` 或 `X.Y.Z-suffix`
   - 示例：`1.10.0`、`1.10.1-fix.1`
3. **特定 Commit**：輸入 commit ID
   - 格式：7-40 位十六進制字符
   - 示例：`e83099e`、`e83099e1234567890abcdef`

### 備份機制

**備份內容**：

- 配置文件：`docker-compose.yaml`、`.env`
- 數據卷：`volumes/` 目錄（壓縮為 tar.gz）

**備份位置**：

```
backups/
├── 1.10.0/                    # 版本號命名
│   ├── docker-compose.yaml
│   ├── .env
│   └── volumes-20251208-143022.tar.gz
└── 1.10.0-20251208-150530/    # 如果同版本多次備份
    ├── docker-compose.yaml
    ├── .env
    └── volumes-20251208-150530.tar.gz
```

### Git 倉庫管理

腳本會自動：

- 從 `$script_dir/dify` 獲取 Dify Git 倉庫
- 執行 `git fetch --tags` 獲取最新標籤
- 切換到指定版本/commit
- 複製新版本的配置文件和資源

## 注意事項

### ⚠️ 重要提醒

1. **備份檢查**：升級前確認備份完成
2. **配置對比**：務必仔細對比新舊配置文件
3. **服務停機**：升級期間服務會停止
4. **Sudo 權限**：備份 volumes 需要 sudo 權限
5. **文件格式**：僅支持 `docker-compose.yaml`（不支持 `.yml`）

### 常見問題

**Q: 如何回滾到舊版本？**

A: 使用備份的配置文件：

```bash
# 依據實際情況修改變量
deploy_dir=docker
backup_tag=1.10.0

cd /path/to/dify-manager/${deploy_dir}
docker compose down
cp backups/${backup_tag}/.env .
cp backups/${backup_tag}/docker-compose.yaml .
sudo tar -xzf backups/${backup_tag}/volumes-*.tar.gz
docker compose up -d
```

**Q: 找不到 Dify Git 倉庫怎麼辦？**

A: 確保在主目錄下有 `dify` 資料夾：

```bash
cd /path/to/dify-manager
git clone https://github.com/langgenius/dify.git
```

**Q: 掃描不到部署目錄？**

A: 檢查：

1. 配置文件名稱必須是 `docker-compose.yaml`（不是 `.yml`）
2. 文件中包含 `image: langgenius/dify-api:` 字段
3. 目錄深度不超過 1 層

**Q: 升級失敗怎麼辦？**

A: 檢查以下內容：

1. 查看錯誤訊息
2. 確認 Git 倉庫狀態
3. 檢查網路連接
4. 查看 Docker 日誌：`docker compose logs`

## 更新日誌

### v2.0.0 (2025/12/08)

**新功能**：

- ✨ 支持自動掃描多個 Dify 部署目錄
- ✨ 支持互動式選擇要升級的部署
- ✨ 優化 Git 倉庫路徑管理
- ✨ 改進版本檢測和提示信息

**改進**：

- 🔧 統一使用 `docker-compose.yaml` 格式
- 🔧 優化錯誤處理和用戶提示
- 🔧 改進備份機制

**修復**：

- 🐛 修正文件名不一致問題
- 🐛 修正相對路徑錯誤

### v1.0.0 (2025/11/29)

**初始版本**：

- ✅ 基本升級功能
- ✅ 配置備份功能
- ✅ 版本驗證功能

## 許可證

本項目採用 MIT 許可證。

## 貢獻

歡迎提交 Issue 和 Pull Request！

## 聯繫方式

如有問題或建議，請提交 Issue。
