cmake_minimum_required(VERSION 3.16)
project(EduClientApi LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Boost 1.90.0 CMake config
set(BOOST_ROOT /home/bai-yu/cpp-external/boost_1_90_0)
set(Boost_DIR /home/bai-yu/cpp-external/boost_1_90_0/stage/lib/cmake/Boost-1.90.0)
find_package(Boost CONFIG REQUIRED COMPONENTS json)

add_executable(edu_client
    main.cpp
    http_client.cpp
    edu_client.cpp
)
target_include_directories(edu_client PRIVATE ${BOOST_ROOT})
target_link_libraries(edu_client PRIVATE Boost::json)
