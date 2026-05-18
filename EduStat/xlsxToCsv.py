# AI辅助参考：Codex（基于 ChatGPT 5.4），2026-03
# 用途：XLS/XLSX 转 CSV 脚本生成
# 说明：脚本基础版本由 AI 辅助生成，后续已结合项目导入流程进行人工调整
import pandas as pd
import sys
import os

def convert_excel_to_csv(input_file, output_file):
    """
    将Excel文件转换为CSV格式
    支持 .xlsx, .xls, .xlsm 等格式
    """
    try:
        print("🚀 开始转换 Excel 到 CSV...")
        
        # 获取文件扩展名
        file_ext = os.path.splitext(input_file)[1].lower()
        
        # 根据文件扩展名选择引擎
        if file_ext == '.xlsx':
            # .xlsx 文件使用 openpyxl
            df = pd.read_excel(input_file, engine='openpyxl')
            engine_used = 'openpyxl'
        elif file_ext == '.xls':
            # 旧的 .xls 文件使用 xlrd
            df = pd.read_excel(input_file, engine='xlrd')
            engine_used = 'xlrd'
        elif file_ext == '.xlsm':
            # 启用宏的Excel文件
            df = pd.read_excel(input_file, engine='openpyxl')
            engine_used = 'openpyxl'
        else:
            # 尝试自动检测
            try:
                df = pd.read_excel(input_file)
                engine_used = 'auto'
            except:
                # 如果自动检测失败，尝试常用引擎
                try:
                    df = pd.read_excel(input_file, engine='openpyxl')
                    engine_used = 'openpyxl'
                except:
                    df = pd.read_excel(input_file, engine='xlrd')
                    engine_used = 'xlrd'
        
        print(f"📊 数据: {len(df)} 行, {len(df.columns)} 列")
        print(f"⚙️ 使用的引擎: {engine_used}")
        
        # 显示前几行数据（调试用）
        print("\n📋 数据预览（前3行）:")
        print(df.head(3))
        
        # 保存为 CSV（使用 utf-8-sig 编码，Excel 可以正确打开）
        df.to_csv(output_file, index=False, encoding='utf-8-sig')
        
        print(f"\n✅ 转换成功！")
        print(f"📁 输入文件: {os.path.abspath(input_file)}")
        print(f"📁 输出文件: {os.path.abspath(output_file)}")
        print(f"📏 文件大小: {os.path.getsize(output_file) / 1024:.2f} KB")
        
        return True
        
    except ImportError as e:
        print(f"❌ 缺少必要的库: {e}")
        print("\n请安装必要的库:")
        print("  pip install pandas openpyxl xlrd")
        return False
        
    except Exception as e:
        print(f"❌ 转换失败: {e}")
        print("\n🔧 调试信息:")
        print(f"  - 输入文件: {input_file}")
        print(f"  - 输出文件: {output_file}")
        print(f"  - 文件是否存在: {os.path.exists(input_file)}")
        print(f"  - 文件大小: {os.path.getsize(input_file) / 1024:.2f} KB" if os.path.exists(input_file) else "  - 文件不存在")
        return False

def check_dependencies():
    """检查必要的库是否安装"""
    missing = []
    try:
        import pandas
    except ImportError:
        missing.append("pandas")
    
    try:
        import openpyxl
    except ImportError:
        missing.append("openpyxl")
    
    try:
        import xlrd
    except ImportError:
        missing.append("xlrd")
    
    if missing:
        print("❌ 缺少必要的库: " + ", ".join(missing))
        print("\n请安装:")
        print(f"  pip install {' '.join(missing)}")
        return False
    return True

if __name__ == "__main__":
    # 检查参数
    if len(sys.argv) < 3:
        print("❌ 缺少参数")
        print("\n📖 使用方法:")
        print("  python xlsxToCsv.py <输入文件> <输出文件>")
        print("\n📝 示例:")
        print("  python xlsxToCsv.py 数据.xlsx 结果.csv")
        print('  python xlsxToCsv.py "成绩单 2024.xlsx" "成绩单.csv"')
        print('  python xlsxToCsv.py "D:/data/测试文件.xls" "D:/data/输出.csv"')
        sys.exit(1)
    
    # 检查依赖
    if not check_dependencies():
        sys.exit(1)
    
    # 获取参数
    inputFile = sys.argv[1]
    outputFile = sys.argv[2]
    
    # 检查输入文件是否存在
    if not os.path.exists(inputFile):
        print(f"❌ 输入文件不存在: {inputFile}")
        print("\n请检查:")
        print("  1. 文件路径是否正确")
        print("  2. 文件名是否包含空格（需要用引号括起来）")
        print("  3. 是否有读取权限")
        sys.exit(1)
    
    # 执行转换
    success = convert_excel_to_csv(inputFile, outputFile)
    
    if not success:
        sys.exit(2)
