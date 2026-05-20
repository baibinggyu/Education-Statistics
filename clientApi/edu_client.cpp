#include "edu_client.hpp"

#include <boost/json.hpp>

namespace json = boost::json;

// ============================================================
// JSON helpers
// ============================================================
namespace {

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

} // namespace

// ============================================================
// EduClient
// ============================================================

EduClient::EduClient(const EduServerConfig& cfg)
    : http_(cfg.host, cfg.port) {}

// ---- Health ----
HttpClient::Response EduClient::health() {
    return http_.get("/");
}

// ---- Auth ----
HttpClient::Response EduClient::register_user(const UserCreate& data) {
    return http_.post("/api/auth/register", to_json(data));
}

HttpClient::Response EduClient::login(const UserLogin& data) {
    return http_.post("/api/auth/login", to_json(data));
}

// ---- Users ----
HttpClient::Response EduClient::get_me() {
    return http_.get("/api/users/me");
}

HttpClient::Response EduClient::update_me(const std::string& new_username) {
    json::object body;
    body["username"] = new_username;
    return http_.patch("/api/users/me", body);
}

HttpClient::Response EduClient::bind_student(const std::string& student_no,
                                              const std::string& real_name) {
    json::object body;
    body["student_no"] = student_no;
    body["real_name"] = real_name;
    return http_.post("/api/users/bind", body);
}

// ---- Courses ----
HttpClient::Response EduClient::create_course(const CourseCreate& data) {
    return http_.post("/api/courses/", to_json(data));
}

HttpClient::Response EduClient::list_my_courses() {
    return http_.get("/api/courses/");
}

HttpClient::Response EduClient::get_course(const std::string& course_uuid) {
    return http_.get("/api/courses/" + course_uuid);
}

HttpClient::Response EduClient::update_course(const std::string& course_uuid,
                                               const std::string& name,
                                               const std::string& description) {
    json::object body;
    if (!name.empty())        body["name"] = name;
    if (!description.empty()) body["description"] = description;
    return http_.patch("/api/courses/" + course_uuid, body);
}

HttpClient::Response EduClient::delete_course(const std::string& course_uuid) {
    return http_.del("/api/courses/" + course_uuid);
}

// ---- Course Members ----
HttpClient::Response EduClient::list_members(const std::string& course_uuid) {
    return http_.get("/api/courses/" + course_uuid + "/members");
}

HttpClient::Response EduClient::add_member(const std::string& course_uuid,
                                            const std::string& username,
                                            const std::string& student_no) {
    json::object body;
    if (!username.empty())    body["username"] = username;
    if (!student_no.empty())  body["student_no"] = student_no;
    return http_.post("/api/courses/" + course_uuid + "/members", body);
}

HttpClient::Response EduClient::remove_member(const std::string& course_uuid,
                                               const std::string& user_uuid) {
    return http_.del("/api/courses/" + course_uuid + "/members/" + user_uuid);
}

// ---- Units ----
HttpClient::Response EduClient::create_unit(const std::string& course_uuid,
                                             const std::string& name,
                                             double weight, double full_score,
                                             int unit_order) {
    json::object body;
    body["name"]       = name;
    body["weight"]     = weight;
    body["full_score"] = full_score;
    body["unit_order"] = unit_order;
    return http_.post("/api/courses/" + course_uuid + "/units", body);
}

HttpClient::Response EduClient::list_units(const std::string& course_uuid) {
    return http_.get("/api/courses/" + course_uuid + "/units");
}

HttpClient::Response EduClient::update_unit(const std::string& course_uuid,
                                             int unit_id, const std::string& name,
                                             double weight, double full_score,
                                             int unit_order) {
    json::object body;
    if (!name.empty())       body["name"]       = name;
    if (weight >= 0)         body["weight"]     = weight;
    if (full_score >= 0)     body["full_score"] = full_score;
    if (unit_order >= 0)     body["unit_order"] = unit_order;
    return http_.patch("/api/courses/" + course_uuid + "/units/"
                       + std::to_string(unit_id), body);
}

