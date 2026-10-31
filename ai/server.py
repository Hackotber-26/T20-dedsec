import json
import os
from pathlib import Path

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from url_reputation import router as url_reputation_router

# --------------------------------------------------
# Configuration
# --------------------------------------------------

OLLAMA_URL = os.getenv(
    "OLLAMA_URL",
    "http://127.0.0.1:11434"
)

OLLAMA_MODEL = os.getenv(
    "OLLAMA_MODEL",
    "qwen2.5:3b"
)

OLLAMA_TIMEOUT = float(
    os.getenv("OLLAMA_TIMEOUT", "90")
)

PROMPT_PATH = (
    Path(__file__).parent
    / "prompts"
    / "scam_analysis.txt"
)

SYSTEM_PROMPT = PROMPT_PATH.read_text(
    encoding="utf-8"
)


# --------------------------------------------------
# Application
# --------------------------------------------------

app = FastAPI(
    title="Pehchaan AI API",
    description="Free local AI-powered scam detection",
    version="1.0.0"
)

app.include_router(url_reputation_router)


# Development CORS configuration.
# Restrict origins before public deployment.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)


# --------------------------------------------------
# Request and response models
# --------------------------------------------------

class AnalysisRequest(BaseModel):
    input: str = Field(
        min_length=1,
        max_length=12000
    )

    inputType: str = Field(
        pattern="^(message|url|upi)$"
    )

    language: str = Field(
        default="auto",
        max_length=30
    )

    app: str = Field(
        default="pehchaan",
        max_length=30
    )


class AnalysisResponse(BaseModel):
    score: int = Field(ge=0, le=100)
    reasons: list[str]
    summary: str


# --------------------------------------------------
# Health check
# --------------------------------------------------

@app.get("/")
async def root():
    return {
        "app": "Pehchaan",
        "status": "running",
        "model": OLLAMA_MODEL
    }


@app.get("/health")
async def health():
    try:
        async with httpx.AsyncClient(
            timeout=5
        ) as client:

            response = await client.get(
                f"{OLLAMA_URL}/api/tags"
            )

            response.raise_for_status()

        return {
            "status": "healthy",
            "ollama": "connected",
            "model": OLLAMA_MODEL
        }

    except httpx.HTTPError:
        raise HTTPException(
            status_code=503,
            detail="Ollama is unavailable"
        )


# --------------------------------------------------
# AI response validation
# --------------------------------------------------

def validate_ai_output(raw_output: str) -> dict:

    try:
        data = json.loads(raw_output)

    except json.JSONDecodeError:
        raise HTTPException(
            status_code=502,
            detail="AI returned invalid JSON"
        )

    if not isinstance(data, dict):
        raise HTTPException(
            status_code=502,
            detail="AI response must be a JSON object"
        )

    score = data.get("score")

    # Do not accept booleans as integers.
    if isinstance(score, bool) or not isinstance(score, int):
        raise HTTPException(
            status_code=502,
            detail="AI returned an invalid score"
        )

    score = max(0, min(100, score))

    raw_reasons = data.get("reasons", [])

    if not isinstance(raw_reasons, list):
        raw_reasons = []

    reasons = []

    for reason in raw_reasons[:3]:
        if isinstance(reason, str):
            reason = reason.strip()

            if reason:
                reasons.append(reason[:300])

    summary = data.get("summary", "")

    if not isinstance(summary, str):
        summary = ""

    summary = summary.strip()[:700]

    if not summary:
        summary = (
            "The AI could not generate a detailed explanation. "
            "Verify independently before taking action."
        )

    return {
        "score": score,
        "reasons": reasons,
        "summary": summary
    }


# --------------------------------------------------
# Main AI detection endpoint
# --------------------------------------------------

@app.post(
    "/v1/analyze",
    response_model=AnalysisResponse
)
async def analyze(request: AnalysisRequest):

    user_content = f"""
Input type: {request.inputType}
Language: {request.language}

Analyse the following untrusted content.

<UNTRUSTED_INPUT>
{request.input}
</UNTRUSTED_INPUT>
"""

    payload = {
        "model": OLLAMA_MODEL,
        "stream": False,
        "format": "json",
        "options": {
            "temperature": 0.1
        },
        "messages": [
            {
                "role": "system",
                "content": SYSTEM_PROMPT
            },
            {
                "role": "user",
                "content": user_content
            }
        ]
    }

    try:
        async with httpx.AsyncClient(
            timeout=OLLAMA_TIMEOUT
        ) as client:

            response = await client.post(
                f"{OLLAMA_URL}/api/chat",
                json=payload
            )

            response.raise_for_status()

            ollama_data = response.json()

    except httpx.TimeoutException:
        raise HTTPException(
            status_code=504,
            detail="AI analysis timed out"
        )

    except httpx.HTTPError:
        raise HTTPException(
            status_code=503,
            detail="Could not communicate with Ollama"
        )

    try:
        ai_content = (
            ollama_data["message"]["content"]
        )

    except (KeyError, TypeError):
        raise HTTPException(
            status_code=502,
            detail="Unexpected Ollama response"
        )

    result = validate_ai_output(ai_content)

    return result