import json
import os
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import Response, StreamingResponse

from deps import get_current_user, require_teacher_or_admin
from models import User
from schemas import AIChatRequest, AIChatResponse, LearningReportRequest, StudentAnalysisRequest

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

    # Anthropic Messages API 要求 system prompt 放在顶层 system 字段
    # 不能作为 messages[0] with role="system"
    system_prompts = [m["content"] for m in messages if m.get("role") == "system"]
    user_messages = [m for m in messages if m.get("role") != "system"]

    payload: dict = {
        "model": model,
        "max_tokens": 8192,
        "stream": False,
        "messages": user_messages,
    }
    if system_prompts:
        payload["system"] = system_prompts if len(system_prompts) > 1 else system_prompts[0]

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


REPORT_SYSTEM_PROMPT = (
    "你是一位专业的教育数据分析师，拥有丰富的教学评估经验。"
    "请根据用户提供的学习数据，生成一份详细、专业的中文学习报告。\n\n"
    "报告必须包含以下五个部分，每个部分标题用 **粗体**，内容不少于指定字数：\n\n"
    "**学习概况**（不少于100字）\n"
    "- 总览课程数量、视频总数、整体完成率\n"
    "- 用数据说话，给出具体的百分比和数字\n"
    "- 简要评价当前学习状态（积极/一般/需努力），附理由\n\n"
    "**各课程详细分析**（每门课不少于80字）\n"
    "- 逐门课程列出：课程名称、视频数量、已完成数、完成率百分比\n"
    "- 消息互动情况（总消息数、未读数）\n"
    "- 对每门课给出评级（优秀≥80%、良好60-79%、一般40-59%、需关注<40%）\n"
    "- 分析该课程的学习投入度和存在的问题\n\n"
    "**学习数据可视化描述**\n"
    "- 用文本描述各课程完成率的对比情况\n"
    "- 指出完成率最高和最低的课程\n"
    "- 分析学习时间的分布是否均衡\n\n"
    "**针对性学习建议**（不少于4条，每条30字以上）\n"
    "- 明确每条建议对应哪门课或哪个学习习惯\n"
    "- 给出具体可执行的行动方案，而非空泛的鼓励\n"
    "- 结合教育心理学原理提出改进策略\n"
    "- 建议应覆盖：补弱项、固强项、时间管理、互动参与等方面\n\n"
    "**综合评估与激励**（不少于80字）\n"
    "- 给出整体学习的量化评分（百分制）\n"
    "- 横向对比各课程表现，总结规律\n"
    "- 设定下一阶段的具体目标\n"
    "- 用温暖而坚定的语气给予鼓励\n\n"
    "格式要求：\n"
    "- 严格使用 **粗体标题** 标记各部分标题\n"
    "- 正文用列表（- 开头）或段落呈现，层次分明\n"
    "- 每个部分之间空一行\n"
    "- 数据用数字和百分比呈现，不要只写文字\n"
    "- 不要使用 LaTeX 公式语法\n"
    "- 不要使用表格，用列表代替\n"
    "- 总字数不少于800字"
)


@router.post("/learning-report", response_model=AIChatResponse)
def generate_learning_report(
    data: LearningReportRequest,
    user: User = Depends(get_current_user),
):
    """根据用户学习数据生成 AI 学习报告。

    客户端收集课程进度、视频完成情况等数据，
    服务端格式化后发送给 DeepSeek 进行分析。
    """
    _ = user
    messages = [
        {"role": "system", "content": REPORT_SYSTEM_PROMPT},
        {"role": "user", "content": f"以下是我的学习数据，请帮我生成学习报告：\n\n{data.learning_data}"},
    ]

    content, model = call_deepseek_anthropic(messages)
    return AIChatResponse(content=content, model=model)


