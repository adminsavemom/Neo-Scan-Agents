# SaveMom: Neonatal AI Analysis System 👶🚀

SaveMom is a state-of-the-art baby monitoring and neonatal AI analysis system designed to provide automated, high-precision clinical assessments for infants in incubators. By leveraging local AI models (**Gemma 4 via Ollama**) and advanced computer vision, the system identifies critical health indicators such as Jaundice, Respiratory Distress, and Neurological patterns.

## 🌟 Key Features

*   **Automated Clinical Assessment**: Performs full neonatal evaluations including:
    *   **Kramer Zones**: Jaundice detection and severity mapping.
    *   **Silverman-Andersen Score**: Respiratory distress evaluation.
    *   **NIPS (Neonatal Infant Pain Scale)**: Pain and distress monitoring.
    *   **NBAS & Prechtl Assessment**: Behavioral and movement quality analysis.
    *   **IMNCI Danger Signs**: Detection of critical clinical "red flags."
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
