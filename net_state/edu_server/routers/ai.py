import json
import os
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from fastapi import APIRouter, Depends, HTTPException, status

from deps import get_current_user
from models import User
from schemas import AIChatRequest, AIChatResponse

router = APIRouter()

SYSTEM_PROMPT = (
    "你是 EduStat 教学统计系统内置的 AI 助手。"
    "请使用中文回答，支持 Markdown 排版，但不要使用 LaTeX 公式语法。"
    "涉及数学内容时，用普通文本、列表或代码块表达，不要输出 "
    "$...$、$$...$$、\\(...\\) 或 \\[...\\]。"
)


def _ai_config() -> tuple[str, str, str, int]:
    api_key = os.getenv("ANTHROPIC_AUTH_TOKEN") or os.getenv("DEEPSEEK_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI service is not configured",
        )

    base_url = os.getenv("ANTHROPIC_BASE_URL", "https://api.deepseek.com/anthropic")
    model = os.getenv("ANTHROPIC_MODEL", "deepseek-v4-pro")
    timeout = int(os.getenv("AI_PROXY_TIMEOUT_SECONDS", "60"))
    return api_key, base_url.rstrip("/"), model, timeout


def call_deepseek_anthropic(messages: list[dict[str, str]]) -> tuple[str, str]:
    api_key, base_url, model, timeout = _ai_config()
    payload = {
        "model": model,
        "max_tokens": 4096,
        "stream": False,
        "messages": messages,
    }

    req = Request(
        f"{base_url}/v1/messages",
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
        },
        method="POST",
    )

    try:
        with urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8")
    except HTTPError as exc:
        detail = "AI upstream request failed"
        try:
            raw = exc.read().decode("utf-8")
            parsed = json.loads(raw)
            upstream_error = parsed.get("error")
            if isinstance(upstream_error, dict):
                detail = upstream_error.get("message") or detail
            elif isinstance(upstream_error, str):
                detail = upstream_error
        except Exception:
            pass
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=detail)
    except URLError:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="AI upstream is unreachable",
        )

    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="AI upstream returned invalid JSON",
        )

    content = data.get("content")
    if isinstance(content, list):
        for item in content:
            if isinstance(item, dict) and item.get("type") == "text":
                text = item.get("text")
                if isinstance(text, str) and text:
                    return text, model

    choices = data.get("choices")
    if isinstance(choices, list) and choices:
        message = choices[0].get("message") if isinstance(choices[0], dict) else None
        text = message.get("content") if isinstance(message, dict) else None
        if isinstance(text, str) and text:
            return text, model

    raise HTTPException(
        status_code=status.HTTP_502_BAD_GATEWAY,
        detail="AI upstream response has no text content",
    )


@router.post("/chat", response_model=AIChatResponse)
def chat_with_ai(
    data: AIChatRequest,
    user: User = Depends(get_current_user),
):
    """登录用户调用 AI 助手。

    DeepSeek API key 只保存在服务器环境变量中，客户端永不接触真实 key。
    """
    _ = user
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    messages.extend(m.model_dump() for m in data.messages)

    content, model = call_deepseek_anthropic(messages)
    return AIChatResponse(content=content, model=model)
