#pragma once

#include <optional>
#include <string>
#include <vector>

// ----- Auth -----
struct UserCreate {
    std::string username;
    std::string password;
    std::string role = "student";
};

struct UserLogin {
    std::string username;
    std::string password;
};

struct TokenOut {
    std::string access_token;
    std::string token_type = "bearer";
};

// ----- User -----
struct UserOut {
    std::string uuid;
    std::string username;
    std::string role;
    std::string created_at;
};

struct StudentBriefOut {
    std::string student_no;
    std::string real_name;
};

struct UserMeOut {
    std::string uuid;
    std::string username;
    std::string role;
    std::string created_at;
    std::optional<StudentBriefOut> student;
};

struct UserPageOut {
    std::vector<UserOut> items;
    int total = 0;
    int page  = 0;
    int size  = 0;
};

// ----- Course -----
struct TeacherBriefOut {
    std::string uuid;
    std::string username;
};

struct CourseCreate {
    std::string name;
    std::optional<std::string> description;
};

struct CourseOut {
    std::string uuid;
    std::string name;
    std::optional<std::string> description;
    std::optional<TeacherBriefOut> teacher;
    std::string status;
    int member_count = 0;
    int video_count  = 0;
    std::string created_at;
};

struct CourseMyOut {
    std::string uuid;
    std::string name;
    std::optional<std::string> description;
    std::optional<TeacherBriefOut> teacher;
    std::string status;
    int member_count = 0;
    int video_count  = 0;
    std::string my_role;
    std::string created_at;
};

// ----- Unit -----
struct UnitOut {
    int id = 0;
    std::string name;
    double weight     = 0;
    double full_score = 100;
    int unit_order    = 0;
    std::string created_at;
};

struct CourseDetailOut {
    std::string uuid;
    std::string name;
    std::optional<std::string> description;
    std::optional<TeacherBriefOut> teacher;
    std::string status;
    std::vector<UnitOut> units;
    int member_count = 0;
    std::string created_at;
};

// ----- Score -----
struct ScoreSingleOut {
    std::string student_uuid;
    std::string student_no;
    std::string real_name;
    std::string course_uuid;
    int unit_id = 0;
    std::string unit_name;
    double score = 0;
    std::string updated_at;
};

struct ScoreEntry {
    std::string student_uuid;
    double score = 0;
};

struct ScoreBatchCreate {
    std::string course_uuid;
    int unit_id = 0;
    std::vector<ScoreEntry> scores;
};

struct ScoreDistributionOut {
    struct Band {
        std::string range;
        int count = 0;
    };
    std::vector<Band> bands;
    int total   = 0;
    double average = 0;
    double median  = 0;
    int passed  = 0;
    int failed  = 0;
};

// ----- Video -----
struct VideoCreate {
    std::string course_uuid;
    std::string title;
    std::optional<std::string> description;
    std::string file_path;
    std::optional<std::string> cover_path;
    int duration  = 0;
    int file_size = 0;
};

struct PlayProgressOut {
    int progress  = 0;
    bool completed = false;
};

struct VideoOut {
    std::string uuid;
    std::string title;
    std::optional<std::string> description;
    std::string course_uuid;
    std::optional<std::string> course_name;
    int duration  = 0;
    int file_size = 0;
    bool has_cover = false;
    std::string status;
    std::string created_at;
};

struct VideoDetailOut {
    std::string uuid;
    std::string title;
    std::optional<std::string> description;
    std::string course_uuid;
    std::optional<std::string> course_name;
    std::optional<TeacherBriefOut> uploader;
    int duration  = 0;
    int file_size = 0;
    std::optional<std::string> cover_url;
    std::string status;
    std::optional<PlayProgressOut> my_progress;
    std::string created_at;
};

// ----- Play Record -----
struct PlayRecordUpdate {
    std::string video_uuid;
    int progress = 0;
    bool completed = false;
};

// ----- File -----
struct FileUploadOut {
    std::string file_path;
    int file_size = 0;
    std::string original_name;
};
