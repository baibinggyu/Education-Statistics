cmake_minimum_required(VERSION 3.20)

qt_add_executable(test_api_client
    test_api_client.cpp
    ${CMAKE_SOURCE_DIR}/api_client.cpp
)

target_link_libraries(test_api_client PRIVATE
    Qt6::Core
    Qt6::Network
    Qt6::Test
)

add_test(NAME test_api_client COMMAND test_api_client)
