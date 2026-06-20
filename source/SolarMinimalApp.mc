import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class SolarMinimalApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view for your watch face
    function getInitialView() {
        return [new SolarMinimalView()];
    }
}

function getApp() as SolarMinimalApp {
    return Application.getApp() as SolarMinimalApp;
}
