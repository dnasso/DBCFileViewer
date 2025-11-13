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
        return "#121212"; // Dark background - darker for better contrast
    }
    return "#FFFFFF"; // Light background
}

QString ThemeManager::textColor() const
{
    if (m_isDarkTheme) {
        return "#E3E3E3"; // Brighter white text for better readability
    }
    return "#212121"; // Dark text on light background
}

QString ThemeManager::secondaryTextColor() const
{
    if (m_isDarkTheme) {
        return "#B3B3B3"; // Brighter secondary text for better contrast
    }
    return "#757575"; // Secondary dark text
}

QString ThemeManager::borderColor() const
{
    if (m_isDarkTheme) {
        return "#3A3A3A"; // Slightly lighter border for visibility
    }
    return "#E0E0E0"; // Light border
}

QString ThemeManager::panelColor() const
{
    if (m_isDarkTheme) {
        return "#1E1E1E"; // Slightly lighter panel for better contrast
    }
    return "#FAFAFA"; // Light panel
}

QString ThemeManager::hoverColor() const
{
    if (m_isDarkTheme) {
        return "#2A2A2A"; // Better hover state for dark theme
    }
    return "#F1F8E9"; // Light hover
}

QString ThemeManager::buttonHoverColor() const
{
    if (m_isDarkTheme) {
        return "#2F2F2F"; // Better button hover for dark theme
    }
    return "#F1F8E9"; // Light button hover
}

QString ThemeManager::bitIndicesColor() const
{
    if (m_isDarkTheme) {
        return "#2A2A2A"; // Dark gray for bit indices background
    }
    return "#F5F5F5"; // Light gray for bit indices background
}

QString ThemeManager::bitIndicesTextColor() const
{
    if (m_isDarkTheme) {
        return "#FFFFFF"; // White text for dark bit indices
    }
    return "#000000"; // Black text for light bit indices
}

QString ThemeManager::labelTextColor() const
{
    if (m_isDarkTheme) {
        return "#E3E3E3"; // Bright text for labels in dark mode
    }
    return "#212121"; // Dark text for labels in light mode
}

void ThemeManager::toggleTheme()
{
    setIsDarkTheme(!m_isDarkTheme);
}
