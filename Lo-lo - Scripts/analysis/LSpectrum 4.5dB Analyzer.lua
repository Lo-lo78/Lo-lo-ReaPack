-- @description LSpectrum Analyzer – 10s Analysis + Accessible 3-Column Table
-- @version 6.6
-- @author Lo-lo and GPT
-- @noindex

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local analysis_duration = 10
local last_tab_time = 0
local kick_mode = false
local ANALYZER_NAME = "JS: LSpectrum 4.5dB Analyzer"
local master = reaper.GetMasterTrack(0)
local current_track = master
local countdown_window_open = false

local result_dir  = reaper.GetResourcePath() .. "/Scripts/Lo-lo - Scripts/analysis/LSpectrum 4.5dB Analyzer"
local result_file = result_dir .. "/spectrum_LastResult.txt"
local help_file   = reaper.GetResourcePath() .. "/Effects/Lo-lo - JSFX/analysis/LSpectrum 4.5dB Analyzer — Full Quick Guide.html"

reaper.RecursiveCreateDirectory(result_dir, 0)

local freqs = {
    22.3, 27.6, 34.3, 42.6, 52.8, 65.6, 81.4, 101,
    125, 155, 193, 239, 297, 369, 458, 568,
    705, 874, 1085, 1346, 1671, 2073, 2573, 3193,
    3962, 4916, 6101, 7571, 9395, 11659, 14468, 17954
}

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local last_key = nil
local last_key_time = 0
local DOUBLE_TIME = 0.30

local last_duration = tonumber(reaper.GetExtState("LSpectrum", "Duration")) or 10
local result_header_type = ""
local current_genre_name = "Default: EDM Synth Pop 4.5 dB"

local sum = {}
local count = 0
local fx
local startTime
local last_spoken = -1
local GetParamEx = reaper.TrackFX_GetParamEx
local last_result_bands = 32
local allow_restart = true

local table_vals = {}
local result_lines = {}
local current_row = 1
local current_col = 1
local running_table = false
local script_running = true
local tab_count = 0

local selection_mode = false
local selected_bands = {}
local band_order = {}
local full_table_vals = {}
local full_band_order = {}

for i = 1, 32 do
    band_order[i] = i
    full_band_order[i] = i
end

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------
local function speak(msg)
    if reaper.osara_outputMessage then
        reaper.osara_outputMessage(tostring(msg))
    end
end

local function is_double(key)
    local t = reaper.time_precise()
    local dbl = (last_key == key and (t - last_key_time) < DOUBLE_TIME)
    last_key = key
    last_key_time = t
    return dbl
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function get_selection_max_band()
    return kick_mode and 14 or 32
end

local function get_selection_band_number()
    return clamp(current_row, 1, get_selection_max_band())
end

local function reset_analysis_state()
    for i = 1, 32 do
        sum[i] = 0
    end
    count = 0
    last_spoken = -1
    startTime = reaper.time_precise()
end

local function get_track_label(track)
    if track == master then
        return "Master"
    end

    local track_num = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
    local _, track_name = reaper.GetTrackName(track)
    return string.format("Track %d (%s)", track_num, track_name)
end

local function get_current_band_number()
    if selection_mode then
        return get_selection_band_number()
    end
    return band_order[current_row] or current_row
end

