#include "ThemeManager.h"
#include <QStandardPaths>
#include <QDebug>

ThemeManager::ThemeManager(QObject *parent)
    : QObject(parent),
      m_isDarkTheme(false),
      m_settings("DBCFileViewer", "DBCParser", this)
{
    loadThemePreference();
}

void ThemeManager::loadThemePreference()
{
    m_isDarkTheme = m_settings.value("darkTheme", false).toBool();
    qDebug() << "Theme loaded from settings: Dark theme =" << m_isDarkTheme;
}

void ThemeManager::saveThemePreference()
{
    m_settings.setValue("darkTheme", m_isDarkTheme);
    qDebug() << "Theme saved to settings: Dark theme =" << m_isDarkTheme;
}

void ThemeManager::setIsDarkTheme(bool dark)
{
    if (m_isDarkTheme != dark) {
        m_isDarkTheme = dark;
        saveThemePreference();
        emit themeChanged();
    }
}

QString ThemeManager::backgroundColor() const
{
    if (m_isDarkTheme) {
        return "#1E1E1E"; // Dark background
    }
    return "#FFFFFF"; // Light background
}

QString ThemeManager::textColor() const
{
    if (m_isDarkTheme) {
        return "#FFFFFF"; // Light text on dark background
    }
    return "#212121"; // Dark text on light background
}

QString ThemeManager::secondaryTextColor() const
{
    if (m_isDarkTheme) {
        return "#B0B0B0"; // Secondary light text
    }
    return "#757575"; // Secondary dark text
}

QString ThemeManager::borderColor() const
{
    if (m_isDarkTheme) {
        return "#404040"; // Dark border
    }
    return "#E0E0E0"; // Light border
}

QString ThemeManager::panelColor() const
{
    if (m_isDarkTheme) {
        return "#2A2A2A"; // Dark panel
    }
    return "#FAFAFA"; // Light panel
}

QString ThemeManager::hoverColor() const
{
    if (m_isDarkTheme) {
        return "#383838"; // Dark hover
    }
    return "#F1F8E9"; // Light hover
}

QString ThemeManager::buttonHoverColor() const
{
    if (m_isDarkTheme) {
        return "#3D3D3D"; // Dark button hover
    }
    return "#F1F8E9"; // Light button hover
}

void ThemeManager::toggleTheme()
{
    setIsDarkTheme(!m_isDarkTheme);
}
