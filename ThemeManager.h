#ifndef THEMEMANAGER_H
#define THEMEMANAGER_H

#include <QObject>
#include <QString>
#include <QColor>
#include <QSettings>

class ThemeManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isDarkTheme READ isDarkTheme WRITE setIsDarkTheme NOTIFY themeChanged)
    Q_PROPERTY(QString backgroundColor READ backgroundColor NOTIFY themeChanged)
    Q_PROPERTY(QString textColor READ textColor NOTIFY themeChanged)
    Q_PROPERTY(QString secondaryTextColor READ secondaryTextColor NOTIFY themeChanged)
    Q_PROPERTY(QString borderColor READ borderColor NOTIFY themeChanged)
    Q_PROPERTY(QString panelColor READ panelColor NOTIFY themeChanged)
    Q_PROPERTY(QString headerColor READ headerColor NOTIFY themeChanged)
    Q_PROPERTY(QString accentColor READ accentColor NOTIFY themeChanged)
    Q_PROPERTY(QString hoverColor READ hoverColor NOTIFY themeChanged)
    Q_PROPERTY(QString buttonHoverColor READ buttonHoverColor NOTIFY themeChanged)
    Q_PROPERTY(QString bitIndicesColor READ bitIndicesColor NOTIFY themeChanged)
    Q_PROPERTY(QString bitIndicesTextColor READ bitIndicesTextColor NOTIFY themeChanged)
    Q_PROPERTY(QString labelTextColor READ labelTextColor NOTIFY themeChanged)

public:
    explicit ThemeManager(QObject *parent = nullptr);

    // Theme state
    bool isDarkTheme() const { return m_isDarkTheme; }
    void setIsDarkTheme(bool dark);

    // Light theme colors
    QString backgroundColor() const;
    QString textColor() const;
    QString secondaryTextColor() const;
    QString borderColor() const;
    QString panelColor() const;
    QString headerColor() const { return "#4CAF50"; }
    QString accentColor() const { return "#4CAF50"; }
    QString hoverColor() const;
    QString buttonHoverColor() const;
    QString bitIndicesColor() const;
    QString bitIndicesTextColor() const;
    QString labelTextColor() const;

    // Helper method to toggle theme
    Q_INVOKABLE void toggleTheme();

signals:
    void themeChanged();

private:
    bool m_isDarkTheme;
    QSettings m_settings;

    void loadThemePreference();
    void saveThemePreference();
};

#endif // THEMEMANAGER_H