HttpClient::Response EduClient::delete_unit(const std::string& course_uuid,
                                             int unit_id) {
    return http_.del("/api/courses/" + course_uuid + "/units/"
                     + std::to_string(unit_id));
}

HttpClient::Response EduClient::reorder_units(
    const std::string& course_uuid,
    const std::vector<std::pair<int, int>>& items) {
    json::array arr;
    for (auto& kv : items)
        arr.push_back({{"unit_id", kv.first}, {"unit_order", kv.second}});
    return http_.post("/api/courses/" + course_uuid + "/units/reorder", arr);
}

// ---- Scores ----
HttpClient::Response EduClient::create_score(const std::string& course_uuid,
                                              const std::string& student_uuid,
                                              int unit_id, double score) {
    json::object body;
    body["course_uuid"]  = course_uuid;
    body["student_uuid"] = student_uuid;
    body["unit_id"]      = unit_id;
    body["score"]        = score;
    return http_.post("/api/scores/", body);
}

HttpClient::Response EduClient::batch_upload_scores(const ScoreBatchCreate& batch) {
    return http_.post("/api/scores/batch", to_json(batch));
}

HttpClient::Response EduClient::get_my_scores(const std::string& course_uuid) {
    return http_.get("/api/scores/course/" + course_uuid + "/my");
}

HttpClient::Response EduClient::get_score_summary(const std::string& course_uuid) {
    return http_.get("/api/scores/course/" + course_uuid + "/summary");
}

HttpClient::Response EduClient::get_score_distribution(const std::string& course_uuid) {
    return http_.get("/api/scores/course/" + course_uuid + "/distribution");
}

// ---- Videos ----
HttpClient::Response EduClient::create_video(const VideoCreate& data) {
    return http_.post("/api/videos/", to_json(data));
}

HttpClient::Response EduClient::list_videos(const std::string& course_uuid) {
    return http_.get("/api/videos/course/" + course_uuid);
}

HttpClient::Response EduClient::get_video(const std::string& video_uuid) {
    return http_.get("/api/videos/" + video_uuid);
}

HttpClient::Response EduClient::update_video(const std::string& video_uuid,
                                              const std::string& title,
                                              const std::string& description,
                                              const std::string& status) {
    json::object body;
    if (!title.empty())       body["title"]       = title;
    if (!description.empty()) body["description"] = description;
    if (!status.empty())      body["status"]      = status;
    return http_.patch("/api/videos/" + video_uuid, body);
}

HttpClient::Response EduClient::delete_video(const std::string& video_uuid) {
    return http_.del("/api/videos/" + video_uuid);
}

HttpClient::Response EduClient::stream_video(const std::string& video_uuid) {
    return http_.get("/api/videos/" + video_uuid + "/stream");
}

// ---- Play Records ----
HttpClient::Response EduClient::update_progress(const std::string& video_uuid,
                                                 int progress, bool completed) {
    json::object body;
    body["video_uuid"] = video_uuid;
    body["progress"]   = progress;
    body["completed"]  = completed;
    return http_.post("/api/play-records/update", body);
}

HttpClient::Response EduClient::get_play_record(const std::string& video_uuid) {
    return http_.get("/api/play-records/" + video_uuid);
}

HttpClient::Response EduClient::get_my_course_records(const std::string& course_uuid) {
    return http_.get("/api/play-records/course/" + course_uuid + "/my");
}

// ---- Files ----
HttpClient::Response EduClient::upload_video(const std::string& file_path,
                                              const std::string& course_uuid) {
    return http_.upload("/api/files/upload/video?course_uuid=" + course_uuid,
                        "file", file_path);
}

HttpClient::Response EduClient::upload_cover(const std::string& file_path) {
    return http_.upload("/api/files/upload/cover", "file", file_path);
}

HttpClient::Response EduClient::get_cover(const std::string& video_uuid) {
    return http_.get("/api/files/cover/" + video_uuid);
}
