#!/bin/bash

# ver 2.0.1
# Dify 升級腳本
# date 2025/12/12

# 執行內容：
# 0. 掃描並選擇 Dify 部署目錄
# 1. 確認升級的版本
#    - fetch tags
#    - 取得最新版本號
#    - 提示用戶輸入 yes 或指定版本號 或 commit ID
#    - 驗證版本號 或 commit ID 格式與存在性
# 2. 檢測版本是否已在 GitHub 發布
#    - 若未發布，警告並詢問是否繼續
# 3. 切換到選擇的版本
# 4. 關閉服務
# 5. 確認當前 docker-compose 檔案是否正常
# 6. 創建備份
# 7. 將當前設定檔標記為 old
# 8. 更新 nginx 與 ssrf_proxy 資料夾
# 9. 複製新設定檔至當前路徑
# 10. 要求用戶比對與更新設定檔
# 11. 刪除舊設定檔
# 12. 啟動服務

# ===== 步驟 0: 掃描並選擇 Dify 部署目錄 =====
echo "========================================"
echo "  Dify 升級腳本 v2.0.0"
echo "========================================"
echo ""

# 檢查是否以 root 或 sudo 執行，若是則警告
if [ "$EUID" -eq 0 ]; then
    echo "⚠ 警告：偵測到以 root/sudo 權限執行"
    echo "建議以一般用戶執行：bash update_script.sh"
    echo "腳本在需要時會自動向您索取 sudo 密碼"
    echo ""
    echo "輸入 yes 強制繼續，或按 Enter 取消："
    read -p "> " root_confirm
    if [[ "$root_confirm" != "yes" ]]; then
        echo "操作已取消"
        exit 1
    fi
fi

# 獲取腳本所在目錄（主目錄）
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "主目錄：$script_dir"
echo ""

# 儲存找到的 Dify 部署目錄
declare -a dify_dirs=()

echo "正在掃描 Dify 部署目錄..."
echo ""

# 搜尋子目錄中的 docker-compose.y(a)ml 文件（僅掃描1層深度）
while IFS= read -r compose_file; do
    # 檢查文件是否包含 "image: langgenius/dify-api:" 字段
    if grep -q "image: langgenius/dify-api:" "$compose_file" 2>/dev/null; then
        # 獲取該文件所在的目錄
        dir_path=$(dirname "$compose_file")
        # 獲取相對於主目錄的路徑
        rel_path=$(realpath --relative-to="$script_dir" "$dir_path")

        echo "✓ 找到 Dify 部署："
        echo "  路徑：$rel_path"
        echo "  檔案：$(basename "$compose_file")"

        # 嘗試提取版本號
        version=$(grep -oP "langgenius/dify-api:\K[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?" "$compose_file" | head -n1)
        if [ -n "$version" ]; then
            echo "  版本：$version"
        fi
        echo ""

        # 將目錄加入列表
        dify_dirs+=("$dir_path")
    fi
done < <(find "$script_dir" -maxdepth 2 -type f -name "docker-compose.yaml" 2>/dev/null)

