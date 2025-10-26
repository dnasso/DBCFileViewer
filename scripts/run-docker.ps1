# Simple run script (assumes VcXsrv is already running)
# If you haven't started VcXsrv, run: run-docker-gui.ps1 instead

docker run -it --rm `
    -e DISPLAY="host.docker.internal:0.0" `
    -e QT_QPA_PLATFORM=xcb `
    --name dbc_parser `
    dbc_parser:linux `
    /app/bin/appDBC_Parser
