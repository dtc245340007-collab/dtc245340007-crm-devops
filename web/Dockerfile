FROM python:3.12-slim

# Tạo người dùng không đặc quyền (UID 10001) theo chuẩn Hardening
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -m -s /bin/bash appuser

WORKDIR /app

# Cài đặt curl cho healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN chown -R appuser:appgroup /app

ENV PYTHONUNBUFFERED=1
EXPOSE 8000

USER appuser

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8000", "src.app:create_app()"]
