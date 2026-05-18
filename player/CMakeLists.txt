cmake_minimum_required(VERSION 3.16)
project(VideoPlayer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Multimedia MultimediaWidgets)

add_executable(VideoPlayer
    main.cpp
    VideoPlayer.cpp
    VideoPlayer.h
)

target_link_libraries(VideoPlayer PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Multimedia
    Qt6::MultimediaWidgets
)
file(COPY ./mov_bbb.mp4 DESTINATION ${CMAKE_BINARY_DIR})
