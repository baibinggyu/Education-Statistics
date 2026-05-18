cmake_minimum_required(VERSION 3.16)
project(EduStat VERSION 0.1 LANGUAGES CXX)

set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOMOC_COMPILER_PREDEFINES OFF)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(QT NAMES Qt5 Qt6  REQUIRED COMPONENTS Core Widgets Charts Sql Network)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core Widgets Charts Sql Network)

set(PROJECT_SOURCES
        main.cpp
        mainwindow.cpp
        mainwindow.h
        mainwindow.ui
        resources.qrc
        appicon.rc
        flowlayout.h
        flowlayout.cpp
)

if(${QT_VERSION_MAJOR} GREATER_EQUAL 6)
    qt_add_executable(EduStat
        MANUAL_FINALIZATION
        ${PROJECT_SOURCES}
        teamCard.h teamCard.cpp
        flowlayout.h flowlayout.cpp
        subjectcard.h subjectcard.cpp
        scoredelegate.h scoredelegate.cpp
    )
# Define target properties for Android with Qt 6 as:
#    set_property(TARGET EduStat APPEND PROPERTY QT_ANDROID_PACKAGE_SOURCE_DIR
#                 ${CMAKE_CURRENT_SOURCE_DIR}/android)
# For more information, see https://doc.qt.io/qt-6/qt-add-executable.html#target-creation
else()
    if(ANDROID)
        add_library(EduStat SHARED
            ${PROJECT_SOURCES}
        )
# Define properties for Android with Qt 5 after find_package() calls as:
#    set(ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android")
    else()
        add_executable(EduStat
            ${PROJECT_SOURCES}
            "${CMAKE_SOURCE_DIR}/stdafx.cpp"
        )
    endif()
endif()

target_link_libraries(EduStat PRIVATE Qt${QT_VERSION_MAJOR}::Widgets Qt${QT_VERSION_MAJOR}::Charts Qt${QT_VERSION_MAJOR}::Sql Qt${QT_VERSION_MAJOR}::Network)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
if(${QT_VERSION} VERSION_LESS 6.1.0)
  set(BUNDLE_ID_OPTION MACOSX_BUNDLE_GUI_IDENTIFIER com.example.EduStat)
endif()
set_target_properties(EduStat PROPERTIES
    ${BUNDLE_ID_OPTION}
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

include(GNUInstallDirs)

install(TARGETS EduStat
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(QT_VERSION_MAJOR EQUAL 6)
    qt_finalize_executable(EduStat)
endif()
target_include_directories(EduStat PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
file(COPY 
    "${CMAKE_CURRENT_SOURCE_DIR}/init.json"
    DESTINATION  "${CMAKE_CURRENT_BINARY_DIR}")
file(COPY "${CMAKE_SOURCE_DIR}/dist" DESTINATION "${CMAKE_BINARY_DIR}")
file(GLOB testXlsx "${CMAKE_SOURCE_DIR}/*.xlsx")
file(COPY ${testXlsx} DESTINATION ${CMAKE_BINARY_DIR})
