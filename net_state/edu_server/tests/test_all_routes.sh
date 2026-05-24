#!/bin/bash
# ==========================================================================
# Edu Server 全端点 curl 测试脚本
#
# 用法:
#   chmod +x test_all_routes.sh
#   ./test_all_routes.sh
#
# 服务器: https://124.222.82.196
# 注意: 需要服务器已部署最新代码且正常运行
# ==========================================================================

BASE="https://124.222.82.196"
CURL="curl -sk"

# ---- 工具函数 ----

# 安全地从 curl 响应中提取 JSON 字段（带重试，处理服务端 503）
# 用法: safe_json <json_key> -- <curl命令...>
# 返回: JSON 字段值，失败返回空字符串
safe_json() {
    local key="$1"; shift
    local resp out code delay
    delay=3
    for i in 1 2 3 4 5 6 7 8; do
        resp=$("$@" -w "\n%{http_code}" 2>/dev/null)
        code=$(echo "$resp" | tail -1)
        out=$(echo "$resp" | sed '$d' | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('$key',''))" 2>/dev/null || true)
        if [ -n "$out" ]; then echo "$out"; return 0; fi
        [ "$code" = "503" ] && sleep $delay
        delay=$((delay + 2))
    done
    return 1
}

# 安全地从 curl 响应中提取 JSON 数组第一个元素的字段（带重试）
# 用法: safe_json_first <json_key> -- <curl命令...>
safe_json_first() {
    local key="$1"; shift
    local resp out code delay
    delay=3
    for i in 1 2 3 4 5 6 7 8; do
        resp=$("$@" -w "\n%{http_code}" 2>/dev/null)
        code=$(echo "$resp" | tail -1)
        out=$(echo "$resp" | sed '$d' | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['$key'])" 2>/dev/null || true)
        if [ -n "$out" ]; then echo "$out"; return 0; fi
        [ "$code" = "503" ] && sleep $delay
        delay=$((delay + 2))
    done
    return 1
}

# 安全地从 curl 响应中提取 JSON 数组最后一个元素的字段（带重试）
# 用法: safe_json_last <json_key> -- <curl命令...>
safe_json_last() {
    local key="$1"; shift
    local resp out code delay
    delay=3
    for i in 1 2 3 4 5 6 7 8; do
        resp=$("$@" -w "\n%{http_code}" 2>/dev/null)
        code=$(echo "$resp" | tail -1)
        out=$(echo "$resp" | sed '$d' | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[-1]['$key'])" 2>/dev/null || true)
        if [ -n "$out" ]; then echo "$out"; return 0; fi
        [ "$code" = "503" ] && sleep $delay
        delay=$((delay + 2))
    done
    return 1
}

# 重试命令（处理服务端偶尔 503）
retry() {
    local max=5
    local delay=2
    for i in $(seq 1 $max); do
        if "$@" > /dev/null 2>&1; then return 0; fi
        sleep $delay
        delay=$((delay + 2))
    done
    return 1
}

check() {
    # $1=描述  $2=期望状态码  $3..=curl 参数
    local desc="$1"; shift
    local expect="$1"; shift
    local actual
    for i in 1 2 3; do
        actual=$("$@" -o /dev/null -w "%{http_code}")
        [ "$actual" != "503" ] && break
        sleep 3
    done
    if [ "$actual" = "$expect" ]; then
        printf "  PASS  %-50s (got %s)\n" "$desc" "$actual"
    else
        printf "  FAIL  %-50s expected %s, got %s\n" "$desc" "$expect" "$actual"
    fi
}

check_body() {
    # $1=描述  $2=期望状态码  $3=body中的关键字  $4..=curl 参数
    local desc="$1"; shift
    local expect="$1"; shift
    local keyword="$1"; shift
    local resp actual body
    for i in 1 2 3; do
        resp=$("$@" -w "\n%{http_code}" 2>/dev/null)
        actual=$(echo "$resp" | tail -1)
        [ "$actual" != "503" ] && break
        sleep 3
    done
    body=$(echo "$resp" | sed '$d')
    if [ "$actual" = "$expect" ] && echo "$body" | grep -q "$keyword"; then
        printf "  PASS  %-50s (body contains '%s')\n" "$desc" "$keyword"
    else
        printf "  FAIL  %-50s expected %s, got %s. body: %s\n" "$desc" "$expect" "$actual" "${body:0:200}"
    fi
}

# ---- 预注册测试账号（时间戳保证唯一）----
SUFFIX=$(date +%s | tail -c5)
TEACHER="api_test_t_$SUFFIX"
STUDENT="api_test_s_$SUFFIX"
PASS="test123"

