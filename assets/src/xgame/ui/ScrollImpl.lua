local class             = require "xgame.class"
local Align             = require "xgame.ui.Align"
local TouchEvent        = require "xgame.event.TouchEvent"
local layouter          = require "xgame.ui.layouter"
local GestureDetector   = require "xgame.ui.GestureDetector"

local math = math
local PI_2 = math.pi / 2
local UPDATE_KEY = "__SCROLLIMPL_UPDATE__"

local ScrollImpl = class("ScrollImpl")

function ScrollImpl:ctor(target, container)
    self._target = target
    self._container = container
    self._detector = GestureDetector.new(target, self)
    self._focuses = setmetatable({}, {__mode = "v"})
    self._scrollHEnabled = true
    self._scrollHAlign = Align.LEFT
    self._scrollVEnabled = true
    self._scrollVAlign = Align.BOTTOM
    self._touchCount = 0
    self._scrolling = false
    self.reboundEnabled = true -- 回弹
    self.maxVel = 4500
    self.minVel = 400
    self.elapseTime = 1
    self.validateThreshold = function (which, rawvalue, newvalue)
        return newvalue
    end

    self.scaleEnabled = false
    self.maxScale = 2
    self.minScale = 1
    self.scalePoint = {x = 0, y = 0}
end

function ScrollImpl:zoom(x, y, delta_dis)
    if not self.scaleEnabled then
        self:_abortAllFocuses()
        return
    end

    local len = math.sqrt(self._target.width * self._target.width,
        self._target.height * self._target.height)
    local scaleX = self._container.scaleX
    local scale = scaleX + 3 * delta_dis * math.max(scaleX, 1) / len
    scale = math.min(self.maxScale, math.max(self:calcMinScale(), scale))
    self:scaleTo(scale, x, y)
    self._target:dispatch(TouchEvent.ZOOMING, scale)
end

function ScrollImpl:calcMinScale()
    return math.max(self.minScale,
        self._target.width / self._container.width,
        self._target.height / self._container.height)
end

function ScrollImpl:scaleTo(scale, x, y)
    local lx, ly = self._container:globalToLocal(
        self._target:localToGlobal(x, y))
    self._container.scaleX = scale
    self._container.scaleY = scale
    self.scalePoint.x = x
    self.scalePoint.y = y

    local nx, ny = self._target:globalToLocal(
        self._container:localToGlobal(lx, ly))
    self._container.x = self._container.x + x - nx
    self._container.y = self._container.y + y - ny
    self:pan(0, 0)
end

function ScrollImpl:press(id, x, y)
    self._container:unschedule(UPDATE_KEY)
    self:_tryFocus(id, x, y)

    self:_checkScrollEnd()

    self._touchCount = self._touchCount + 1
    if self._touchCount == 1 then
        self._target:dispatch(TouchEvent.SCROLL_BEGIN)
    end
end

function ScrollImpl:_checkScrollEnd()
    if self._touchCount <= 0 and self._scrolling then
        self._target:dispatch(TouchEvent.SCROLL_END)
        self._scrolling = false
        self._touchCount = 0
    end
end

function ScrollImpl:release(id, x, y)
    self:_abortFocus(id)
    self._touchCount = self._touchCount - 1
    self:_checkScrollEnd()
end

function ScrollImpl:_tryFocus(id, x, y)
    x, y = self._target:localToGlobal(x, y)
    local hit, capturePoints = self._container:hit({
        [id] = {x = x, y = y, id = id}})
    if hit then
        self._focuses[id] = hit
        self._focuses[id]:touch_down(capturePoints)
    end
end

function ScrollImpl:_abortFocus(id)
    local focus = self._focuses[id]
    if focus then
        if focus.cobj then
            focus:touch_cancel(focus.touches)
        end
        self._focuses[id] = nil
    end
end

function ScrollImpl:_abortAllFocuses()
    for id in pairs(self._focuses) do
        self:_abortFocus(id)
    end
end

function ScrollImpl:tap(id, x, y)
    -- assert(self._focuses[id]) ?
    local focus = self._focuses[id]
    if focus and focus.cobj then
        focus:touch_up(focus.touches)
        self._focuses[id] = nil
        self._touchCount = self._touchCount - 1
        self:_checkScrollEnd()
    end
end

function ScrollImpl:pan(deltaX, deltaY)
    self:_abortAllFocuses()

    local target = self._target
    local left, right, top, bottom = target:getScrollBounds()
    local x = self._container.x
    local y = self._container.y

    if self._scrollHEnabled then
        -- 如果左边界或右边界在可视范围，拖动距离应缩减
        if left > 0 or right < target.width then
            deltaX = deltaX * 0.3
        end

        -- 不需要回弹
        if not self.reboundEnabled then
            if left + deltaX > 0 then
                deltaX = 0 - left
            elseif right + deltaX < target.width then
                deltaX = target.width - right
            end
        end

        x = x + deltaX
    end

    if self._scrollVEnabled then
        -- 如果上边界或下边界在可视范围，拖动距离应缩减
        if bottom > 0 or top < target.height then
            deltaY = deltaY * 0.3
        end

        -- 不需要回弹
        if not self.reboundEnabled then
            if bottom + deltaY > 0 then
                deltaY = 0 - bottom
            elseif top + deltaY < target.height then
                deltaY = target.height - top
            end
        end

        y = y + deltaY
    end

    self._container.x = x
    self._container.y = y
    self._scrolling = true
    self._target:dispatch(TouchEvent.SCROLLING)
