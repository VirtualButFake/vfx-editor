print("Running")
local selection = script

local story = selection.stories["App.story"]
local requiredStory = require(story)

local destroy = requiredStory.story(game.CoreGui.ScreenGui, {controls={Height="550", Width="350"}})