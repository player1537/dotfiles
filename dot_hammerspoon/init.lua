
local ulid = (function ()
    ---
    -- Module for creating Universally Unique Lexicographically Sortable Identifiers.
    --
    -- Modeled after the [ulid implementation by alizain](https://github.com/alizain/ulid). Please checkout the
    -- documentation there for the design and characteristics of ulid.
    --
    -- **IMPORTANT**: the standard Lua versions, based on the standard C library are
    -- unfortunately very weak regarding time functions and randomizers.
    -- So make sure to set it up properly!
    --
    -- @copyright Copyright 2016-2017 Thijs Schreijer
    -- @license [mit](https://opensource.org/licenses/MIT)
    -- @author Thijs Schreijer


    -- Crockford's Base32 https://en.wikipedia.org/wiki/Base32
    local ENCODING = {
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "M", 
    "N", "P", "Q", "R", "S", "T", "V", "W", "X", "Y", "Z"
    }
    local ENCODING_LEN = #ENCODING
    local TIME_LEN = 10
    local RANDOM_LEN = 16


    local floor = math.floor
    local concat = table.concat
    local random = math.random
    local now


    if (ngx or {}).now then
    -- nginx
        now = ngx.now
    elseif package.loaded["socket"] and package.loaded["socket"].gettime then
        -- LuaSocket
        now = package.loaded["socket"].gettime
    else
        -- plain Lua
        now = function()
            error("No time function available, please provide time in seconds with millisecond precision", 2)
        end
    end


    --- Sets the time function to get default times from.
    -- This function should return time in seconds since unix epoch, with millisecond
    -- precision. The default set will be `ngx.now()` or alternatively `socket.gettime()`, if
    -- niether is available, it will insert an error throwing placeholder function.
    -- @param f the function to set
    -- @return `true`
    -- @name set_time_func
    local function set_time_func(f)
        assert(type(f) == "function", "expected 1st argument to be a function")
        now = f
        return true
    end


    --- Sets the random function to get random input from.
    -- This function should return a number between 0 and 1 when called without
    -- arguments. The default is `math.random`, this is ok for LuaJIT, but the
    -- standard PuC-Rio Lua versions have a weak randomizer that is better replaced.
    -- @param f the function to set
    -- @return `true`
    -- @name set_random_func
    local function set_random_func(f)
        assert(type(f) == "function", "expected 1st argument to be a function")
        random = f
        return true
    end


    --- generates the time-based part of a `ulid`.
    -- @param time (optional) time to generate the string from, in seconds since 
    -- unix epoch, with millisecond precision (defaults to now)
    -- @param len (optional) the length of the time-based string to return (defaults to 10)
    -- @return time-based part of `ulid` string
    -- @name encode_time
    local function encode_time(time, len) 
        time = floor((time or now()) * 1000)
        len = len or TIME_LEN
    
        local result = {}
        for i = len, 1, -1 do
            local mod = time % ENCODING_LEN
            result[i] = ENCODING[mod + 1]
            time = (time - mod) / ENCODING_LEN
        end
        return concat(result)
    end

    --- generates the random part of a `ulid`.
    -- @param len (optional) the length of the random string to return (defaults to 16)
    -- @return random part of `ulid` string
    -- @name encode_random
    local function encode_random(len)
        len = len or RANDOM_LEN
        local result = {}
        for i = 1, len do
            result[i] = ENCODING[floor(random() * ENCODING_LEN) + 1]
        end
        return concat(result)
    end

    --- generates a `ulid`.
    -- @param time (optional) time to generate the `ulid` from, in seconds since 
    -- unix epoch, with millisecond precision (defaults to now)
    -- @return `ulid` string
    -- @name ulid
    -- @usage local ulid_mod = require("ulid")
    --
    -- -- load LuaSocket so we can reuse its gettime function
    -- local socket = require("socket")
    -- -- set the time function explicitly, but by default it 
    -- -- will be picked up as well
    -- ulid_mod.set_time_func(socket.gettime)
    --
    -- -- seed the random generator, needed for the example, but ONLY DO THIS ONCE in your
    -- -- application, unless you know what you are doing! And try to use a better seed than
    -- -- the time based seed used here.
    -- math.randomseed(socket.gettime()*10000)
    --
    -- -- get a ulid from current time
    -- local id = ulid_mod.ulid()
    local function ulid(time)
        return encode_time(time) .. encode_random()
    end

    local _M = {
        ulid = ulid,
        encode_time = encode_time,
        encode_random = encode_random,
        set_time_func = set_time_func,
        set_random_func = set_random_func,
    }

    return setmetatable(_M, {
        __call = function(self, ...) 
            return ulid(...) 
        end
    })
end)()

ulid.set_time_func(function()
    return os.time() * 100
end)



function MakeUUID()
    -- Thanks https://gist.github.com/jrus/3197011?permalink_comment_id=4223719#gistcomment-4223719
    math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 9)))

    -- Thanks https://gist.github.com/jrus/3197011
    local random = math.random
    local uuid = string.gsub('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx', '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)

    local short = string.sub(uuid, 1, string.len('xxxxxxxx'))

    return short, uuid
end


function MakeULID()
    math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 9)))

    local long = ulid()
    local short = string.sub(long, 1, 10)

    return short, long
