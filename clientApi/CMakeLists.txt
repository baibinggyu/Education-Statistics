cmake_minimum_required(VERSION 3.16)
project(EduClientApi LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Boost 1.90.0 CMake config
set(BOOST_ROOT /home/bai-yu/cpp-external/boost_1_90_0)
set(Boost_DIR /home/bai-yu/cpp-external/boost_1_90_0/stage/lib/cmake/Boost-1.90.0)
find_package(Boost CONFIG REQUIRED COMPONENTS json)

# Client library
add_library(clientapi STATIC
    http_client.cpp
    edu_client.cpp
)
target_include_directories(clientapi PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${BOOST_ROOT}
)
target_link_libraries(clientapi PUBLIC Boost::json)

# Test executable
add_executable(test_endpoints test_endpoints.cpp)
target_link_libraries(test_endpoints PRIVATE clientapi)
