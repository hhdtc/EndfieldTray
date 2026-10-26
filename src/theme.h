#pragma once

#include <QColor>
#include <QObject>
#include <QString>

/**
 * Small palette object exposed to QML as `Theme`.
 *
 * The visual language is charcoal + acid lime, with thin technical rules,
 * chamfered corners and very restrained glow. It intentionally avoids the
 * default Breeze look so the bar reads as a single custom piece.
 */
class Theme : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QColor bg READ bg CONSTANT)
    Q_PROPERTY(QColor panel READ panel CONSTANT)
    Q_PROPERTY(QColor panelAlt READ panelAlt CONSTANT)
    Q_PROPERTY(QColor surface READ surface CONSTANT)
    Q_PROPERTY(QColor surfaceHot READ surfaceHot CONSTANT)
    Q_PROPERTY(QColor line READ line CONSTANT)
    Q_PROPERTY(QColor lineBright READ lineBright CONSTANT)
    Q_PROPERTY(QColor accent READ accent CONSTANT)
    Q_PROPERTY(QColor accentSoft READ accentSoft CONSTANT)
    Q_PROPERTY(QColor accentDim READ accentDim CONSTANT)
    Q_PROPERTY(QColor text READ text CONSTANT)
    Q_PROPERTY(QColor textDim READ textDim CONSTANT)
    Q_PROPERTY(QColor textFaint READ textFaint CONSTANT)
    Q_PROPERTY(QColor warning READ warning CONSTANT)
    Q_PROPERTY(QColor danger READ danger CONSTANT)
    Q_PROPERTY(QColor ok READ ok CONSTANT)
    Q_PROPERTY(QColor badgeDark READ badgeDark CONSTANT)
    Q_PROPERTY(QString sans READ sans CONSTANT)
    Q_PROPERTY(QString mono READ mono CONSTANT)
    Q_PROPERTY(QString cjk READ cjk CONSTANT)
    Q_PROPERTY(int barHeight READ barHeight CONSTANT)
    Q_PROPERTY(int barWidth READ barWidth CONSTANT)

public:
    explicit Theme(QObject *parent = nullptr);

    QColor bg() const { return QColor(QStringLiteral("#141313")); }
    QColor panel() const { return QColor(QStringLiteral("#312f30")); }
    QColor panelAlt() const { return QColor(QStringLiteral("#242223")); }
    QColor surface() const { return QColor(QStringLiteral("#3a3738")); }
    QColor surfaceHot() const { return QColor(QStringLiteral("#464243")); }
    QColor line() const { return QColor(QStringLiteral("#4a4647")); }
    QColor lineBright() const { return QColor(QStringLiteral("#625d5e")); }
    QColor accent() const { return QColor(QStringLiteral("#c8cc4d")); }
    QColor accentSoft() const { return QColor(QStringLiteral("#aeb23f")); }
    QColor accentDim() const { return QColor(QStringLiteral("#7a7e2e")); }
    QColor text() const { return QColor(QStringLiteral("#f2f0ed")); }
    QColor textDim() const { return QColor(QStringLiteral("#b6b1ae")); }
    QColor textFaint() const { return QColor(QStringLiteral("#807a7b")); }
    QColor warning() const { return QColor(QStringLiteral("#e7aa5a")); }
    QColor danger() const { return QColor(QStringLiteral("#e56f66")); }
    QColor ok() const { return QColor(QStringLiteral("#a9c46a")); }
    QColor badgeDark() const { return QColor(QStringLiteral("#262425")); }

    QString sans() const { return m_sans; }
    QString mono() const { return m_mono; }
    QString cjk() const { return m_cjk; }
    int barHeight() const { return 44; }
    int barWidth() const { return 620; }

    void setLoadedFamilies(const QStringList &families);

private:
    QString m_sans = QStringLiteral("Rajdhani");
    QString m_mono = QStringLiteral("JetBrains Mono");
    QString m_cjk = QStringLiteral("Noto Sans CJK SC");
};
