import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class LecternApp extends Application.AppBase {
    private var _link as ClickerLink;

    function initialize() {
        AppBase.initialize();
        _link = new ClickerLink();
    }

    function onStart(state as Dictionary?) as Void {
        _link.start();
    }

    function onStop(state as Dictionary?) as Void {
        _link.stop();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new LecternView(_link), new LecternDelegate(_link)];
    }
}
