cmake_minimum_required(VERSION 3.20)

project(EduStat_qml VERSION 2.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml Widgets Concurrent)

# Boost + OpenSSL (for ChatBackend)
set(BOOST_ROOT /home/bai-yu/cpp-external/boost_1_90_0)
set(Boost_DIR /home/bai-yu/cpp-external/boost_1_90_0/stage/lib/cmake/Boost-1.90.0)
find_package(Boost CONFIG REQUIRED COMPONENTS json)
find_package(OpenSSL REQUIRED)

# Suppress Qt CMake policy warnings
qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 OLD)

qt_add_executable(EduStat_qml
    main.cpp
    chat_backend.cpp
    ../chat/chat_client.cpp
)

qt_add_qml_module(EduStat_qml
    URI "EduStat"
    VERSION 2.0
    QML_FILES
        qml_ui/main.qml
        qml_ui/ClassInfoPage.qml
        qml_ui/RollCallPage.qml
        qml_ui/TeamUpPage.qml
        qml_ui/StudentInfoPage.qml
        qml_ui/SubjectManagePage.qml
        qml_ui/AddSubjectPage.qml
        qml_ui/CourseApplicationPage.qml
        qml_ui/LoginPage.qml
        qml_ui/VideoPlayerPage.qml
        qml_ui/ResourcePage.qml
        qml_ui/AnnouncementPage.qml
        qml_ui/CountdownPage.qml
        qml_ui/MessagePage.qml
        qml_ui/ChatPage.qml
)

target_include_directories(EduStat_qml PRIVATE
    ${CMAKE_SOURCE_DIR}/../chat
    ${BOOST_ROOT}
)

target_link_libraries(EduStat_qml PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::Qml
    Qt6::Widgets
    Qt6::Concurrent
    Boost::json
    OpenSSL::SSL
    OpenSSL::Crypto
)

# Copy FluentUI plugin to build directory for runtime QML import
add_custom_command(TARGET EduStat_qml POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${CMAKE_SOURCE_DIR}/FluentUI
    $<TARGET_FILE_DIR:EduStat_qml>/FluentUI
)