end

function ScrollImpl:fling(velX, velY)
    self._touchCount = self._touchCount - 1
    self:_abortAllFocuses()

    local target = self._target
    local left, right, top, bottom = target:getScrollBounds()
    local MAX, MIN = self.maxVel, self.minVel

    -- time, factor, duration
    local tx, fx, dx = 0, 1, self.elapseTime
    local ty, fy, dy = 0, 1, self.elapseTime

    velX = math.abs(velX) < 100 and 0 or velX
    velY = math.abs(velY) < 100 and 0 or velY

    if self._scrollHEnabled and velX ~= 0 then
        local factor = (left > 0 or right < target.width) and 0.5 or 1
        local dir = velX < 0 and -1 or 1
        velX = math.min(MAX, math.max(MIN, math.abs(velX))) * dir * factor
        dx = dx * factor
    else
        velX = 0
    end

    if self._scrollVEnabled and velY ~= 0 then
        local factor = (bottom > 0 or top < target.height) and 0.5 or 1
        local dir = velY < 0 and -1 or 1
        velY = math.min(MAX, math.max(MIN, math.abs(velY))) * dir * factor
        dy = dy * factor
    else
        velY = 0
    end

    local function equal(x1, x2)
        local diff = x1 - x2
        return diff < 0.1 and diff > -0.1
    end

    self._container:schedule(function (delta)
        local x, y = self._container:get_position()
        local last_x, last_y = x, y

        tx = tx + delta * fx
        ty = ty + delta * fy

        -- 衰减函数，参考ease族函数
        local vx = velX * (1 - math.sin(math.min(1, tx / dx) * PI_2))
        local vy = velY * (1 - math.sin(math.min(1, ty / dy) * PI_2))

        -- 逼近目标
        x = x + vx * delta
        y = y + vy * delta

        local tox = self:_validateX(x, self._scrollHEnabled)
        local toy = self:_validateY(y, self._scrollVEnabled)

        -- 如果有效目标与计算目标不一致，表明有一边已经在可视范围内
        -- 这种情况，加速衰减
        fx = equal(tox, x) and fx or 5
        fy = equal(toy, y) and fy or 5

        -- 回弹
        x = math.abs(vx) < 20 and (x + (tox - x) * delta * 10) or x
        y = math.abs(vy) < 20 and (y + (toy - y) * delta * 10) or y

        self._container.x = x
        self._container.y = y

        if not self.reboundEnabled then
            self:validate()
        end

        if equal(x, last_x) and equal(y, last_y) then
            self._container:unschedule(UPDATE_KEY)
            self:_checkScrollEnd()
        else
            self._target:dispatch(TouchEvent.SCROLLING)
        end
    end, UPDATE_KEY)
end

function ScrollImpl:validate()
    local target = self._target
    local left, right, top, bottom = target:getScrollBounds()
    local x = self._container.x
    local y = self._container.y

    if left > 0 or right < target.width then
        x = self:_validateX(x, true)
    end

    if bottom > 0 or top < target.height then
        y = self:_validateY(y, true)
    end

    self._container.x = x
    self._container.y = y
end

function ScrollImpl:_validateX(value, force)
    if not force then
        return value
    end

    local target = self._target
    local left, right = target:getScrollBounds()
    local x = self._container.x
    local width = right - left

    if self._scrollHAlign == Align.LEFT then
        if left > 0 or width < target.width then
            value = self.validateThreshold("L", value, x + (0 - left))
        elseif right < target.width then
            value = self.validateThreshold("R", value,
                x + (target.width - right))
        end
    else
        if right < target.width or width < target.width then
            value = self.validateThreshold("R", value,
                x + (target.width - right))
        elseif left > 0 then
            value = self.validateThreshold("L", value, x + (0 - left))
        end
    end

    return value
end

function ScrollImpl:_validateY(value, force)
    if not force then
        return value
    end

    local target = self._target
    local _, _, top, bottom = target:getScrollBounds()
    local y = self._container.y
    local height = top - bottom

    if self._scrollVAlign == Align.BOTTOM then
        if bottom > 0 or height < target.height then
            value = self.validateThreshold("B", value, y + (0 - bottom))
        elseif top < target.height then
            value = self.validateThreshold("T", value,
                y + (target.height - top))
        end
    else
        if top < target.height or height < target.height then
            value = self.validateThreshold("T", value,
                y + (target.height - top))
        elseif bottom > 0 then
            value = self.validateThreshold("B", value, y + (0 - bottom))
        end
    end

    return value
end

function ScrollImpl:update()
    self:validate()
end

function ScrollImpl:validateLater()
    layouter.addUpdate(self)
end

function ScrollImpl.Get:scrollHEnabled()
    return self._scrollHEnabled
end
function ScrollImpl.Set:scrollHEnabled(value)
    self._scrollHEnabled = value
    self:validateLater()
end

function ScrollImpl.Get:scrollVEnabled()
    return self._scrollVEnabled
end
function ScrollImpl.Set:scrollVEnabled(value)
    self._scrollVEnabled = value
    self:validateLater()
end

function ScrollImpl.Get:scrollHAlign()
    return self._scrollHAlign
end
function ScrollImpl.Set:scrollHAlign(value)
    self._scrollHAlign = value
    self:validateLater()
end

function ScrollImpl.Get:scrollVAlign()
    return self._scrollVAlign
end
function ScrollImpl.Set:scrollVAlign(value)
    self._scrollVAlign = value
    self:validateLater()
end

return ScrollImpl