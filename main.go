// Package main 實現一個簡單的 HTTP 服務器，用於提供 API endpoints 的 CSV 數據。
//
// 服務器提供兩個端點：
//   - /api_endpoints_with_summary.csv: 提供帶摘要的 API endpoints 數據
//   - /api_endpoints_daily_summary.csv: 提供按日期聚合的統計數據
//
// 用於與 Grafana Infinity Plugin 整合，實現 API endpoint 追蹤的可視化。
package main

import (
	"encoding/csv"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
)

// setCSVHeaders 設置 HTTP 響應頭為 CSV 格式
func setCSVHeaders(w http.ResponseWriter, filename string) {
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%s", filename))
}

// main 啟動 HTTP 服務器，提供 CSV 數據 API 端點。
func main() {
	// 設置 API endpoints 數據端點，包含摘要信息
	http.HandleFunc("/api_endpoints_with_summary.csv", func(w http.ResponseWriter, r *http.Request) {
		// 設置響應頭為 CSV
		setCSVHeaders(w, "api_endpoints_with_summary.csv")

		// 讀取原始 CSV 文件
		csvPath := "api_endpoints_with_summary.csv"
		file, err := os.Open(csvPath)
		if err != nil {
			log.Printf("Error opening file %s: %v", csvPath, err)
			http.Error(w, fmt.Sprintf("Unable to access %s file", csvPath), http.StatusInternalServerError)
			return
		}
		defer file.Close()

		// 讀取 CSV 數據
		reader := csv.NewReader(file)
		records, err := reader.ReadAll()
		if err != nil {
			log.Printf("Error reading CSV file %s: %v", csvPath, err)
			http.Error(w, "Error processing CSV data", http.StatusInternalServerError)
			return
		}

		// 創建 CSV writer
		writer := csv.NewWriter(w)
		defer writer.Flush()

		// 寫入標題行，按用戶要求的欄位名稱
		writer.Write([]string{"Time", "Field", "Value"})

		// 處理每一行數據
		for i, record := range records {
			if i == 0 {
				// 跳過原始標題行
				continue
			}

			if len(record) >= 3 {
				// 映射欄位：date → Time, api → Field, summary → Value
				time := strings.Trim(record[0], "\"")
				field := strings.Trim(record[2], "\"")
				value := strings.Trim(record[1], "\"")

				writer.Write([]string{time, field, value})
			}
		}
	})

	// 每日統計 API 端點 - 返回聚合的 CSV 數據
	http.HandleFunc("/api_endpoints_daily_summary.csv", func(w http.ResponseWriter, r *http.Request) {
		// 設置響應頭為 CSV
		setCSVHeaders(w, "api_endpoints_daily_summary.csv")

		// 直接返回 CSV 文件內容
		csvPath := "api_endpoints_daily_summary.csv"
		if _, err := os.Stat(csvPath); os.IsNotExist(err) {
			log.Printf("File not found: %s", csvPath)
			http.Error(w, fmt.Sprintf("Unable to access %s file", csvPath), http.StatusInternalServerError)
			return
		}

		http.ServeFile(w, r, csvPath)
	})

	fmt.Println("Server starting on http://localhost:8005")
	fmt.Println("CSV endpoint: http://localhost:8005/api_endpoints_with_summary.csv")
	fmt.Println("Daily summary endpoint: http://localhost:8005/api_endpoints_daily_summary.csv")

	// 啟動 HTTP 服務器並阻塞運行
	log.Fatal(http.ListenAndServe(":8005", nil))
}
