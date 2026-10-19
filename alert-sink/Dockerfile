FROM python:3.12-alpine

RUN addgroup -g 10001 appgroup && \
    adduser -u 10001 -G appgroup -s /bin/sh -D appuser

WORKDIR /app
COPY app.py .
RUN chown -R appuser:appgroup /app

USER appuser
EXPOSE 5000
ENV PYTHONUNBUFFERED=1

CMD ["python", "app.py"]
