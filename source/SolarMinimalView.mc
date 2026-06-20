import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Time;
import Toybox.Time.Gregorian;


class SolarMinimalView extends WatchUi.WatchFace {
    private var _yahaUsagiBmp; 

    // Seconds tracking variables for partial update
    private var _secX = 0;
    private var _secY = 0;
    private var _secFont = Graphics.FONT_TINY;
    private var _secClipX = 0;
    private var _secClipY = 0;
    private var _secClipWidth = 0;
    private var _secClipHeight = 0;

    // Performance optimization caching variables
    private var _lastMin = -1;
    private var _dateText = "";
    private var _batteryText = "";
    private var _batteryDaysText = "";
    private var _solarText = "";
    
    // Heart rate tracking optimization variables
    private var _lastHrReadSec = -1;
    private var _hrText = "--";

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc as Graphics.Dc) as Void {
        // We perform custom drawing directly in onUpdate to support responsive layouts
        _yahaUsagiBmp = WatchUi.loadResource(Rez.Drawables.YahaUsagi);
    }

    // Called when this View is brought to the foreground
    function onShow() as Void {
    }

    // Update the watch face display
    function onUpdate(dc as Graphics.Dc) as Void {
        // Ensure no clipping area is active during full update
        dc.clearClip();

        // Clear background to solid black
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Get screen dimensions
        var screenWidth = dc.getWidth();
        var screenHeight = dc.getHeight();
        var centerX = screenWidth / 2;
        var centerY = screenHeight / 2;

        // 1. Get current time digits
        var clockTime = System.getClockTime();
        var hhString = clockTime.hour.format("%02d");
        var mmString = clockTime.min.format("%02d");
        var ssString = clockTime.sec.format("%02d");

        // --- DRAW TIME (Hours:Minutes) ---
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        
        var hourFont = Graphics.FONT_NUMBER_HOT;
        var minuteFont = Graphics.FONT_NUMBER_HOT;
        var colFont = Graphics.FONT_LARGE;
        var secFont = Graphics.FONT_TINY;
        
        var hhWidth = dc.getTextWidthInPixels(hhString, hourFont);
        var colWidth = dc.getTextWidthInPixels(":", colFont);
        var mmWidth = dc.getTextWidthInPixels(mmString, minuteFont);
        
        var hourHeight = dc.getFontHeight(hourFont);
        var minuteHeight = dc.getFontHeight(minuteFont);
        
        // Centered vertically based on minute height
        var numY = centerY - (minuteHeight / 2) - 5;
        
        // Align hours vertically to center with the minutes
        var hourNumY = numY + (minuteHeight - hourHeight) / 2;
        
        // Dynamically align colons vertically with the giant FONT_NUMBER_HOT
        var colY = numY + (minuteHeight - dc.getFontHeight(colFont)) / 2;
        
        // Position seconds directly below Minutes (tightly spaced relative to minutes)
        var secY = numY + minuteHeight - 16;
        
        // Red line & Battery parameters (using 5px spacing)
        var lineWidth = 3;
        var lineSpacing = 5;
        var rightPadding = 12; // Extra padding on the right to prevent circular screen clipping

        // Calculate width of only the time portion
        var timeWidth = hhWidth + colWidth + mmWidth + 4;
        
        var batteryFont = Graphics.FONT_XTINY;

        // Get date, battery, and solar info (cached, only update when minute changes or first run)
        if (_lastMin != clockTime.min || _dateText.equals("")) {
            _lastMin = clockTime.min;
            
            // Get date info
            var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
            _dateText = today.day_of_week + " " + today.day;
            
            // Get battery stats
            var stats = System.getSystemStats();
            _batteryText = "PW: " + stats.battery.format("%d") + "%";
            
            if (stats has :batteryInDays && stats.batteryInDays != null) {
                _batteryDaysText = "D-: " + stats.batteryInDays.format("%d") + "D";
            } else {
                _batteryDaysText = "-- d";
            }
            
            // Get solar intensity info
            var solarIntensity = 0;
            if (stats has :solarIntensity && stats.solarIntensity != null) {
                solarIntensity = stats.solarIntensity;
            }
            _solarText = "SLR: " + solarIntensity.format("%d");
        }
        var dateTextWidth = dc.getTextWidthInPixels(_dateText, batteryFont);
        var batteryTextWidth = dc.getTextWidthInPixels(_batteryText, batteryFont);
        var batteryDaysTextWidth = dc.getTextWidthInPixels(_batteryDaysText, batteryFont);
        var solarTextWidth = dc.getTextWidthInPixels(_solarText, batteryFont);

        // Get heart rate info (with cached logic to avoid frequent history database access)
        var hr = null;
        var info = Activity.getActivityInfo();
        if (info != null) {
            hr = info.currentHeartRate;
        }
        if (hr != null) {
            _hrText = "HR: " + hr.format("%d");
            _lastHrReadSec = clockTime.sec;
        } else {
            // Only read history at most once every 10 seconds to save power when sensor is null
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
        var hrTextWidth = dc.getTextWidthInPixels(_hrText, batteryFont);

        var rightBlockWidth = batteryTextWidth;
        if (hrTextWidth > rightBlockWidth) {
            rightBlockWidth = hrTextWidth;
        }
        if (dateTextWidth > rightBlockWidth) {
            rightBlockWidth = dateTextWidth;
        }
        if (batteryDaysTextWidth > rightBlockWidth) {
            rightBlockWidth = batteryDaysTextWidth;
        }
        if (solarTextWidth > rightBlockWidth) {
            rightBlockWidth = solarTextWidth;
        }

        // Calculate total combined width of the entire group (Time + Line + Right Block + Padding)
        var totalWidth = timeWidth + lineSpacing + lineWidth + lineSpacing + 1 + rightBlockWidth + rightPadding;
        
        // Align starting X position dynamically so the entire group is centered horizontally
        var startX = centerX - (totalWidth / 2) + 5;

        // Draw Hours
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, hourNumY, hourFont, hhString, Graphics.TEXT_JUSTIFY_LEFT);
        
        // Draw first colon
        dc.drawText(startX + hhWidth + 2, colY, colFont, ":", Graphics.TEXT_JUSTIFY_LEFT);
        
        // Draw Minutes
        dc.drawText(startX + hhWidth + colWidth + 4, numY, minuteFont, mmString, Graphics.TEXT_JUSTIFY_LEFT);

        // Draw Seconds (positioned directly next to the red line, right-aligned with the Minutes block to keep spacing identical)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var secX = startX + timeWidth - 10;
        dc.drawText(secX, secY, secFont, ssString, Graphics.TEXT_JUSTIFY_RIGHT);

        // Update tracking variables for 1Hz partial updates
        var secWidth = dc.getTextWidthInPixels("59", secFont);
        var secHeight = dc.getFontHeight(secFont);
        _secX = secX;
        _secY = secY;
        _secFont = secFont;
        _secClipX = secX - secWidth - 2;
        _secClipY = secY;
        _secClipWidth = secWidth + 4;
        _secClipHeight = secHeight;



        // Draw the vertical red line on the right side of the time
        var lineX = startX + timeWidth + lineSpacing;
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        var extraHeight = 20; // Total extra height to add in pixels 
        dc.fillRectangle(lineX, numY - (extraHeight / 2), lineWidth, minuteHeight + extraHeight);

        // Draw Date, Battery, Solar, Days, and HR Info on the right side of the red line
        var batteryX = lineX + lineWidth + lineSpacing + 1;
        var tinyFontHeight = dc.getFontHeight(batteryFont);
        var textSpacing = 2;
        var totalTextHeight = tinyFontHeight * 5 + textSpacing * 4;
        var rightBlockY = centerY - (totalTextHeight / 2);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(batteryX, rightBlockY, batteryFont, _dateText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(batteryX, rightBlockY + tinyFontHeight + textSpacing, batteryFont, _batteryText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(batteryX, rightBlockY + (tinyFontHeight + textSpacing) * 2, batteryFont, _solarText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(batteryX, rightBlockY + (tinyFontHeight + textSpacing) * 3, batteryFont, _batteryDaysText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(batteryX, rightBlockY + (tinyFontHeight + textSpacing) * 4, batteryFont, _hrText, Graphics.TEXT_JUSTIFY_LEFT);
    
        // --- DRAW YAHAUSAGI BITMAP AND DAILY STEPS ---
        var steps = 0;
        var actInfo = ActivityMonitor.getInfo();
        if (actInfo != null && actInfo.steps != null) {
            steps = actInfo.steps;
        }
        var stepsText = steps.toString();

        var imgWidth = _yahaUsagiBmp.getWidth();
        var imgHeight = _yahaUsagiBmp.getHeight();
        var stepsTextWidth = dc.getTextWidthInPixels(stepsText, batteryFont);
        
        var spacing = 5;
        var combinedWidth = imgWidth + spacing + stepsTextWidth;
        
        // X-axis: Center the combined block (image + steps) horizontally
        var combinedStartX = centerX - (combinedWidth / 2);
        var imgX = combinedStartX;
        var stepsX = combinedStartX + imgWidth + spacing;

        // Y-axis: Position below the red line's bottom
        var imgY = numY + minuteHeight + (extraHeight / 2) + 20;
        var stepsY = imgY + (imgHeight - dc.getFontHeight(batteryFont)) / 2;

        // Draw image and daily steps
        dc.drawBitmap(imgX, imgY, _yahaUsagiBmp);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(stepsX, stepsY, batteryFont, stepsText, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Implement 1Hz partial update for seconds in low power mode
    function onPartialUpdate(dc as Graphics.Dc) as Void {
        // Skip rendering if tracking variables are not initialized
        if (_secClipWidth == 0) {
            return;
        }

        var clockTime = System.getClockTime();
        var ssString = clockTime.sec.format("%02d");

        // Set clipping region
        dc.setClip(_secClipX, _secClipY, _secClipWidth, _secClipHeight);

        // Clear the old seconds with background color (black)
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Draw new seconds value
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_secX, _secY, _secFont, ssString, Graphics.TEXT_JUSTIFY_RIGHT);

        // Clear clipping region to restore draw state
        dc.clearClip();
    }

    // Called when this View is removed from the screen
    function onHide() as Void {
    }

    // Terminate sleep mode (gesture detected, high power mode)
    function onExitSleep() as Void {
        WatchUi.requestUpdate();
    }

    // Enter sleep mode (timeout reached, low power mode)
    function onEnterSleep() as Void {
        WatchUi.requestUpdate();
    }
}
