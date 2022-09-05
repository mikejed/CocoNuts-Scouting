#include <Json.au3>
#include <SQLite.au3>

#include <EditConstants.au3>

FileInstall(@ScriptDir & "\SQLite3.dll", @TempDir & "\SQLite3.dll")

Global $hDB, $aColList, $sColListPath = @ScriptDir & "\DataList.txt"
Global $aResult, $iRows, $iCols

; I need a list of the columns to include in the database. If the file doesn't exist, create it.
If Not FileExists($sColListPath) Then
	If MsgBox(1, "Columns not found", "File DataList.txt not found - click OK to create a default file or cancel to exit" & @CRLF & @CRLF &"(Team Number, Team Name, Match, and Comment will always be included)") = 2 Then Exit
	$hColList = FileOpen($sColListPath,2)
	FileWriteLine($hColList,"PrefStart")
	FileWriteLine($hColList,"PrefDrive")
	FileWriteLine($hColList,"PrefScore")
	FileWriteLine($hColList,"CompatAuto")
	FileWriteLine($hColList,"DriveSkill")
	FileWriteLine($hColList,"TargetsHigh")
	FileWriteLine($hColList,"TargetsLow")
	FileWriteLine($hColList,"Endgame")
	FileWriteLine($hColList,"Aggression")
	FileWriteLine($hColList,"Outlier")
	FileWriteLine($hColList,"BreakImpact")
EndIf

; Read the list of columns from the file for the rest of this session
$aColList = FileReadToArray($sColListPath)

;Start the SQLite engine from the dll we installed in the temp dir
_SQLite_Startup(@TempDir & "\SQLite3.dll")
If @error Then
        MsgBox($MB_SYSTEMMODAL, "SQLite Error", "SQLite3.dll Can't be Loaded!" & @CRLF & @CRLF & _
                        "Not FOUND in @ScriptDir, @WorkingDir," & @CRLF & @TAB & "@LocalAppDataDir\AutoIt v3\SQLite," & @CRLF & @TAB & "@SystemDir or @WindowsDir")
        Exit
EndIf

; Create the UI
Global $hGui = GUICreate("CocoNuts Scouting Data Entry", 320, 240)
Global $hFileMenu = GUICtrlCreateMenu("File")
Global $hNewMenu = GUICtrlCreateMenuItem("New", $hFileMenu)
Global $hOpenMenu = GUICtrlCreateMenuItem("Open", $hFileMenu)
Global $hStatusBar = GUICtrlCreateLabel("  No file open", 0, 200, 320, 20)
GUICtrlSetBkColor(-1, 0xFFFFFF)
Global $hAddDataButton = GUICtrlCreateButton("Add new match data", 70, 80, 170, 40)

