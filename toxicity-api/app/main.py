import os
import torch
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from transformers import AutoTokenizer, AutoModelForSequenceClassification

app = FastAPI(title="Russian Toxicity API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

MODEL_DIR = "/app/model"
CHECKPOINT = "cointegrated/rubert-tiny-toxicity"

print("Loading model...")
tokenizer = AutoTokenizer.from_pretrained(CHECKPOINT, cache_dir=MODEL_DIR)
model = AutoModelForSequenceClassification.from_pretrained(CHECKPOINT, cache_dir=MODEL_DIR)
model.eval()
print("Model loaded!")

LABELS = ["non_toxic", "insult", "obscenity", "threat", "dangerous"]

class TextRequest(BaseModel):
    text: str

class BatchRequest(BaseModel):
    texts: list[str]

def predict(text: str) -> dict:
    with torch.no_grad():
        inputs = tokenizer(text, return_tensors="pt", truncation=True, padding=True, max_length=512)
        proba = torch.sigmoid(model(**inputs).logits).cpu().numpy()[0]
    scores = {label: round(float(p), 4) for label, p in zip(LABELS, proba)}
    scores["is_toxic"] = scores["non_toxic"] < 0.5
    scores["toxicity_score"] = round(1 - float(proba[0]) * (1 - float(proba[4])), 4)
    return scores

@app.get("/health")
def health():
    return {"status": "ok", "model": CHECKPOINT}

@app.post("/check")
def check_text(req: TextRequest):
    return {"text": req.text, "result": predict(req.text)}

@app.post("/batch")
def check_batch(req: BatchRequest):
    results = []
    for text in req.texts[:20]:  # лимит 20 за раз
        results.append({"text": text, "result": predict(text)})
    return {"results": results}

# Для простого GET-запроса тоже (удобно для curl)
@app.get("/check")
def check_get(text: str):
    return {"text": text, "result": predict(text)}
