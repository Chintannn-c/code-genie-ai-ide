# 🧞‍♂️ Code Genie
### *The Indestructible AI Coding Orchestrator*

[![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)](https://fastapi.tiangolo.com/)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev/)
[![MongoDB](https://img.shields.io/badge/MongoDB-47A248?style=for-the-badge&logo=mongodb)](https://www.mongodb.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

**Code Genie** is a production-grade AI orchestration engine designed for high-performance code engineering. By leveraging a **Triple-Layer Failover Architecture**, Code Genie guarantees 100% uptime by dynamically routing requests through a pool of 12+ free-tier AI models, ensuring elite-level reasoning with zero operational costs.

---

## 💎 Core Architecture

### 🛡️ Omni-Failover Engine
Code Genie never stops. If a primary model (like Gemini) throttles or fails, the orchestrator automatically pivots through:
1. **Primary**: Gemini 2.0 Flash
2. **Secondary**: Groq (Llama 3.3 70B)
3. **Tertiary**: OpenRouter (GPT-OSS 120B)
4. **Safety Net**: Hugging Face (Mistral 7B)

### 🎨 Diamond UI/UX
A developer-centric interface built with Flutter, featuring:
- **Glassmorphism Design**: Semi-transparent UI elements with real-time blur.
- **Smart Notifications**: Native OS-level alerts with integrated deep-linking.
- **Interactive Editor**: Real-time syntax detection and parallel AI analysis.

---

## 🛠️ Technical Stack

| Layer | Technologies |
| :--- | :--- |
| **Frontend** | Flutter, Provider, Google Fonts, Flutter Animate |
| **Backend** | Python 3.12, FastAPI, Motor (Async MongoDB) |
| **Networking** | Ngrok Secure Tunneling, WebSockets, SSE |
| **AI Providers** | Google Gemini, Groq, OpenRouter, Hugging Face |
| **Security** | Native Bcrypt, Anti-Billing Filters, JWT Auth |

---

## 🚀 Quick Start

### 1. Prerequisites
- Flutter SDK (Latest)
- Python 3.12+
- MongoDB (Running locally)

### 2. Backend Setup
```bash
cd backend
pip install -r requirements.txt
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 3. Tunnel Activation
```bash
# In a separate terminal
python backend/start_tunnel.py
```

### 4. Frontend Launch
```bash
flutter run
```

---

## 🔐 Security & Safety
- **Anti-Billing Lock**: The system is hard-coded to reject any non-free model IDs, preventing accidental charges.
- **Secure Tunneling**: Automated Ngrok orchestration with interstitial bypass headers.
- **Data Isolation**: High-performance data pathing to prevent file-watcher loops.

---

*Developed with passion by the Code Genie AI Team.*
