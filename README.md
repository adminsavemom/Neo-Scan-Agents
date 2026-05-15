
## NeoScan Agents — AI Neonatal Screening for Every Newborn

**Subtitle:** Offline multimodal neonatal diagnostics powered by Gemma 4 — enabling nurses, ASHA workers, and mothers to detect life‑threatening newborn conditions in under 90 seconds.

**Tagline:** Clinical-grade neonatal screening in 90 seconds. No doctor. No internet. No excuses.

### The Problem
Every 26 seconds, a newborn dies from a condition a trained eye could have caught. Many deaths (99%) occur in low- and middle-income countries where skilled neonatal screening is not always available. Conditions like jaundice, birth asphyxia, respiratory distress, and sepsis show visible or audible early signs — and are treatable if detected early. The gap is detection, not treatment.

### Key Metrics (selected)
- **Global neonatal deaths (2024):** 2.3 million — WHO 2025
- **Preventable with skilled birth attendance:** ~45% — Lancet Neonatology 2024
- **Rural births in India without a neonatal specialist:** 70% — NHM India 2024
- **Asphyxia window before irreversible brain damage:** 6 minutes — ILCOR Guidelines 2024
- **Estimated kernicterus (India):** ~30,000 cases/year — NNF India 2024

### What We Built
NeoScan Agents is a fully offline, multimodal neonatal screening system built on a fine‑tuned Gemma 4 model. A caregiver points their phone at a newborn and receives a structured five‑module clinical report in under 90 seconds — processing video and audio on‑device with zero internet dependency. The model was fine‑tuned using Unsloth across two modalities:

- Image: Jaundice detection (skin & scleral yellowing), trained for all skin tones including Fitzpatrick IV–VI.
- Audio: Cry classification using the ICSD dataset — cry / not cry / burping — enabling distress characterization.

The fine‑tuned model is exported in two formats for deployment:
- LiteRT (.literlm) for the Flutter Android app.
- GGUF for edge/web deployment via Ollama.

### Deployment Targets
- Mobile (Android / Tablet): Flutter app + Google LiteRT engine — bedside, home visits.
- Edge device (Raspberry Pi, clinic station): Web app + Ollama + GGUF model — shared devices in rural clinics or NICU stations.

Both deployments run the same fine‑tuned model, fully offline. Minimum recommended mobile spec: Android 10+, 6–8GB RAM.

### Five Diagnostic Modules (Live Diagnostic Session)
NeoScan runs six sequential stages producing findings, confidence scores, plain‑language explanations, and a Potential Harm card for each:

1. **Jaundice AI** — analyses frames for skin and scleral yellowing; flags bilirubin risk and phototherapy assessment.
2. **Cry Analysis** — classifies audio (cry / not cry / burping) and characterises distress (pain, hunger, normal).
3. **Asphyxia Screening** — fuses visual and audio cues to detect high‑risk asphyxia patterns; issues NICU referral guidance when convergent signals appear.
4. **RDS Screening** — detects respiratory distress signs (nasal flaring, chest retractions, grunting); can run standalone for monitoring.
5. **Cyanosis Screening** — examines lips, fingertips, and facial tone for bluish discolouration indicating low oxygen.
6. **Summary & Triage** — synthesises module outputs into a single triage: Safe, Monitor, or Refer Immediately, with caregiver actions.

### Use Cases
- Immediate post‑delivery screening when no specialist is present.
- Continuous ward monitoring on an edge station for structured check‑ins.
- ASHA worker home visits (day 3–5 jaundice peak) using existing smartphones.
- Mother‑led home monitoring after hospital discharge with plain‑language guidance.
- Telemedicine triage: structured report shared with remote clinicians for data‑driven decisions.

### Impact Estimates (conservative)
- 10% of India’s ASHA network using NeoScan on visits: ~2.5M babies screened/year, 3,000–6,000 jaundice brain‑damage cases prevented.
- 25% rural district hospital screening at delivery: ~4.4M babies screened/year, 10,000–15,000 asphyxia/RDS interventions triggered.
- Mother post‑discharge screening in tier‑2/3 cities: ~5M screens/year, 6,000+ kernicterus cases averted.

### Technology Stack (summary)
| Component | Technology |
|---|---|
| Base Model | Gemma 4 E4B |
| Fine‑Tuning | Unsloth (multimodal image + audio) |
| Mobile Format | LiteRT (.literlm) |
| Edge Format | GGUF via Ollama |
| Mobile App | Flutter (Android) |
| Web / Edge App | Ollama + local web UI |

### Privacy & Safety
All processing is on‑device or on a local edge server; patient data never leaves the device. The report is designed for triage, not definitive diagnosis — always recommend clinical follow‑up when the tool flags high risk.

---
For details on integrating NeoScan Agents into the existing SaveMom pipeline, or to add deployment instructions and sample artifacts, open an issue or request the integration steps.

## 🌟 Key Features

