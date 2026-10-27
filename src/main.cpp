#include "autostart.h"
#include "inputregion.h"
#include "recentappsmodel.h"
#include "systemservice.h"
#include "theme.h"
#include "traycontroller.h"
#include "traymodel.h"
#include "windowmodel.h"

#include <QCommandLineParser>
#include <QDir>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QLockFile>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlPropertyMap>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QTimer>

#include <LayerShellQt/window.h>

#include <memory>

int main(int argc, char **argv)
{
    if (const int code = handleAutostartCli(argc, argv); code >= 0) {
        return code;
    }

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("Endfield Tray"));
    QGuiApplication::setApplicationDisplayName(QStringLiteral("Endfield Tray"));
    QGuiApplication::setApplicationVersion(QStringLiteral("0.1.8"));
    QGuiApplication::setOrganizationName(QStringLiteral("EndfieldTray"));
    QGuiApplication::setDesktopFileName(QStringLiteral("endfield-tray"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Endfield-inspired floating taskbar for KDE Plasma 6 Wayland."));
    parser.addHelpOption();
    parser.addVersionOption();
    QCommandLineOption windowedOption(QStringList{QStringLiteral("w"), QStringLiteral("windowed")},
                                      QStringLiteral("Run as a normal window (development / screenshots)."));
    QCommandLineOption noLockOption(QStringLiteral("no-lock"),
                                    QStringLiteral("Allow multiple instances."));
    QCommandLineOption autostartOption(QStringLiteral("autostart"),
                                       QStringLiteral("Show or set login autostart (status, enable, disable)."),
                                       QStringLiteral("action"), QStringLiteral("status"));
    QCommandLineOption previewOption(QStringLiteral("preview-panel"),
                                     QStringLiteral("Open a panel at startup (windows, power, network, volume, battery, tray)."),
                                     QStringLiteral("panel"));
    QCommandLineOption screenshotOption(QStringLiteral("screenshot"),
                                        QStringLiteral("Grab the QML window to this file and exit (development aid)."),
                                        QStringLiteral("path"));
    parser.addOption(windowedOption);
    parser.addOption(noLockOption);
    parser.addOption(autostartOption);
    parser.addOption(previewOption);
    parser.addOption(screenshotOption);
    parser.process(app);

    std::unique_ptr<QLockFile> lock;
    if (!parser.isSet(noLockOption)) {
        const QString runtime = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
        lock = std::make_unique<QLockFile>(QDir(runtime).filePath(QStringLiteral("endfield-tray.lock")));
        if (!lock->tryLock(120)) {
            qWarning("endfield-tray is already running.");
            return 0;
        }
    }

    QIcon::setThemeName(QStringLiteral("breeze"));
    QIcon::setFallbackThemeName(QStringLiteral("hicolor"));

    Theme theme;
    QStringList loadedFamilies;
    const QStringList fontFiles{
        QStringLiteral(":/assets/fonts/Rajdhani-Medium.ttf"),
        QStringLiteral(":/assets/fonts/Rajdhani-SemiBold.ttf"),
        QStringLiteral(":/assets/fonts/Rajdhani-Bold.ttf"),
        QStringLiteral(":/assets/fonts/JetBrainsMono-Regular.ttf"),
        QStringLiteral(":/assets/fonts/JetBrainsMono-Medium.ttf"),
    };
    for (const QString &font : fontFiles) {
        const int id = QFontDatabase::addApplicationFont(font);
        if (id >= 0) {
            loadedFamilies += QFontDatabase::applicationFontFamilies(id);
        } else {
            qWarning() << "endfield-tray: failed to load font" << font;
        }
    }
    theme.setLoadedFamilies(loadedFamilies);

    const bool onWayland = QGuiApplication::platformName().contains(QStringLiteral("wayland"), Qt::CaseInsensitive);
    const bool windowed = parser.isSet(windowedOption) || !onWayland;

    QQmlPropertyMap appInfo;
    appInfo.insert(QStringLiteral("windowed"), windowed);
    appInfo.insert(QStringLiteral("layerShell"), onWayland && !windowed);
    appInfo.insert(QStringLiteral("version"), QGuiApplication::applicationVersion());
    appInfo.insert(QStringLiteral("platform"), QGuiApplication::platformName());
    appInfo.insert(QStringLiteral("previewPanel"), parser.value(previewOption));

    WindowModel windowModel;
    RecentAppsModel recentApps(&windowModel);
    TrayController trayController;
    TrayModel trayModel;
    SystemService systemService;
    InputRegion inputRegion;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("Theme"), &theme);
    engine.rootContext()->setContextProperty(QStringLiteral("App"), &appInfo);
    engine.rootContext()->setContextProperty(QStringLiteral("WindowModel"), &windowModel);
    engine.rootContext()->setContextProperty(QStringLiteral("RecentApps"), &recentApps);
    engine.rootContext()->setContextProperty(QStringLiteral("TrayMenu"), &trayController);
    engine.rootContext()->setContextProperty(QStringLiteral("TrayModel"), &trayModel);
    engine.rootContext()->setContextProperty(QStringLiteral("System"), &systemService);
    engine.rootContext()->setContextProperty(QStringLiteral("InputRegion"), &inputRegion);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);

    engine.loadFromModule(QStringLiteral("Endfield"), QStringLiteral("Main"));

    if (engine.rootObjects().isEmpty()) {
        return 1;
    }
    if (auto *window = qobject_cast<QWindow *>(engine.rootObjects().constFirst())) {
        // The scope must be set before the platform window exists. "dock" makes
        // KWin treat the layer surface like a panel, so Show Desktop does not
        // hide it.
        if (auto *layerShell = LayerShellQt::Window::get(window)) {
            layerShell->setScope(QStringLiteral("dock"));
        }
        window->show();
        inputRegion.setWindow(window);
    }

    if (parser.isSet(screenshotOption)) {
        const QString path = parser.value(screenshotOption);
        QTimer::singleShot(3000, &app, [&engine, path] {
            if (auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst())) {
                const QImage image = window->grabWindow();
                if (!image.save(path)) {
                    qWarning() << "endfield-tray: could not save screenshot" << path;
                }
            }
            QCoreApplication::quit();
        });
    }

    return app.exec();
}
