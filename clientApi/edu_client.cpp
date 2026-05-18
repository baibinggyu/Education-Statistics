#include "edu_client.hpp"

#include <boost/json.hpp>
#include <stdexcept>

namespace json = boost::json;

// ---------- JSON helpers ----------
namespace {

// --- 构建 JSON ---
json::object to_json(const UserCreate& d) {
    return {{"username", d.username}, {"password", d.password}, {"role", d.role}};
}
json::object to_json(const UserLogin& d) {
    return {{"username", d.username}, {"password", d.password}};
}
json::object to_json(const CourseCreate& d) {
    json::object obj;
    obj["name"] = d.name;
    if (d.description) obj["description"] = *d.description;
    return obj;
}
json::object to_json(const ScoreEntry& d) {
    return {{"student_uuid", d.student_uuid}, {"score", d.score}};
}
json::object to_json(const ScoreBatchCreate& d) {
    json::array arr;
    for (auto& s : d.scores) arr.push_back(to_json(s));
    return {{"course_uuid", d.course_uuid}, {"unit_id", d.unit_id}, {"scores", arr}};
}
json::object to_json(const VideoCreate& d) {
    json::object obj;
    obj["course_uuid"] = d.course_uuid;
    obj["title"]       = d.title;
    obj["file_path"]   = d.file_path;
    obj["duration"]    = d.duration;
    obj["file_size"]   = d.file_size;
    if (d.description) obj["description"] = *d.description;
    if (d.cover_path)  obj["cover_path"]  = *d.cover_path;
    return obj;
}
json::object to_json(const PlayRecordUpdate& d) {
    return {{"video_uuid", d.video_uuid}, {"progress", d.progress}, {"completed", d.completed}};
}

// --- 解析 JSON ---
TokenOut from_json_token(const json::value& jv) {
    auto& o = jv.as_object();
    return {json::value_to<std::string>(o.at("access_token")),
            json::value_to<std::string>(o.at("token_type"))};
}
UserOut from_json_user(const json::value& jv) {
    auto& o = jv.as_object();
    return {json::value_to<std::string>(o.at("uuid")),
            json::value_to<std::string>(o.at("username")),
            json::value_to<std::string>(o.at("role")),
            json::value_to<std::string>(o.at("created_at"))};
}
StudentBriefOut from_json_student_brief(const json::value& jv) {
    auto& o = jv.as_object();
    return {json::value_to<std::string>(o.at("student_no")),
            json::value_to<std::string>(o.at("real_name"))};
}
UserMeOut from_json_user_me(const json::value& jv) {
    auto& o = jv.as_object();
    UserMeOut u;
    u.uuid     = json::value_to<std::string>(o.at("uuid"));
    u.username = json::value_to<std::string>(o.at("username"));
    u.role     = json::value_to<std::string>(o.at("role"));
    u.created_at = json::value_to<std::string>(o.at("created_at"));
    if (o.find("student") != o.end() && !o.at("student").is_null())
        u.student = from_json_student_brief(o.at("student"));
    return u;
}
TeacherBriefOut from_json_teacher(const json::value& jv) {
    auto& o = jv.as_object();
    return {json::value_to<std::string>(o.at("uuid")),
            json::value_to<std::string>(o.at("username"))};
}
CourseMyOut from_json_course_my(const json::value& jv) {
    auto& o = jv.as_object();
    CourseMyOut c;
    c.uuid       = json::value_to<std::string>(o.at("uuid"));
    c.name       = json::value_to<std::string>(o.at("name"));
    c.status     = json::value_to<std::string>(o.at("status"));
    c.my_role    = json::value_to<std::string>(o.at("my_role"));
    c.created_at = json::value_to<std::string>(o.at("created_at"));
    c.member_count = static_cast<int>(o.at("member_count").as_int64());
    c.video_count  = static_cast<int>(o.at("video_count").as_int64());
    if (o.find("description") != o.end() && !o.at("description").is_null())
        c.description = json::value_to<std::string>(o.at("description"));
    if (o.find("teacher") != o.end() && !o.at("teacher").is_null())
        c.teacher = from_json_teacher(o.at("teacher"));
    return c;
}
CourseOut from_json_course(const json::value& jv) {
    auto& o = jv.as_object();
    CourseOut c;
    c.uuid       = json::value_to<std::string>(o.at("uuid"));
    c.name       = json::value_to<std::string>(o.at("name"));
    c.status     = json::value_to<std::string>(o.at("status"));
    c.created_at = json::value_to<std::string>(o.at("created_at"));
    c.member_count = static_cast<int>(o.at("member_count").as_int64());
    c.video_count  = static_cast<int>(o.at("video_count").as_int64());
    if (o.find("description") != o.end() && !o.at("description").is_null())
        c.description = json::value_to<std::string>(o.at("description"));
    if (o.find("teacher") != o.end() && !o.at("teacher").is_null())
        c.teacher = from_json_teacher(o.at("teacher"));
    return c;
}
UnitOut from_json_unit(const json::value& jv) {
    auto& o = jv.as_object();
    return {static_cast<int>(o.at("id").as_int64()),
            json::value_to<std::string>(o.at("name")),
            o.at("weight").as_double(),
            o.at("full_score").as_double(),
            static_cast<int>(o.at("unit_order").as_int64()),
            json::value_to<std::string>(o.at("created_at"))};
}
CourseDetailOut from_json_course_detail(const json::value& jv) {
    auto& o = jv.as_object();
    CourseDetailOut c;
    c.uuid       = json::value_to<std::string>(o.at("uuid"));
    c.name       = json::value_to<std::string>(o.at("name"));
    c.status     = json::value_to<std::string>(o.at("status"));
    c.created_at = json::value_to<std::string>(o.at("created_at"));
    c.member_count = static_cast<int>(o.at("member_count").as_int64());
    if (o.find("description") != o.end() && !o.at("description").is_null())
        c.description = json::value_to<std::string>(o.at("description"));
    if (o.find("teacher") != o.end() && !o.at("teacher").is_null())
        c.teacher = from_json_teacher(o.at("teacher"));
    for (auto& u : o.at("units").as_array())
        c.units.push_back(from_json_unit(u));
    return c;
}
ScoreSingleOut from_json_score(const json::value& jv) {
    auto& o = jv.as_object();
    ScoreSingleOut s;
    s.student_uuid = json::value_to<std::string>(o.at("student_uuid"));
    s.student_no   = json::value_to<std::string>(o.at("student_no"));
    s.real_name    = json::value_to<std::string>(o.at("real_name"));
    s.course_uuid  = json::value_to<std::string>(o.at("course_uuid"));
    s.unit_id      = static_cast<int>(o.at("unit_id").as_int64());
    s.unit_name    = json::value_to<std::string>(o.at("unit_name"));
    s.score        = o.at("score").as_double();
    s.updated_at   = json::value_to<std::string>(o.at("updated_at"));
    return s;
}
PlayProgressOut from_json_progress(const json::value& jv) {
    auto& o = jv.as_object();
    return {static_cast<int>(o.at("progress").as_int64()),
            o.at("completed").as_bool()};
}
VideoOut from_json_video(const json::value& jv) {
    auto& o = jv.as_object();
    VideoOut v;
    v.uuid       = json::value_to<std::string>(o.at("uuid"));
    v.title      = json::value_to<std::string>(o.at("title"));
    v.course_uuid = json::value_to<std::string>(o.at("course_uuid"));
    v.status     = json::value_to<std::string>(o.at("status"));
    v.created_at = json::value_to<std::string>(o.at("created_at"));
    v.duration   = static_cast<int>(o.at("duration").as_int64());
    v.file_size  = static_cast<int>(o.at("file_size").as_int64());
    v.has_cover  = o.at("has_cover").as_bool();
    if (o.find("description") != o.end() && !o.at("description").is_null())
        v.description = json::value_to<std::string>(o.at("description"));
    if (o.find("course_name") != o.end() && !o.at("course_name").is_null())
        v.course_name = json::value_to<std::string>(o.at("course_name"));
    return v;
}
VideoDetailOut from_json_video_detail(const json::value& jv) {
    auto& o = jv.as_object();
    VideoDetailOut v;
    v.uuid       = json::value_to<std::string>(o.at("uuid"));
    v.title      = json::value_to<std::string>(o.at("title"));
    v.course_uuid = json::value_to<std::string>(o.at("course_uuid"));
    v.status     = json::value_to<std::string>(o.at("status"));
    v.created_at = json::value_to<std::string>(o.at("created_at"));
    v.duration   = static_cast<int>(o.at("duration").as_int64());
    v.file_size  = static_cast<int>(o.at("file_size").as_int64());
    if (o.find("description") != o.end() && !o.at("description").is_null())
        v.description = json::value_to<std::string>(o.at("description"));
    if (o.find("course_name") != o.end() && !o.at("course_name").is_null())
        v.course_name = json::value_to<std::string>(o.at("course_name"));
    if (o.find("uploader") != o.end() && !o.at("uploader").is_null())
        v.uploader = from_json_teacher(o.at("uploader"));
    if (o.find("cover_url") != o.end() && !o.at("cover_url").is_null())
        v.cover_url = json::value_to<std::string>(o.at("cover_url"));
    if (o.find("my_progress") != o.end() && !o.at("my_progress").is_null())
        v.my_progress = from_json_progress(o.at("my_progress"));
    return v;
}
ScoreDistributionOut from_json_distribution(const json::value& jv) {
    auto& o = jv.as_object();
    ScoreDistributionOut d;
    d.total   = static_cast<int>(o.at("total").as_int64());
    d.average = o.at("average").as_double();
    d.median  = o.at("median").as_double();
    d.passed  = static_cast<int>(o.at("passed").as_int64());
    d.failed  = static_cast<int>(o.at("failed").as_int64());
    for (auto& b : o.at("bands").as_array()) {
        auto& bo = b.as_object();
        d.bands.push_back({json::value_to<std::string>(bo.at("range")),
                           static_cast<int>(bo.at("count").as_int64())});
    }
    return d;
}

} // anonymous namespace

