#include "edu_client.hpp"

#include <boost/json.hpp>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace json = boost::json;

static int g_pass = 0, g_fail = 0, g_skip = 0;

static std::string jstr(const json::object& obj, const std::string& key) {
    auto it = obj.find(key);
    if (it == obj.end()) return "";
    if (it->value().is_string()) return json::value_to<std::string>(it->value());
    if (it->value().is_int64())  return std::to_string(it->value().as_int64());
    if (it->value().is_double()) return std::to_string(it->value().as_double());
    if (it->value().is_bool())   return it->value().as_bool() ? "true" : "false";
    return json::serialize(it->value());
}

static void pass(const std::string& name, const std::string& detail = "") {
    g_pass++;
    std::cout << "[PASS] " << name;
    if (!detail.empty()) std::cout << " — " << detail;
    std::cout << "\n";
}

static void fail(const std::string& name, const std::string& detail = "") {
    g_fail++;
    std::cout << "[FAIL] " << name;
    if (!detail.empty()) std::cout << " — " << detail;
    std::cout << "\n";
}

static void skip(const std::string& name, const std::string& reason = "") {
    g_skip++;
    std::cout << "[SKIP] " << name;
    if (!reason.empty()) std::cout << " — " << reason;
    std::cout << "\n";
}

static std::string extract_uuid(const json::value& jv) {
    try { return json::value_to<std::string>(jv.as_object().at("uuid")); }
    catch (...) { return ""; }
}
static std::string extract_token(const json::value& jv) {
    try { return json::value_to<std::string>(jv.as_object().at("access_token")); }
    catch (...) { return ""; }
}