*   **Automated Clinical Assessment**: Performs full neonatal evaluations including: jaundice, respiratory distress, asphyxia risk, and cry analysis.
*   **Staged AI Pipeline**: Optimized local inference using a staged approach to overcome context window limits of edge models.
*   **Video & Audio Processing**: Extracts visual frames and audio features (cries/distress) for multi-modal analysis.
*   **Clinical Dashboard**: Intuitive frontend for healthcare providers to track baby health history and real-time alerts.
*   **Gemma 4 Fine-tuning**: Included research notebooks for jaundice detection optimization.

---

## 🏗️ System Architecture

The project follows a modern decoupled architecture:

```mermaid
graph TD
    A[Frontend: Vite + React] -->|Upload Video| B[Backend: FastAPI]
    B -->|Preprocessing| C[OpenCV / Librosa]
    C -->|Staged Frames| D[Ollama / Gemma 4]
    D -->|Structured JSON| B
    B -->|Save Results| E[PostgreSQL Database]
    B -->|Response| A
```

### Folder Structure Explanation
*   `Baby-Monitoring/`: Frontend application built with React, Vite, and Tailwind CSS.
*   `backend/`: FastAPI service. Contains `main.py` (entry point), `v1/` (API routes), `ollama/` (AI integration), and `db/` (database models).
*   `Notebook/`: Research and development notebooks for fine-tuning Gemma models.
*   `demo/`: Sample media and demonstration assets.
*   `output/`: Local storage for `.gguf` model files and temporary processing outputs.

---

## 🛠️ Tech Stack

| Layer | Technologies |
| :--- | :--- |
| **Frontend** | React, Vite, TypeScript, Tailwind CSS, Lucide Icons |
| **Backend** | FastAPI, SQLAlchemy (Async), Alembic, Pydantic |
| **AI/ML** | Gemma 4, Ollama, OpenCV, Librosa |
| **Database** | PostgreSQL |
| **DevOps** | Python 3.10+, Node.js, Uvicorn |

---

## 🚀 Getting Started

### 1. Prerequisites
*   **Ollama**: [Download and install Ollama](https://ollama.ai/)
*   **Python**: 3.10 or higher
*   **Node.js**: 18.x or higher
*   **PostgreSQL**: A running instance (or use the provided connection string in `.env`)
*   **FFmpeg**: Required for audio processing (`brew install ffmpeg`)

### 2. AI Model Setup (Ollama & Gemma)
Pull the base model:
```bash
ollama pull gemma4:e2b
```
*(Optional)* If you have a custom `.gguf` file from the fine-tuning process, place it in `backend/output/`. The system will automatically register it on startup.

### 3. Backend Setup
```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows use `venv\Scripts\activate`
pip install -r requirements.txt
```

**Environment Variable Setup**:
Create a `backend/.env` file:
```env
DATABASE_URL=postgresql+asyncpg://user:pass@host:port/dbname
```

**Run Backend**:
```bash
uvicorn main:app --reload
```

### 4. Frontend Setup
```bash
cd Baby-Monitoring
npm install
npm run dev
```

### 5. Notebooks & Demo
To run the research notebooks:
```bash
cd Notebook
jupyter notebook
```

---

## 📊 API Usage & Workflow

### Neonatal Video Analysis
**Endpoint**: `POST /v1/analysis`
**Description**: Uploads a baby incubator video for full assessment.

**Parameters**:
*   `baby_id`: Unique identifier for the infant.
*   `video`: File upload (MP4, WebM, AVI, MOV).

**Example Workflow**:
1.  **Validation**: Backend validates file size (max 100MB) and format.
2.  **Extraction**: OpenCV extracts frames at 2 FPS; Librosa extracts audio context.
3.  **AI Inference**: The staged pipeline runs:
    *   **Stage 1 (Skin)**: Jaundice and cyanosis detection.
    *   **Stage 2 (Respiratory)**: Breathing pattern and SA score.
    *   **Stage 3 (Neurology)**: Movement and tone analysis.
4.  **Data Persistence**: Results are validated via Pydantic and saved to PostgreSQL.

---

## 🔧 Troubleshooting
*   **422 Unprocessable Entity**: Usually indicates a JSON parsing error from the AI model or video extraction failure. Check `backend/main.py` logs.
*   **Ollama Connection**: Ensure Ollama is running in the background (`ollama serve`).
*   **Database Errors**: Verify the `DATABASE_URL` and ensure the PostgreSQL service is reachable.

---

## 🔮 Future Improvements
*   [ ] Real-time WebSocket integration for live monitor feeds.
*   [ ] Multi-modal cry analysis using deep learning audio classifiers.
*   [ ] Automated clinical report generation (PDF).
*   [ ] Mobile companion app for parents.

---

## 🤝 Contribution Guide
1. Fork the repo and create your branch from `main`.
2. Ensure your code follows the existing style and includes comments.
3. Submit a PR with a detailed description of your changes.

---

## 📄 License
This project is licensed under the MIT License.

---
*Developed for the Gemma 4 Hackathon by the SaveMom Team.*
