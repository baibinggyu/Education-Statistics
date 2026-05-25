cmake_minimum_required(VERSION 3.20)

project(EduStat_qml VERSION 2.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml Widgets Concurrent Network Multimedia MultimediaWidgets)

# ai-sdk-cpp
set(AI_SDK_DIR /home/bai-yu/cpp-external/ai-sdk-cpp)
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
add_subdirectory(${AI_SDK_DIR} ${CMAKE_BINARY_DIR}/ai-sdk-cpp EXCLUDE_FROM_ALL)

# libxlsxwriter (static)
set(LIBXLSXWRITER_DIR /home/bai-yu/cpp-external/libxlsxwriter)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(USE_STATIC_MSVC_RUNTIME ON CACHE BOOL "" FORCE)
add_subdirectory(${LIBXLSXWRITER_DIR} ${CMAKE_BINARY_DIR}/libxlsxwriter EXCLUDE_FROM_ALL)

# Suppress Qt CMake policy warnings
qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 OLD)

qt_add_executable(EduStat_qml
    main.cpp
    agent_backend.cpp
    api_client.cpp
    video_player_proxy.cpp
    VideoPlayer.cpp
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

        qml_ui/CourseApplicationPage.qml
        qml_ui/LoginPage.qml
        qml_ui/VideoPlayerPage.qml
        qml_ui/ResourcePage.qml
        qml_ui/AnnouncementPage.qml
        qml_ui/CountdownPage.qml
        qml_ui/MessagePage.qml
        qml_ui/ChatPage.qml
    RESOURCES
        sounds/alarm.wav
)

target_link_libraries(EduStat_qml PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::Qml
    Qt6::Widgets
    Qt6::Concurrent
    Qt6::Network
    Qt6::Multimedia
    Qt6::MultimediaWidgets
    ai::core
    ai::openai
    ai::anthropic
    xlsxwriter
    ZLIB::ZLIB
)

# Path to FunASR source directory (for dev; bundled alongside binary for deploy)
set(FUNASR_SOURCE_DIR "${CMAKE_SOURCE_DIR}/../FunASR")
add_compile_definitions(FUNASR_SOURCE_DIR="${FUNASR_SOURCE_DIR}")

# Copy FluentUI plugin to build directory for runtime QML import
add_custom_command(TARGET EduStat_qml POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${CMAKE_SOURCE_DIR}/FluentUI
    $<TARGET_FILE_DIR:EduStat_qml>/FluentUI
)

# Copy FunASR asr.py to build output (for subtitle feature)
add_custom_command(TARGET EduStat_qml POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
    $<TARGET_FILE_DIR:EduStat_qml>/FunASR
    COMMAND ${CMAKE_COMMAND} -E copy
    ${FUNASR_SOURCE_DIR}/asr.py
    $<TARGET_FILE_DIR:EduStat_qml>/FunASR/asr.py
)

# ---- Tests ----
option(BUILD_EDUSTAT_TESTS "Build EduStat ApiClient tests" ON)
if(BUILD_EDUSTAT_TESTS)
    enable_testing()
    find_package(Qt6 REQUIRED COMPONENTS Test)
    add_subdirectory(tests)
endif()
