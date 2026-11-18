import Toybox.Lang;
import Toybox.WatchUi;

// Maps the fenix buttons to slide commands. Buttons work without looking;
// touch input is swallowed so a brushed screen can't change slides.
class LecternDelegate extends WatchUi.BehaviorDelegate {
    private var _link as ClickerLink;

    function initialize(link as ClickerLink) {
        BehaviorDelegate.initialize();
        _link = link;
    }

    // DOWN button.
    function onNextPage() as Boolean {
        _link.send(LecternProtocol.CMD_NEXT);
        return true;
    }

    // UP button.
    function onPreviousPage() as Boolean {
        _link.send(LecternProtocol.CMD_PREVIOUS);
        return true;
    }

    // START button: the easiest one to find by feel.
    function onSelect() as Boolean {
        _link.send(LecternProtocol.CMD_NEXT);
        return true;
    }

    // BACK asks first, so a stray press mid-talk doesn't drop the connection.
    function onBack() as Boolean {
        WatchUi.pushView(new WatchUi.Confirmation("Quit Lectern?"), new QuitDelegate(), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        return true;
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        return true;
    }
}
