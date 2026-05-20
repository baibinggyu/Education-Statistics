#pragma once

#include <string>
#include <vector>

#include "config.hpp"
#include "http_client.hpp"
#include "types.hpp"

class EduClient {
public:
    explicit EduClient(const EduServerConfig& cfg);

    /// 登录后自动保存 token，后续请求自动带 Authorization 头
    void set_token(const std::string& token) { http_.set_token(token); }
    bool has_token() const { return http_.has_token(); }

    // ---- Health ----
    HttpClient::Response health();

    // ---- Auth ----
    HttpClient::Response register_user(const UserCreate& data);
    HttpClient::Response login(const UserLogin& data);

    // ---- Users (self) ----
    HttpClient::Response get_me();
    HttpClient::Response update_me(const std::string& new_username);
    HttpClient::Response bind_student(const std::string& student_no,
                                       const std::string& real_name);

    // ---- Courses ----
    HttpClient::Response create_course(const CourseCreate& data);
    HttpClient::Response list_my_courses();
    HttpClient::Response get_course(const std::string& course_uuid);
    HttpClient::Response update_course(const std::string& course_uuid,
                                       const std::string& name = "",
                                       const std::string& description = "");
    HttpClient::Response delete_course(const std::string& course_uuid);

    // ---- Course Members ----
    HttpClient::Response list_members(const std::string& course_uuid);
    HttpClient::Response add_member(const std::string& course_uuid,
                                    const std::string& username = "",
                                    const std::string& student_no = "");
    HttpClient::Response remove_member(const std::string& course_uuid,
                                       const std::string& user_uuid);

    // ---- Units ----
    HttpClient::Response create_unit(const std::string& course_uuid,
                                     const std::string& name,
                                     double weight = 0, double full_score = 100,
                                     int unit_order = 0);
    HttpClient::Response list_units(const std::string& course_uuid);
    HttpClient::Response update_unit(const std::string& course_uuid,
                                     int unit_id, const std::string& name = "",
                                     double weight = -1, double full_score = -1,
                                     int unit_order = -1);
    HttpClient::Response delete_unit(const std::string& course_uuid, int unit_id);
    HttpClient::Response reorder_units(const std::string& course_uuid,
                                       const std::vector<std::pair<int, int>>& items);

    // ---- Scores ----
    HttpClient::Response create_score(const std::string& course_uuid,
                                      const std::string& student_uuid,
                                      int unit_id, double score);
    HttpClient::Response batch_upload_scores(const ScoreBatchCreate& batch);
    HttpClient::Response get_my_scores(const std::string& course_uuid);
    HttpClient::Response get_score_summary(const std::string& course_uuid);
    HttpClient::Response get_score_distribution(const std::string& course_uuid);

    // ---- Videos ----
    HttpClient::Response create_video(const VideoCreate& data);
    HttpClient::Response list_videos(const std::string& course_uuid);
    HttpClient::Response get_video(const std::string& video_uuid);
    HttpClient::Response update_video(const std::string& video_uuid,
                                      const std::string& title = "",
                                      const std::string& description = "",
                                      const std::string& status = "");
    HttpClient::Response delete_video(const std::string& video_uuid);
    HttpClient::Response stream_video(const std::string& video_uuid);

    // ---- Play Records ----
    HttpClient::Response update_progress(const std::string& video_uuid,
                                         int progress, bool completed);
    HttpClient::Response get_play_record(const std::string& video_uuid);
    HttpClient::Response get_my_course_records(const std::string& course_uuid);

    // ---- Files ----
    HttpClient::Response upload_video(const std::string& file_path,
                                      const std::string& course_uuid);
    HttpClient::Response upload_cover(const std::string& file_path);
    HttpClient::Response get_cover(const std::string& video_uuid);

private:
    HttpClient http_;
};
