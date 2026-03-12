const express = require('express');
const axios = require('axios');
const path = require('path');

const app = express();
const PORT = 3000;
const API_URL = process.env.API_URL || 'http://toxicity-api:8000';

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
    const msg = err.response?.data?.detail || err.message;
    res.status(500).json({ error: `API недоступен: ${msg}` });
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
    const msg = err.response?.data?.detail || err.message;
    res.status(500).json({ error: `API недоступен: ${msg}` });
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
