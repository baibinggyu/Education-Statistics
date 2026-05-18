#pragma once

#include <string>
#include <vector>

#include "config.hpp"
#include "http_client.hpp"
#include "types.hpp"

class EduClient {
public:
    explicit EduClient(const EduServerConfig& cfg);

    // ---- Auth ----
    TokenOut register_user(const UserCreate& data);
    TokenOut login(const UserLogin& data);

    // ---- Users (self) ----
    UserMeOut get_me();
    UserOut update_me(const std::string& new_username);

    // ---- Courses ----
    std::vector<CourseMyOut> list_my_courses();
    CourseDetailOut get_course(const std::string& course_uuid);
    CourseOut create_course(const CourseCreate& data);

    // ---- Units ----
    UnitOut create_unit(const std::string& course_uuid, const std::string& name,
                        double weight = 0, double full_score = 100, int order = 0);

    // ---- Scores ----
    std::vector<ScoreSingleOut> list_scores(const std::string& course_uuid,
                                            int unit_id = 0, int page = 1);
    void batch_upload_scores(const ScoreBatchCreate& batch);
    ScoreDistributionOut score_distribution(const std::string& course_uuid,
                                            int unit_id);

    // ---- Videos ----
    VideoOut create_video(const VideoCreate& data);
    std::vector<VideoOut> list_videos(const std::string& course_uuid = "");
    VideoDetailOut get_video(const std::string& video_uuid);

    // ---- Play Records ----
    void update_progress(const std::string& video_uuid, int progress, bool completed);

    // ---- Health ----
    boost::json::value health();

private:
    HttpClient http_;
};
