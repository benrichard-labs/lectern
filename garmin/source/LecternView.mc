import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Shows the link status, the last acknowledged command and a button legend.
class LecternView extends WatchUi.View {
    private var _link as ClickerLink;

    function initialize(link as ClickerLink) {
        View.initialize();
        _link = link;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var state = _link.getState();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(statusColor(state), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, height * 17 / 100, 6);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height * 23 / 100, Graphics.FONT_SMALL, statusText(state), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(
            cx,
            height / 2,
            Graphics.FONT_LARGE,
            centerText(state),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height * 68 / 100, Graphics.FONT_XTINY, "START / DOWN: next", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, height * 77 / 100, Graphics.FONT_XTINY, "UP: previous", Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function statusText(state as Number) as String {
        switch (state) {
            case LINK_SCANNING:
                return "Looking for Mac";
            case LINK_CONNECTING:
                return "Connecting";
            case LINK_READY:
                return "Connected";
            case LINK_ERROR:
                return _link.getError();
            default:
                return "Starting";
        }
    }

    private function statusColor(state as Number) as Graphics.ColorType {
        switch (state) {
            case LINK_READY:
                return Graphics.COLOR_GREEN;
            case LINK_ERROR:
                return Graphics.COLOR_RED;
            default:
                return Graphics.COLOR_ORANGE;
        }
    }

    private function centerText(state as Number) as String {
        if (state != LINK_READY) {
            return "Lectern";
        }
        var last = _link.getLastSent();
        if (last == LecternProtocol.CMD_NEXT) {
            return "NEXT";
        }
        if (last == LecternProtocol.CMD_PREVIOUS) {
            return "PREV";
        }
        return "Ready";
    }
}
