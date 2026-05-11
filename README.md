# StatAudit Pro: Advanced Forensic AI Orchestrator 🚀

StatAudit Pro (formerly Code Genie) is a high-performance forensic-grade orchestration engine designed for deep document auditing, financial analysis, and autonomous code engineering. It leverages a parallel multi-model architecture to provide best-in-class reasoning while maintaining a 100% free-tier infrastructure.

## ✨ Key Features

- **Parallel Multi-Model Orchestration**: Queries multiple top-tier models (Gemini 2.0, Groq, and OpenRouter) in parallel to reach a high-confidence consensus.
- **May 2026 "Best Free" Stack**: Optimized for the latest free-tier models on OpenRouter, featuring high-parameter reasoning engines like **GPT-OSS 120B**, **Llama 3.3 70B**, and **Qwen 3 Coder**.
- **Autonomous Agentic Planning**: Decomposes complex forensic goals into actionable engineering steps and executes them proactively with workspace awareness.
- **Forensic-Grade Reliability**: Implements parallel ensemble consensus and automatic model failover to ensure 100% uptime for critical audit tasks.
- **StatAudit Dashboard**: A premium Flutter interface for tracking Gini coefficients, risk concentrations, and anomaly spikes in real-time.

## 🛡️ Forensic Audit Strategy

The engine utilizes a **Smart Overlap** strategy for transaction sampling, prioritizing high-risk unique entities while maintaining strict global vendor uniqueness.

### AI Engine Tiers:
- **Tier 1 (Reasoning)**: Llama 3.3 70B & GPT-OSS 120B (OpenRouter Free)
- **Tier 2 (Stability)**: Gemini 2.0 Flash (Direct)
- **Tier 3 (Speed)**: Groq (Speculative Decoding)

## 🛠️ Technology Stack

- **Frontend**: Flutter / Dart
- **Backend**: FastAPI (Python)
- **Database**: MongoDB & Persistent File Cache
- **AI Ecosystem**: 
  - Google Gemini 3.1 Pro & Flash
  - Groq (Llama 3.3 70B)
  - OpenRouter (100% Free Model Pool)

## 🚀 Getting Started

### Prerequisites
- Flutter SDK
- Python 3.12+
- MongoDB instance

### Backend Setup
1. `cd backend`
2. `pip install -r requirements.txt`
3. Configure `.env` with your API keys.
4. `python -m uvicorn app.main:app --reload`

### Frontend Setup
1. `flutter pub get`
2. `flutter run`

---
*Built for forensic excellence by the StatAudit AI Team.*
