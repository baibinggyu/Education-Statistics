FROM python:3.14-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
COPY . .
ENV edu_server_host=0.0.0.0
ENV edu_server_port=55555
EXPOSE 55555
CMD ["./run.sh"]