;Now show the main UI and run the loop until it's closed.
GUISetState()
While 1
	Global $msg = GUIGetMsg()
	Switch $msg
		Case -3 ; The main UI was closed
			DoExit()

		Case $hNewMenu ; File > New
			Local $sNewDbPath = FileSaveDialog("New File", @WorkingDir, "Database Files (*.db)", 18)
			If @error Then ContinueLoop ; cancel button clicked

			; If another database is already open, close it.
			If $hDB <> '' Then _SQLite_Close()

			; Attempt to open the file selected (which will create a new file assuming it doesn't already exist). Don't delete previous contents if it does already exist, just in case.
			$hDB = _SQLite_Open($sNewDbPath)
			If @error Then
				MsgBox(16, "Error", "Error opening database. Exiting")
				DoExit()
			EndIf

			; Now create the tables in the database. Teams should be rather static, but Matches only has 3 hardcoded columns I rely on existing- the rest will be added dynamically below.
			_SQLite_Exec(-1, "CREATE TABLE [Teams] ([TeamNumber], [TeamName])")
			_SQLite_Exec(-1, "CREATE TABLE [Matches] ([TeamNumber], [Match], [Comment])")

			; Now that the tables exist, add all of the dynamic columns to [Matches].
			UpdateMatchColumnList()

			; Indicate the file path of the new database in the status bar.
			SetStatusBar($sNewDbPath)

		Case $hOpenMenu ; File > Open
			Local $sNewDbPath = FileOpenDialog("Open File", @WorkingDir, "Database Files (*.db)")
			If @error Then ContinueLoop ; cancel button clicked

			; If another database is already open, close it.
			If $hDB <> '' Then _SQLite_Close()

			; Attempt to open the file selected.
			$hDB = _SQLite_Open($sNewDbPath)
			If @error Then
				MsgBox(16, "Error", "Error opening database.")
				SetStatusBar("No file open")
				_SQLite_Close()
				$hDB = ''
				ContinueLoop
			EndIf

			; Make sure that the [Matches] table exists - I don't create the table on opened databases.
			_SQLite_GetTable2D(-1, "SELECT * FROM [Matches] LIMIT 1", $aResult, $iRows, $iCols)
			If @error Or $iCols < 3 Then
				MsgBox(16, "Error", "The selected database isn't compatible with this program")
				SetStatusBar("No file open")
				_SQLite_Close()
				$hDB = ''
				ContinueLoop
			EndIf

			; Make sure the [Teams] table exists - I don't create the table on opened databases.
			_SQLite_GetTable2D(-1, "SELECT * FROM [Teams] LIMIT 1", $aResult, $iRows, $iCols)
			If @error Or $iCols < 2 Then
				MsgBox(16, "Error", "The selected database isn't compatible with this program")
				SetStatusBar("No file open")
				_SQLite_Close()
				$hDB = ''
				ContinueLoop
			EndIf

			; Make sure all the custom columns exist in the [Matches] table. Extra columns don't hurt anything, if others already existed.
			UpdateMatchColumnList()

			; Indicate the file path of the now-open database in the status bar.
			SetStatusBar($sNewDbPath)

		Case $hAddDataButton
			If $hDB == '' Then
				MsgBox(16, "Error", "You must open a database before you can add data")
				ContinueLoop
			EndIf

			; Create the dialogue UI.
			Global $h_NewDataGui = GUICreate("Add Match Data", 320, 140)
			Global $h_NewDataInput = GUICtrlCreateEdit("", 0, 0, 320, 100, BitOR($ES_WANTRETURN, $ES_AUTOVSCROLL))
			Global $h_NewDataSubmit = GUICtrlCreateButton("Load Data", 50, 100, 220, 40)
			GUISetState(@SW_SHOW, $h_NewDataGui)

			While 1
				$msg = GUIGetMsg()
				Switch $msg
					Case -3 ; Dialog closed
						GUISetState(@SW_HIDE, $h_NewDataGui)
						ExitLoop

					Case $h_NewDataSubmit ; Data entered - now digest the data and enter it into the database. Extra data (not indicated by custom column file) is ignored.
						$s_Input = Json_Decode(StringStripCR(GUICtrlRead($h_NewDataInput)))
						GUISetState(@SW_HIDE, $h_NewDataGui)

						Local $sTeamNumber	= GetEscapedJson($s_Input, 'TeamNumber')
						Local $sTeamName 	= GetEscapedJson($s_Input, 'TeamName')
						Local $sMatch		= GetEscapedJson($s_Input, 'Match')
						Local $sComment		= GetEscapedJson($s_Input, 'Comment')

						; Add or update team name in [Teams] table
						_SQLite_GetTable2D(-1, "SELECT [TeamNumber], [TeamName] FROM [Teams] WHERE [TeamNumber] = " & $sTeamNumber, $aResult, $iRows, $iCols)
						If $iRows > 0 Then
							If $aResult[0][1] <> $sTeamName Then
								If MsgBox(36, "Change team name?", "Team " & $sTeamNumber & " is already recorded with a name of " & $aResult[0][1] & ". Do you want to update their name to " & $sTeamName & "?") == 6 Then
									; Team name already recorded but they've chosen to update it.
									_SQLite_Exec(-1, "UPDATE [Teams] SET [TeamName] = '" & $sTeamName & "' WHERE [TeamNumber] = " & $sTeamNumber)
								EndIf
							EndIf
						Else
							; Team name not already recorded. Add it.
							_SQLite_Exec(-1, "INSERT INTO [Teams] ([TeamNumber], [TeamName]) VALUES (" & $sTeamNumber & ", '" & $sTeamName & "'")
						EndIf

						; See if the team number and match number match a record already in the database. If so, confirm they want to duplicate data.
						_SQLite_GetTable2D(-1, "SELECT * FROM [Matches] WHERE [TeamNumber] = " & $sTeamNumber & " AND [Match] = " & $sMatch, $aResult, $iRows, $iCols)
						If $iRows == 0 Or MsgBox(36, "Duplicate Record", "You already have a record for team " & $sTeamNumber & " on match " & $sMatch & ". Are you sure you want to add this data also?") == 6 Then

							; Start building the query: first list all of the columns we'll insert data into.
							Local $sQuery = "INSERT INTO [Matches] (" & "[TeamNumber], [Match], [Comment]"
							For $i = 0 To UBound($aColList)-1
								$sQuery &= ", [" & $aColList[$i] & "]"
							Next

							; Continue building the query: now list all of the data to put into the columns.
							$sQuery &= ") VALUES (" & $sTeamNumber & ", " & $sMatch & ", '" & $sComment & "'"
							For $i = 0 To UBound($aColList)-1
								$sQuery &= ", '" & GetEscapedJson($s_Input, $aColList[$i]) & "'"
							Next
							$sQuery &= ")"

							;ConsoleWrite($sQuery & @CRLF)

							; Now run the query to store the data.
							_SQLite_Exec(-1, $sQuery)
						EndIf
						ExitLoop
				EndSwitch
			WEnd

	EndSwitch
	Sleep(50)
WEnd

; Function to update the status bar: first take the rightmost 50 characters, and then if there's a backslash strip everything to the left and prepend with '...'
Func SetStatusBar($_sText)
	If StringLen($_sText) > 50 Then
		$_sText = StringRight($_sText, 50)
		$_sText = "...\" & StringTrimLeft($_sText, StringInStr($_sText,"\"))
	EndIf
	GUICtrlSetData($hStatusBar, $_sText)
EndFunc

; Function to loop through the custom columns and see if they already exist in [Matches] table. If not, add them.
Func UpdateMatchColumnList()
	Local $_aResult, $_iRows, $_iCols
	For $_i = 0 To UBound($aColList)-1
		_SQLite_GetTable2D(-1, "SELECT [" & $aColList[$_i] & "] FROM [Matches] LIMIT 1", $_aResult, $_iRows, $_iCols)
		If @error Or $_iCols < 1 Then
			_SQLite_Exec(-1, "ALTER TABLE [Matches] ADD COLUMN [" & $aColList[$_i] & "]")
		EndIf
	Next
EndFunc

; Function to get the property of a specific key from the indicated JSON string.
Func GetEscapedJson($_string, $_key)
	Return StringReplace(StringReplace(Json_ObjGet($_string, $_key), '\n', @CRLF), "'", "''")
EndFunc

; Call this function instead of Exit once the SQLite engine is running to make sure everything shuts down gracefully.
Func DoExit()
	If $hDB <> '' Then _SQLite_Close()
	_SQLite_Shutdown()
	Exit
EndFunc