# 檢查是否找到任何 Dify 部署目錄
if [ ${#dify_dirs[@]} -eq 0 ]; then
    echo "========================================"
    echo "❌ 未找到任何 Dify 部署目錄"
    echo "========================================"
    echo "請確認以下條件："
    echo "  1. 目錄中存在 docker-compose.yaml"
    echo "  2. 文件中包含 'image: langgenius/dify-api:' 字段"
    exit 1
fi

echo "========================================"
echo "找到 ${#dify_dirs[@]} 個 Dify 部署目錄"
echo "========================================"
echo ""

# 如果只有一個目錄，直接使用
if [ ${#dify_dirs[@]} -eq 1 ]; then
    selected_dir="${dify_dirs[0]}"
    rel_path=$(realpath --relative-to="$script_dir" "$selected_dir")
    echo "只有一個部署目錄，自動選擇："
    echo "  $rel_path"
    echo ""
else
    # 顯示選項讓用戶選擇
    echo "請選擇要升級的 Dify 部署目錄："
    echo ""

    for i in "${!dify_dirs[@]}"; do
        dir="${dify_dirs[$i]}"
        rel_path=$(realpath --relative-to="$script_dir" "$dir")

        # 提取版本號
        version=$(grep -oP "langgenius/dify-api:\K[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?" "$dir/docker-compose.yaml" | head -n1)

        num=$((i + 1))
        if [ -n "$version" ]; then
            echo "  [$num] $rel_path (版本: $version)"
        else
            echo "  [$num] $rel_path"
        fi
    done

    echo ""
    echo "  [0] 取消操作"
    echo ""

    # 循環直到獲得有效的選擇
    while true; do
        read -p "請輸入選項編號 [0-${#dify_dirs[@]}]: " choice

        # 檢查是否取消
        if [[ "$choice" == "0" ]]; then
            echo "操作已取消"
            exit 0
        fi

        # 檢查輸入是否為數字且在有效範圍內
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#dify_dirs[@]} ]; then
            index=$((choice - 1))
            selected_dir="${dify_dirs[$index]}"
            break
        else
            echo "❌ 無效的選項，請輸入 0-${#dify_dirs[@]} 之間的數字"
        fi
    done
fi

# 顯示選擇的目錄
echo ""
echo "========================================"
echo "已選擇目錄："
selected_rel_path=$(realpath --relative-to="$script_dir" "$selected_dir")
echo "  $selected_rel_path"
echo "========================================"
echo ""

# 切換到選擇的目錄
cd "$selected_dir" || {
    echo "❌ 錯誤：無法切換到目錄 $selected_dir"
    exit 1
}

echo "✓ 已切換到工作目錄：$selected_dir"
echo ""

# Dify Git 倉庫路徑（固定在主目錄下的 dify）
dify_repo_path="$script_dir/dify"

# 檢查 Git 倉庫是否存在
if [ ! -d "$dify_repo_path/.git" ]; then
    echo "❌ 錯誤：找不到 Dify Git 倉庫於 $dify_repo_path"
    exit 1
fi

echo "✓ Dify Git 倉庫：$dify_repo_path"
echo ""

# ===== 步驟 1: 選擇要升級的版本 =====
echo ""
echo "正在獲取最新版本資訊..."
git --work-tree="$dify_repo_path" --git-dir="$dify_repo_path/.git" fetch --tags

# 獲取最新版本號（僅正式版，不包含 beta、rc 等預發布版本）
latest_tag=$(git --work-tree="$dify_repo_path" --git-dir="$dify_repo_path/.git" tag -l | \
             grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | \
             sort -V | \
             tail -1)

if [ -z "$latest_tag" ]; then
    echo "錯誤：無法獲取最新版本號"
    exit 1
fi

echo "最新版本: $latest_tag"
echo ""
echo "是否要升級到最新版本 $latest_tag?"
echo "輸入 'yes' 使用最新版本"
echo "或輸入指定版本號 (例如: 1.10.0 或 1.10.1-fix.1)"
echo "或輸入 commit ID (例如: abc1234 或完整 SHA)"

# 循環直到獲得有效的版本號
while true; do
    read -p "> " user_input

    # 檢查是否輸入 yes
    if [[ "$user_input" == "yes" ]]; then
        target_version="$latest_tag"
        echo "選擇版本: $target_version"
        break
    fi

    # 檢查輸入是否符合版本號格式（TAG）
    if [[ "$user_input" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
        # 驗證版本號是否存在
        if git --work-tree="$dify_repo_path" --git-dir="$dify_repo_path/.git" tag -l | grep -q "^${user_input}$"; then
            target_version="$user_input"
            echo "選擇版本: $target_version"
            break
        else
            echo "錯誤：版本 $user_input 不存在"
            echo "請重新輸入 'yes'、版本號或 commit ID:"
            continue
        fi
    # 檢查是否為 commit ID 格式（7-40 個十六進制字符）
    elif [[ "$user_input" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
        # 驗證 commit 是否存在
        if git --work-tree="$dify_repo_path" --git-dir="$dify_repo_path/.git" cat-file -e "${user_input}^{commit}" 2>/dev/null; then
            target_version="$user_input"
            echo "選擇 commit: $target_version"
            break
        else
            echo "錯誤：commit $user_input 不存在"
            echo "請重新輸入 'yes'、版本號或有效的 commit ID:"
            continue
        fi
    else
        echo "錯誤：輸入格式不正確"
        echo "請輸入版本號 (如 1.10.0 或 1.10.1-fix.1) 或 commit ID (如 abc1234)"
        echo "請重新輸入 'yes'、版本號或 commit ID:"
        continue
    fi
done

# 檢查版本是否已在 GitHub 發布（僅對 TAG 版本號檢查）
if [[ "$target_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
    echo ""
    echo "檢查版本 $target_version 是否已在 GitHub 發布..."
    if curl -s -I "https://github.com/langgenius/dify/releases/tag/$target_version" | grep -q "HTTP/2 200"; then
        echo "✓ 版本 $target_version 已在 GitHub 正式發布"
    else
        echo ""
        echo "⚠ WARNING: 版本 $target_version 尚未在 GitHub 正式發布"
        echo "這可能是一個開發版本，建議謹慎使用"
        echo ""
        echo "是否要繼續使用此版本？(輸入 'yes' 繼續)"

        while true; do
            read -p "> " continue_input
            if [[ "$continue_input" == "yes" ]]; then
                echo "繼續使用版本 $target_version"
                break
            else
                echo "操作已取消"
                exit 0
            fi
        done
    fi
else
    # 如果是 commit ID，直接跳過 GitHub release 檢查
    echo ""
    echo "⚠ 注意：使用 commit ID ($target_version) 進行部署"
    echo "這是一個特定的開發版本，請確保您了解此 commit 的內容"
fi

# 切換到選擇的版本
echo ""
echo "正在切換到版本 $target_version..."
git --work-tree="$dify_repo_path" --git-dir="$dify_repo_path/.git" checkout "$target_version"

if [ $? -ne 0 ]; then
    echo "錯誤：切換版本失敗"
    exit 1
fi

echo "✓ 成功切換到版本 $target_version"
echo ""

echo ""
echo "===== 開始升級到版本 $target_version ====="
echo ""

# stop service first
docker compose down

# Docker image 名稱
image_name="langgenius/dify-api"
# 使用 grep 提取當前版本號（支持預發布版本如 1.10.1-fix.1）
current_version=$(grep -oP "$image_name:\K[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?" docker-compose.yaml | head -n1)

# 如果找不到版本號，則報錯並結束
if [ -z "$current_version" ]; then
    echo "找不到版本號，請確認 docker-compose.yaml 格式是否正確。"
    exit 1
fi

echo "當前版本: $current_version"

# 生成統一的時間戳
backup_timestamp=$(date +%Y%m%d-%H%M%S)

# 創建備份資料夾（如果已存在則加上時間戳）
backup_dir="backups/$current_version"
if [ -d "$backup_dir" ]; then
    # 目錄已存在，創建帶時間戳的新目錄
    backup_dir="backups/${current_version}-${backup_timestamp}"
    echo "備份目錄已存在，創建新目錄：$backup_dir"
fi

mkdir -p "$backup_dir"
echo "✓ 已成功創建備份資料夾：$backup_dir"

# 備份檔案至版本資料夾
echo "正在備份配置檔案..."
cp docker-compose.yaml "$backup_dir"
cp .env "$backup_dir"
echo "✓ 配置檔案備份完成"

echo "正在備份 volumes 資料夾（這可能需要一些時間）..."
# checkpoint 單位是 record（記錄），預設 1 record = 512 bytes
# 20000 records = 10 MB (每 10 MB 顯示一個點)
sudo tar --checkpoint=20000 --checkpoint-action=dot -czf "$backup_dir/volumes-${backup_timestamp}.tar.gz" volumes
echo "✓ volumes 備份完成"

# rename tag
mv docker-compose.yaml old_docker-compose.yaml
mv .env .old_env

# 來源有變更，目標路徑才更新
rsync -av --update "$dify_repo_path/docker/nginx/" ./nginx/
rsync -av --update "$dify_repo_path/docker/ssrf_proxy/" ./ssrf_proxy/

cp "$dify_repo_path/docker/docker-compose.yaml" .
cp "$dify_repo_path/docker/.env.example" .env


echo "請打開 vscode 對比以下檔案，並把要保留的設定移至新的設定檔"
echo ".old_env -> .env"
echo "old_docker-compose.yaml -> docker-compose.yaml"
echo ""
echo "當完成以上操作後，輸入 yes 來繼續..."

# 用戶輸入 yes 才繼續腳本
while true; do
    read -p "> " input
    if [[ "$input" == "yes" ]]; then
        echo "繼續執行..."
        break
    else
        echo "輸入無效，請重新輸入."
    fi
done

rm .old_env
rm old_docker-compose.yaml

docker compose up -d
sudo chown -R 1001:1001 volumes/app/storage/