end


hs.hotkey.bind({"cmd", "shift"}, "U", function()
	CopyUUID()
end)


local __CopyUUID_uuid = nil
function CopyUUID()
    -- generate uuid

    local short, long = MakeULID()

    if __CopyUUID_uuid == short then
        hs.pasteboard.setContents(long)
        __CopyUUID_uuid = long
    else
        hs.pasteboard.setContents(short)
        __CopyUUID_uuid = short
    end
end


hs.hotkey.bind({"cmd", "shift"}, "D", function()
	CopyDate()
end)


function MakeDate()
    -- e.g. short = "2025-04-10"
    -- e.g. long = "2025-04-10 12:34:56"
    local short = os.date('%Y-%m-%d')
    local long = os.date('%Y-%m-%d %H:%M:%S')

    return short, long
end


function CopyDate()
    -- generate date

    local short, long = MakeDate()

    if __CopyUUID_uuid == short then
        hs.pasteboard.setContents(long)
        __CopyUUID_uuid = long
    else
        hs.pasteboard.setContents(short)
        __CopyUUID_uuid = short
    end
end



function GetSize()
	local window = hs.window.frontmostWindow()
	local frame = window:frame()

	hs.alert.show(frame.w .. 'x' .. frame.h)
end



local __9610d3e6_pid = nil
local __027a4992_width = nil
function SetWidth()
	local window = hs.window.frontmostWindow()
	local application = window:application()
	local name = application:name()
	local pid = application:pid()
	local frame = window:frame()

	local targetWidth = 1290
	if name == 'TextEdit' then
		targetWidth = 779
	end

	if pid == __9610d3e6_pid then
		if frame.w == targetWidth then
			targetWidth = __027a4992_width
		end

		if targetWidth == frame.w then
			if targetWidth == 1290 then
				targetWidth = 779
			elseif targetWidth == 779 then
				targetWidth = 1290
			end
		end
	end
	__9610d3e6_pid = pid
	__027a4992_width = frame.w

	frame.w = targetWidth
	window:setFrame(frame)
end


function Reposition()
	local window = hs.window.frontmostWindow()
	local application = window:application()
	local name = application:name()
	local pid = application:pid()
	local frame = window:frame()

	frame.x = 0
	frame.y = 0
	window:setFrame(frame)
end


function SetHeightToMax()
	local window = hs.window.frontmostWindow()
	local application = window:application()
	local name = application:name()
	local pid = application:pid()
	local frame = window:frame()

	frame.h = 1080
	window:setFrame(frame)
end


function GetAndroid()
--	hs.execute('eval "$(/opt/homebrew/bin/brew shellenv)" && /Users/nebula/bin/,scrcpy 5555 8K')
--	hs.execute('eval "$(/opt/homebrew/bin/brew shellenv)" && tmux new-session -d -s 4Y0YTXZGH0B9VB9ZHW4ZFD0743 bash -c "eval ' .. '"' .. '\\$(/opt/homebrew/bin/brew shellenv)' .. '"' .. '/Users/nebula/bin/,scrcpy 5555 8K"')
	hs.execute('eval "$(/opt/homebrew/bin/brew shellenv)" && /Users/nebula/.nix-profile/bin/tmux new-session -d -s 4Y0YTXZGH0B9VB9ZHW4ZFD0743 /Users/nebula/bin/,scrcpy 5555')
end


local menubar = hs.menubar.new(true, 'th.setWidth')
menubar:setTitle('W')
menubar:setClickCallback(function(mods)
	SetWidth()
	if mods.alt then
		Reposition()
		SetHeightToMax()
	end
end)

-- local Smenubar = hs.menubar.new(true, 'th.getSize')
-- Smenubar:setTitle('S')
-- Smenubar:setClickCallback(function(mods)
-- 	GetSize()
-- end)

-- local Amenubar = hs.menubar.new(true, 'th.getAndroid')
-- Amenubar:setTitle('A')
-- Amenubar:setClickCallback(function(mods)
-- 	GetAndroid()
-- end)


-- PaperWM = hs.loadSpoon("PaperWM")
-- PaperWM:bindHotkeys({
-- 	focus_left = {{"alt", "cmd"}, "left"},
-- 	focus_right = {{"alt", "cmd"}, "right"},
-- })
-- PaperWM:start()


-- hs.hotkey.bind({"alt", "Q", function()
--     local s = hs.pasteboard.getContents()
--     -- local p = hs.execute(
-- end)

hs.caffeinate.set("displayIdle", true)