STUDENT_ANALYSIS_SYSTEM_PROMPT = (
    "你是一位拥有15年经验的资深教育评估专家，专门为学校教师提供精准的学生学习情况诊断报告。"
    "请根据提供的学生数据，生成一份专业、详尽的中文学情分析报告。\n\n"
    "报告必须包含以下六个部分，每个部分标题用 **粗体**，内容不少于指定字数：\n\n"
    "**学生基本信息概览**（不少于80字）\n"
    "- 姓名、所在课程\n"
    "- 整体学业评级（优秀/良好/一般/需关注/高风险，给出具体评分百分制分数）\n"
    "- 一句话总结该生的学习画像\n\n"
    "**各考核单元成绩分析**（每个单元不少于50字）\n"
    "- 逐单元列出成绩，标注是否达标\n"
    "- 对未达标单元重点分析，推测可能的原因\n"
    "- 计算各单元与满分的差距\n"
    "- 指出成绩波动大或持续低迷的单元\n\n"
    "**学习参与度评估**（不少于100字）\n"
    "- 出勤情况分析（出勤率、缺勤次数、迟到次数）\n"
    "- 视频学习参与度（课程视频总数 vs 该生完成情况）\n"
    "- 消息互动情况\n"
    "- 学习态度和行为模式总结\n\n"
    "**优势与薄弱环节**（不少于120字）\n"
    "- 明确列出2-3个优势领域，用数据支撑\n"
    "- 明确列出2-3个薄弱环节，分析深层原因\n"
    "- 分析是否存在偏科现象\n"
    "- 评估该生的学习能力和潜力\n\n"
    "**学业风险预警**（不少于80字）\n"
    "- 标注风险等级（无风险/低风险/中风险/高风险）\n"
    "- 明确指出是否有挂科风险，给出预估概率\n"
    "- 分析风险来源（成绩不足/缺勤过多/参与度低）\n"
    "- 给出预警时间窗口和紧急程度\n\n"
    "**教师辅导建议**（不少于5条，每条40字以上）\n"
    "- 给出具体的教学干预措施，区分紧急和长期\n"
    "- 建议需结合该生的具体情况，有针对性\n"
    "- 包含：课后辅导方案、学习计划调整、心理激励、家校沟通建议\n"
    "- 每一条都要可落地执行，不要空洞\n\n"
    "格式要求：\n"
    "- 严格使用 **粗体标题** 标记各部分标题\n"
    "- 正文用列表（- 开头）或段落呈现，层次分明\n"
    "- 每个部分之间空一行\n"
    "- 所有判断必须有数据依据\n"
    "- 不要使用 LaTeX 公式语法\n"
    "- 不要使用表格，用列表代替\n"
    "- 语气专业、客观、建设性，体现教育者的温度\n"
    "- 总字数不少于900字"
)


@router.post("/student-analysis", response_model=AIChatResponse)
def analyze_student(
    data: StudentAnalysisRequest,
    user: User = Depends(require_teacher_or_admin),
):
    """教师对单个学生进行 AI 学情分析。

    客户端收集该学生的成绩、视频进度、出勤等数据，
    服务端转发给 DeepSeek 生成诊断报告。
    """
    _ = user
    messages = [
        {"role": "system", "content": STUDENT_ANALYSIS_SYSTEM_PROMPT},
        {"role": "user", "content": f"请分析以下学生的学习情况：\n\n{data.student_data}"},
    ]

    content, model = call_deepseek_anthropic(messages)
    return AIChatResponse(content=content, model=model)


# ============================================================
# Anthropic Messages API 透传代理（供 EduStat_qml Agent 使用）
# ============================================================
# 客户端 ai-sdk-cpp 通过此端点透明访问 DeepSeek Anthropic API。
# JWT 从 x-api-key 头部传入（而非标准 Authorization: Bearer），
# 因为 ai-sdk-cpp 的 Anthropic client 使用 x-api-key 传认证凭据。

@router.api_route("/anthropic-proxy/{path:path}", methods=["POST", "GET", "PUT"])
async def anthropic_proxy(
    path: str,
    request: Request,
):
    """透明代理到 DeepSeek Anthropic API。

    ai-sdk-cpp 的 Anthropic client 会向 {base}/v1/messages 发 POST，
    所以 base 应设为 {server}/api/ai/anthropic-proxy。
    JWT 通过 x-api-key 头部传入。
    """
    from database import SessionLocal
    from security import decode_access_token
    from models import User
    from jose import JWTError

    # 1. 验证 JWT（从 x-api-key 头部读取，非标准 Authorization: Bearer）
    jwt_token = request.headers.get("x-api-key") or request.headers.get("X-Api-Key")
    if not jwt_token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing x-api-key header")

    db = SessionLocal()
    try:
        try:
            payload = decode_access_token(jwt_token)
            user_uuid = payload.get("sub")
            if not user_uuid:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
        except JWTError:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

        user = db.query(User).filter(User.uuid == user_uuid).first()
        if not user or user.status != 1:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found or disabled")
    finally:
        db.close()

    # 2. 获取 DeepSeek API 配置
    api_key, upstream_base, model, timeout = _ai_config()

    # 3. 读取客户端原始请求体
    body = await request.body()

    # 4. 转发到 DeepSeek Anthropic API
    upstream_url = f"{upstream_base}/{path}"
    req_headers = {
        "Content-Type": "application/json",
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
    }

    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(timeout)) as client:
            proxy_resp = await client.post(
                upstream_url,
                content=body,
                headers=req_headers,
            )
            return Response(
                content=proxy_resp.content,
                status_code=proxy_resp.status_code,
                headers=dict(proxy_resp.headers),
            )
    except httpx.TimeoutException:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="AI upstream timeout")