local function get_active_band_list()
    local max_band = get_selection_max_band()
    local list = {}

    for i = 1, max_band do
        if selected_bands[i] then
            list[#list + 1] = i
        end
    end

    if #list == 0 then
        for i = 1, max_band do
            list[#list + 1] = i
        end
    end

    return list
end

local function build_next_scan_text()
    local active_bands = get_active_band_list()
    return "Next scan. " ..
           get_track_label(current_track) ..
           ". " .. current_genre_name ..
           ". " .. #active_bands .. " bands active."
end

local function get_result_window_title()
    return "Analysis Result – " .. get_track_label(current_track) .. " – " .. current_genre_name
end

local function build_result_title_text()
    return get_result_window_title()
end

local function get_countdown_window_title()
    return "Countdown – " .. get_track_label(current_track)
end

local function get_current_header()
    return result_header_type ~= "" and result_header_type or "Analysis type: Unknown"
end

local function normalize_windows_path(path)
    return tostring(path):gsub("/", "\\")
end

local function init_result_window()
    gfx.quit()
    gfx.init(get_result_window_title(), 4000, 4000, 0, 0, 0)
end

local function init_countdown_window()
    gfx.quit()
    gfx.init(get_countdown_window_title(), 800, 400)
    countdown_window_open = true
end

local function refresh_visible_table_from_full_data()
    local active_bands = get_active_band_list()

    table_vals = {}
    result_lines = {}
    band_order = {}

    result_lines[#result_lines + 1] = "Band | Frequency | dB"
    result_lines[#result_lines + 1] = "-----------------------------"

    for row = 1, #active_bands do
        local band = active_bands[row]
        local db = full_table_vals[band] or 0

        band_order[row] = band
        table_vals[row] = db
        result_lines[#result_lines + 1] =
            string.format("%2d   | %7.1f Hz | %+.2f dB", band, freqs[band], db)
    end

    last_result_bands = math.max(1, #active_bands)
    current_row = clamp(current_row, 1, last_result_bands)
    current_col = clamp(current_col, 1, 3)
end

local function update_tone_preview()
    if not fx or not current_track or selection_mode then return end

    local band = get_current_band_number()
    local freq = freqs[band] or 440
    reaper.TrackFX_SetParam(current_track, fx, 35, freq)

    local db = table_vals[current_row] or 0
    local tone_db = clamp(-24 + db, -60, 0)
    reaper.TrackFX_SetParam(current_track, fx, 36, tone_db)
end

local function get_current_line_text()
    local band = get_current_band_number()

    if selection_mode then
        local state = selected_bands[band] and "selected" or "unselected"
        return "Band " .. band ..
               ", " .. freqs[band] .. " hertz" ..
               ", " .. state
    end

    return "Band " .. band ..
           ", " .. freqs[band] .. " hertz" ..
           ", " .. string.format("%+.2f dB", table_vals[current_row] or 0)
end

local function build_full_report_text()
    local body = (#result_lines > 0) and table.concat(result_lines, "\n") or "No analysis data available."
    return build_result_title_text() .. "\n" .. get_current_header() .. "\n" .. body
end

local function open_with_delay(open_fn, message)
    speak(message)

    local speak_delay = 0.35
    local start = reaper.time_precise()

    local function delayed_open()
        if reaper.time_precise() - start >= speak_delay then
            open_fn()
            script_running = false
            running_table = false
            gfx.quit()
        else
            reaper.defer(delayed_open)
        end
    end

    reaper.defer(delayed_open)
end

local function clear_all_band_selections()
    local max_band = get_selection_max_band()

    for i = 1, max_band do
        selected_bands[i] = nil
    end

    speak("All bands restored. " .. max_band .. " bands active.")
end

local function toggle_current_band_selection()
    local band = get_selection_band_number()
    selected_bands[band] = not selected_bands[band]

    if selected_bands[band] then
        speak("Band " .. band .. " selected")
    else
        speak("Band " .. band .. " unselected")
    end
end

local function init_target_from_saved_preference()
    local target = reaper.GetExtState("LSpectrum", "Target")
    if target == "track" then
        local tr = reaper.GetSelectedTrack(0, 0)
        if tr then
            current_track = tr
            current_track, fx = ensureJSFX_on_selected()
        else
            current_track = master
            fx = ensureJSFX()
        end
    else
        current_track = master
        fx = ensureJSFX()
    end
end

local function ask_analysis_duration()
    local ok, user = reaper.GetUserInputs(
        "Analysis Duration",
        1,
        "Seconds (min 10):,extrawidth=100",
        tostring(last_duration)
    )
    if not ok then
        return false
    end

    local val = tonumber(user)
    analysis_duration = (val and val >= 10) and val or 10
    last_duration = analysis_duration
    reaper.SetExtState("LSpectrum", "Duration", tostring(last_duration), false)
    return true
end

------------------------------------------------------------
-- PERSISTENCE
------------------------------------------------------------
function load_last_target()
    local t = reaper.GetExtState("LSpectrum", "Target")
    return (t == "track") and "track" or "master"
end

function save_target(value)
    reaper.SetExtState("LSpectrum", "Target", value, true)
end

------------------------------------------------------------
-- WINDOW TITLE
------------------------------------------------------------
function update_window_title()
    if not running_table or not script_running then return end
    init_result_window()
end

------------------------------------------------------------
-- FX MANAGEMENT
------------------------------------------------------------
function removeJSFX()
    local fx_master = reaper.TrackFX_GetByName(master, ANALYZER_NAME, false)
    while fx_master ~= -1 do
        reaper.TrackFX_Delete(master, fx_master)
        fx_master = reaper.TrackFX_GetByName(master, ANALYZER_NAME, false)
    end

    local track_count = reaper.CountTracks(0)
    for i = 0, track_count - 1 do
        local tr = reaper.GetTrack(0, i)
        local fx_id = reaper.TrackFX_GetByName(tr, ANALYZER_NAME, false)
        while fx_id ~= -1 do
            reaper.TrackFX_Delete(tr, fx_id)
            fx_id = reaper.TrackFX_GetByName(tr, ANALYZER_NAME, false)
        end
    end

    fx = nil
    current_track = master
end

function ensureJSFX()
    local fx_id = reaper.TrackFX_GetByName(master, ANALYZER_NAME, false)
    if fx_id == -1 then
        fx_id = reaper.TrackFX_AddByName(master, ANALYZER_NAME, false, 1)
        if fx_id == -1 then
            reaper.MB("Cannot load analyzer FX.", "Error", 0)
            return nil
        end
    end
    return fx_id
end

function ensureJSFX_on_selected()
    if reaper.CountSelectedTracks(0) == 0 then
        if reaper.osara_outputMessage then
            reaper.osara_outputMessage("No track selected")
        else
            reaper.MB("No track selected", "Error", 0)
        end
        return nil
    end

    local tr = reaper.GetSelectedTrack(0, 0)
    local fx_id = reaper.TrackFX_GetByName(tr, ANALYZER_NAME, false)

    if fx_id == -1 then
        fx_id = reaper.TrackFX_AddByName(tr, ANALYZER_NAME, false, 1)
        if fx_id == -1 then
            speak("Cannot load analyzer FX on selected track")
            return nil
        end
    end

    return tr, fx_id
end

function change_analysis_target(char)
    if char == string.byte("t") or char == string.byte("T") then
        if fx then
            removeJSFX()
        end
        current_track, fx = ensureJSFX_on_selected()

    elseif char == string.byte("m") or char == string.byte("M") then
        if fx then
            removeJSFX()
        end
        current_track = master
        fx = ensureJSFX()
    end
end

function openHelp()
    if reaper.CF_ShellExecute then
        reaper.CF_ShellExecute(help_file)
        return
    end

    if reaper.GetOS():match("Win") then
        local win_file = normalize_windows_path(help_file)
        os.execute('cmd /c start "" "' .. win_file .. '"')
    elseif reaper.GetOS():match("OSX") then
        os.execute('open "' .. help_file .. '"')
    else
        os.execute('xdg-open "' .. help_file .. '"')
    end
end

------------------------------------------------------------
-- FILE
------------------------------------------------------------
function openTxt()
    if reaper.CF_ShellExecute then
        reaper.CF_ShellExecute(result_file)
        return
    end

    if reaper.GetOS():match("Win") then
        local win_file = normalize_windows_path(result_file)
        os.execute('cmd /c start "" "' .. win_file .. '"')
    elseif reaper.GetOS():match("OSX") then
        os.execute('open "' .. result_file .. '"')
    else
        os.execute('xdg-open "' .. result_file .. '"')
    end
end

------------------------------------------------------------
-- ACCESSIBLE TABLE
------------------------------------------------------------
function speak_cell()
    local band = get_current_band_number()
    if not band then return end

    if current_col == 1 then
        if selection_mode then
            local state = selected_bands[band] and "selected" or "unselected"
            speak("Band " .. band .. ", " .. state)
        else
            speak("Band " .. band)
        end
    elseif current_col == 2 then
        speak(freqs[band] .. " hertz")
    else
        if selection_mode then
            local state = selected_bands[band] and "selected" or "unselected"
            speak(state)
        else
            speak(string.format("%+.2f dB", table_vals[current_row] or 0))
        end
    end
end

function restart_analysis()
    gfx.quit()
    running_table = false
    script_running = true
    selection_mode = false
    reset_analysis_state()
    readerLoop()
end

function tableLoop()
    if not script_running or not running_table then return end

    local char = gfx.getchar()

    ----------------------------------------------------
    -- ESC
    ----------------------------------------------------
    if char == 27 then
        script_running = false
        running_table = false
        gfx.quit()
        removeJSFX()
        return 0
    end

    ----------------------------------------------------
    -- O / P
    ----------------------------------------------------
    if char == string.byte("o") or char == string.byte("O") then
        removeJSFX()
        open_with_delay(openTxt, "Please wait, loading text file")
        return
    end

    if char == string.byte("p") or char == string.byte("P") then
        removeJSFX()
        open_with_delay(openTxt, "Please wait, loading text file")
        return
    end

    ----------------------------------------------------
    -- CTRL+C
    ----------------------------------------------------
    if char == 3 and reaper.CF_SetClipboard then
        reaper.CF_SetClipboard(build_full_report_text())
        speak("Copied to clipboard")
    end

    ----------------------------------------------------
    -- F1 = open quick guide
    ----------------------------------------------------
    if char == 26161 then
        removeJSFX()
        open_with_delay(openHelp, "Please wait, loading quick guide")
        return
    end

----------------------------------------------------
-- DELETE = restore all bands
----------------------------------------------------
if char == 6579564 then
    local current_band = get_current_band_number()

    clear_all_band_selections()

    if not selection_mode then
        refresh_visible_table_from_full_data()

        local found_row = 1
        for row = 1, last_result_bands do
            if band_order[row] == current_band then
                found_row = row
                break
            end
        end

        current_row = found_row
        current_col = clamp(current_col, 1, 3)
        update_tone_preview()
    end

    reaper.defer(tableLoop)
    return
end

----------------------------------------------------
-- \ = announce next scan settings
----------------------------------------------------
if char == string.byte("\\") then
    speak(build_next_scan_text())
end

    ----------------------------------------------------
    -- B = toggle band selection mode
    ----------------------------------------------------
    if char == string.byte("b") or char == string.byte("B") then
        local current_band = get_current_band_number()
        selection_mode = not selection_mode
        current_col = 1

        if selection_mode then
            current_row = clamp(current_band, 1, get_selection_max_band())
            speak("Band selection mode")
            speak_cell()
        else
            refresh_visible_table_from_full_data()
            local found_row = 1
            for row = 1, last_result_bands do
                if band_order[row] == current_band then
                    found_row = row
                    break
                end
            end
            current_row = found_row
            speak("Band selection mode off")
            speak_cell()
            update_tone_preview()
        end

        reaper.defer(tableLoop)
        return
    end

    ----------------------------------------------------
    -- R
    ----------------------------------------------------
    if char == string.byte("r") or char == string.byte("R") then
        if fx then
            restart_analysis()
            return
        else
            speak("No analysis JSFX found, press T or M to load")
        end
    end

    ----------------------------------------------------
    -- T
    ----------------------------------------------------
    if char == string.byte("t") or char == string.byte("T") then
        local sel_track = reaper.GetSelectedTrack(0, 0)

        if not sel_track then
            speak("No track selected")
        elseif current_track ~= sel_track then
            speak("Switching to selected track analysis")

            if current_track == master then
                removeJSFX()
            end

            current_track = sel_track
            change_analysis_target(char)
            save_target("track")
        else
            speak("Already on selected track analysis")
        end
    end

    ----------------------------------------------------
    -- M
    ----------------------------------------------------
    if char == string.byte("m") or char == string.byte("M") then
        speak("Switching to master track analysis")

        if current_track ~= master then
            removeJSFX()
            current_track = master
            change_analysis_target(char)
            save_target("master")
        else
            speak("Already on master track analysis")
        end
    end

    ----------------------------------------------------
    -- NAVIGATION
    ----------------------------------------------------
    local nav_max_row = selection_mode and get_selection_max_band() or last_result_bands

    if char == 30064 then -- Up
        local new_row = math.max(1, current_row - 1)
        if new_row ~= current_row then
            current_row = new_row
            speak_cell()
            if not selection_mode then
                update_tone_preview()
            end
        end
    end

    if char == 1685026670 then -- Down
        local new_row = math.min(nav_max_row, current_row + 1)
        if new_row ~= current_row then
            current_row = new_row
            speak_cell()
            if not selection_mode then
                update_tone_preview()
            end
        end
    end

    if char == 1818584692 then -- Left
        local new_col = math.max(1, current_col - 1)
        if new_col ~= current_col then
            current_col = new_col
            speak_cell()
        end
    end

    if char == 1919379572 then -- Right
        local new_col = math.min(3, current_col + 1)
        if new_col ~= current_col then
            current_col = new_col
            speak_cell()
        end
    end

    if char == 1752132965 then -- Home
        if current_row ~= 1 then
            current_row = 1
            speak_cell()
            if not selection_mode then
                update_tone_preview()
            end
        end
    end

    if char == 6647396 then -- End
        if current_row ~= nav_max_row then
            current_row = nav_max_row
            speak_cell()
            if not selection_mode then
                update_tone_preview()
            end
        end
    end

    if char == 1885828464 then -- Page Up
        local new_row = math.max(1, current_row - 8)
        if new_row ~= current_row then
            current_row = new_row
            speak_cell()
            if not selection_mode then
                update_tone_preview()
            end
        end
    end

    if char == 1885824110 then -- Page Down
        local new_row = math.min(nav_max_row, current_row + 8)
        if new_row ~= current_row then
            current_row = new_row
            speak_cell()
            if not selection_mode then
                update_tone_preview()
            end
        end
    end

    ----------------------------------------------------
    -- TAB
    ----------------------------------------------------
    if char == 9 then
        local now = reaper.time_precise()

        if now - last_tab_time > 0.40 then
            tab_count = 0
        end

        tab_count = tab_count + 1
        last_tab_time = now

        if tab_count == 3 then
            tab_count = 0
            if reaper.CF_SetClipboard then
                reaper.CF_SetClipboard(get_current_line_text())
            end
            speak("Line copied to clipboard")

        elseif tab_count == 2 then
            speak(get_current_line_text())

        elseif tab_count == 1 then
            speak_cell()
        end
    end

    ----------------------------------------------------
    -- 1 / 2 / 3
    ----------------------------------------------------
    if char == string.byte("1") then
        local band = get_current_band_number()

        if is_double("1") then
            if reaper.CF_SetClipboard then
                reaper.CF_SetClipboard(tostring(band))
            end
            speak("Copied to clipboard")
        else
            speak("Band " .. band)
        end
    end

    if char == string.byte("2") then
        local band = get_current_band_number()

        if is_double("2") then
            if reaper.CF_SetClipboard then
                reaper.CF_SetClipboard(tostring(freqs[band]))
            end
            speak("Copied to clipboard")
        else
            speak(freqs[band] .. " hertz")
        end
    end

    if char == string.byte("3") then
        if is_double("3") then
            if reaper.CF_SetClipboard then
                if selection_mode then
                    local band = get_current_band_number()
                    reaper.CF_SetClipboard(selected_bands[band] and "selected" or "unselected")
                else
                    reaper.CF_SetClipboard(string.format("%+.2f", table_vals[current_row] or 0))
                end
            end
            speak("Copied to clipboard")
        else
            if selection_mode then
                local band = get_current_band_number()
                speak(selected_bands[band] and "selected" or "unselected")
            else
                speak(string.format("%+.2f dB", table_vals[current_row] or 0))
            end
        end
    end

    ----------------------------------------------------
    -- FX COMMANDS
    ----------------------------------------------------
    if fx and current_track then
        if char == string.byte("+") then
            local val = select(1, GetParamEx(current_track, fx, 32))
            val = math.min(0, val + 5)
            reaper.TrackFX_SetParam(current_track, fx, 32, val)
            speak("Noise level " .. val .. " dB")
        end

        if char == string.byte("-") then
            local val = select(1, GetParamEx(current_track, fx, 32))
            val = math.max(-120, val - 5)
            reaper.TrackFX_SetParam(current_track, fx, 32, val)
            speak("Noise level " .. val .. " dB")
        end

        local genre_names = {
            [0] = "Flat 0 dB",
            [1] = "Pop Soft 2 dB",
            [2] = "Old Pop Rock 3 dB",
            [3] = "Modern Pop 4 dB",
            [4] = "Default: EDM Synth Pop 4.5 dB",
            [5] = "Trap Urban 5 dB",
            [6] = "Lo Fi Warm 6 dB"
        }

local function set_genre(value)
    reaper.TrackFX_SetParam(current_track, fx, 33, value)
    current_genre_name = genre_names[value]
    speak(genre_names[value])
end

        if char == string.byte("a") or char == string.byte("A") then set_genre(0) end
        if char == string.byte("s") or char == string.byte("S") then set_genre(1) end
        if char == string.byte("d") or char == string.byte("D") then set_genre(2) end
        if char == string.byte("f") or char == string.byte("F") then set_genre(3) end
        if char == string.byte("g") or char == string.byte("G") then set_genre(4) end
        if char == string.byte("h") or char == string.byte("H") then set_genre(5) end
        if char == string.byte("j") or char == string.byte("J") then set_genre(6) end
    end

    ----------------------------------------------------
    -- ENTER
    ----------------------------------------------------
    if char == 13 and fx and current_track and not selection_mode then
        local tone_state = select(1, GetParamEx(current_track, fx, 34))
        local band = get_current_band_number()

        if tone_state < 0.5 then
            reaper.TrackFX_SetParam(current_track, fx, 34, 1)
            reaper.TrackFX_SetParam(current_track, fx, 35, freqs[band] or 440)
            speak("Tone on, " .. (freqs[band] or 440) .. " hertz")
        else
            reaper.TrackFX_SetParam(current_track, fx, 34, 0)
            speak("Tone off")
        end
    end

    ----------------------------------------------------
    -- SPACE
    ----------------------------------------------------
    if char == 32 and (gfx.mouse_cap & 8) == 0 then
        if selection_mode then
            toggle_current_band_selection()
        else
            local state = reaper.GetPlayState()
            if state == 0 or state == 2 then
                reaper.OnPlayButton()
            else
                reaper.OnStopButton()
            end
        end
    end

    reaper.defer(tableLoop)
end

------------------------------------------------------------
-- ANALYSIS LOOP
------------------------------------------------------------
function readerLoop()
    if not script_running then return end

    if not countdown_window_open then
        init_countdown_window()
    end

    local key = gfx.getchar()

    if key == 32 then
        local state = reaper.GetPlayState()
        if state == 0 or state == 2 then
            reaper.OnPlayButton()
        else
            reaper.OnStopButton()
        end
    end

    if key == 27 then
        speak("Cancelled")
        script_running = false
        running_table = false
        gfx.quit()
        removeJSFX()
        return 0
    end

    local now = reaper.time_precise()
    local elapsed = now - startTime
    local sec = math.floor(elapsed)

    if sec ~= last_spoken and elapsed < analysis_duration then
        local remaining = analysis_duration - sec
        speak(tostring(remaining))
        last_spoken = sec
    end

    for i = 1, 32 do
        local db = select(1, GetParamEx(current_track, fx, i - 1))
        sum[i] = sum[i] + db
    end
    count = count + 1

    if elapsed < analysis_duration then
        reaper.defer(readerLoop)
    else
        gfx.quit()
        countdown_window_open = false
        finalize()
    end
end

------------------------------------------------------------
-- FINALIZE
------------------------------------------------------------
function finalize()
    local active_bands = get_active_band_list()

    full_table_vals = {}
    full_band_order = {}
    for _, band in ipairs(active_bands) do
        full_table_vals[band] = sum[band] / count
        full_band_order[#full_band_order + 1] = band
    end

    result_lines = {}
    result_lines[#result_lines + 1] = "Band | Frequency | dB"
    result_lines[#result_lines + 1] = "-----------------------------"

    band_order = {}
    table_vals = {}
    last_result_bands = #active_bands

    for row, band in ipairs(active_bands) do
        local avg = full_table_vals[band] or 0
        band_order[row] = band
        table_vals[row] = avg
        result_lines[#result_lines + 1] =
            string.format("%2d   | %7.1f Hz | %+.2f dB", band, freqs[band], avg)
    end

    allow_restart = true
    selection_mode = false

    local header_line = "Analysis type: " .. get_track_label(current_track)
    local content = header_line ..
                    "\nGenre: " .. current_genre_name ..
                    "\n" .. table.concat(result_lines, "\n")

    result_header_type = header_line
    reaper.SetExtState("LSpectrum", "LastGenre", current_genre_name, true)

    local f = assert(io.open(result_file, "wb"))
    f:write(content)
    f:close()

    init_result_window()

    running_table = true
    script_running = true
    current_row = 1
    current_col = 1

    reaper.defer(function() speak_cell() end)
    tableLoop()
end

------------------------------------------------------------
-- LOAD LAST RESULTS
------------------------------------------------------------
function load_last_results()
    local f = io.open(result_file, "r")
    if not f then
        speak("No previous analysis found")
        return false
    end

    local lines = {}
    for line in f:lines() do
        lines[#lines + 1] = line
    end
    f:close()

    if #lines < 3 then
        speak("Result file is empty or invalid")
        return false
    end

    result_header_type = lines[1]
    current_genre_name = reaper.GetExtState("LSpectrum", "LastGenre") or "Unknown Genre"

    result_lines = {}
    for i = 3, #lines do
        result_lines[#result_lines + 1] = lines[i]
    end

    table_vals = {}
    band_order = {}
    full_table_vals = {}
    full_band_order = {}

    local idx = 1
    for i = 3, #result_lines do
        local band, _, db = result_lines[i]:match("(%d+)%s+|%s+([%d%.]+)%s+Hz%s+|%s+([%+%-%.%d]+)")
        if band and db then
            band = tonumber(band)
            db = tonumber(db)
            band_order[idx] = band
            table_vals[idx] = db
            full_table_vals[band] = db
            full_band_order[#full_band_order + 1] = band
            idx = idx + 1
        end
    end

    last_result_bands = math.max(1, idx - 1)
    selection_mode = false
    allow_restart = false
    return true
end

------------------------------------------------------------
-- START ANALYSIS
------------------------------------------------------------
function start_new_analysis()
    init_target_from_saved_preference()
    if not fx then return end
    if not ask_analysis_duration() then return end

    reset_analysis_state()
    readerLoop()
end

function start_new_analysis_on_selected()
    local tr, fx_id = ensureJSFX_on_selected()
    if not tr then return end

    current_track = tr
    fx = fx_id
    save_target("track")

    if not ask_analysis_duration() then return end

    reset_analysis_state()
    readerLoop()
end

------------------------------------------------------------
-- MENU
------------------------------------------------------------
local menu = "New Analysis|Last Analysis|Kick Analysis (Bands 1–14)|New Analysis on Selected Track"
local choice = gfx.showmenu(menu)

if choice == 1 then
    kick_mode = false
    start_new_analysis()
    return

elseif choice == 2 then
    kick_mode = false
    init_target_from_saved_preference()

    last_duration = tonumber(reaper.GetExtState("LSpectrum", "Duration")) or 10
    analysis_duration = last_duration

    if load_last_results() then
        running_table = true
        script_running = true
        current_row = 1
        current_col = 1

        init_result_window()
        reaper.defer(function() speak_cell() end)
        tableLoop()
        return
    end

elseif choice == 3 then
    kick_mode = true
    start_new_analysis()
    return

elseif choice == 4 then
    kick_mode = false
    start_new_analysis_on_selected()
    return
end
