-- ====================================================================
-- SCANNER DE INVENTÁRIO, RARIDADES E REMOTES DE VENDA (100% NATIVO)
-- ====================================================================
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local pgui = player:WaitForChild("PlayerGui", 20)
local report = "=== RELATÓRIO DO INVENTÁRIO E REMOTES DE VENDA ===\n\n"

-- 1. VARREDURA DE REMOTES COM NOMES SUSPEITOS DE VENDA/INVENTÁRIO
report = report .. "[1] REMOTES ENCONTRADOS NO REPLICATEDSTORAGE:\n"
local foundRemotes = 0
for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        local name = obj.Name:lower()
        if name:find("sell") or name:find("item") or name:find("inventory") or name:find("trash") or name:find("delete") or name:find("equip") then
            foundRemotes = foundRemotes + 1
            report = report .. string.format("   -> [%s] %s (Path: %s)\n", obj.ClassName, obj.Name, obj:GetFullName())
        end
    end
end
if foundRemotes == 0 then report = report .. "   (Nenhum Remote específico com nome 'Sell' encontrado)\n" end

-- 2. VARREDURA DA ESTRUTURA DO INVENTÁRIO (PlayerGui)
report = report .. "\n[2] ESTRUTURA DE ITENS NO INVENTÁRIO (PlayerGui):\n"
local scroll = pgui:FindFirstChild("Main")
    and pgui.Main:FindFirstChild("MainFrame")
    and pgui.Main.MainFrame:FindFirstChild("Items")
    and pgui.Main.MainFrame.Items:FindFirstChild("Scroll")

if scroll then
    local count = 0
    for _, itemSlot in ipairs(scroll:GetChildren()) do
        if itemSlot:IsA("GuiObject") and itemSlot.Name ~= "UIGridLayout" and itemSlot.Name ~= "UIPadding" then
            count = count + 1
            if count <= 5 then -- Analisa detalhadamente os 5 primeiros itens
                report = report .. string.format("\n   • Item Slot: '%s'\n", itemSlot.Name)
                
                -- Atributos do Slot
                for attrName, attrVal in pairs(itemSlot:GetAttributes()) do
                    report = report .. string.format("      [Attr] %s = %s\n", tostring(attrName), tostring(attrVal))
                end

                -- Filhos / Labels / Cores
                for _, child in ipairs(itemSlot:GetDescendants()) do
                    if child:IsA("TextLabel") and child.Text ~= "" then
                        report = report .. string.format("      [TextLabel] %s: '%s'\n", child.Name, child.Text)
                    elseif child:IsA("UIStroke") then
                        report = report .. string.format("      [Borda/Cor] %s = %s\n", child.Name, tostring(child.Color))
                    end
                end
            end
        end
    end
    report = report .. string.format("\nTotal de slots detectados: %d\n", count)
else
    report = report .. "   (Container MainFrame.Items.Scroll não encontrado ou inventário fechado)\n"
end

print("\n" .. report .. "\n")
if setclipboard then
    setclipboard(report)
end
