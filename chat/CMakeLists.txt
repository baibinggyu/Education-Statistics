cmake_minimum_required(VERSION 3.16)
project(ChatClient LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Boost 1.90.0 CMake config
set(BOOST_ROOT /home/bai-yu/cpp-external/boost_1_90_0)
set(Boost_DIR /home/bai-yu/cpp-external/boost_1_90_0/stage/lib/cmake/Boost-1.90.0)
find_package(Boost CONFIG REQUIRED COMPONENTS json)
find_package(OpenSSL REQUIRED)

add_executable(chat
    main.cpp
    chat_client.cpp
)
target_include_directories(chat PRIVATE ${BOOST_ROOT})
target_link_libraries(chat PRIVATE
    Boost::json
    OpenSSL::SSL
    OpenSSL::Crypto
)
