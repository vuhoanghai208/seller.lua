-- Khai báo cấu hình
getgenv().Config = {
    ["Account Hold Gem"] = "", -- Thay bằng tên tài khoản thực tế
    ["Gem"] = "50b",
    ["Time Remove"] = 5, -- phút
    ["Link Webhook"] = "",
    ["Hop sever"] = 15, -- phút
}

getgenv().hugemode = {
    ["All Huges Normal"] = { strategy = "+2%", sell = true },
    ["All Huges Golden"] = { strategy = "-2%", sell = false },
    ["All Huges Rainbow"] = { strategy = "", sell = true },
    ["All Huges Shiny"] = { strategy = "", sell = false }
}

getgenv().item = {
    ["Hype Egg 2"] = 95,
}

-- Đợi game tải hoàn tất
repeat task.wait() until game:IsLoaded()

-- Khai báo dịch vụ
local VirtualUser = game:GetService("VirtualUser")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- Chống idle
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- Đợi giao diện người dùng sẵn sàng
repeat
    task.wait()
until game:IsLoaded() and
    LocalPlayer:FindFirstChild("PlayerGui") and
    LocalPlayer.PlayerGui:FindFirstChild("MainLeft") and
    LocalPlayer.PlayerGui.MainLeft.Left.Currency.Diamonds.Diamonds.Visible == true and
    not LocalPlayer:FindFirstChild("GUIFX Holder")

-- Đếm số pet "Huge"
local save = require(ReplicatedStorage.Library.Client.Save)
local totalhuge = 0
spawn(function()
    while task.wait() do
        totalhuge = 0
        for _, v in pairs(save.Get().Inventory.Pet) do
            if string.find(v.id, "Huge") then
                totalhuge = totalhuge + 1
            end
        end
    end
end)

-- Teleport dựa trên số pet "Huge"
if game.PlaceId == 8737899170 then
    local success, err = pcall(function()
        if totalhuge >= 5 then
            TeleportService:Teleport(15588442388)
        else
            TeleportService:Teleport(15502339080)
        end
    end)
    if not success then
        warn("Teleport thất bại: " .. err)
        task.wait(5) -- Thử lại sau 5 giây
    end
end