echo "==========================================="
echo "  Edu Server 全端点测试"
echo "  教师: $TEACHER  学生: $STUDENT"
echo "==========================================="

# ============================
# 注册
# ============================
echo ""
echo "=== 注册 ==="

check "教师注册" "201" \
    $CURL -X POST "$BASE/api/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$TEACHER\",\"password\":\"$PASS\",\"role\":\"teacher\",\"real_name\":\"张老师\"}"

sleep 1

check "学生注册" "201" \
    $CURL -X POST "$BASE/api/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$STUDENT\",\"password\":\"$PASS\",\"role\":\"student\",\"student_no\":\"SN$SUFFIX\",\"real_name\":\"李同学\"}"

check "重复注册应409/400" "409" \
    $CURL -X POST "$BASE/api/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$TEACHER\",\"password\":\"x\",\"role\":\"teacher\"}"

# ============================
# 登录
# ============================
echo ""
echo "=== 登录 ==="

# 登录（带重试）
T_TOKEN=$(safe_json access_token \
    $CURL -X POST "$BASE/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$TEACHER\",\"password\":\"$PASS\"}")
echo "  教师 token: ${T_TOKEN:0:30}..."

S_TOKEN=$(safe_json access_token \
    $CURL -X POST "$BASE/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$STUDENT\",\"password\":\"$PASS\"}")
echo "  学生 token: ${S_TOKEN:0:30}..."

if [ -z "$T_TOKEN" ] || [ -z "$S_TOKEN" ]; then
    echo "FATAL: 无法获取 token，服务器可能宕机或网络不通"
    exit 1
fi

check "错误密码应401" "401" \
    $CURL -X POST "$BASE/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$TEACHER\",\"password\":\"wrongpass\"}"

check "无 token 应401" "401" \
    $CURL "$BASE/api/users/me"

# ============================
# 用户信息
# ============================
echo ""
echo "=== 用户信息 ==="

check "教师 GET /me" "200" \
    $CURL "$BASE/api/users/me" -H "Authorization: Bearer $T_TOKEN"

T_UUID=$(safe_json uuid $CURL "$BASE/api/users/me" -H "Authorization: Bearer $T_TOKEN")
S_UUID=$(safe_json uuid $CURL "$BASE/api/users/me" -H "Authorization: Bearer $S_TOKEN")
echo "  教师 UUID: $T_UUID"
echo "  学生 UUID: $S_UUID"

# ============================
# 课程
# ============================
echo ""
echo "=== 课程 ==="

check "教师创建课程" "201" \
    $CURL -X POST "$BASE/api/courses/" \
    -H "Authorization: Bearer $T_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"测试课程_$SUFFIX\",\"description\":\"curl自动创建\"}"

C_UUID=$(safe_json uuid \
    $CURL -X POST "$BASE/api/courses/" \
    -H "Authorization: Bearer $T_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"测试课程2_$SUFFIX\"}")
echo "  课程 UUID: $C_UUID"

check "教师查看课程列表" "200" \
    $CURL "$BASE/api/courses/" -H "Authorization: Bearer $T_TOKEN"

check "教师查看课程详情" "200" \
    $CURL "$BASE/api/courses/$C_UUID" -H "Authorization: Bearer $T_TOKEN"

check "学生不能创建课程" "403" \
    $CURL -X POST "$BASE/api/courses/" \
    -H "Authorization: Bearer $S_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"学生课程\"}"

check "非成员不能看课程" "403" \
    $CURL "$BASE/api/courses/$C_UUID" -H "Authorization: Bearer $S_TOKEN"

check "不存在的课程 404" "404" \
    $CURL "$BASE/api/courses/00000000-0000-0000-0000-000000000000" -H "Authorization: Bearer $T_TOKEN"

# ============================
# 课程成员
# ============================
echo ""
echo "=== 课程成员 ==="

check "教师拉学生入课" "201" \
    $CURL -X POST "$BASE/api/courses/$C_UUID/members" \
    -H "Authorization: Bearer $T_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$STUDENT\"}"

check "查看课程成员" "200" \
    $CURL "$BASE/api/courses/$C_UUID/members" -H "Authorization: Bearer $T_TOKEN"

check "学生查看课程成员" "200" \
    $CURL "$BASE/api/courses/$C_UUID/members" -H "Authorization: Bearer $S_TOKEN"

# ============================
# 评分单元
# ============================
echo ""
echo "=== 评分单元 ==="

