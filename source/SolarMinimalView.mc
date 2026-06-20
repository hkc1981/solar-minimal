import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Position;
import Toybox.Weather;
import Toybox.Application.Storage;

class SolarMinimalView extends WatchUi.WatchFace {
    private var _yahaUsagiBmp; 

    // Seconds tracking variables for partial update
    private var _secX = 0;
    private var _secY = 0;
    private var _secClipX = 0;
    private var _secClipY = 0;
    private var _secClipWidth = 0;
    private var _secClipHeight = 0;

    // --- 效能優化：靜態字體高度快取 ---
    private var _hourHeight = 0;
    private var _minuteHeight = 0;
    private var _colHeight = 0;
    private var _secHeight = 0;
    private var _batteryFontHeight = 0;

    // --- 效能優化：狀態追蹤與資料快取 ---
    private var _lastMin = -1;
    private var _lastDay = -1;
    private var _lastSteps = -1;
    private var _lastHrReadSec = -1;
    private var _needsLayout = true; // 髒標記：是否需要重新計算座標

    // 文字快取
    private var _hhString = "";
    private var _mmString = "";
    private var _dateText = "";
    private var _batteryText = "";
    private var _batteryDaysText = "";
    private var _solarText = "";
    private var _hrText = "--";
    private var _stepsText = "";
    private var _sunEventsText = "SR --:--  SS --:--";

