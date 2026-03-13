const express = require('express');
const axios = require('axios');
const path = require('path');

const app = express();
const PORT = 3000;
const API_URL = process.env.API_URL || 'http://toxicity-api:8000';

// Security headers
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  next();
});

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Прокси к Python API — одиночный текст
app.post('/api/check', async (req, res) => {
  try {
    const { text } = req.body;
    if (!text || !text.trim()) return res.status(400).json({ error: 'Текст не передан' });
    const response = await axios.post(`${API_URL}/check`, { text });
    res.json(response.data);
  } catch (err) {
    res.status(500).json({ error: 'API недоступен' });
  }
});

// Прокси к Python API — батч
app.post('/api/batch', async (req, res) => {
  try {
    const { texts } = req.body;
    if (!texts || !texts.length) return res.status(400).json({ error: 'Тексты не переданы' });
    const response = await axios.post(`${API_URL}/batch`, { texts });
    res.json(response.data);
  } catch (err) {
    res.status(500).json({ error: 'API недоступен' });
  }
});

// Статус API
app.get('/api/health', async (req, res) => {
  try {
    const response = await axios.get(`${API_URL}/health`);
    res.json({ ui: 'ok', api: response.data });
  } catch {
    res.status(503).json({ ui: 'ok', api: 'unavailable' });
  }
});

app.listen(PORT, () => {
  console.log(`UI запущен: http://localhost:${PORT}`);
  console.log(`API URL: ${API_URL}`);
});
