<#
.SYNOPSIS
A Rogue-like game written in PowerShell. Inspired by the classic PC game Rogue and written to allow others to learn PowerShell in a fun way. Written by Emre Motan.

.DESCRIPTION
The Get-Inventory function uses Windows Management Instrumentation (WMI) toretrieve service pack version, operating system build number, and BIOS serial number from one or more remote computers. 
Computer names or IP addresses are expected as pipeline input, or may bepassed to the –computerName parameter. 
Each computer is contacted sequentially, not in parallel.

.PARAMETER computerNameAccepts 
a single computer name or an array of computer names. You mayalso provide IP addresses.

.PARAMETER path
The path and file name of a text file. Any computers that cannot be reached will be logged to this file. 
This is an optional parameter; if it is notincluded, no log file will be generated.

.EXAMPLE
Read computer names from Active Directory and retrieve their inventory information.
Get-ADComputer –filter * | Select{Name="computerName";Expression={$_.Name}} | Get-Inventory.

.EXAMPLE 
Read computer names from a file (one name per line) and retrieve their inventory information
Get-Content c:\names.txt | Get-Inventory.

.NOTES
You need to run this function as a member of the Domain Admins group; doing so is the only way to ensure you have permission to query WMI from the remote computers.
#>

<#
PowerRogue Design

v1
Player character is of one class, SysAdmin. Stats include "concentration" e.g. health, "SkillSet" e.g. attack power, "Knowledge" which is experience, "Position" which is level (e.g. Junior, regular, senior, lead...).
Player provides a name.
Game has a title screen with colorful "PowerRogue" art.
Goal is to ascend levels of the office building to reach the Tome of Productivity.
Enemies get progressively more difficult. Set # of enemies per level.
Enemies:
- Spam lvl 1
- Bug lvl 2
- Virus lvl 3
- Meeting lvl 4
- Ambiguity lvl 5
Can pick up "money" along the way. Enemies drop them.
Granted "Knowledge" when enemy is defeated.
Leveling up "Knowledge" increases SkillSet and Concentration.
Maps are randomly generated "Rogue-Like"
Stairways are point between levels. Cannot go back up stairs - stairway disappears.

Controls:
Arrow keys are all that's needed.
'q' saves and quits the game.

GameFlow:
- Title Screen
- Ask for name
- Create level 1
- Player reaches stairway
- Create level 2
...
- Player reaches stairway on level 5
- Game End Screen
-- Shows all stats, money, congratulations

Objects:
- Current level Map
- Game global info
- Player
- Enemies dictionary
- Enemies on current level

#>

# Display welcome screen
Clear-Host
Write-Host 'Welcome to PowerRogue, the Rogue-like game written in PowerShell'

# Ask for player's name
$name = Read-Host 'What is the player''s name?'

$playerClass = @"
// Stats include "concentration" e.g. health, "SkillSet" e.g. attack power, "Knowledge" which is experience, 
// "PositionLevel" which is level (e.g. Junior, regular, senior, lead...).
public class Player
{
    public int xPos;
	public int yPos;
	
	public int concentration;
	public int skillSet;
	public int knowledge;
	public int positionLevel;
	
	public int money;
	
	public string name; // String works; don't need to use char[]
}
"@

# Player initialization
Add-Type -TypeDefinition $playerClass
$player = New-Object Player
$player.xPos = 1
$player.yPos = 1
$player.name = $name
$player.concentration = 10
$player.skillSet = 1
$player.knowledge = 1
$player.positionLevel = 1
$player.money = 0