    // --- 效能優化：座標快取 (避免每秒重複計算) ---
    private var _startX = 0;
    private var _hourNumY = 0;
    private var _colY = 0;
    private var _numY = 0;
    private var _sunEventsY = 0;
    private var _lineX = 0;
    private var _batteryX = 0;
    private var _rightBlockY = 0;
    private var _imgX = 0;
    private var _imgY = 0;
    private var _stepsX = 0;
    private var _stepsY = 0;
    private var _timeWidth = 0;
    private var _hhWidth = 0;
    private var _colWidth = 0;

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc as Graphics.Dc) as Void {
        _yahaUsagiBmp = WatchUi.loadResource(Rez.Drawables.YahaUsagi);

        // 🌟 優化：字體高度是固定的，在 onLayout 算一次就好，不用每秒算
        _hourHeight = dc.getFontHeight(Graphics.FONT_NUMBER_HOT);
        _minuteHeight = dc.getFontHeight(Graphics.FONT_NUMBER_HOT);
        _colHeight = dc.getFontHeight(Graphics.FONT_LARGE);
        _secHeight = dc.getFontHeight(Graphics.FONT_TINY);
        _batteryFontHeight = dc.getFontHeight(Graphics.FONT_XTINY);
        
        _needsLayout = true; // 初始化時強制計算佈局
    }

    function onShow() as Void {}

    // Update the watch face display
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.clearClip();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var clockTime = System.getClockTime();
        var ssString = clockTime.sec.format("%02d"); // 秒數每秒都要算

        // 1. 檢查分鐘是否改變 (改變時觸發更新)
        if (_lastMin != clockTime.min) {
            _lastMin = clockTime.min;
            _hhString = clockTime.hour.format("%02d");
            _mmString = clockTime.min.format("%02d");
            
            // 更新日期
            var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
            _dateText = today.day_of_week + " " + today.day;
            
            // 更新日出日落時間
            var dayChanged = (_lastDay != today.day);
            if (dayChanged || _sunEventsText.equals("SR --:--  SS --:--")) {
                _lastDay = today.day;
                updateSunEvents(Time.now());
            }
            
            // 更新電量與太陽能
            var stats = System.getSystemStats();
            _batteryText = "PW: " + stats.battery.format("%d") + "%";
            if (stats has :batteryInDays && stats.batteryInDays != null) {
                _batteryDaysText = "D-: " + stats.batteryInDays.format("%d") + "D";
            } else {
                _batteryDaysText = "-- d";
            }
            
            var solarIntensity = 0;
            if (stats has :solarIntensity && stats.solarIntensity != null) {
                solarIntensity = stats.solarIntensity;
            }
            _solarText = "SLR: " + solarIntensity.format("%d");
            
            _needsLayout = true; // 狀態改變，標記需要重新排版
        }

        // 2. 更新心率 (每 10 秒檢查一次，或依賴系統即時變數)
        var hr = null;
        var info = Activity.getActivityInfo();
        if (info != null) {
            hr = info.currentHeartRate;
        }
        
        var oldHrText = _hrText;
        if (hr != null) {
            _hrText = "HR: " + hr.format("%d");
            _lastHrReadSec = clockTime.sec;
        } else {
            var secondsSinceLastRead = (clockTime.sec - _lastHrReadSec + 60) % 60;
            if (_lastHrReadSec == -1 || secondsSinceLastRead >= 10) {
                _lastHrReadSec = clockTime.sec;
                var hrIter = ActivityMonitor.getHeartRateHistory(1, true);
                if (hrIter != null) {
                    var hrSample = hrIter.next();
                    if (hrSample != null && hrSample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                        hr = hrSample.heartRate;
                    }
                }
                _hrText = "HR: " + (hr != null ? hr.format("%d") : "--");
            }
        }
        // 如果心率字串改變，可能影響寬度，觸發重新排版
        if (!_hrText.equals(oldHrText)) {
            _needsLayout = true;
        }

        // 3. 更新步數 (只有步數真的改變時才轉字串，省 CPU)
        var actInfo = ActivityMonitor.getInfo();
        if (actInfo != null && actInfo.steps != null && actInfo.steps != _lastSteps) {
            _lastSteps = actInfo.steps;
            _stepsText = _lastSteps.toString();
            _needsLayout = true; // 步數改變，影響底部置中，觸發重新排版
        }

        // 🌟 核心優化：只有當關鍵資料改變時，才進行昂貴的「寬度測量」與「佈局計算」
        if (_needsLayout) {
            var screenWidth = dc.getWidth();
            var screenHeight = dc.getHeight();
            var centerX = screenWidth / 2;
            var centerY = screenHeight / 2;

            _hhWidth = dc.getTextWidthInPixels(_hhString, Graphics.FONT_NUMBER_HOT);
            _colWidth = dc.getTextWidthInPixels(":", Graphics.FONT_LARGE);
            var mmWidth = dc.getTextWidthInPixels(_mmString, Graphics.FONT_NUMBER_HOT);
            
            _numY = centerY - (_minuteHeight / 2) - 5;
            _hourNumY = _numY + (_minuteHeight - _hourHeight) / 2;
            _colY = _numY + (_minuteHeight - _colHeight) / 2;
            _secY = _numY + _minuteHeight - 16;
            _sunEventsY = _numY - 35;
            
            var lineWidth = 3;
            var lineSpacing = 5;
            var rightPadding = 12; 

            _timeWidth = _hhWidth + _colWidth + mmWidth + 4;

            var dateTextWidth = dc.getTextWidthInPixels(_dateText, Graphics.FONT_XTINY);
            var batteryTextWidth = dc.getTextWidthInPixels(_batteryText, Graphics.FONT_XTINY);
            var batteryDaysTextWidth = dc.getTextWidthInPixels(_batteryDaysText, Graphics.FONT_XTINY);
            var solarTextWidth = dc.getTextWidthInPixels(_solarText, Graphics.FONT_XTINY);
            var hrTextWidth = dc.getTextWidthInPixels(_hrText, Graphics.FONT_XTINY);

            var rightBlockWidth = batteryTextWidth;
            if (hrTextWidth > rightBlockWidth) { rightBlockWidth = hrTextWidth; }
            if (dateTextWidth > rightBlockWidth) { rightBlockWidth = dateTextWidth; }
            if (batteryDaysTextWidth > rightBlockWidth) { rightBlockWidth = batteryDaysTextWidth; }
            if (solarTextWidth > rightBlockWidth) { rightBlockWidth = solarTextWidth; }

            var totalWidth = _timeWidth + lineSpacing + lineWidth + lineSpacing + 1 + rightBlockWidth + rightPadding;
            
            // 快取所有繪圖座標
            _startX = centerX - (totalWidth / 2) + 5;
            _secX = _startX + _timeWidth - 10;
            _lineX = _startX + _timeWidth + lineSpacing;
            _batteryX = _lineX + lineWidth + lineSpacing + 1;
            
            var textSpacing = 2;
            var totalTextHeight = _batteryFontHeight * 5 + textSpacing * 4;
            _rightBlockY = centerY - (totalTextHeight / 2);

            // 底部烏薩奇與步數座標
            var imgWidth = _yahaUsagiBmp.getWidth();
            var imgHeight = _yahaUsagiBmp.getHeight();
            var stepsTextWidth = dc.getTextWidthInPixels(_stepsText, Graphics.FONT_XTINY);
            var spacing = 5;
            var combinedWidth = imgWidth + spacing + stepsTextWidth;
            var combinedStartX = centerX - (combinedWidth / 2);
            
            _imgX = combinedStartX;
            _stepsX = combinedStartX + imgWidth + spacing;
            var extraHeight = 20;
            _imgY = _numY + _minuteHeight + (extraHeight / 2) + 20;
            _stepsY = _imgY + (imgHeight - _batteryFontHeight) / 2;

            // 計算 partial update 的剪裁區域
            var secWidth = dc.getTextWidthInPixels("59", Graphics.FONT_TINY);
            _secClipX = _secX - secWidth - 2;
            _secClipY = _secY;
            _secClipWidth = secWidth + 4;
            _secClipHeight = _secHeight;

            _needsLayout = false; // 算完就關閉標記
        }

        // --- 🚀 繪圖階段 (只剩下純粹的繪製指令，極致省電) ---
        
        // 頂部日出日落時間 (置中對齊在時分數字上方)
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_startX + (_timeWidth / 2), _sunEventsY, Graphics.FONT_XTINY, _sunEventsText, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        // 時、冒號、分
        dc.drawText(_startX, _hourNumY, Graphics.FONT_NUMBER_HOT, _hhString, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(_startX + _hhWidth + 2, _colY, Graphics.FONT_LARGE, ":", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(_startX + _hhWidth + _colWidth + 4, _numY, Graphics.FONT_NUMBER_HOT, _mmString, Graphics.TEXT_JUSTIFY_LEFT);
        
        // 秒數
        dc.drawText(_secX, _secY, Graphics.FONT_TINY, ssString, Graphics.TEXT_JUSTIFY_RIGHT);

        // 紅線
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_lineX, _numY - 10, 3, _minuteHeight + 20); // 20 是 extraHeight

        // 右側資料群組
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var textSpacing = 2;
        dc.drawText(_batteryX, _rightBlockY, Graphics.FONT_XTINY, _dateText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(_batteryX, _rightBlockY + _batteryFontHeight + textSpacing, Graphics.FONT_XTINY, _batteryText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(_batteryX, _rightBlockY + (_batteryFontHeight + textSpacing) * 2, Graphics.FONT_XTINY, _solarText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(_batteryX, _rightBlockY + (_batteryFontHeight + textSpacing) * 3, Graphics.FONT_XTINY, _batteryDaysText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(_batteryX, _rightBlockY + (_batteryFontHeight + textSpacing) * 4, Graphics.FONT_XTINY, _hrText, Graphics.TEXT_JUSTIFY_LEFT);
    
        // 底部烏薩奇與步數
        dc.drawBitmap(_imgX, _imgY, _yahaUsagiBmp);
        dc.drawText(_stepsX, _stepsY, Graphics.FONT_XTINY, _stepsText, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function onPartialUpdate(dc as Graphics.Dc) as Void {
        if (_secClipWidth == 0) { return; }

        var clockTime = System.getClockTime();
        var ssString = clockTime.sec.format("%02d");

        dc.setClip(_secClipX, _secClipY, _secClipWidth, _secClipHeight);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_secX, _secY, Graphics.FONT_TINY, ssString, Graphics.TEXT_JUSTIFY_RIGHT);

        dc.clearClip();
    }

    private function updateSunEvents(now as Time.Moment) as Void {
        var location = null;
        
        if (Toybox has :Position && Toybox.Position has :getInfo) {
            var positionInfo = Position.getInfo();
            if (positionInfo != null && positionInfo.position != null) {
                location = positionInfo.position;
            }
        }
        
        if (location == null) {
            var activityInfo = Activity.getActivityInfo();
            if (activityInfo != null && activityInfo.currentLocation != null) {
                location = activityInfo.currentLocation;
            }
        }
        
        if (location == null) {
            if (Toybox has :Weather && Toybox.Weather has :getCurrentConditions) {
                var cond = Weather.getCurrentConditions();
                if (cond != null && cond.observationLocationPosition != null) {
                    location = cond.observationLocationPosition;
                }
            }
        }
        
        if (location == null) {
            var lat = Storage.getValue("last_lat");
            var lon = Storage.getValue("last_lon");
            if (lat != null && lon != null) {
                location = new Position.Location({
                    :latitude => lat,
                    :longitude => lon,
                    :format => :degrees
                });
            }
        } else {
            var coords = location.toDegrees();
            Storage.setValue("last_lat", coords[0]);
            Storage.setValue("last_lon", coords[1]);
        }
        
        if (location != null) {
            if (Toybox has :Weather && Toybox.Weather has :getSunrise && Toybox.Weather has :getSunset) {
                var sunrise = Weather.getSunrise(location, now);
                var sunset = Weather.getSunset(location, now);
                
                if (sunrise != null && sunset != null) {
                    var deviceSettings = System.getDeviceSettings();
                    var is24Hour = deviceSettings.is24Hour;
                    
                    var sunriseInfo = Gregorian.info(sunrise, Time.FORMAT_SHORT);
                    var sunsetInfo = Gregorian.info(sunset, Time.FORMAT_SHORT);
                    
                    var sunriseHour = sunriseInfo.hour;
                    var sunsetHour = sunsetInfo.hour;
                    
                    if (!is24Hour) {
                        sunriseHour = sunriseHour % 12;
                        if (sunriseHour == 0) { sunriseHour = 12; }
                        sunsetHour = sunsetHour % 12;
                        if (sunsetHour == 0) { sunsetHour = 12; }
                    }
                    
                    _sunEventsText = Lang.format("SR $1$:$2$  SS $3$:$4$", [
                        sunriseHour.format("%02d"),
                        sunriseInfo.min.format("%02d"),
                        sunsetHour.format("%02d"),
                        sunsetInfo.min.format("%02d")
                    ]);
                    return;
                }
            }
        }
        
        _sunEventsText = "SR --:--  SS --:--";
    }

    function onHide() as Void {}
    function onExitSleep() as Void { WatchUi.requestUpdate(); }
    function onEnterSleep() as Void { WatchUi.requestUpdate(); }
}