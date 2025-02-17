#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QIcon>
#include <QGuiApplication>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QGuiApplication::setWindowIcon(QIcon("dbctrain.ico"));
    //app.setWindowIcon(QIcon("dbctrain.png"));

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("DBC_Parser", "Main");

    return app.exec();
}