// ============================================================
// EduClient
// ============================================================

EduClient::EduClient(const EduServerConfig& cfg)
    : http_(cfg.host, cfg.port) {}

// ---- Auth ----
TokenOut EduClient::register_user(const UserCreate& data) {
    auto resp = http_.post("/api/auth/register", to_json(data));
    auto token = from_json_token(resp);
    http_.set_token(token.access_token);
    return token;
}

TokenOut EduClient::login(const UserLogin& data) {
    auto resp = http_.post("/api/auth/login", to_json(data));
    auto token = from_json_token(resp);
    http_.set_token(token.access_token);
    return token;
}

// ---- Users ----
UserMeOut EduClient::get_me() {
    return from_json_user_me(http_.get("/api/users/me"));
}

UserOut EduClient::update_me(const std::string& new_username) {
    json::object body;
    body["username"] = new_username;
    return from_json_user(http_.put("/api/users/me", body));
}

// ---- Courses ----
std::vector<CourseMyOut> EduClient::list_my_courses() {
    std::vector<CourseMyOut> ret;
    auto jv = http_.get("/api/courses/my");
    for (auto& item : jv.as_array())
        ret.push_back(from_json_course_my(item));
    return ret;
}

CourseDetailOut EduClient::get_course(const std::string& course_uuid) {
    return from_json_course_detail(
        http_.get("/api/courses/" + course_uuid));
}

