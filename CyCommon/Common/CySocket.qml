pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
    id: root

    property string path: ""
    property var parser: null
    property bool connected: false
    property bool linkUp: false

    property int reconnectBaseMs: 400
    property int reconnectMaxMs: 15000

    property int _reconnectAttempt: 0
    property bool _hasConnectedOnce: false
    property bool _tearingDown: false

    signal connectionStateChanged

    onConnectedChanged: {
        if (connected) {
            _restartSocket();
        } else {
            reconnectTimer.stop();
            _teardown();
        }
    }

    // Quickshell's Socket cannot redial after a failed attempt: its dead
    // QLocalSocket is only cleared when a *successful* connection closes, and
    // setting connected back to true is a no-op while the object exists. Every
    // attempt therefore gets a fresh Socket instance.
    function _restartSocket() {
        _teardown();
        socketLoader.active = true;
    }

    function _teardown() {
        _tearingDown = true;
        socketLoader.active = false;
        _tearingDown = false;
        if (linkUp) {
            linkUp = false;
            connectionStateChanged();
        }
    }

    function _handleSocketStateChange(socketConnected) {
        linkUp = socketConnected;
        connectionStateChanged();

        if (_tearingDown)
            return;
        if (socketConnected) {
            _hasConnectedOnce = true;
            _reconnectAttempt = 0;
            reconnectTimer.stop();
            return;
        }

        // Quickshell's Socket reconnects itself after a previously established
        // connection drops. Replacing it here races that reconnect; only a
        // failed initial connection needs a fresh Socket (onError also handles
        // failed automatic reconnect attempts).
        if (connected && !_hasConnectedOnce)
            _scheduleReconnect();
    }

    function send(data) {
        const socket = socketLoader.item;
        if (!socket)
            return;
        const json = typeof data === "string" ? data : JSON.stringify(data);
        const message = json.endsWith("\n") ? json : json + "\n";
        socket.write(message);
        socket.flush();
    }

    function _scheduleReconnect() {
        const pow = Math.min(_reconnectAttempt, 10);
        const base = Math.min(reconnectBaseMs * Math.pow(2, pow), reconnectMaxMs);
        const jitter = Math.floor(Math.random() * Math.floor(base / 4));
        reconnectTimer.interval = base + jitter;
        reconnectTimer.restart();
        _reconnectAttempt++;
    }

    Loader {
        id: socketLoader
        active: false

        // Dial only once `item` is assigned: a unix connect can complete
        // synchronously, and handlers fired mid-creation would see a null
        // `socketLoader.item`, silently dropping the first sends.
        onLoaded: item.connected = true

        sourceComponent: Socket {
            path: root.path
            parser: root.parser

            onConnectionStateChanged: {
                root._handleSocketStateChange(connected);
            }

            // A failed dial emits only the error signal, never a connection
            // state transition, so the retry loop must also start from here.
            onError: err => {
                if (root.connected && !root.linkUp && !root._tearingDown)
                    root._scheduleReconnect();
            }
        }
    }

    Timer {
        id: reconnectTimer
        repeat: false
        onTriggered: {
            if (root.connected && !root.linkUp)
                root._restartSocket();
        }
    }
}
