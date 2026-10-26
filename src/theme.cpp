#include "theme.h"

Theme::Theme(QObject *parent)
    : QObject(parent)
{
}

void Theme::setLoadedFamilies(const QStringList &families)
{
    for (const QString &family : families) {
        if (family.contains(QStringLiteral("Rajdhani"), Qt::CaseInsensitive)) {
            m_sans = family;
        } else if (family.contains(QStringLiteral("JetBrains"), Qt::CaseInsensitive)) {
            m_mono = family;
        }
    }
}
