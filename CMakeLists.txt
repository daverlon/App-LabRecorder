cmake_minimum_required(VERSION 3.12)

project(LabRecorder
    DESCRIPTION "Record and write LabStreamingLayer streams to an XDF file"
    HOMEPAGE_URL "https://github.com/labstreaminglayer/App-LabRecorder/"
    LANGUAGES C CXX
    VERSION 1.16.4)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake" ${CMAKE_MODULE_PATH})

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(BUILD_GUI "Build the GUI, set to off for CLI only build" ON)

set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO")
set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "")

# ---- LSL ----
if(ANDROID)
    set(LIBLSL_SOURCE_PATH "../../LSL/liblsl" CACHE STRING "Path to liblsl sources")
    add_subdirectory(${LIBLSL_SOURCE_PATH} liblsl_bin)
    add_library(LSL::lsl ALIAS lsl)
else()
    find_package(LSL REQUIRED
        HINTS ${LSL_INSTALL_ROOT}
        "${CMAKE_CURRENT_LIST_DIR}/../../LSL/liblsl/build/"
        "${CMAKE_CURRENT_LIST_DIR}/../../LSL/liblsl/build/install"
        "${CMAKE_CURRENT_LIST_DIR}/../../LSL/liblsl/out/build/x64-Release"
        "${CMAKE_CURRENT_LIST_DIR}/../../LSL/liblsl/out/install/x64-Release"
        PATH_SUFFIXES share/LSL)
endif()

# ---- Qt ----
if (BUILD_GUI)
    set(CMAKE_AUTOMOC ON)
    set(CMAKE_AUTORCC ON)
    set(CMAKE_AUTOUIC ON)
    find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core)
    find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core Widgets Network DBus)
endif()

find_package(Threads REQUIRED)

# ---- xdfwriter ----
add_subdirectory(xdfwriter)

# ---- Include libxdf ----
if (WIN32)
    set(XDF_INCLUDE_DIR "C:/Program Files (x86)/libxdf/include")
    set(XDF_LIBRARY "C:/Program Files (x86)/libxdf/lib/xdf.lib")
endif()

if(APPLE)
    set(XDF_INCLUDE_DIR "/opt/homebrew/include")  # or /opt/homebrew/include
    set(XDF_LIBRARY "/usr/local/lib/libxdf.dylib")  # or .a if statically linked
endif()


add_library(libxdf STATIC IMPORTED)
set_target_properties(libxdf PROPERTIES
    IMPORTED_LOCATION "${XDF_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${XDF_INCLUDE_DIR}"
)

# ---- GUI target ----
if (BUILD_GUI)
    add_executable(${PROJECT_NAME} MACOSX_BUNDLE
        src/main.cpp
        src/mainwindow.cpp
        src/mainwindow.h
        src/mainwindow.ui
        src/recording.h
        src/recording.cpp
        src/tcpinterface.h
        src/tcpinterface.cpp
    )

    target_link_libraries(${PROJECT_NAME}
        PRIVATE
        xdfwriter
        libxdf
        Qt${QT_VERSION_MAJOR}::Core
        Qt${QT_VERSION_MAJOR}::Widgets
        Qt${QT_VERSION_MAJOR}::Network
        Qt${QT_VERSION_MAJOR}::DBus
        Threads::Threads
        LSL::lsl
    )

    target_compile_definitions(${PROJECT_NAME} PRIVATE BUILD_GUI)
endif()

# ---- CLI target ----
add_executable(LabRecorderCLI MACOSX_BUNDLE
    src/clirecorder.cpp
    src/recording.h
    src/recording.cpp
)

target_link_libraries(LabRecorderCLI
    PRIVATE
    xdfwriter
    libxdf
    Threads::Threads
    LSL::lsl
)

# ---- Install targets ----
installLSLApp(xdfwriter)
installLSLApp(testxdfwriter)
installLSLApp(LabRecorderCLI)

if (BUILD_GUI)
    installLSLApp(${PROJECT_NAME})
    installLSLAuxFiles(${PROJECT_NAME}
        ${PROJECT_NAME}.cfg
        LICENSE
        README.md
    )
else()
    installLSLAuxFiles(LabRecorderCLI
        ${PROJECT_NAME}.cfg
        LICENSE
        README.md
    )
endif()

# ---- Windows: copy runtime libs ----
if (WIN32)
    if (BUILD_GUI)
        get_target_property(QT_QMAKE_EXECUTABLE Qt::qmake IMPORTED_LOCATION)
        get_filename_component(QT_WINDEPLOYQT_EXECUTABLE ${QT_QMAKE_EXECUTABLE} PATH)
        set(QT_WINDEPLOYQT_EXECUTABLE "${QT_WINDEPLOYQT_EXECUTABLE}/windeployqt.exe")

        add_custom_command(
            TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND ${QT_WINDEPLOYQT_EXECUTABLE}
            --no-translations --no-system-d3d-compiler
            --qmldir ${CMAKE_CURRENT_SOURCE_DIR}
            $<TARGET_FILE_DIR:${PROJECT_NAME}>)

        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            $<TARGET_FILE:LSL::lsl>
            $<TARGET_FILE:xdfwriter>
            "${XDF_LIBRARY}"
            $<TARGET_FILE_DIR:${PROJECT_NAME}>)
    else()
        add_custom_command(TARGET LabRecorderCLI POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            $<TARGET_FILE:LSL::lsl>
            $<TARGET_FILE:xdfwriter>
            "${XDF_LIBRARY}"
            $<TARGET_FILE_DIR:LabRecorderCLI>)
    endif()
endif()

# ---- Copy config to output dir ----
if (BUILD_GUI)
    add_custom_command(
        TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy
        ${CMAKE_CURRENT_SOURCE_DIR}/${PROJECT_NAME}.cfg
        $<TARGET_FILE_DIR:${PROJECT_NAME}>)
else()
    add_custom_command(
        TARGET LabRecorderCLI POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy
        ${CMAKE_CURRENT_SOURCE_DIR}/${PROJECT_NAME}.cfg
        $<TARGET_FILE_DIR:LabRecorderCLI>)
endif()

# ---- Android extras (Qt 6) ----
if(Qt6_FOUND AND BUILD_GUI)
    set_target_properties(${PROJECT_NAME} PROPERTIES
        QT_ANDROID_EXTRA_LIBS "${CMAKE_CURRENT_BINARY_DIR}/liblsl_bin/liblsl.so")
    qt_finalize_executable(${PROJECT_NAME})
endif()

# ---- CPack / Packaging ----
set(CPACK_DEBIAN_LABRECORDER_PACKAGE_SECTION "science" CACHE INTERNAL "")
LSLGenerateCPackConfig()