-- Logic chính trong Trading Plaza
if game.PlaceId == 15588442388 or game.PlaceId == 15502339080 then
    -- Hàm tìm gian hàng gần nhất
    local function getnearboot()
        local pos, id
        local distance = math.huge
        local playerPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position
        if not playerPos then return nil, nil end

        for _, v in pairs(workspace.TradingPlaza.BoothSpawns:GetChildren()) do
            if v and v.WorldPivot and v:GetAttribute("ID") then
                local boothPosition = v.WorldPivot.Position
                local currentDistance = (boothPosition - playerPos).Magnitude
                local boothId = v:GetAttribute("ID")
                if boothId and currentDistance < distance then
                    distance = currentDistance
                    pos = boothPosition
                    id = boothId
                end
            end
        end
        return pos, id
    end

    -- Chiếm gian hàng
    local pos, id = getnearboot()
    if pos and id then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(-5, 5, 0))
        task.wait()
        local v_u_23 = require(game.ReplicatedStorage.Library.Client.Network)
        local success, err = pcall(function()
            v_u_23.Invoke("Booths_ClaimBooth", id)
        end)
        if not success then
            warn("Không thể chiếm gian hàng: " .. err)
        end
    else
        warn("Không tìm thấy gian hàng gần!")
    end

    -- Gửi kim cương (nếu cần)
    LocalPlayer.PlayerGui._MACHINES.MailboxMachine.Enabled = true
    local gemneedsend = LocalPlayer.PlayerGui._MACHINES.MailboxMachine.Frame.SendFrame.Bottom.Diamonds.Frame.Amount.Text
    LocalPlayer.PlayerGui._MACHINES.MailboxMachine.Enabled = false

    local v_u_5 = require(game.ReplicatedStorage.Library.Functions)

    local function sendgem(iditem)
        local args = {
            [1] = getgenv().Config["Account Hold Gem"],
            [2] = "Made By Honglamx",
            [3] = "Currency",
            [4] = tostring(iditem),
            [5] = LocalPlayer.leaderstats["\240\159\146\142 Diamonds"].Value - v_u_5.ParseNumberSmart(gemneedsend)
        }
        local success, err = pcall(function()
            v_u_23.Invoke("Mailbox: Send", unpack(args))
        end)
        if not success then
            warn("Lỗi khi gửi kim cương: " .. err)
        end
    end

    spawn(function()
        while task.wait() do
            if LocalPlayer.leaderstats["\240\159\146\142 Diamonds"].Value >= v_u_5.ParseNumberSmart(getgenv().Config["Gem"]) then
                for i, v in pairs(save.Get().Inventory.Currency) do
                    if v.id == "Diamonds" then
                        sendgem(i)
                    end
                end
            end
        end
    end)

    -- Xóa listing định kỳ
    local listedItems = {}
    spawn(function()
        while task.wait(getgenv().Config["Time Remove"] * 60) do
            if game.PlaceId == 15588442388 or game.PlaceId == 15502339080 then
                local removedAny = false
                for _, v in pairs(workspace.__THINGS.Booths:GetChildren()) do
                    if v:GetAttribute("Owner") == LocalPlayer.UserId then
                        for _, v1 in pairs(v.Pets.BoothTop.PetScroll:GetChildren()) do
                            if v1:IsA("Frame") then
                                local success, err = pcall(function()
                                    ReplicatedStorage.Network["Booths_RemoveListing"]:InvokeServer(v1.Name)
                                end)
                                if success then
                                    removedAny = true
                                else
                                    warn("Lỗi khi xóa listing: " .. err)
                                end
                            end
                        end
                    end
                end
                if removedAny then
                    listedItems = {}
                end
            end
        end
    end)

    -- Hàm xác định loại pet Huge
    local function getPetType(petId)
        if string.find(petId, "Golden") then
            return "All Huges Golden"
        elseif string.find(petId, "Rainbow") then
            return "All Huges Rainbow"
        elseif string.find(petId, "Shiny") then
            return "All Huges Shiny"
        else
            return "All Huges Normal"
        end
    end

    -- Hàm tính hệ số giá từ chiến lược
    local function getMultiplier(strategy)
        if strategy == "" then
            return 1
        end
        local sign = strategy:sub(1,1)
        local percentStr = strategy:sub(2,-2)
        local percent = tonumber(percentStr)
        if percent then
            if sign == "+" then
                return 1 + percent / 100
            elseif sign == "-" then
                return 1 - percent / 100
            end
        end
        return 1
    end

    -- Tạo listing cho vật phẩm và pet "Huge"
    local Items = require(game:GetService("ReplicatedStorage").Library.Items.Types)

    while task.wait() do
        if game.PlaceId == 15588442388 or game.PlaceId == 15502339080 then
            -- Tạo listing cho vật phẩm không phải pet
            for i, v in save.Get().Inventory do
                for i1, v1 in pairs(v) do
                    local am = v1._am or 1
                    if getgenv().item[v1.id] and i ~= "Pet" and not listedItems[i1] then
                        local petItem = Items.Types[i]:Get(i1)
                        local petRAP = petItem:GetRAP() or 0
                        if petRAP > 0 then
                            local price = math.floor(petRAP * (getgenv().item[v1.id] / 100))
                            local listingAmount = (am >= 5000) and 5000 or am
                            local args = {
                                [1] = tostring(i1),
                                [2] = price,
                                [3] = listingAmount
                            }
                            local success, err = pcall(function()
                                v_u_23.Invoke("Booths_CreateListing", unpack(args))
                            end)
                            if success then
                                listedItems[i1] = true
                            else
                                warn("Lỗi khi tạo listing cho vật phẩm: " .. err)
                            end
                        end
                    end
                end
            end

            -- Tạo listing cho pet "Huge"
            for i, v in pairs(save.Get().Inventory.Pet) do
                if string.find(v.id, "Huge") then
                    local petType = getPetType(v.id)
                    local config = getgenv().hugemode[petType]
                    if config and config.sell and not listedItems[i] then
                        local petItem = Items.Types["Pet"]:Get(i)
                        local petRAP = petItem:GetRAP() or 0
                        if petRAP > 0 then
                            local multiplier = getMultiplier(config.strategy)
                            local price = math.floor(petRAP * multiplier)
                            local args = {
                                [1] = tostring(i),
                                [2] = price,
                                [3] = v._am or 1
                            }
                            local success, err = pcall(function()
                                v_u_23.Invoke("Booths_CreateListing", unpack(args))
                            end)
                            if success then
                                listedItems[i] = true
                            else
                                warn("Lỗi khi tạo listing cho pet: " .. err)
                            end
                            task.wait(1)
                        end
                    end
                end
            end
        end
    end

    -- Webhook khi có giao dịch
    local BoothPurchaseEvent = ReplicatedStorage:FindFirstChild("BoothPurchase")
    if BoothPurchaseEvent then
        BoothPurchaseEvent.OnClientEvent:Connect(function(buyer, listingId)
            local webhookUrl = getgenv().Config["Link Webhook"]
            if webhookUrl and webhookUrl ~= "" then
                local payload = {
                    content = "Sale made: " .. buyer.Name .. " bought listing " .. listingId
                }
                local jsonPayload = HttpService:JSONEncode(payload)
                local success, response = pcall(function()
                    HttpService:PostAsync(webhookUrl, jsonPayload)
                end)
                if success then
                    print("Webhook sent successfully")
                else
                    warn("Error sending webhook: " .. response)
                end
            end
        end)
    else
        warn("BoothPurchase event not found in ReplicatedStorage")
    end

    -- Nhảy server
    local function HopServer()
        local placeId = game.PlaceId
        local jobId = game.JobId
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("[invalid url, do not cite] .. placeId .. "/servers/Public?sortOrder=Desc&limit=100"))
        end)
        if success and result and result.data then
            for _, server in ipairs(result.data) do
                if server.playing < server.maxPlayers and server.id ~= jobId then
                    local teleportSuccess, teleportErr = pcall(function()
                        TeleportService:TeleportToPlaceInstance(placeId, server.id)
                    end)
                    if not teleportSuccess then
                        warn("Teleport failed: " .. teleportErr)
                    end
                    break
                end
            end
        end
    end

    spawn(function()
        while true do
            task.wait(getgenv().Config["Hop sever"] * 60)
            HopServer()
        end
    end)
end
