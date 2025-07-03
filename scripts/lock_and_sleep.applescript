tell application "System Events"
    -- Lock the screen
    do shell script "/System/Library/CoreServices/Menu\\ Extras/User.menu/Contents/Resources/CGSession -suspend"
end tell

tell application "System Events"
    -- Sleep the display
    do shell script "pmset displaysleepnow"
end tell
