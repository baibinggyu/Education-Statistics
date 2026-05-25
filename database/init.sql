CREATE DATABASE IF NOT EXISTS edu_server_database
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE edu_server_database;

-- users
CREATE TABLE IF NOT EXISTS users (
                                     id BIGINT PRIMARY KEY AUTO_INCREMENT,
                                     uuid CHAR(36) NOT NULL UNIQUE,

                                     username VARCHAR(64) NOT NULL UNIQUE,
                                     password_hash VARCHAR(255) NOT NULL,

                                     role ENUM('student', 'teacher', 'admin')
                                         NOT NULL DEFAULT 'student',

                                     status TINYINT NOT NULL DEFAULT 1,

                                     created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- students
CREATE TABLE IF NOT EXISTS students (
                                        id BIGINT PRIMARY KEY AUTO_INCREMENT,

                                        user_id BIGINT UNIQUE,

                                        student_no VARCHAR(64) NOT NULL UNIQUE,
                                        real_name VARCHAR(64) NOT NULL,

                                        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

                                        FOREIGN KEY (user_id) REFERENCES users(id)
);

-- courses
CREATE TABLE IF NOT EXISTS courses (
                                       id BIGINT PRIMARY KEY AUTO_INCREMENT,

                                       uuid CHAR(36) NOT NULL UNIQUE,

                                       name VARCHAR(128) NOT NULL,
                                       description TEXT,

                                       teacher_id BIGINT NOT NULL,

                                       status ENUM('normal', 'hidden', 'deleted')
                                           NOT NULL DEFAULT 'normal',

                                       created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

                                       FOREIGN KEY (teacher_id) REFERENCES users(id)
);

-- course_members
CREATE TABLE IF NOT EXISTS course_members (
                                              id BIGINT PRIMARY KEY AUTO_INCREMENT,

                                              course_id BIGINT NOT NULL,
                                              user_id BIGINT NOT NULL,

                                              member_role ENUM('student', 'teacher')
                                                               NOT NULL DEFAULT 'student',

                                              created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

                                              UNIQUE KEY uk_course_user (course_id, user_id),

                                              FOREIGN KEY (course_id) REFERENCES courses(id),
                                              FOREIGN KEY (user_id) REFERENCES users(id)
);

-- units
CREATE TABLE IF NOT EXISTS units (
                                     id BIGINT PRIMARY KEY AUTO_INCREMENT,

                                     course_id BIGINT NOT NULL,

                                     name VARCHAR(128) NOT NULL,

                                     weight DOUBLE DEFAULT 0,
                                     full_score DOUBLE DEFAULT 100,

                                     unit_order INT NOT NULL DEFAULT 0,

                                     created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

                                     UNIQUE KEY uk_course_unit_name (course_id, name),

                                     FOREIGN KEY (course_id) REFERENCES courses(id)
);

-- scores
CREATE TABLE IF NOT EXISTS scores (
                                      id BIGINT PRIMARY KEY AUTO_INCREMENT,

                                      student_id BIGINT NOT NULL,
                                      course_id BIGINT NOT NULL,
                                      unit_id BIGINT NOT NULL,

                                      score DOUBLE,

                                      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

                                      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                                          ON UPDATE CURRENT_TIMESTAMP,

                                      UNIQUE KEY uk_student_course_unit (
                                                                         student_id,
                                                                         course_id,
                                                                         unit_id
                                          ),

                                      FOREIGN KEY (student_id) REFERENCES students(id),
                                      FOREIGN KEY (course_id) REFERENCES courses(id),
                                      FOREIGN KEY (unit_id) REFERENCES units(id)
);

-- videos
CREATE TABLE IF NOT EXISTS videos (
                                      id BIGINT PRIMARY KEY AUTO_INCREMENT,

                                      uuid CHAR(36) NOT NULL UNIQUE,

                                      course_id BIGINT NOT NULL,

                                      uploader_id BIGINT NOT NULL,

                                      title VARCHAR(255) NOT NULL,
                                      description TEXT,

                                      file_path VARCHAR(255) NOT NULL,

                                      cover_path VARCHAR(255),

                                      duration INT DEFAULT 0,

                                      file_size BIGINT DEFAULT 0,

                                      status ENUM('normal', 'hidden', 'deleted')
                                          NOT NULL DEFAULT 'normal',

                                      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

                                      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                                          ON UPDATE CURRENT_TIMESTAMP,

                                      FOREIGN KEY (course_id) REFERENCES courses(id),
                                      FOREIGN KEY (uploader_id) REFERENCES users(id)
);

-- play_records
CREATE TABLE IF NOT EXISTS play_records (
                                            id BIGINT PRIMARY KEY AUTO_INCREMENT,

                                            user_id BIGINT NOT NULL,
                                            video_id BIGINT NOT NULL,

    -- 当前播放进度（秒）
                                            progress INT NOT NULL DEFAULT 0,

    -- 0 未完成，1 已完成
                                            completed TINYINT NOT NULL DEFAULT 0,

                                            last_played_at DATETIME DEFAULT CURRENT_TIMESTAMP
                                                ON UPDATE CURRENT_TIMESTAMP,

                                            UNIQUE KEY uk_user_video (user_id, video_id),

                                            FOREIGN KEY (user_id) REFERENCES users(id),
                                            FOREIGN KEY (video_id) REFERENCES videos(id)
);

-- -------------------------------------------
-- 考勤签到表
-- -------------------------------------------
CREATE TABLE IF NOT EXISTS attendances (
                                            id BIGINT AUTO_INCREMENT PRIMARY KEY,
                                            uuid VARCHAR(36) NOT NULL UNIQUE COMMENT '外部UUID',
                                            course_id BIGINT NOT NULL,
                                            created_by BIGINT NOT NULL COMMENT '发起签到的教师',
                                            title VARCHAR(255) NOT NULL COMMENT '签到标题',
                                            status ENUM('open','closed') NOT NULL DEFAULT 'open' COMMENT '进行中/已结束',
                                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                                            closed_at DATETIME DEFAULT NULL,
                                            FOREIGN KEY (course_id) REFERENCES courses(id),
                                            FOREIGN KEY (created_by) REFERENCES users(id)
);

-- -------------------------------------------
-- 考勤记录表
-- -------------------------------------------
CREATE TABLE IF NOT EXISTS attendance_records (
                                            id BIGINT AUTO_INCREMENT PRIMARY KEY,
                                            attendance_id BIGINT NOT NULL,
                                            student_id BIGINT NOT NULL COMMENT '学生用户ID',
                                            status ENUM('present','absent','late','leave') NOT NULL DEFAULT 'present',
                                            note TEXT,
                                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                                            UNIQUE KEY uk_attendance_student (attendance_id, student_id),
                                            FOREIGN KEY (attendance_id) REFERENCES attendances(id),
                                            FOREIGN KEY (student_id) REFERENCES users(id)
);
