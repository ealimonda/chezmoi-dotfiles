-- Hammerspoon configuration --

-- General Settings {{{1

hs.window.animationDuration = 0.05


-- Modes {{{1

-- Window Management mode {{{2
wmmode = hs.hotkey.modal.new({'ctrl'}, '´')
-- Slate compatibility
hs.hotkey.bind({'shift'}, 'f1', nil, function()
    -- {{{
    wmmode:enter()
end) -- }}}

-- {{{3

function wmmode:entered()
    -- {{{
    self.sticky_mode = false
    hs.alert.closeAll()
    hs.alert.show("Window Manager", 'forever')
end -- }}}

function wmmode:exited()
    -- {{{
    self.sticky_mode = false
    hs.alert.closeAll()
end -- }}}

function wmmode:autoexit()
    -- {{{
    if not self.sticky_mode then
        self:exit()
    end
end -- }}}

wmmode:bind({}, 'escape', function()
    -- {{{
    wmmode:exit()
end) -- }}}
wmmode:bind({'shift'}, 'f1', function()
    -- {{{
    wmmode:exit()
end) -- }}}
wmmode:bind({'ctrl'}, '´', function()
    -- {{{
    if wmmode.sticky_mode then
        wmmode:exit()
        return
    end
    wmmode.sticky_mode = true
    hs.alert.closeAll()
    hs.alert.show("Window Manager *", 'forever')
end) -- }}}

-- Function Definitions {{{1

-- Window Management {{{2

-- Nudge {{{3
-- Moves the currently selected window on the screen by dx, dy (absolute pixels
-- if > 1, otherwise percentage of screen)
function window_nudge(dx, dy)
    -- {{{
    if (not dx or dx == 0) and (not dy or dy == 0) then
        return
    end
    local win = hs.window.focusedWindow()
    if not win then
        return
    end
    local f = win:frame()
    local screen = win:screen():fullFrame()
    if dx then
        if math.abs(dx) <= 1 then
            f.x = f.x + math.floor(screen.w * dx)
        else
            f.x = f.x + dx
        end
        if f.x < screen.x then
            f.x = screen.x
        end
        if f.x + f.w > screen.x + screen.w then
            f.x = screen.x + screen.w - f.w
        end
    end
    if dy then
        if math.abs(dy) <= 1 then
            f.y = f.y + math.floor(screen.h * dy)
        else
            f.y = f.y + dy
        end
        if f.y < screen.y then
            f.y = screen.y
        end
        if f.y + f.h > screen.y + screen.h then
            f.y = screen.y + screen.h - f.h
        end
    end
    win:setFrameInScreenBounds(f)
end -- }}}
function window_nudge_factory(modal, dx, dy)
    -- {{{
    return function()
        undo:push()
        window_nudge(dx, dy)
        modal:autoexit()
    end
end -- }}}

-- Grid {{{3
-- Moves the currently selected window on the screen based on a 12x12 grid
function window_to_grid(gx, gw, gy, gh)
    -- {{{
    local win = hs.window.focusedWindow()
    if not win then
        return
    end
    local f = win:frame()
    local screen = win:screen():fullFrame()
    if gx or gw then
        if not gx or not gw then
            -- Either both present or both missing.
            return
        end
        if gx < 0 or gw <= 0 or gx+gw > 12 then
            return
        end
        f.x = screen.x + gx * screen.w / 12
        f.w = gw * screen.w / 12
    end
    if gy or gh then
        if not gy or not gh then
            -- Either both present or both missing.
            return
        end
        if gy < 0 or gh <= 0 or gy+gh > 12 then
            return
        end
        f.y = screen.y + gy * screen.h / 12
        f.h = gh * screen.h / 12
    end
    win:setFrameInScreenBounds(f)
end -- }}}
function window_to_grid_factory(modal, gx, gw, gy, gh)
    -- {{{
    return function()
        undo:push()
        window_to_grid(gx, gw, gy, gh)
        modal:autoexit()
    end
end -- }}}

-- Center {{{3
-- Moves the currently selected window to the center of the specified screen
-- (-1: west; 0/nil: current; 1: east)
function window_to_screen(screen_dir)
    -- {{{
    local win = hs.window.focusedWindow()
    if not win then
        return
    end
    local f = win:frame()
    local screen_data = nil
    if not s then
        screen_data = win:screen()
    elseif s < 0 then
        screen_data = win:screen():toWest()
    else
        screen_data = win:screen():toEast()
    end
    if not screen_data then
        return
    end
    local screen = screen_data:fullFrame()
    f.x = screen.x + (screen.w - f.w) / 2
    f.y = screen.y + (screen.h - f.h) / 2
    win:setFrameInScreenBounds(f)
end -- }}}
function window_to_screen_factory(modal, screen_dir)
    -- {{{
    return function()
        undo:push()
        window_to_screen(screen_dir)
        modal:autoexit()
    end
end -- }}}

-- Undo {{{2

-- From https://github.com/heptal/dotfiles/blob/master/roles/hammerspoon/files/window.lua
undo = {}

-- Push to Undo History {{{3
function undo:push()
    -- {{{
    local win = hs.window.focusedWindow()
    if win and not undo[win:id()] then
        self[win:id()] = win:frame()
    end
end -- }}}

-- Pop from Undo History {{{3
function undo:pop()
    -- {{{
    local win = hs.window.focusedWindow()
    if win and self[win:id()] then
        win:setFrame(self[win:id()])
        self[win:id()] = nil
    end
end


-- General Bindings {{{1

-- Hammerspoon Functions {{{2

-- Reload {{{3
wmmode:bind({'cmd'}, 'r', function()
    -- {{{
    wmmode:exit()
    print("Reloading...")
    hs.alert.closeAll()
    hs.alert.show("Reloading...", 'forever')
    timer = hs.timer.doAfter(1, function()
        hs.reload()
    end)
end) -- }}}

-- Undo {{{3
wmmode:bind({}, 'u', function()
    -- {{{
    undo:pop()
    wmmode:autoexit()
end) -- }}}

-- Window Management Bindings {{{1

-- Nudge/Move {{{2

-- Move to left edge {{{3
wmmode:bind({}, 'h', window_nudge_factory(wmmode, -1, 0))

-- Move to right edge {{{3
wmmode:bind({}, 'l', window_nudge_factory(wmmode, 1, 0))

-- Move to top edge {{{3
wmmode:bind({}, 'k', window_nudge_factory(wmmode, 0, -1))

-- Move to bottom edge {{{3
wmmode:bind({}, 'j', window_nudge_factory(wmmode, 0, 1))

-- Move 10% left {{{3
local nudge_left = window_nudge_factory(wmmode, -0.1, 0)
wmmode:bind({'shift'}, 'h', nudge_left, nil, nudge_left)

-- Move 10% right {{{3
local nudge_right = window_nudge_factory(wmmode, 0.1, 0)
wmmode:bind({'shift'}, 'l', nudge_right, nil, nudge_right)

-- Move 10% up {{{3
local nudge_up = window_nudge_factory(wmmode, 0, -0.1)
wmmode:bind({'shift'}, 'k', nudge_up, nil, nudge_up)

-- Move 10% down {{{3
local nudge_down = window_nudge_factory(wmmode, 0, 0.1)
wmmode:bind({'shift'}, 'j', nudge_down, nil, nudge_down)

-- Centered {{{2

-- Centered, keep size {{{3
local center_current_screen = window_to_screen_factory(wmmode, 0)
wmmode:bind({}, 'f', center_current_screen)
wmmode:bind({}, 'pad0', center_current_screen)

-- Centered, large {{{3
local grid_almostfull = window_to_grid_factory(wmmode, 1, 10, 1, 10)
wmmode:bind({'shift'}, 'f', grid_almostfull)
wmmode:bind({}, 'pad.', grid_almostfull)

-- Centered, full {{{3
local grid_full = window_to_grid_factory(wmmode, 0, 12, 0, 12)
wmmode:bind({}, 's', grid_full)
wmmode:bind({}, 'pad5', grid_full)

-- Halves {{{2

-- Left half {{{3
local grid_lefthalf = window_to_grid_factory(wmmode, 0, 6, 0, 12)
wmmode:bind({}, 'a', grid_lefthalf)
wmmode:bind({}, 'pad4', grid_lefthalf)

-- Right half {{{3
local grid_righthalf = window_to_grid_factory(wmmode, 6, 6, 0, 12)
wmmode:bind({}, 'd', grid_righthalf)
wmmode:bind({}, 'pad6', grid_righthalf)

-- Top half {{{3
local grid_tophalf = window_to_grid_factory(wmmode, 0, 12, 0, 6)
wmmode:bind({}, 'w', grid_tophalf)
wmmode:bind({}, 'pad8', grid_tophalf)

-- Bottom half {{{3
local grid_bottomhalf = window_to_grid_factory(wmmode, 0, 12, 6, 6)
wmmode:bind({}, 'x', grid_bottomhalf)
wmmode:bind({}, 'pad2', grid_bottomhalf)

-- Thirds {{{2

-- HCenter 1/3 {{{3
wmmode:bind({'alt'}, 's', window_to_grid_factory(wmmode, 4, 4, 0, 12))

-- HCenter 2/3 {{{3
wmmode:bind({'shift'}, 's', window_to_grid_factory(wmmode, 2, 8, 0, 12))

-- Left 1/3 {{{3
wmmode:bind({'alt'}, 'a', window_to_grid_factory(wmmode, 0, 4, 0, 12))

-- Left 2/3 {{{3
wmmode:bind({'shift'}, 'a', window_to_grid_factory(wmmode, 0, 8, 0, 12))

-- Right 1/3 {{{3
wmmode:bind({'alt'}, 'd', window_to_grid_factory(wmmode, 8, 4, 0, 12))

-- Right 2/3 {{{3
wmmode:bind({'shift'}, 'd', window_to_grid_factory(wmmode, 4, 8, 0, 12))

-- Top 1/3 {{{3
wmmode:bind({'alt'}, 'w', window_to_grid_factory(wmmode, 0, 12, 0, 4))

-- Top 2/3 {{{3
wmmode:bind({'shift'}, 'w', window_to_grid_factory(wmmode, 0, 12, 0, 8))

-- Bottom 1/3 {{{3
wmmode:bind({'alt'}, 'x', window_to_grid_factory(wmmode, 0, 12, 8, 4))

-- Bottom 2/3 {{{3
wmmode:bind({'shift'}, 'x', window_to_grid_factory(wmmode, 0, 12, 4, 8))

-- Corner Quarters (H1/2 V1/2) {{{2

-- Top Left Quarter {{{3
local grid_topleftquarter = window_to_grid_factory(wmmode, 0, 6, 0, 6)
wmmode:bind({}, 'q', grid_topleftquarter)
wmmode:bind({}, 'pad7', grid_topleftquarter)

-- Bottom Left Quarter {{{3
local grid_bottomleftquarter = window_to_grid_factory(wmmode, 0, 6, 6, 6)
wmmode:bind({}, 'z', grid_bottomleftquarter)
wmmode:bind({}, 'pad1', grid_bottomleftquarter)

-- Top Right Quarter {{{3
local grid_toprightquarter = window_to_grid_factory(wmmode, 6, 6, 0, 6)
wmmode:bind({}, 'e', grid_toprightquarter)
wmmode:bind({}, 'pad9', grid_toprightquarter)

-- Bottom Right Quarter {{{3
local grid_bottomrightquarter = window_to_grid_factory(wmmode, 6, 6, 6, 6)
wmmode:bind({}, 'c', grid_bottomrightquarter)
wmmode:bind({}, 'pad3', grid_bottomrightquarter)

-- Corner Thirds (H1/2 Vx/3) {{{2

-- Top Left 1/3 {{{3
wmmode:bind({'alt'}, 'q', window_to_grid_factory(wmmode, 0, 6, 0, 4))

-- Top Left 2/3 {{{3
wmmode:bind({'shift'}, 'q', window_to_grid_factory(wmmode, 0, 6, 0, 8))

-- Bottom Left 1/3 {{{3
wmmode:bind({'alt'}, 'z', window_to_grid_factory(wmmode, 0, 6, 8, 4))

-- Bottom Left 2/3 {{{3
wmmode:bind({'shift'}, 'z', window_to_grid_factory(wmmode, 0, 6, 4, 8))

-- Top Right 1/3 {{{3
wmmode:bind({'alt'}, 'e', window_to_grid_factory(wmmode, 6, 6, 0, 4))

-- Top Right 2/3 {{{3
wmmode:bind({'shift'}, 'e', window_to_grid_factory(wmmode, 6, 6, 0, 8))

-- Bottom Right 1/3 {{{3
wmmode:bind({'alt'}, 'c', window_to_grid_factory(wmmode, 6, 6, 8, 4))

-- Bottom Right 2/3 {{{3
wmmode:bind({'shift'}, 'c', window_to_grid_factory(wmmode, 6, 6, 4, 8))

-- Move Between Screens {{{2

-- Left {{{3
wmmode:bind({}, '[', function()
    -- {{{
    undo:push()
    local win = hs.window.focusedWindow()
    -- win:moveOneScreenWest(true, true)
    -- HACK replacing the above line that's erroring out
    win:moveToScreen(win:screen():toWest(), true, true)
    -- END HACK
    wmmode:autoexit()
end) -- }}}

-- Right {{{3
wmmode:bind({}, ']', function()
    -- {{{
    undo:push()
    local win = hs.window.focusedWindow()
    -- win:moveOneScreenEast(true, true)
    -- HACK replacing the above line that's erroring out
    win:moveToScreen(win:screen():toEast(), true, true)
    -- END HACK
    wmmode:autoexit()
end) -- }}}

-- Resize vertically {{{2

-- Expand to full height {{{3
local vertical_expand_fullheight = window_to_grid_factory(wmmode, nil, nil, 0, 12)
wmmode:bind({}, '=', vertical_expand_fullheight)
wmmode:bind({}, 'pad+', vertical_expand_fullheight)

-- Contract to 3/4 {{{3
local vertical_contract_threefourths = window_to_grid_factory(wmmode, nil, nil, 1, 9)
wmmode:bind({}, '-', vertical_contract_threefourths)
wmmode:bind({}, 'pad-', vertical_contract_threefourths)


-- Manual Grid-Based Resizing {{{2

-- Grid Settings {{{3
hs.grid.setMargins({0, 0})
hs.grid.setGrid('6x4', nil)
hs.grid.ui.textColor                   = {   1,   1,   1,   1 }
hs.grid.ui.cellColor                   = {   0,   0,   0, 0.3 }
hs.grid.ui.cellStrokeColor             = { 0.2, 0.2, 0.2, 0.8 }
hs.grid.ui.selectedColor               = { 0.7, 0.2,   0, 0.4 }
hs.grid.ui.highlightColor              = { 0.7, 0.7,   0, 0.4 }
hs.grid.ui.highlightStrokeColor        = {   0,   0,   0,   1 }
hs.grid.ui.cyclingHighlightColor       = {   0, 0.2, 0.8, 0.5 }
hs.grid.ui.cyclingHighlightStrokeColor = { 0.6, 0.8,   0,   1 }
hs.grid.ui.textSize                    = 64
hs.grid.ui.cellStrokeWidth             = 5
hs.grid.ui.highlightStrokeWidth        = 30
hs.grid.ui.fontName                    = 'HelveticaNeue-Thin'
hs.grid.ui.showExtraKeys               = true
--hs.grid.HINTS = {
--    { 'f1', 'f2', 'f3', 'f4', 'f5', 'f6', 'f7', 'f8', 'f9', 'f10' },
--    { '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' },
--    { 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P' },
--    { 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ';' },
--    { 'Z', 'X', 'C', 'V', 'B', 'N', 'M', ',', '.', '/' }
--}

-- Toggle Grid {{{3
wmmode:bind({}, 'space', function()
    -- {{{
    undo:push()
    hs.grid.toggleShow()
    wmmode:autoexit()
end) -- }}}

-- Pre-Defined Window Positions and Layouts {{{2

-- Positions {{{3
window_layouts = {
    {"iTunes",       "MiniPlayer",            "iMac",           nil,        nil,       hs.geometry.rect(0, -800, 350, 850)},
    {"iTunes",       "MiniPlayer", "Macbook Pro LCD",           nil,          hs.geometry.rect(0, 0, 310, 640),        nil},
    {"Safari",                nil,     "DELL U2412M",      hs.geometry.unitrect(0.145, 0, 0.75, 1),        nil,        nil},
    {"Firefox",               nil,     "DELL U2412M",      hs.geometry.unitrect(0.145, 0, 0.75, 1),        nil,        nil},
    {"Nightly",               nil,     "DELL U2412M",      hs.geometry.unitrect(0.145, 0, 0.75, 1),        nil,        nil},
    {"FirefoxNightly",        nil,     "DELL U2412M",      hs.geometry.unitrect(0.145, 0, 0.75, 1),        nil,        nil},
    {"Firefox Nightly",       nil,     "DELL U2412M",      hs.geometry.unitrect(0.145, 0, 0.75, 1),        nil,        nil},
    {"Safari",                nil,     "DELL U2719DC",     hs.geometry.unitrect(0.145, 0, 0.75, 1),        nil,        nil},
    {"Firefox",               nil,     "DELL U2719DC",     hs.geometry.unitrect(0.145, 0, 0.75, 1),        nil,        nil},
    {"Nightly",               nil,     "DELL U2719DC",     hs.geometry.unitrect(0.145, 0, 0.75, 1),        nil,        nil},
    {"FirefoxNightly",        nil,     "DELL U2719DC",     hs.geometry.unitrect(0.145, 0, 0.75, 1),        nil,        nil},
    {"Firefox Nightly",       nil,     "DELL U2719DC",     hs.geometry.unitrect(0.145, 0, 0.75, 1),        nil,        nil},
    {"Twitter",               nil,            "iMac",           nil,        nil,       hs.geometry.rect(0, -700, 400, 700)},
    {   "Mail", "All Mailboxes.*",            "iMac", hs.geometry.unitrect(0.505, 0.1, 0.495, 0.6),        nil,        nil},
    { "iTerm2",           ".*@.*",            "iMac",   hs.geometry.unitrect(0.5, 0.03, 0.5, 0.55),        nil,        nil},
}

-- Functions {{{3
function apply_singlewindow_layout(layouts)
    -- {{{
    local win = hs.window.focusedWindow()
    if not win then
        return
    end
    local app = win:application()
    local frame = nil
    local entry = hs.fnutils.find(layouts, function(candidate)
        if candidate[1] ~= app:name() then
            return false
        end
        if candidate[2] and not string.match(win:title(), candidate[2]) then
            return false
        end
        if candidate[3] and not hs.screen.find(candidate[3]) then
            return false
        end
        return true
    end)
    if not entry then
        hs.printf("Application not found in any layout: %s", app:name())
        return
    end
    local screen = hs.screen.find(entry[3])
    if (type(screen) == "table") then
        screen = screen[1]
    end
    if entry[4] then
        frame = screen:fromUnitRect(entry[4])
    elseif entry[5] then
        local screen_frame = screen:frame()
        local local_frame = entry[5]
        local x = screen_frame.x + local_frame.x
        local y = screen_frame.y + local_frame.y
        if local_frame.x < 0 then
            x = x + screen_frame.w
        end
        if local_frame.y < 0 then
            y = y + screen_frame.h
        end
        frame = hs.geometry.rect(x, y, local_frame.w, local_frame.h)
    elseif entry[6] then
        local screen_frame = screen:fullFrame()
        local local_frame = entry[6]
        local x = screen_frame.x + local_frame.x
        local y = screen_frame.y + local_frame.y
        if local_frame.x < 0 then
            x = x + screen_frame.w
        end
        if local_frame.y < 0 then
            y = y + screen_frame.h
        end
        frame = hs.geometry.rect(x, y, local_frame.w, local_frame.h)
    end
    win:move(frame, screen, true)
end -- }}}

-- Apply Entire Layout {{{3
wmmode:bind({'shift'}, 'return', function()
    -- {{{
    -- TODO: No undo available for this operation right now.
    hs.layout.apply(window_layouts, string.match)
    wmmode:autoexit()
end) -- }}}

-- Apply only to current window {{{3
wmmode:bind({}, 'return', function()
    -- {{{
    undo:push()
    apply_singlewindow_layout(window_layouts)
    wmmode:autoexit()
end) -- }}}

-- Window/App Selection Bindings {{{1

-- Exposé {{{2

-- (disabled due to memory leaks)

-- Settings {{{3
-- hs.expose.ui.textColor                       = {0.9, 0.9, 0.9, 1}
-- hs.expose.ui.fontName                        = 'HelveticaNeue-Thin'
-- hs.expose.ui.textSize                        = 40
-- hs.expose.ui.highlightColor                  = {0.2, 0.6, 0.8, 0.9}
-- hs.expose.ui.backgroundColor                 = {0.1, 0.1, 0.1, 0.75}
-- hs.expose.ui.closeModeModifier               = 'alt'
-- hs.expose.ui.closeModeBackgroundColor        = {0.8, 0.2, 0.1, 0.75}
-- hs.expose.ui.minimizeModeModifier            = 'shift'
-- hs.expose.ui.minimizeModeBackgroundColor     = {0.1, 0.2, 0.3, 0.75}
-- hs.expose.ui.onlyActiveApplication           = false
-- hs.expose.ui.includeNonVisible               = true
-- hs.expose.ui.nonVisibleStripBackgroundColor  = {0.03, 0.1, 0.15, 0.75}
-- hs.expose.ui.nonVisibleStripPosition         = 'right'
-- hs.expose.ui.nonVisibleStripWidth            = 0.15
-- hs.expose.ui.includeOtherSpaces              = true
-- hs.expose.ui.otherSpacesStripBackgroundColor = {0.1, 0.1, 0.1, 0.75}
-- hs.expose.ui.otherSpacesStripPosition        = 'top'
-- hs.expose.ui.otherSpacesStripWidth           = 0.15
-- hs.expose.ui.showTitles                      = true
-- hs.expose.ui.showThumbnails                  = true
-- hs.expose.ui.thumbnailAlpha                  = 0.5
-- hs.expose.ui.highlightThumbnailAlpha         = 1
-- hs.expose.ui.highlightThumbnailStrokeWidth   = 8
-- hs.expose.ui.maxHintLetters                  = 3
-- hs.expose.ui.fitWindowsMaxIterations         = 30
-- hs.expose.ui.fitWindowsInBackground          = false
-- expose = hs.expose.new()
-- app_expose = hs.expose.new(nil, {
--     onlyActiveApplication = true
-- })
-- simple_expose = hs.expose.new(nil, {
--     showThumbnails = false,
--     highlightColor = {0.2, 0.6, 0.8, 0.2}
-- })
-- simple_app_expose = hs.expose.new(nil, {
--     onlyActiveApplication = true,
--     showThumbnails = false,
--     highlightColor = {0.2, 0.6, 0.8, 0.2}
-- })
-- 
-- -- Global Exposé {{{3
-- wmmode:bind({}, '´', function()
--     -- {{{
--     expose:toggleShow()
--     wmmode:autoexit()
-- end) -- }}}
-- wmmode:bind({'alt'}, '`', function()
--     -- {{{
--     simple_expose:toggleShow()
--     wmmode:autoexit()
-- end) -- }}}
-- 
-- -- App Exposé {{{3
-- wmmode:bind({'shift'}, '`', function()
--     -- {{{
--     app_expose:toggleShow()
--     wmmode:autoexit()
-- end) -- }}}
-- wmmode:bind({'shift', 'alt'}, '`', function()
--     -- {{{
--     simple_app_expose:toggleShow()
--     wmmode:autoexit()
-- end) -- }}}

-- Window Selection Hints {{{2

-- Settings {{{3
hs.hints.fontName = 'Monaco'
hs.hints.fontSize = 18
hs.hints.showTitleThresh = 2
hs.hints.style = 'vimperator'
-- hs.hints.titleMaxSize = '32'

-- Vimperator-Style Hints {{{3
wmmode:bind({}, 'tab', function()
    -- {{{
    hs.hints.windowHints()
    wmmode:autoexit()
end) -- }}}

-- Tabbing {{{2

-- Settings {{{3
hs.window.switcher.ui.textColor             = {1, 1, 1}
hs.window.switcher.ui.fontName              = 'HelveticaNeue-Light'
hs.window.switcher.ui.textSize              = 16
hs.window.switcher.ui.highlightColor        = {0.8, 0.5, 0, 0.8}
hs.window.switcher.ui.backgroundColor       = {0.3, 0.3, 0.3, 0.7}
hs.window.switcher.ui.onlyActiveApplication = true
hs.window.switcher.ui.showTitles            = false
hs.window.switcher.ui.titleBackgroundColor  = {0, 0, 0, 0.8}
hs.window.switcher.ui.showThumbnails        = true
hs.window.switcher.ui.thumbnailSize         = 128
hs.window.switcher.ui.showSelectedThumbnail = true
hs.window.switcher.ui.selectedThumbnailSize = 384
hs.window.switcher.ui.showSelectedTitle     = true
windowswitcher = hs.window.switcher.new()

-- Ctrl-(Shift)-Tab {{{3
wmmode:bind({'ctrl'}, 'tab', function()
    -- {{{
    -- TODO: This probably requires an event tap in order to be able to leave wmmode when releasing ctrl
    windowswitcher:next()
end) -- }}}
wmmode:bind({'ctrl', 'shift'}, 'tab', function()
    -- {{{
    -- TODO: This probably requires an event tap in order to be able to leave wmmode when releasing ctrl
    windowswitcher:previous()
end) -- }}}

-- Select display {{{2

-- From http://bezhermoso.github.io/2016/01/20/making-perfect-ramen-lua-os-x-automation-with-hammerspoon/
-- DISPLAY FOCUS SWITCHING --

--One hotkey should just suffice for dual-display setups as it will naturally
--cycle through both.
--A second hotkey to reverse the direction of the focus-shift would be handy
--for setups with 3 or more displays.

-- Functions {{{3

--Predicate that checks if a window belongs to a screen
function is_in_screen(screen, win)
    -- {{{
    return win:screen() == screen
end -- }}}

-- Brings focus to the scren by setting focus on the front-most application in it.
-- Also move the mouse cursor to the center of the screen. This is because
-- Mission Control gestures & keyboard shortcuts are anchored, oddly, on where the
-- mouse is focused.
function focus_screen(screen)
    -- {{{
    --Get windows within screen, ordered from front to back.
    --If no windows exist, bring focus to desktop. Otherwise, set focus on
    --front-most application window.
    local windows = hs.fnutils.filter(
        hs.window.orderedWindows(),
        hs.fnutils.partial(is_in_screen, screen))
    local windowToFocus = #windows > 0 and windows[1] or hs.window.desktop()
    windowToFocus:focus()
end -- }}}

-- Bring focus to previous display/screen {{{3
wmmode:bind({'cmd'}, "[", function()
    -- {{{
  focus_screen(hs.window.focusedWindow():screen():previous())
end) -- }}}

-- Bring focus to next display/screen {{{3
wmmode:bind({'cmd'}, "]", function()
    -- {{{
    focus_screen(hs.window.focusedWindow():screen():next())
end) -- }}}

-- END DISPLAY FOCUS SWITCHING --

-- Select windows with arrows {{{2

-- East {{{3
wmmode:bind({}, 'right', function()
    -- {{{
    local win = hs.window.focusedWindow()
    if not win then
        wmmode:autoexit()
        return
    end
    local candidates = win:windowsToEast(nil, true)
    if #candidates > 0 then
        candidates[1]:focus()
    end
    wmmode:autoexit()
end) -- }}}

-- North {{{3
wmmode:bind({}, 'up', function()
    -- {{{
    local win = hs.window.focusedWindow()
    if not win then
        wmmode:autoexit()
        return
    end
    local candidates = win:windowsToNorth(nil, true)
    if #candidates > 0 then
        candidates[1]:focus()
    end
    wmmode:autoexit()
end) -- }}}

-- South {{{3
wmmode:bind({}, 'down', function()
    -- {{{
    local win = hs.window.focusedWindow()
    if not win then
        wmmode:autoexit()
        return
    end
    local candidates = win:windowsToSouth(nil, true)
    if #candidates > 0 then
        candidates[1]:focus()
    end
    wmmode:autoexit()
end) -- }}}

-- West {{{3
wmmode:bind({}, 'left', function()
    -- {{{
    local win = hs.window.focusedWindow()
    if not win then
        wmmode:autoexit()
        return
    end
    local candidates = win:windowsToWest(nil, true)
    if #candidates > 0 then
        candidates[1]:focus()
    end
    wmmode:autoexit()
end) -- }}}


-- URL Dispatcher {{{1

-- From: https://github.com/zzamboni/oh-my-hammerspoon

-- Sets Hammerspoon as the default browser for HTTP/HTTPS links, and
-- dispatches them to different apps according to the patterns define
-- in the config. If no pattern matches, `default_handler` is used.

-- Configuration {{{2
url_dispatcher = {
    config = {
        patterns = {
            -- evaluated in the order they are declared. Entry format: { "url pattern", "application bundle ID" }
            -- e.g.
            --      { "https?://gmail.com", "com.google.Chrome" },
            --      { "https?://en.wikipedia.org", "org.epichrome.app.Wikipedia" },
        },
        -- Bundle ID for default URL handler
        default_handler = "com.apple.Safari",
        handlers = {
            "org.mozilla.firefox",
            "com.apple.Safari",
            "com.microsoft.edgemac",
            "org.mozilla.nightly",
            "com.vivaldi.Vivaldi",
            "org.chromium.Chromium",
        },
        -- Handle Slack-redir URLs specially so that we apply the rule on the destination URL
        decode_slack_redir_urls = false,
    },
}

-- Functions {{{2

-- Misc {{{3

-- Decode URLs
local hex_to_char = function(x)
    -- {{{
    return string.char(tonumber(x, 16))
end -- }}}

local unescape = function(url)
    -- {{{
    return url:gsub("%%(%x%x)", hex_to_char)
end -- }}}

-- Attempt at getting an app ID from either an ID or the app name. Not fully debugged yet.
function getAppId(app, launch)
    -- {{{
    if launch == nil then
        launch = false
    end
    -- Convert to app name if it's a bundleID
    local name = hs.application.nameForBundleID(app)
    local appid = nil
    if name ~= nil then
        -- app is a valid bundleID, so we return it
        hs.printf("Found an app with bundle ID %s: %s", app, name)
        appid = app
    else
        -- assume it's an app name, first try to find it running
        local appobj = hs.application.find(app)
        if appobj ~= nil then
            appid = appobj:bundleID()
            hs.printf("Found a running app that matches %s: %s (bundle ID %s)", app, appobj:name(), appid)
        else
            if launch then
                -- as a last resort, try to launch it and then get its ID
                hs.printf("Trying to launch app %s", app)
                if hs.application.launchOrFocus(app) then
                    appobj = hs.application.find(app)
                    hs.printf("appobj = %s", hs.inspect(appobj))
                    if appobj ~= nil then
                        hs.printf("Found a running app that matches %s: %s (bundle ID %s)", app, appobj:name(), appid)
                        appid = appobj:bundleID()
                    else
                        hs.printf("%s launched successfully, but can't find it running", app)
                    end
                else
                    hs.printf("Launching app %s failed", app)
                end
            else
                hs.printf("No running app matches '%s', launch=false so not trying to run one", app)
            end
        end
    end
    return appid
end -- }}}

-- Callback {{{3

function url_dispatcher.customHttpCallback(scheme, host, params, fullUrl)
    -- {{{
    hs.printf("Handling URL %s", fullUrl)
    local url = fullUrl
    if url_dispatcher.config.decode_slack_redir_urls then
        local newUrl = string.match(url, 'https://slack.redir.net/.*url=(.*)')
        if newUrl then
            url = unescape(newUrl)
            hs.printf("Got slack-redir URL, target URL: %s", url)
        end
    end
    for i,pair in ipairs(url_dispatcher.config.patterns) do
        local p = pair[1]
        local app = pair[2]
        hs.printf("Matching %s against %s", url, p)
        if string.match(url, p) then
            hs.printf("  Match! Opening with %s", app)
            -- id = getAppId(app, true)
            id = app
            if id ~= nil then
                hs.urlevent.openURLWithBundle(url, id)
                return
            else
                hs.printf("I could not find an application that matches '%s', falling through to default handler", app)
            end
        end
    end
    --hs.urlevent.openURLWithBundle(url, url_dispatcher.config.default_handler)
    url_dispatcher.current_url[#url_dispatcher.current_url + 1] = url
    if not url_dispatcher.chooser:isVisible() then
        url_dispatcher.chooser:width(500 * 100 / hs.screen.mainScreen():frame().w)
        url_dispatcher.chooser:show()
    end
end -- }}}

function url_dispatcher:init()
    -- {{{
    hs.urlevent.httpCallback = self.customHttpCallback
    hs.urlevent.setDefaultHandler('http')
    self.current_url = {}
    self.chooser = hs.chooser.new(function(handler)
        if #url_dispatcher.current_url == 0 then
            return
        end
        local url = url_dispatcher.current_url[1]
        table.remove(url_dispatcher.current_url, 1)
        if handler and handler.bundle_id then
            hs.urlevent.openURLWithBundle(url, handler.bundle_id)
        end
        if #url_dispatcher.current_url > 0 then
            url_dispatcher.timer = hs.timer.doAfter(0, function()
                url_dispatcher.timer = nil
                url_dispatcher.chooser:show()
            end)
        end
    end)
    self.chooser:bgDark(true)
    self.chooser:fgColor({ white = 0.95, alpha = 1 })
    self.chooser:subTextColor({ white =  0.5, alpha = 1 })
    self.chooser:choices(hs.fnutils.imap(self.config.handlers, function(handler)
        local app_name = hs.application.nameForBundleID(handler)
        return {
            ["text"] = app_name,
            ["image"] = hs.image.imageFromAppBundle(handler),
            ["subText"] = string.format("Open page with %s", app_name),
            ["bundle_id"] = handler,
        }
    end))
    self.chooser:rows(#self.config.handlers > 6 and 6 or #self.config.handlers)
end -- }}}

url_dispatcher:init()

-- }}}1

-- Finally, show a notification that we finished loading the config
hs.notify.new( {title='Hammerspoon', subTitle='Configuration loaded'} ):send()

-- WIP {{{1


-- Unused keys {{{2

-- function NYI()
--     hs.alert.show('Not implemented!', 2)
-- end

-- wmmode:bind({}, '1', NYI)
-- wmmode:bind({}, '2', NYI)
-- wmmode:bind({}, '3', NYI)
-- wmmode:bind({}, '4', NYI)
-- wmmode:bind({}, '5', NYI)
-- wmmode:bind({}, '6', NYI)
-- wmmode:bind({}, '7', NYI)
-- wmmode:bind({}, '8', NYI)
-- wmmode:bind({}, '9', NYI)
-- wmmode:bind({}, '0', NYI)
-- wmmode:bind({}, 'r', NYI)
-- wmmode:bind({}, 't', NYI)
-- wmmode:bind({}, 'y', NYI)
-- wmmode:bind({}, 'i', NYI)
-- wmmode:bind({}, 'o', NYI)
-- wmmode:bind({}, 'p', NYI)
-- wmmode:bind({}, 'g', NYI)
-- wmmode:bind({}, ';', NYI)
-- wmmode:bind({}, '\'', NYI)
-- wmmode:bind({}, '\\', NYI)
-- wmmode:bind({}, 'v', NYI)
-- wmmode:bind({}, 'b', NYI)
-- wmmode:bind({}, 'n', NYI)
-- wmmode:bind({}, 'm', NYI)
-- wmmode:bind({}, ',', NYI)
-- wmmode:bind({}, '.', NYI)
-- wmmode:bind({}, '/', NYI)
-- wmmode:bind({}, '´', NYI)
-- wmmode:bind({}, 'f1', NYI)
-- wmmode:bind({}, 'f2', NYI)
-- wmmode:bind({}, 'f3', NYI)
-- wmmode:bind({}, 'f4', NYI)
-- wmmode:bind({}, 'f5', NYI)
-- wmmode:bind({}, 'f6', NYI)
-- wmmode:bind({}, 'f7', NYI)
-- wmmode:bind({}, 'f8', NYI)
-- wmmode:bind({}, 'f9', NYI)
-- wmmode:bind({}, 'f10', NYI)
-- wmmode:bind({}, 'f11', NYI)
-- wmmode:bind({}, 'f12', NYI)
-- wmmode:bind({}, 'f13', NYI)
-- wmmode:bind({}, 'f14', NYI)
-- wmmode:bind({}, 'f15', NYI)
-- wmmode:bind({}, 'f16', NYI)
-- wmmode:bind({}, 'f17', NYI)
-- wmmode:bind({}, 'f18', NYI)
-- wmmode:bind({}, 'f19', NYI)
-- wmmode:bind({}, 'f20', NYI)
-- wmmode:bind({}, 'pad*', NYI)
-- wmmode:bind({}, 'pad/', NYI)
-- wmmode:bind({}, 'pad=', NYI)
-- wmmode:bind({}, 'padclear', NYI)
-- wmmode:bind({}, 'padenter', NYI)
-- wmmode:bind({}, 'delete', NYI)
-- wmmode:bind({}, 'help', NYI)
-- wmmode:bind({}, 'home', NYI)
-- wmmode:bind({}, 'pageup', NYI)
-- wmmode:bind({}, 'forwarddelete', NYI)
-- wmmode:bind({}, 'end', NYI)
-- wmmode:bind({}, 'pagedown', NYI)

-- Future inspirations: {{{2
-- https://github.com/scottcs/dot_hammerspoon/blob/master/.hammerspoon/modules/battery.lua
-- https://github.com/scottcs/dot_hammerspoon
-- https://github.com/ashfinal/awesome-hammerspoon
-- https://github.com/peterhajas/dotfiles/blob/master/hammerspoon/.hammerspoon/itunes_albumart.lua
-- TODO: Keyboard layout switcher http://www.hammerspoon.org/docs/hs.keycodes.html

-- Temp/test stuff {{{2
layoutchooser = hs.chooser.new(function(result)
    -- print(hs.inspect(result))
    if result.type == 'layout' then
        hs.keycodes.setLayout(result.text)
    elseif result.type == 'method' then
        hs.keycodes.setMethod(result.text)
    end
end)
layoutchooser:choices(hs.fnutils.concat(
    hs.fnutils.map(hs.keycodes.methods(), function(e)
        return {
            ["text"] = e,
            ["image"] = (function(img)
                if img then
                    return img
                else
                    return hs.keycodes.currentLayoutIcon()
                end
            end)(hs.keycodes.iconForLayoutOrMethod(e)),
            ["type"] = "method"
        }
    end),
    hs.fnutils.map(hs.keycodes.layouts(), function(e)
        return {
            ["text"] = e,
            ["image"] = hs.keycodes.iconForLayoutOrMethod(e),
            ["type"] = "layout"
        }
    end)
))
wmmode:bind({}, '`', function()
    -- {{{
    layoutchooser:width(500 * 100 / hs.screen.mainScreen():frame().w)
    layoutchooser:show()
    wmmode:autoexit()
end) -- }}}

-- }}}1

-- vim: set ts=4 sw=4 et foldmethod=marker foldenable : --