# Function to check position the player wants to go walk onto
# For now, just check if the tile is walkable
# Can be used for both player and NPCs
Function CheckDestTileWalkable
{
    if ($destX -lt 30 -and $destY -lt 30 `
	    -and $destX -ge 0 -and $destY -ge 0)
	{
	    $i = $Global:roomData[$destY][$destX]
		if ($i -eq 46 -or `
		    $i -eq "<" -or `
			$i -eq "*")
		{
	    	$walkableFlg = 1
		}
		else
		{
		    $walkableFlg = 0
	    }
	}
	else
	{
		$walkableFlg = 0
	}

	return $walkableFlg
}

# Array to hold descriptions of actions taken
$Global:actionLog = @()
$gameLevel = 1

# As long as $running == 1, the game's main loop... loops
$running = 1
$foundTome = 0

# TODO:
# Randomly sized room
# Place enemies on map based on level (level 1 = one enemy, level 2 = two enemies, etc...)
# Goal is to get treasure and call enemies

$Global:roomData = @()

function CreateLevel
{
	# Room Data
	# Create large, empty room
	# 30x30, like Pixel Dungeon (Android)
	$Global:roomData = @(
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
	   ( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 )
	)

	# Create room (debug algorithm)
	for ($y=0; $y -lt 30; $y++)
	{
	    for ($x=0; $x -lt 30; $x++)
		{
		    if ($y -eq 0 -or $y -eq 30 - 1)
			{
			    $Global:roomData[$y][$x] = 45
		  	}
		    elseif ($x -eq 0 -or $x -eq 30 - 1)
			{
			    $Global:roomData[$y][$x] = 124
			}
			else
			{
			    $Global:roomData[$y][$x] = 46
			}
		}
	}
	
	# Place stairs up if Level 1 - 4
	if($gameLevel -lt 5)
	{
	    $roomData[2][2] = "<"
	}
	
	# Place Tome of Productivity if Level 5
	if($gameLevel -eq 5)
	{
	    $roomData[2][2] = "*"
	}
	
    # Set player location
	$player.xPos = 1
	$player.yPos = 1
	
	$Global:actionLog += "Entering floor " + $gameLevel + " of the office building..."
}



CreateLevel

# Main game loop
do {
	Clear-Host
	$screenData = ''
	
	# Debug output
	$screenData += "PCx: $($player.xPos)" + "`n"
	$screenData += "PCy: $($player.yPos)" + "`n"
	$screenData += "WalkableFlg: $walkableFlg" + "`n"
	$i = $Global:roomData[$player.yPos][$player.xPos]
	$screenData += "MapTile: $i" + "`n"
	$screenData += "Game Level: $gameLevel" + "`n"
	$screenData += "" + "`n"
	
	# Draw screen
	# Originally I was drawing each tile of the map individually using Write-Host -NoNewLine
	# I optimized this proceedure by constructing a string $screen that builds up the screen data
	# piece by piece. This data is displayed to the screen just before the "wait for input" command
	# is called.
	for ($y=0; $y -lt 30; $y++)
	{
	    for ($x=0; $x -lt 30; $x++)
		{
		    $asciiCode = $Global:roomData[$y][$x]		
			
			# Draw the player character if we're processing its position
			if($x -eq $player.xPos -and $y -eq $player.yPos)
			{
			    $screenData += ([char]64)
			}
			elseif($Global:roomData[$y][$x] -eq 0)
			{
			    $screenData += " "
			}
			else
			# Draw map tile
			{
			    $screenData += ([char]$asciiCode)
			}
		}
		$screenData += "`n"
	}
	
	# Draw player stats
	$screenData += "Name: " + $player.name + " | Concentration: " + $player.concentration + " | SkillSet: " + $player.skillSet + " | Knowledge: " + $player.knowledge + " | Position: " + $player.positionLevel + " | Floor #: " + $gameLevel + "`n"
	
	# Draw action log
    # We can access the last element in an array by referring to [-1]. Similarly, the fifth from the end would be [-5].
	$screenData += "`n"
	$screenData += $Global:actionLog[-5] + "`n"
	$screenData += $Global:actionLog[-4] + "`n"
	$screenData += $Global:actionLog[-3] + "`n"
	$screenData += $Global:actionLog[-2] + "`n"
	$screenData += $Global:actionLog[-1] + "`n"
	
	#foreach ($command in $Global:actionLogReverse)
	#{
	#    $screenData += $command + "`n"
	#}
	
	# Display contents of Screen Data
	Write-Host $screenData
	
	# Get player input
	$inputKey = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")

	# process player input using VirtualKeyCodes
	switch ($inputKey.VirtualKeyCode)
	{
	    # case 'q' key: Exit game
		81 { $running = 0}
	
	    # case 'up' key: 
	    38 { 
		   $destX = $player.xPos
		   $destY = $player.yPos - 1
		   $walkableFlg = CheckDestTileWalkable
		
		   if ($walkableFlg -eq 1)
		   {
		       $player.xPos = $destX
			   $player.yPos = $destY
			   
			   
     		   $command = "Player moves north"
    		   $Global:actionLog += $command
		   }
		   else
		   {
		       $command = "Path blocked"
    		   $Global:actionLog += $command   
		   }
		}
	
	    # case 'down' key:
	    40 { 
		   $destX = $player.xPos
		   $destY = $player.yPos + 1
		   $walkableFlg = CheckDestTileWalkable
		
		   if ($walkableFlg -eq 1)
		   {
		       $player.xPos = $destX
			   $player.yPos = $destY
			   
               $command = "Player moves south"
    		   $Global:actionLog += $command
		   }
		   else
		   {
		       $command = "Path blocked"
    		   $Global:actionLog += $command   
		   }
		}
	
		# case 'left' key:
	    37 { 
		   $destX = $player.xPos - 1
		   $destY = $player.yPos
		   $walkableFlg = CheckDestTileWalkable
		
		   if ($walkableFlg -eq 1)
		   {
		       $player.xPos = $destX
			   $player.yPos = $destY
			   $player.yPos = $destY
			   
               $command = "Player moves west"
    		   $Global:actionLog += $command
		   }
		   else
		   {
		       $command = "Path blocked"
    		   $Global:actionLog += $command   
		   }
		}
	
		# case 'right' key:
	    39 { 
		   $destX = $player.xPos + 1
		   $destY = $player.yPos
		   $walkableFlg = CheckDestTileWalkable
		
		   if ($walkableFlg -eq 1)
		   {
		       $player.xPos = $destX
			   $player.yPos = $destY
			   $player.yPos = $destY
			   
               $command = "Player moves east"
    		   $Global:actionLog += $command
		   }
		   else
		   {
		       $command = "Path blocked"
    		   $Global:actionLog += $command   
		   }
		} 
	}
	
	# Check to see if we're on a stairway tile
	if($roomData[$player.yPos][$player.xPos] -eq "<")
	{
		$gameLevel += 1
		CreateLevel
	}
	
	# Check to see if we're on the Tome of Productivity tile
	if($roomData[$player.yPos][$player.xPos] -eq "*")
	{
		$running = 0
		$foundTome = 1
	}
	
}
while ($running -eq 1)

# Check to see if player beat the game
if($foundTome -eq 1)
{
	Clear-Host
	Write-Host "Congratulations! You can now go be productive! `n"
	
	#Display stats
	Write-Host "Final stats:"
	Write-Host "Player name:" $player.name
	Write-Host "Player concentration:" $player.concentration
	Write-Host "Player SkillSet:" $player.skillSet
	Write-Host "Player Knowledge:" $player.knowledge
	Write-Host "Player Position:" $player.positionLevel
}