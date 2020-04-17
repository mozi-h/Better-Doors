hook.Add("PostGamemodeLoaded", "bd_PostGamemodeLoaded", function()
  if engine.ActiveGamemode() == "darkrp" then
    print("Loading Better Doors")

    if SERVER then
      include("betterdoors/betterdoors_sv.lua")
    end

    DarkRP.declareChatCommand{
      command = "setgroup",
      description = "Sets the group of the door you're looking at.",
      delay = 0
    }

    DarkRP.declareChatCommand{
      command = "getgroup",
      description = "Prints the group of the door you're looking at.",
      delay = 0
    }

    DarkRP.declareChatCommand{
      command = "listgroups",
      description = "Lists all door groups on this map.",
      delay = 0
    }


  else
    print("Not loading Better Doors as this is not DarkRP")
  end
end)