CourseOut EduClient::create_course(const CourseCreate& data) {
    return from_json_course(http_.post("/api/courses", to_json(data)));
}

// ---- Units ----
UnitOut EduClient::create_unit(const std::string& course_uuid,
                               const std::string& name,
                               double weight, double full_score, int order) {
    json::object body;
    body["name"]       = name;
    body["weight"]     = weight;
    body["full_score"] = full_score;
    body["unit_order"] = order;
    return from_json_unit(
        http_.post("/api/courses/" + course_uuid + "/units", body));
}

// ---- Scores ----
std::vector<ScoreSingleOut> EduClient::list_scores(
    const std::string& course_uuid, int unit_id, int page) {
    std::string path = "/api/scores/" + course_uuid
                     + "?unit_id=" + std::to_string(unit_id)
                     + "&page=" + std::to_string(page);
    std::vector<ScoreSingleOut> ret;
    auto jv = http_.get(path);
    auto& obj = jv.as_object();
    for (auto& item : obj.at("items").as_array())
        ret.push_back(from_json_score(item));
    return ret;
}

void EduClient::batch_upload_scores(const ScoreBatchCreate& batch) {
    http_.post("/api/scores/batch", to_json(batch));
}

ScoreDistributionOut EduClient::score_distribution(
    const std::string& course_uuid, int unit_id) {
    std::string path = "/api/scores/" + course_uuid
                     + "/distribution?unit_id=" + std::to_string(unit_id);
    return from_json_distribution(http_.get(path));
}

// ---- Videos ----
VideoOut EduClient::create_video(const VideoCreate& data) {
    return from_json_video(http_.post("/api/videos", to_json(data)));
}

std::vector<VideoOut> EduClient::list_videos(const std::string& course_uuid) {
    std::string path = "/api/videos";
    if (!course_uuid.empty()) path += "?course_uuid=" + course_uuid;
    std::vector<VideoOut> ret;
    auto jv = http_.get(path);
    for (auto& item : jv.as_array())
        ret.push_back(from_json_video(item));
    return ret;
}

VideoDetailOut EduClient::get_video(const std::string& video_uuid) {
    return from_json_video_detail(http_.get("/api/videos/" + video_uuid));
}

// ---- Play Records ----
void EduClient::update_progress(const std::string& video_uuid,
                                int progress, bool completed) {
    PlayRecordUpdate data{video_uuid, progress, completed};
    http_.post("/api/play-records", to_json(data));
}

// ---- Health ----
json::value EduClient::health() {
    return http_.get("/");
}