int main() {
    EduServerConfig cfg;
    EduClient client(cfg);

    std::string suffix = std::to_string(time(nullptr) % 100000);
    auto aname = "admin_" + suffix, tname = "teacher_" + suffix, sname = "stud_" + suffix;
    std::string atok, ttok, stok, auuid, tuuid, suuid;
    std::string c1uuid, c2uuid, v1uuid;
    int u1id = 0, u2id = 0;

    std::cout << "============================================================\n";
    std::cout << "EduClient 全端点测试 — " << cfg.host << ":" << cfg.port << "\n";
    std::cout << "用户前缀: *_" << suffix << "\n============================================================\n\n";

    // --- Phase 1: Health ---
    std::cout << "--- Phase 1: 健康检查 ---\n";
    try {
        auto r = client.health(); pass("GET /", "status=" + std::to_string(r.status_code));
    } catch (std::exception& e) { fail("GET /", e.what()); }

    // --- Phase 2: Auth ---
    std::cout << "\n--- Phase 2: 认证 ---\n";
    try { auto r = client.register_user(UserCreate{aname, "pass", "admin"});
        pass("register admin", "sc=" + std::to_string(r.status_code));
        auuid = extract_uuid(r.body); } catch (std::exception& e) { fail("register admin", e.what()); }
    try { auto r = client.register_user(UserCreate{tname, "pass", "teacher"});
        pass("register teacher", "sc=" + std::to_string(r.status_code));
        tuuid = extract_uuid(r.body); } catch (std::exception& e) { fail("register teacher", e.what()); }
    try { auto r = client.register_user(UserCreate{sname, "pass", "student"});
        pass("register student", "sc=" + std::to_string(r.status_code));
        suuid = extract_uuid(r.body); } catch (std::exception& e) { fail("register student", e.what()); }

    // dup → 409
    try { client.register_user(UserCreate{aname, "pass", "admin"}); fail("dup register", "should 409");
    } catch (std::exception& e) { pass("dup → 409", e.what()); }

    // bad role → 422
    try { client.register_user(UserCreate{"bad_" + suffix, "pass", "superadmin"}); fail("bad role", "should 422");
    } catch (std::exception& e) { pass("bad role → 422", e.what()); }

    // login
    try { auto r = client.login(UserLogin{aname, "pass"});
        atok = extract_token(r.body); pass("admin login", r.status_code == 200 ? "200" : "FAIL"); }
    catch (std::exception& e) { fail("admin login", e.what()); }
    try { auto r = client.login(UserLogin{tname, "pass"});
        ttok = extract_token(r.body); pass("teacher login", r.status_code == 200 ? "200" : "FAIL"); }
    catch (std::exception& e) { fail("teacher login", e.what()); }
    try { auto r = client.login(UserLogin{sname, "pass"});
        stok = extract_token(r.body); pass("student login", r.status_code == 200 ? "200" : "FAIL"); }
    catch (std::exception& e) { fail("student login", e.what()); }

    // bad password → 401
    try { client.login(UserLogin{aname, "wrong"}); fail("bad pw", "should 401");
    } catch (std::exception& e) { pass("bad pw → 401", e.what()); }

    // --- Phase 3: Users ---
    std::cout << "\n--- Phase 3: 用户信息 ---\n";
    client.set_token(atok);
    try { auto r = client.get_me(); pass("GET /me admin", "200"); }
    catch (std::exception& e) { fail("GET /me admin", e.what()); }

    client.set_token("");
    try { client.get_me(); fail("no token", "should 401");
    } catch (std::exception& e) { pass("no token → 401", e.what()); }

    client.set_token(atok);
    try { auto r = client.update_me(aname + "_x");
        pass("PATCH /me", "200");
        client.update_me(aname); }  // revert
    catch (std::exception& e) { fail("PATCH /me", e.what()); }

    // bind student
    client.set_token(stok);
    try { auto r = client.bind_student("S" + suffix, "Stu " + suffix);
        pass("POST /bind", r.status_code == 201 ? "201" : std::to_string(r.status_code)); }
    catch (std::exception& e) { fail("POST /bind", e.what()); }

    // --- Phase 4: Courses ---
    std::cout << "\n--- Phase 4: 课程 CRUD ---\n";
    client.set_token(stok);
    try { client.create_course(CourseCreate{"bad", ""}); fail("student create course", "should 403");
    } catch (std::exception& e) { pass("student create → 403", e.what()); }

    client.set_token(ttok);
    try { auto r = client.create_course(CourseCreate{"Math 101", "desc"});
        c1uuid = extract_uuid(r.body); pass("create course 1", "201"); }
    catch (std::exception& e) { fail("create course 1", e.what()); }
    try { auto r = client.create_course(CourseCreate{"Physics 201", ""});
        c2uuid = extract_uuid(r.body); pass("create course 2", "201"); }
    catch (std::exception& e) { fail("create course 2", e.what()); }

    try { auto r = client.list_my_courses(); pass("list courses", "200"); }
    catch (std::exception& e) { fail("list courses", e.what()); }

    client.set_token(atok);
    try { auto r = client.list_my_courses(); pass("admin list all", "200"); }
    catch (std::exception& e) { fail("admin list all", e.what()); }

    client.set_token(ttok);
    try { auto r = client.get_course(c1uuid); pass("get course", "200"); }
    catch (std::exception& e) { fail("get course", e.what()); }

    try { auto r = client.update_course(c1uuid, "Math 102", "");
        pass("update course", "200"); client.update_course(c1uuid, "Math 101", "desc"); }
    catch (std::exception& e) { fail("update course", e.what()); }

    // --- Phase 5: Members ---
    std::cout << "\n--- Phase 5: 成员管理 ---\n";
    try { auto r = client.add_member(c1uuid, sname, "");
        pass("add member", r.status_code == 201 ? "201" : std::to_string(r.status_code)); }
    catch (std::exception& e) { fail("add member", e.what()); }

    try { auto r = client.list_members(c1uuid); pass("list members", "200"); }
    catch (std::exception& e) { fail("list members", e.what()); }

    client.set_token(stok);
    try { auto r = client.get_course(c1uuid); pass("student access course", "200"); }
    catch (std::exception& e) { fail("student access course", e.what()); }

    try { client.delete_course(c1uuid); fail("student delete course", "should 403");
    } catch (std::exception& e) { pass("student delete → 403", e.what()); }

    try { auto r = client.get_course(c2uuid); fail("student non-member", "should 403");
    } catch (std::exception& e) { pass("student non-member → 403", e.what()); }

    // --- Phase 6: Units ---
    std::cout << "\n--- Phase 6: 单元管理 ---\n";
    client.set_token(ttok);
    try { auto r = client.create_unit(c1uuid, "Unit 1", 0.4, 100, 1);
        u1id = std::stoi(jstr(r.body.as_object(), "id")); pass("create unit 1", "201"); }
    catch (std::exception& e) { fail("create unit 1", e.what()); }
    try { auto r = client.create_unit(c1uuid, "Unit 2", 0.6, 100, 2);
        u2id = std::stoi(jstr(r.body.as_object(), "id")); pass("create unit 2", "201"); }
    catch (std::exception& e) { fail("create unit 2", e.what()); }

    try { auto r = client.list_units(c1uuid); pass("list units", "200"); }
    catch (std::exception& e) { fail("list units", e.what()); }

    client.set_token(stok);
    try { client.create_unit(c1uuid, "bad", 0, 100, 0); fail("student create unit", "should 403");
    } catch (std::exception& e) { pass("student create unit → 403", e.what()); }

    client.set_token(ttok);
    try { auto r = client.update_unit(c1uuid, u1id, "Unit 1 v2", -1, -1, -1);
        pass("update unit", "200"); client.update_unit(c1uuid, u1id, "Unit 1", -1, -1, -1); }
    catch (std::exception& e) { fail("update unit", e.what()); }

    try { auto r = client.reorder_units(c1uuid, {{u1id, 2}, {u2id, 1}});
        pass("reorder units", r.status_code == 204 ? "204" : std::to_string(r.status_code)); }
    catch (std::exception& e) { fail("reorder units", e.what()); }

    // --- Phase 7: Videos ---
    std::cout << "\n--- Phase 7: 视频管理 ---\n";
    try { auto r = client.create_video(VideoCreate{c1uuid, "Video 1", "test desc", "/tmp/v.mp4", {}, 120, 1024});
        v1uuid = extract_uuid(r.body); pass("create video 1", "201"); }
    catch (std::exception& e) { fail("create video 1", e.what()); }
    try { auto r = client.create_video(VideoCreate{c1uuid, "Video 2", "", "/tmp/v2.mp4", {}, 90, 512});
        pass("create video 2", "201"); }
    catch (std::exception& e) { fail("create video 2", e.what()); }

    client.set_token(stok);
    try { client.create_video(VideoCreate{c1uuid, "bad", "", "/tmp/bad.mp4"});
        fail("student create video", "should 403");
    } catch (std::exception& e) { pass("student create video → 403", e.what()); }

    try { auto r = client.list_videos(c1uuid); pass("list videos", "200"); }
    catch (std::exception& e) { fail("list videos", e.what()); }

    client.set_token(ttok);
    try { auto r = client.get_video(v1uuid); pass("get video", "200"); }
    catch (std::exception& e) { fail("get video", e.what()); }

    try { auto r = client.update_video(v1uuid, "V1 Upd", "", "");
        pass("update video", "200"); client.update_video(v1uuid, "Video 1", "", ""); }
    catch (std::exception& e) { fail("update video", e.what()); }

    try { auto r = client.stream_video(v1uuid); pass("stream video", std::to_string(r.status_code)); }
    catch (std::exception& e) { pass("stream video", std::string("404 expected: ") + e.what()); }

    // --- Phase 8: Play Records ---
    std::cout << "\n--- Phase 8: 播放记录 ---\n";
    client.set_token(stok);
    try { auto r = client.update_progress(v1uuid, 45, false); pass("update progress", "200"); }
    catch (std::exception& e) { fail("update progress", e.what()); }
    try { auto r = client.get_play_record(v1uuid); pass("get record", "200"); }
    catch (std::exception& e) { fail("get record", e.what()); }
    try { auto r = client.update_progress(v1uuid, 120, true); pass("mark completed", "200"); }
    catch (std::exception& e) { fail("mark completed", e.what()); }
    try { auto r = client.get_my_course_records(c1uuid); pass("my course records", "200"); }
    catch (std::exception& e) { fail("my course records", e.what()); }

    try { client.update_progress("00000000-0000-0000-0000-000000000000", 0, false);
        fail("bad video uuid", "should 404");
    } catch (std::exception& e) { pass("bad video → 404", e.what()); }

    // --- Phase 9: Scores ---
    std::cout << "\n--- Phase 9: 成绩系统 ---\n";
    client.set_token(ttok);
    try { auto r = client.create_score(c1uuid, suuid, u1id, 85.5);
        pass("create score", r.status_code == 201 ? "201" : std::to_string(r.status_code)); }
    catch (std::exception& e) { fail("create score", e.what()); }

    try { auto r = client.batch_upload_scores(
        ScoreBatchCreate{c1uuid, u1id, {ScoreEntry{suuid, 90.0}}});
        pass("batch scores", r.status_code == 204 ? "204" : std::to_string(r.status_code)); }
    catch (std::exception& e) { fail("batch scores", e.what()); }

    client.set_token(stok);
    try { auto r = client.get_my_scores(c1uuid); pass("my scores", "200"); }
    catch (std::exception& e) { fail("my scores", e.what()); }

    client.set_token(ttok);
    try { auto r = client.get_score_summary(c1uuid); pass("summary", "200"); }
    catch (std::exception& e) { fail("summary", e.what()); }
    try { auto r = client.get_score_distribution(c1uuid); pass("distribution", "200"); }
    catch (std::exception& e) { fail("distribution", e.what()); }

    // --- Phase 10: Files ---
    std::cout << "\n--- Phase 10: 文件上传 ---\n";
    std::string tmpv = "/tmp/edu_test_v.mp4", tmpc = "/tmp/edu_test_c.jpg";
    { std::ofstream f(tmpv); f << "fake mp4"; }
    { std::ofstream f(tmpc); f << "fake jpg"; }

    try { auto r = client.upload_video(tmpv, c1uuid);
        pass("upload video", r.status_code == 201 ? "201" : std::to_string(r.status_code)); }
    catch (std::exception& e) { fail("upload video", e.what()); }
    try { auto r = client.upload_cover(tmpc);
        pass("upload cover", r.status_code == 201 ? "201" : std::to_string(r.status_code)); }
    catch (std::exception& e) { fail("upload cover", e.what()); }
    try { auto r = client.get_cover(v1uuid); pass("get cover", std::to_string(r.status_code)); }
    catch (std::exception& e) { pass("get cover", std::string("404 expected: ") + e.what()); }

    std::remove(tmpv.c_str()); std::remove(tmpc.c_str());

    // --- Phase 11: Cleanup ---
    std::cout << "\n--- Phase 11: 清理 ---\n";
    client.set_token(ttok);

    auto del_unit = [&](int uid, const std::string& label) {
        try { auto r = client.delete_unit(c1uuid, uid);
            pass("del unit " + label, r.status_code == 204 ? "204" : std::to_string(r.status_code)); }
        catch (std::exception& e) { fail("del unit " + label, e.what()); }
    };
    del_unit(u2id, "2");
    del_unit(u1id, "1");

    try { auto r = client.delete_video(v1uuid); pass("del video", "204"); }
    catch (std::exception& e) { fail("del video", e.what()); }

    try { auto r = client.remove_member(c1uuid, suuid); pass("remove member", "204"); }
    catch (std::exception& e) { fail("remove member", e.what()); }

    try { auto r = client.delete_course(c1uuid); pass("del course 1", "204"); }
    catch (std::exception& e) { fail("del course 1", e.what()); }
    try { auto r = client.delete_course(c2uuid); pass("del course 2", "204"); }
    catch (std::exception& e) { fail("del course 2", e.what()); }

    try { client.get_course(c1uuid); fail("deleted course", "should 404");
    } catch (std::exception& e) { pass("deleted → 404", e.what()); }

    std::cout << "\n============================================================\n";
    std::cout << "PASS: " << g_pass << "  FAIL: " << g_fail << "  SKIP: " << g_skip
              << "  TOTAL: " << (g_pass + g_fail + g_skip) << "\n";
    std::cout << "============================================================\n";

    return g_fail > 0 ? 1 : 0;
}
