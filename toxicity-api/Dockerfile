FROM python:3.11-slim

WORKDIR /app

# Системные зависимости
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

# Скачать модель при сборке, чтобы не качать при каждом запуске
RUN python -c "\
from transformers import AutoTokenizer, AutoModelForSequenceClassification; \
AutoTokenizer.from_pretrained('cointegrated/rubert-tiny-toxicity', cache_dir='/app/model'); \
AutoModelForSequenceClassification.from_pretrained('cointegrated/rubert-tiny-toxicity', cache_dir='/app/model'); \
print('Model downloaded successfully')"

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
