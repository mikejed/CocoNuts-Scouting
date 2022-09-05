#include <SQLite.au3>
;number, name, change over time, randomize, last score, rounds
Global $a_Teams[21][6] = [[1234, "lions", 0.1, 0, 0, 0] _
						, [2345, "tigers", 1.2, 0.5, 0, 0] _
						, [3456, "bears", -0.2, 0.5, 0, 0] _
						, [4567, "wizards", 2, 1, 0, 0] _
						, [5678, "eagles", 0.5, 0.2, 0, 0] _
						, [6789, "falcons", 0.1, 4, 0, 0] _
						, [7890, "cheese", -0.5, 1, 0, 0] _
						, [1324, "lime", -0.5, 0, 0, 0] _
						, [2435, "orange", -1, 0, 0, 0] _
						, [3546, "oregano", 1, 0, 0, 0] _
						, [4657, "newbies", 0, 3, 0, 0] _
						, [5768, "gears", 0.4, 5, 0, 0] _
						, [6879, "wires", -2, 3, 0, 0] _
						, [7980, "cogs", 1.2, 1, 0, 0] _
						, [1345, "sprockets", 0.8, 2, 0, 0] _
						, [2456, "squirrels", 0.5, 8, 0, 0] _
						, [3567, "dogs", 2, 6, 0, 0] _
						, [4678, "cats", 0.8, 2, 0, 0] _
						, [5555, "pigs", 0.2, 3, 0, 0] _
						, [6666, "parrots", 0.76, 1.2, 0, 0] _
						, [7777, "seeds", 0, 1, 0, 0] _
						]
Global $boolean[2] = ['true','false']
_SQLite_Startup()
_SQLite_Open(@ScriptDir & "\data.db")

Local $aResult, $iRows, $iCols

If $iCols < 1 Or $aResult[1][0] < 20220902.1 Then
	ConsoleWrite("New Database" & @CRLF)
	_SQLite_Exec(-1, "CREATE TABLE [__MigrationHistory] ([Id], [Name], [Version])")
	_SQLite_Exec(-1, "CREATE TABLE [Matches] ([TeamNumber], [Match], [PrefStart], [PrefDrive], [PrefScore], [CompatAuto], [DriveSkill], [TargetsHigh], [TargetsLow], [Endgame], [Aggression], [Outlier], [BreakImpact], [Comment])")
	_SQLite_Exec(-1, "INSERT INTO [__MigrationHistory] ([Id], [Name], [Version]) VALUES (20220902.1, 'CreateDatabase', '1.0')")
	_SQLite_Exec(-1, "CREATE TABLE [Teams] ([TeamNumber], [TeamName])")
Else
	ConsoleWrite("Existing Database" & @CRLF)
EndIf

For $team = 0 To 20 Step 1
	$a_Teams[$team][4] = Random(0, 20, 1)
	_SQLite_Exec(-1, "INSERT INTO [Teams] ([TeamNumber], [TeamName]) VALUES (" & $a_Teams[$team][0] & ", '" & $a_Teams[$team][1] & "')")
Next

For $round = 1 To 28 Step 1
	;shuffle the teams, then order them by the number of rounds. The top 6 teams will be in this round.
	_ArrayShuffle($a_Teams)
	_ArraySort($a_Teams, 0, 0, 0, 5)
	For $team = 0 To 5 Step 1
		$a_Teams[$team][5] += 1;indicate they've competed in one more round
		Local $increase = $a_Teams[$team][2] + Random($a_Teams[$team][3]*-1, $a_Teams[$team][3])
		$a_Teams[$team][4] = Round($a_Teams[$team][4] + $increase)
		If $a_Teams[$team][4] < 0 Then $a_Teams[$team][4] = 0

		_SQLite_Exec(-1, "INSERT INTO [Matches] (" & _
						"[TeamNumber]" & _
						", [Match]" & _
						", [PrefStart]" & _
						", [PrefDrive]" & _
						", [PrefScore]" & _
						", [CompatAuto]" & _
						", [DriveSkill]" & _
						", [TargetsHigh]" & _
						", [TargetsLow]" & _
						", [Endgame]" & _
						", [Aggression]" & _
						", [Outlier]" & _
						", [BreakImpact]" & _
						", [Comment]" & _
					")" & _
					" VALUES ( " & _
						$a_Teams[$team][0] & _
						", " & $round & _
						", '" & Random(1,3,1) & "'" & _
						", '" & Random(1,3,1) & "'" & _
						", '" & Random(1,3,1) & "'" & _
						", '" & $boolean[Random(0,1,1)] & "'" & _
						", '" & Random(1,5,1) & "'" & _
						", '" & $a_Teams[$team][4] & "'" & _
						", '" & Round(0.15 * $a_Teams[$team][4]) & "'" & _
						", '" & GetEndgame($a_Teams[$team][4]) & "'" & _
						", '" & Random(1,5,1) & "'" & _
						", '" & $boolean[Random(0,1,1)] & "'" & _
						", '" & $boolean[Random(0,1,1)] & "'" & _
						", 'There were " & Random(0, 20, 1) & " " & $a_Teams[Random(0,20,1)][1] & " members yelling this round.'" & _
						")" _
		)
	Next
Next

_SQLite_GetTable2D(-1, "SELECT * FROM [Matches]", $aResult, $iCols, $iRows)
_ArrayDisplay($aResult)

_SQLite_Close()
_SQLite_Shutdown()

Func GetEndgame($_i)
	$_i = $_i / 5
	If $_i > 4 Then $_i = 4
	Return Round($_i)
EndFunc