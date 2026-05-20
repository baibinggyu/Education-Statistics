import sys
from pathlib import Path
from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from pydantic import ValidationError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from routers import ai
from schemas import AIChatRequest


def fake_user():
    return SimpleNamespace(id=1, uuid="user-1", username="tester", role="student", status=1)


def test_ai_chat_forwards_system_prompt(monkeypatch):
    captured = {}

    def fake_call(messages):
        captured["messages"] = messages
        return "你好，我是 AI 助手。", "deepseek-v4-pro"

    monkeypatch.setattr(ai, "call_deepseek_anthropic", fake_call)

    resp = ai.chat_with_ai(
        AIChatRequest(messages=[{"role": "user", "content": "你好"}]),
        user=fake_user(),
    )

    assert resp.content == "你好，我是 AI 助手。"
    assert resp.model == "deepseek-v4-pro"
    assert captured["messages"][0]["role"] == "system"
    assert "不要使用 LaTeX" in captured["messages"][0]["content"]
    assert captured["messages"][1] == {"role": "user", "content": "你好"}


def test_ai_chat_rejects_empty_messages():
    with pytest.raises(ValidationError):
        AIChatRequest(messages=[])


def test_ai_config_requires_server_key(monkeypatch):
    monkeypatch.delenv("ANTHROPIC_AUTH_TOKEN", raising=False)
    monkeypatch.delenv("DEEPSEEK_API_KEY", raising=False)

    with pytest.raises(HTTPException) as exc:
        ai._ai_config()

    assert exc.value.status_code == 503
    assert exc.value.detail == "AI service is not configured"


def test_ai_config_reads_server_env(monkeypatch):
    monkeypatch.setenv("ANTHROPIC_AUTH_TOKEN", "sk-test")
    monkeypatch.setenv("ANTHROPIC_BASE_URL", "https://example.test/anthropic/")
    monkeypatch.setenv("ANTHROPIC_MODEL", "deepseek-test")
    monkeypatch.setenv("AI_PROXY_TIMEOUT_SECONDS", "12")

    api_key, base_url, model, timeout = ai._ai_config()

    assert api_key == "sk-test"
    assert base_url == "https://example.test/anthropic"
    assert model == "deepseek-test"
    assert timeout == 12
