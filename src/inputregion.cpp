#include "inputregion.h"

#include <QGuiApplication>
#include <QWindow>
#include <QTimer>

#include <wayland-client.h>

#include <QtWaylandClient/private/qwaylanddisplay_p.h>
#include <QtWaylandClient/private/qwaylandwindow_p.h>

InputRegion::InputRegion(QObject *parent)
    : QObject(parent)
{
}

void InputRegion::setWindow(QWindow *window)
{
    m_window = window;
    update();
}

void InputRegion::apply(const QRect &barRect, const QRect &popupRect, bool fullScreen)
{
    m_barRect = barRect;
    m_popupRect = popupRect;
    m_fullScreen = fullScreen;
    update();
}

void InputRegion::update()
{
    if (!m_window) {
        return;
    }
    if (!QGuiApplication::platformName().contains(QStringLiteral("wayland"), Qt::CaseInsensitive)) {
        return;
    }

    auto *platformWindow = m_window->handle();
    auto *waylandWindow = dynamic_cast<QtWaylandClient::QWaylandWindow *>(platformWindow);
    if (!waylandWindow || !waylandWindow->wlSurface()) {
        // The surface may not exist during the first QML completion callback.
        QTimer::singleShot(40, this, &InputRegion::update);
        return;
    }

    wl_surface *surface = waylandWindow->wlSurface();
    wl_compositor *compositor = waylandWindow->display()->compositor()->object();
    if (!compositor) {
        return;
    }

    wl_region *region = wl_compositor_create_region(compositor);
    if (m_fullScreen) {
        // Use an explicit full-window region instead of a null (infinite)
        // region. It is more reliable across compositor updates when a panel
        // opens over the full-screen transparent layer.
        wl_region_add(region, 0, 0, m_window->width(), m_window->height());
    } else {
        if (!m_barRect.isEmpty()) {
            wl_region_add(region, m_barRect.x(), m_barRect.y(), m_barRect.width(), m_barRect.height());
        }
        if (!m_popupRect.isEmpty()) {
            wl_region_add(region, m_popupRect.x(), m_popupRect.y(), m_popupRect.width(), m_popupRect.height());
        }
    }
    wl_surface_set_input_region(surface, region);
    wl_region_destroy(region);
    wl_surface_commit(surface);
}