check "创建单元" "201" \
    $CURL -X POST "$BASE/api/courses/$C_UUID/units" \
    -H "Authorization: Bearer $T_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"平时作业\",\"weight\":0.3,\"full_score\":100.0,\"unit_order\":1}"

UNIT_ID=$(safe_json_first id $CURL "$BASE/api/courses/$C_UUID/units" -H "Authorization: Bearer $T_TOKEN")
echo "  单元 ID: $UNIT_ID"

check "查看单元列表" "200" \
    $CURL "$BASE/api/courses/$C_UUID/units" -H "Authorization: Bearer $T_TOKEN"

check "更新单元" "200" \
    $CURL -X PATCH "$BASE/api/courses/$C_UUID/units/$UNIT_ID" \
    -H "Authorization: Bearer $T_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"weight\":0.5}"

check "学生不能创建单元" "403" \
    $CURL -X POST "$BASE/api/courses/$C_UUID/units" \
    -H "Authorization: Bearer $S_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"学生单元\",\"weight\":0.3,\"full_score\":100.0}"

# ============================
# 成绩
# ============================
echo ""
echo "=== 成绩 ==="

check "教师录入成绩" "201" \
    $CURL -X POST "$BASE/api/scores/" \
    -H "Authorization: Bearer $T_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"course_uuid\":\"$C_UUID\",\"student_uuid\":\"$S_UUID\",\"unit_id\":$UNIT_ID,\"score\":88.5}"

check "学生查看自己成绩" "200" \
    $CURL "$BASE/api/scores/course/$C_UUID/my" -H "Authorization: Bearer $S_TOKEN"

check "教师查看成绩汇总" "200" \
    $CURL "$BASE/api/scores/course/$C_UUID/summary" -H "Authorization: Bearer $T_TOKEN"

check "教师看成绩分布" "200" \
    $CURL "$BASE/api/scores/course/$C_UUID/distribution" -H "Authorization: Bearer $T_TOKEN"

check "学生不能看汇总" "403" \
    $CURL "$BASE/api/scores/course/$C_UUID/summary" -H "Authorization: Bearer $S_TOKEN"

# ============================
# 公告
# ============================
echo ""
echo "=== 公告 ==="

check "教师发布公告" "201" \
    $CURL -X POST "$BASE/api/courses/$C_UUID/announcements" \
    -H "Authorization: Bearer $T_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"curl测试公告\",\"content\":\"自动测试发布\",\"ann_type\":\"课程通知\",\"pinned\":true,\"notify\":false}"

A_UUID=$(safe_json_first uuid $CURL "$BASE/api/courses/$C_UUID/announcements" -H "Authorization: Bearer $T_TOKEN")
echo "  公告 UUID: $A_UUID"

check "查看公告列表" "200" \
    $CURL "$BASE/api/courses/$C_UUID/announcements" -H "Authorization: Bearer $T_TOKEN"

check "查看单条公告" "200" \
    $CURL "$BASE/api/courses/$C_UUID/announcements/$A_UUID" -H "Authorization: Bearer $T_TOKEN"

check "学生不能发公告" "403" \
    $CURL -X POST "$BASE/api/courses/$C_UUID/announcements" \
    -H "Authorization: Bearer $S_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"学生公告\",\"content\":\"?\"}"

check "删除公告" "204" \
    $CURL -X DELETE "$BASE/api/courses/$C_UUID/announcements/$A_UUID" \
    -H "Authorization: Bearer $T_TOKEN"

# ============================
# 消息系统（QQ 风格）
# ============================
echo ""
echo "=== 消息系统 ==="

# 教师发给学生
check "教师发消息给学生" "201" \
    $CURL -X POST "$BASE/api/courses/$C_UUID/messages" \
    -H "Authorization: Bearer $T_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\":\"你好李同学！\",\"msg_type\":\"学习提醒\",\"recipient_username\":\"$STUDENT\"}"

# 教师群发
check "教师群发消息" "201" \
    $CURL -X POST "$BASE/api/courses/$C_UUID/messages" \
    -H "Authorization: Bearer $T_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\":\"全体通知：明天考试\",\"msg_type\":\"考试安排\"}"

# 学生回复教师
check "学生回复教师" "201" \
    $CURL -X POST "$BASE/api/courses/$C_UUID/messages" \
    -H "Authorization: Bearer $S_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\":\"谢谢老师！\",\"msg_type\":\"课堂反馈\",\"recipient_username\":\"$TEACHER\"}"

