#!/bin/bash

# 檢查參數
if [ $# -eq 0 ]; then
    SWAGGER_FILE="../docs/swagger.yaml"
    echo "使用默認 swagger 文件: $SWAGGER_FILE"
elif [ $# -eq 1 ]; then
    SWAGGER_FILE="$1"
    echo "使用指定的 swagger 文件: $SWAGGER_FILE"
else
    echo "使用方法: $0 [swagger_file]"
    echo "範例: $0 docs/swagger.yaml"
    exit 1
fi

# 檢查文件是否存在
if [ ! -f "$SWAGGER_FILE" ]; then
    echo "錯誤: 文件 '$SWAGGER_FILE' 不存在"
    exit 1
fi

# 查找所有 API endpoint 的首次出現日期
echo "查找所有 API endpoint 的首次出現日期..."
echo "========================================"

# 從 swagger.yaml 中提取所有 API endpoints
endpoints=$(grep "^  /" "$SWAGGER_FILE" | sed 's/:$//' | sed 's/^  //')

echo "找到以下 API endpoints："
echo "$endpoints"
echo ""
echo "========================================"
echo "開始查找每個 endpoint 的首次提交..."
echo ""

# 使用 git blame 來查找每一行的首次提交
echo "正在生成 git blame 信息..."
blame_file="swagger_blame.tmp"
git blame "$SWAGGER_FILE" > "$blame_file"

# 創建臨時文件來存儲 endpoint 到提交的映射
mapping_file="endpoint_mapping.tmp"

# 清空映射文件
> "$mapping_file"

# 讀取 blame 文件，為每個 endpoint 找到首次出現的提交
line_num=1
while IFS= read -r line; do
    # 提取 endpoint 行
    endpoint_in_line=$(echo "$line" | grep "^  /" | sed 's/:$//' | sed 's/^  //')
    if [ -n "$endpoint_in_line" ]; then
        # 從 blame 文件中找到對應的行
        blame_info=$(sed -n "${line_num}p" "$blame_file")
        commit_hash=$(echo "$blame_info" | awk '{print $1}')

        # 檢查是否已經記錄過這個 endpoint
        if ! grep -q "^$endpoint_in_line|" "$mapping_file"; then
            echo "$endpoint_in_line|$commit_hash" >> "$mapping_file"
        fi
    fi
    line_num=$((line_num + 1))
done < "$SWAGGER_FILE"

# 清理臨時文件
rm -f "$blame_file"

# 生成按日期排序的文件
sorted_file="endpoints_sorted_by_date.txt"
> "$sorted_file"

# 收集所有成功的 endpoint 和日期
while IFS= read -r endpoint; do
    if [ -z "$endpoint" ]; then
        continue
    fi

    # 從映射文件中獲取提交哈希
    commit_hash=$(grep "^$endpoint|" "$mapping_file" | cut -d'|' -f2)

    if [ -n "$commit_hash" ] && [ "$commit_hash" != "0000000000000000000000000000000000000000" ]; then
        # 獲取提交日期
        commit_date=$(git log -1 --pretty=format:"%ad" --date=short "$commit_hash" 2>/dev/null)
        if [ -n "$commit_date" ]; then
            echo "$commit_date $endpoint" >> "$sorted_file"
        fi
    fi
done <<< "$endpoints"

# 按日期排序
sort -k1 "$sorted_file" -o "$sorted_file"

# 清理臨時文件
rm -f "$mapping_file"

echo "========================================"
echo "生成 CSV 格式輸出..."
echo ""

# 創建 CSV 輸出文件
csv_file="endpoints_with_summary.csv"
echo "date,summary,api" > "$csv_file"

# 讀取排序後的文件，為每個 endpoint 添加 summary
while IFS=' ' read -r date api; do
    if [ -z "$date" ] || [ -z "$api" ]; then
        continue
    fi

    # 在 swagger.yaml 中查找對應的 summary
    summary=$(grep -A 20 "^  $api:" "$SWAGGER_FILE" | grep "      summary:" | head -1 | sed 's/      summary: //' | sed 's/^"//' | sed 's/"$//')

    # 如果還是沒有找到 summary，設為空
    if [ -z "$summary" ]; then
        summary="N/A"
    fi

    # 輸出到 CSV（處理可能的逗號和引號）
    escaped_summary=$(echo "$summary" | sed 's/"/""/g')
    echo "\"$date\",\"$escaped_summary\",\"$api\"" >> "$csv_file"

done < "endpoints_sorted_by_date.txt"

echo "CSV 文件已生成: $csv_file"
echo "總行數: $(wc -l < "$csv_file")"

echo ""
echo "========================================"
echo "生成每日統計 CSV..."

# 創建每日統計 CSV 文件
daily_csv_file="endpoints_daily_summary.csv"
echo "date,count,summary" > "$daily_csv_file"

# 使用臨時文件來統計數據（避免 bash 關聯數組兼容性問題）
temp_stats_file="temp_stats.txt"
> "$temp_stats_file"

# 讀取已生成的詳細 CSV
while IFS=',' read -r date summary api; do
    # 移除引號
    date=$(echo "$date" | sed 's/^"//' | sed 's/"$//')
    summary=$(echo "$summary" | sed 's/^"//' | sed 's/"$//')
    api=$(echo "$api" | sed 's/^"//' | sed 's/"$//')

    if [ "$date" = "date" ]; then
        continue  # 跳過標題行
    fi

    # 將數據寫入臨時文件
    echo "$date|$summary" >> "$temp_stats_file"
done < "$csv_file"

# 處理統計數據並生成最終的 CSV
temp_output_file="temp_output.txt"
> "$temp_output_file"

sort "$temp_stats_file" | awk -F'|' '
{
    date = $1
    summary = $2

    # 統計每個日期的 API 數量
    counts[date]++

    # 收集每個日期的 summaries（排除 N/A）
    if (summary != "N/A" && summary != "") {
        if (summaries[date] == "") {
            summaries[date] = summary
        } else {
            summaries[date] = summaries[date] "," summary
        }
    }
}
END {
    for (date in counts) {
        count = counts[date]
        summary = summaries[date]
        if (summary == "") summary = "N/A"

        # 處理 summary 中的特殊字符
        gsub(/"/, "\"\"", summary)

        print date "|" count "|" summary
    }
}
' | sort | awk -F'|' '{
    date = $1
    count = $2
    summary = $3

    print "\"" date "\"," count ",\"" summary "\"" >> "'"$temp_output_file"'"
}'

# 將處理後的數據追加到最終 CSV 文件
cat "$temp_output_file" >> "$daily_csv_file"

# 清理臨時文件
rm -f "$temp_stats_file" "$temp_output_file" "$sorted_file"

echo "每日統計 CSV 文件已生成: $daily_csv_file"
echo "總行數: $(wc -l < "$daily_csv_file")"

echo ""
echo "========================================"
echo "最終輸出文件："
echo "1. $csv_file - API endpoints 詳細信息"
echo "2. $daily_csv_file - 按日期聚合的統計"