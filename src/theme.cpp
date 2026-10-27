#include "theme.h"

#include <QFontDatabase>

Theme::Theme(QObject *parent)
    : QObject(parent)
{
    // Use the same hinted UI font as Plasma for body text and Chinese labels.
    // Rajdhani remains the display face for headings and numerals.
    const QFont systemFont = QFontDatabase::systemFont(QFontDatabase::GeneralFont);
    if (!systemFont.family().isEmpty())
        m_cjk = systemFont.family();
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
