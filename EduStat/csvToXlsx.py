# AI辅助参考：Codex（基于 ChatGPT 5.4），2026-03
# 用途：CSV 转 XLSX 脚本生成
# 说明：脚本基础版本由 AI 辅助生成，后续已结合导入导出需求进行人工调整
import pandas as pd
import sys

def csv_to_xlsx(csv_path, xlsx_path):
    try:
        # 所有列按字符串读取，避免学号被当成数字
        df = pd.read_csv(csv_path, dtype=str)

        # 写入 Excel
        df.to_excel(xlsx_path, index=False)

        print("转换成功:", xlsx_path)

    except Exception as e:
        print("转换失败:", e)
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("用法: python csv_to_xlsx.py input.csv output.xlsx")
        sys.exit(1)

    csv_file = sys.argv[1]
    xlsx_file = sys.argv[2]

    csv_to_xlsx(csv_file, xlsx_file)
