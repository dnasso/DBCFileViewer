#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include "DbcParser.h"

// Import the Qt::StringLiterals namespace
using namespace Qt::StringLiterals;

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    
    // Set the Material style
    QQuickStyle::setStyle("Material");
    
    // Create the DBC parser
    DbcParser dbcParser;
    
    QQmlApplicationEngine engine;
    
    // Make the parser available to QML
    engine.rootContext()->setContextProperty("dbcParser", &dbcParser);
    
    // Use the previously working URL path
    const QUrl url(u"qrc:/qt/qml/DBC_Parser/Main.qml"_s);
    
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    
    engine.load(url);
    
    return app.exec();
}