# 学生不能发给其他学生
check "学生不能发给其他学生" "403" \
    $CURL -X POST "$BASE/api/courses/$C_UUID/messages" \
    -H "Authorization: Bearer $S_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\":\"偷偷发给同学\",\"msg_type\":\"其他\",\"recipient_username\":\"nonexistent_student\"}"

# 学生不能群发
check "学生不能群发" "403" \
    $CURL -X POST "$BASE/api/courses/$C_UUID/messages" \
    -H "Authorization: Bearer $S_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\":\"学生群发测试\",\"msg_type\":\"其他\"}"

# 查看消息列表
check "教师查看消息列表" "200" \
    $CURL "$BASE/api/courses/$C_UUID/messages" -H "Authorization: Bearer $T_TOKEN"

check "学生查看消息列表" "200" \
    $CURL "$BASE/api/courses/$C_UUID/messages" -H "Authorization: Bearer $S_TOKEN"

# 对话查询（QQ 风格核心）
check_body "教师查看与学生对话" "200" "你好李同学" \
    $CURL "$BASE/api/courses/$C_UUID/messages/conversation/$S_UUID" \
    -H "Authorization: Bearer $T_TOKEN"

check_body "学生查看与教师对话" "200" "谢谢老师" \
    $CURL "$BASE/api/courses/$C_UUID/messages/conversation/$T_UUID" \
    -H "Authorization: Bearer $S_TOKEN"

# 未读数
check "教师查看未读数" "200" \
    $CURL "$BASE/api/courses/$C_UUID/messages/unread-count" \
    -H "Authorization: Bearer $T_TOKEN"

check "学生查看未读数" "200" \
    $CURL "$BASE/api/courses/$C_UUID/messages/unread-count" \
    -H "Authorization: Bearer $S_TOKEN"

# 标记已读（学生标记教师发来的消息为已读）
MSG_UUID=$(safe_json_first uuid \
    $CURL "$BASE/api/courses/$C_UUID/messages/conversation/$T_UUID" \
    -H "Authorization: Bearer $S_TOKEN")
check "标记消息已读" "200" \
    $CURL -X POST "$BASE/api/courses/$C_UUID/messages/$MSG_UUID/read" \
    -H "Authorization: Bearer $S_TOKEN"

# 删除消息（学生删除自己发的最后一条消息）
STUDENT_MSG_UUID=$(safe_json_last uuid \
    $CURL "$BASE/api/courses/$C_UUID/messages/conversation/$T_UUID" \
    -H "Authorization: Bearer $S_TOKEN")
check "学生删除自己的消息" "204" \
    $CURL -X DELETE "$BASE/api/courses/$C_UUID/messages/$STUDENT_MSG_UUID" \
    -H "Authorization: Bearer $S_TOKEN"

# ============================
# 播放记录
# ============================
echo ""
echo "=== 播放记录 ==="

check "查不存在视频的播放记录" "404" \
    $CURL "$BASE/api/play-records/non-existent-uuid" \
    -H "Authorization: Bearer $S_TOKEN"

check "课程播放记录列表" "200" \
    $CURL "$BASE/api/play-records/course/$C_UUID/my" \
    -H "Authorization: Bearer $S_TOKEN"

# ============================
# 视频列表
# ============================
echo ""
echo "=== 视频 ==="

check "查看课程视频列表" "200" \
    $CURL "$BASE/api/videos/course/$C_UUID" \
    -H "Authorization: Bearer $T_TOKEN"

# ============================
# 错误场景
# ============================
echo ""
echo "=== 错误场景 ==="

check "错误 token 应401" "401" \
    $CURL "$BASE/api/users/me" -H "Authorization: Bearer bad.token.here"

check "不存在的课程 404" "404" \
    $CURL "$BASE/api/courses/00000000-0000-0000-0000-000000000000" \
    -H "Authorization: Bearer $T_TOKEN"

# ============================
# 文件上传
# ============================
echo ""
echo "=== 文件上传 ==="

check "无认证上传视频应401" "401" \
    $CURL -X POST "$BASE/api/files/upload/video"

check "无认证上传封面应401" "401" \
    $CURL -X POST "$BASE/api/files/upload/cover"

# ============================
# AI Chat
# ============================
echo ""
echo "=== AI Chat ==="

check "无认证调用 AI 应401" "401" \
    $CURL -X POST "$BASE/api/ai/chat" \
    -H "Content-Type: application/json" \
    -d '{"messages":[{"role":"user","content":"hi"}]}'

echo ""
echo "==========================================="
echo "  测试完成"
echo "==========================================="
