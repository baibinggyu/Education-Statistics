#!/usr/bin/env python3
# AI辅助参考：Codex（基于 ChatGPT 5.4），2026-03
# 用途：测试数据 Excel 样例生成
# 说明：脚本基础版本由 AI 辅助生成，后续已结合项目测试场景进行人工调整
# generate_test_xlsx.py

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random

def generate_test_xlsx(filename="测试数据.xlsx"):
    """
    生成测试用的 Excel 文件
    """
    print(f"正在生成测试文件: {filename}")
    
    # 设置随机种子，确保每次生成的数据一致
    random.seed(42)
    np.random.seed(42)
    
    # 1. 学生成绩表
    students_data = {
        '学号': [f'202400{str(i).zfill(3)}' for i in range(1, 21)],
        '姓名': ['张', '李', '王', '刘', '陈', '赵', '孙', '周', '吴', '郑',
                '冯', '褚', '卫', '蒋', '沈', '韩', '杨', '朱', '秦', '许'],
        '语文': np.random.randint(60, 100, 20),
        '数学': np.random.randint(55, 100, 20),
        '英语': np.random.randint(65, 100, 20),
        '班级': random.choices(['一班', '二班', '三班'], k=20)
    }
    
    # 计算总分
    students_df = pd.DataFrame(students_data)
    students_df['总分'] = students_df['语文'] + students_df['数学'] + students_df['英语']
    students_df['平均分'] = (students_df['总分'] / 3).round(1)
    
    # 2. 销售数据表
    products = ['笔记本电脑', '手机', '平板电脑', '显示器', '键盘', '鼠标', '耳机']
    dates = [datetime.now() - timedelta(days=x) for x in range(30)]
    
    sales_data = {
        '日期': [d.strftime('%Y-%m-%d') for d in dates],
        '产品': random.choices(products, k=30),
        '销量': np.random.randint(5, 50, 30),
        '单价': np.random.choice([3999, 4999, 5999, 1999, 2999, 899, 299, 199], 30),
        '销售额': [0] * 30  # 先占位
    }
    
    sales_df = pd.DataFrame(sales_data)
    sales_df['销售额'] = sales_df['销量'] * sales_df['单价']
    
    # 3. 员工信息表
    depts = ['技术部', '市场部', '销售部', '人事部', '财务部', '行政部']
    positions = {
        '技术部': ['工程师', '架构师', '技术经理'],
        '市场部': ['专员', '主管', '经理'],
        '销售部': ['销售代表', '销售主管', '销售经理'],
        '人事部': ['专员', '主管', '经理'],
        '财务部': ['会计', '财务主管', '财务经理'],
        '行政部': ['助理', '主管', '经理']
    }
    
    employee_data = {
        '工号': [f'EMP{str(i).zfill(4)}' for i in range(1, 16)],
        '姓名': ['张三', '李四', '王五', '赵六', '钱七', '孙八', '周九', '吴十',
                '郑一一', '王十二', '李十三', '张十四', '刘十五', '陈十六', '林十七'],
        '部门': random.choices(depts, k=15),
        '职位': [None] * 15,
        '入职日期': [datetime.now() - timedelta(days=random.randint(100, 1000)) for _ in range(15)],
        '月薪': np.random.randint(5000, 30000, 15)
    }
    
    # 根据部门设置职位
    for i, dept in enumerate(employee_data['部门']):
        employee_data['职位'][i] = random.choice(positions[dept])
    
    employee_df = pd.DataFrame(employee_data)
    employee_df['入职日期'] = employee_df['入职日期'].dt.strftime('%Y-%m-%d')
    
    # 4. 创建多个 sheet 的 Excel 文件
    with pd.ExcelWriter(filename, engine='openpyxl') as writer:
        students_df.to_excel(writer, sheet_name='学生成绩', index=False)
        sales_df.to_excel(writer, sheet_name='销售数据', index=False)
        employee_df.to_excel(writer, sheet_name='员工信息', index=False)
    
    print(f"✅ 测试文件生成成功: {filename}")
    print(f"📊 包含工作表:")
    print(f"   - 学生成绩: {len(students_df)} 行, {len(students_df.columns)} 列")
    print(f"   - 销售数据: {len(sales_df)} 行, {len(sales_df.columns)} 列")
    print(f"   - 员工信息: {len(employee_df)} 行, {len(employee_df.columns)} 列")

def generate_simple_test(filename="简单测试.xlsx"):
    """
    生成简单的测试文件（只有少量数据）
    """
    data = {
        '姓名': ['张三', '李四', '王五', '赵六', '孙七'],
        '年龄': [25, 30, 28, 35, 32],
        '城市': ['北京', '上海', '广州', '深圳', '成都'],
        '分数': [85, 92, 78, 88, 95]
    }
    
    df = pd.DataFrame(data)
    df.to_excel(filename, index=False)
    print(f"✅ 简单测试文件生成: {filename}")
    print(f"📊 数据: {len(df)} 行, {len(df.columns)} 列")

def generate_large_test(filename="大数据测试.xlsx", rows=1000):
    """
    生成大数据量的测试文件
    """
    print(f"正在生成大型测试文件 ({rows} 行)...")
    
    data = {
        'ID': range(1, rows + 1),
        '名称': [f'Item_{i}' for i in range(1, rows + 1)],
        '类别': random.choices(['A类', 'B类', 'C类', 'D类'], k=rows),
        '数量': np.random.randint(1, 1000, rows),
        '单价': np.random.uniform(10, 1000, rows).round(2),
        '日期': [datetime.now() - timedelta(days=random.randint(0, 365)) for _ in range(rows)]
    }
    
    df = pd.DataFrame(data)
    df['总价'] = (df['数量'] * df['单价']).round(2)
    df['日期'] = df['日期'].dt.strftime('%Y-%m-%d')
    
    df.to_excel(filename, index=False)
    print(f"✅ 大型测试文件生成: {filename}")
    print(f"📊 数据: {len(df)} 行, {len(df.columns)} 列")

if __name__ == "__main__":
    print("=" * 50)
    print("📋 Excel 测试文件生成工具")
    print("=" * 50)
    
    # 生成各种测试文件
    generate_test_xlsx("测试数据.xlsx")
    print("-" * 50)
    
    generate_simple_test("简单测试.xlsx")
    print("-" * 50)
    
    generate_large_test("大数据测试.xlsx", 500)  # 生成500行数据
    print("-" * 50)
    
    print("\n✅ 所有测试文件生成完成！")
    print("\n可用文件:")
    print("  1. 测试数据.xlsx (包含3个工作表)")
    print("  2. 简单测试.xlsx (5行简单数据)")
    print("  3. 大数据测试.xlsx (500行测试数据)")
