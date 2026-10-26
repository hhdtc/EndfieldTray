cmake_minimum_required(VERSION 3.22)

project(EndfieldTray VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 DBus WaylandClient)
find_package(LayerShellQt REQUIRED)
find_package(LibTaskManager REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(GIO REQUIRED IMPORTED_TARGET gio-2.0)

qt_standard_project_setup(REQUIRES 6.8)

set(QML_FILES
    qml/Main.qml

    qml/components/EndfieldFrame.qml
    qml/components/IconGlyph.qml
    qml/components/BarButton.qml
    qml/components/StatusChip.qml
    qml/components/SectionHeader.qml
    qml/components/SignalBars.qml
    qml/components/ChamferButton.qml
    qml/components/EndfieldSlider.qml
    qml/components/Toast.qml
    qml/components/EmptyState.qml
    qml/components/RecentAppButton.qml
    qml/components/GroupPopup.qml
    qml/components/RingBadge.qml

    qml/panels/BasePanel.qml
    qml/panels/WindowsPanel.qml
    qml/panels/PowerPanel.qml
    qml/panels/BluetoothPanel.qml
    qml/panels/NetworkPanel.qml
    qml/panels/VolumePanel.qml
    qml/panels/BatteryPanel.qml
    qml/panels/TrayPanel.qml
    qml/panels/TrayMenuPanel.qml
)

qt_add_executable(endfield-tray
    src/main.cpp
    src/theme.h
    src/theme.cpp
    src/windowmodel.h
    src/windowmodel.cpp
    src/recentappsmodel.h
    src/recentappsmodel.cpp
    src/traycontroller.h
    src/traycontroller.cpp
    src/traymodel.h
    src/traymodel.cpp
    src/systemservice.h
    src/systemservice.cpp
    src/inputregion.h
    src/inputregion.cpp
)

qt_add_qml_module(endfield-tray
    URI Endfield
    VERSION 1.0
    QML_FILES ${QML_FILES}
)

qt_add_resources(endfield-tray "app_assets"
    PREFIX "/assets"
    BASE assets
    FILES
        assets/fonts/Rajdhani-Medium.ttf
        assets/fonts/Rajdhani-SemiBold.ttf
        assets/fonts/Rajdhani-Bold.ttf
        assets/fonts/JetBrainsMono-Regular.ttf
        assets/fonts/JetBrainsMono-Medium.ttf
        assets/fonts/OFL-Rajdhani.txt
        assets/fonts/OFL-JetBrainsMono.txt
)

target_include_directories(endfield-tray PRIVATE
    src
    "${Qt6WaylandClient_DIR}/../../../include/qt6/QtWaylandClient/${Qt6_VERSION}"
    "${Qt6WaylandClient_DIR}/../../../include/qt6/QtWaylandGlobal/${Qt6_VERSION}"
    "${Qt6Gui_DIR}/../../../include/qt6/QtGui/${Qt6_VERSION}"
    "${Qt6Gui_DIR}/../../../include/qt6/QtGui/${Qt6_VERSION}/QtGui"
    "${Qt6Core_DIR}/../../../include/qt6/QtCore/${Qt6_VERSION}"
    "${Qt6Core_DIR}/../../../include/qt6/QtCore/${Qt6_VERSION}/QtCore"
)

target_link_libraries(endfield-tray PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::DBus
    Qt6::WaylandClient
    LayerShellQt::Interface
    PW::LibTaskManager
    PkgConfig::GIO
)

install(TARGETS endfield-tray RUNTIME DESTINATION bin)
install(FILES assets/endfield-tray.svg DESTINATION share/icons/hicolor/scalable/apps)
install(FILES assets/endfield-tray.desktop DESTINATION share/applications)
