#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=../favicon.ico
#AutoIt3Wrapper_Res_ProductName=CocoNuts Data Scanner
#AutoIt3Wrapper_Res_ProductVersion=2.2
#AutoIt3Wrapper_Res_LegalCopyright=2024 by Michael Garrison
#AutoIt3Wrapper_Res_Language=1033
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

; Compiled using AutoIt v3.3.16.0

#include <includes\Json.au3>

#include <EditConstants.au3>
#include <GuiListView.au3>
#include <GUIConstants.au3>

Global $hDB, $aColList, $sColListPath = @ScriptDir & "\DataList.txt"
Global $aResult, $iRows, $iCols

; I need a list of the columns to include in the headers. If the file doesn't exist, create it.
If Not FileExists($sColListPath) Then
	If MsgBox(1, "Columns not found", "File DataList.txt not found - click OK to create a default file or cancel to exit" & @CRLF & @CRLF &"(Team Number, Match, and Comment will always be included)") = 2 Then Exit
	$hColList = FileOpen($sColListPath,2)
	FileWriteLine($hColList,"PrefStart")
	FileWriteLine($hColList,"CycleTime")
	FileWriteLine($hColList,"DefenseOnly")
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

#Region; Create the UI
Global $hGui = GUICreate("CocoNuts Scouting Data Entry", 320, 260)
Global $hFileMenu = GUICtrlCreateMenu("File")
Global $hNewMenu = GUICtrlCreateMenuItem("New", $hFileMenu)
Global $hOpenMenu = GUICtrlCreateMenuItem("Open", $hFileMenu)

Global $hNewDataInput = GUICtrlCreateEdit("", 0, 0, 320, 140, BitOR($ES_WANTRETURN, $ES_AUTOVSCROLL))
Global $hNewDataSubmit = GUICtrlCreateButton("Open or create a .csv" & @CRLF & "file to add data", 80, 170, 170, 40, $BS_MULTILINE)
GUICtrlSetState($hNewDataSubmit, $GUI_DISABLE)

Global $hStatusBar = GUICtrlCreateLabel("  No file open", 0, 220, 320, 20)
GUICtrlSetBkColor(-1, 0xFFFFFF)
#EndRegion

;Now show the UI and run the loop until it's closed.
GUISetState()
While 1
	Global $msg = GUIGetMsg()
	Switch $msg
		Case -3 ; The UI was closed
			DoExit()

		Case $hNewMenu ; File > New
			Local $sNewDbPath = FileSaveDialog("New File", @WorkingDir, "CSV Files (*.csv)", 18)
			If @error Then ContinueLoop ; cancel button clicked

			; If another file is already open, close it.
			If $hDB <> '' Then FileClose($hDB)

			; Attempt to open the file selected (which will create a new file assuming it doesn't already exist).
			$hDB = FileOpen($sNewDbPath, 1)
			If @error Then
				MsgBox(16, "Error", "Error opening data file. Exiting")
				DoExit()
			EndIf

			; Now create the header row (remember this is the equivalent of the [Matches] table in the old database approach).
			Local $sColList = "TeamNumber,Match,"
			For $_i = 0 To UBound($aColList)-1
				$sColList &= $aColList[$_i] & ","
			Next
			$sColList &= "Comment"
			FileWriteline($hDB, $sColList)

			; Indicate the file path of the new file in the status bar. This also enables the controls now that a file is open.
			SetStatusBar($sNewDbPath)

		Case $hOpenMenu ; File > Open
			Local $sNewDbPath = FileOpenDialog("Open File", @WorkingDir, "CSV Files (*.csv)")
			If @error Then ContinueLoop ; cancel button clicked

			; If another file is already open, close it.
			If $hDB <> '' Then FileClose($hDB)

			; Attempt to open the file selected.
			$hDB = FileOpen($sNewDbPath, 1)
			If @error Then
				MsgBox(16, "Error", "Error opening data file.")
				SetStatusBar("No file open")
				$hDB = ''
				ContinueLoop
			EndIf

			; Indicate the file path of the now-open file in the status bar.
			SetStatusBar($sNewDbPath)

		Case $hNewDataSubmit
			If $hDB == '' Then
				MsgBox(16, "Error", "You must open a data file before you can add data")
				ContinueLoop
			EndIf

			If StringLen(GUICtrlRead($hNewDataInput)) < 2 Or StringStripWS(StringLeft(GuiCtrlRead($hNewDataInput),1),3) <> '{' Or StringStripWS(StringRight(GuiCtrlRead($hNewDataInput),1),3) <> '}' Then
				MsgBox(16, "Error", "Make sure you've scanned information into the text field 😅")
				ContinueLoop
			EndIf

			; Data entered - now digest the data and add it to the file. Extra data (not indicated by custom column file) is ignored.
			$s_Input = Json_Decode(StringStripWS(GUICtrlRead($hNewDataInput),3))

			If UBound(Json_ObjGetKeys($s_Input)) - 3 <> UBound($aColList) Then
				MsgBox(16, "Error", "The data doesn't seem to be formatted correctly. Maybe try scanning again?")
				ContinueLoop
			EndIf

			Local $sTeamNumber	= GetEscapedJson($s_Input, 'TeamNumber')
			Local $sMatch		= GetEscapedJson($s_Input, 'Match')
			Local $sComment		= GetEscapedJson($s_Input, 'Comment')

			; Start building the query: first list all of the columns we'll insert data into.
			Local $sQuery = $sTeamNumber & "," & $sMatch

			; Continue building the query: now list all of the data to put into the columns.
			For $i = 0 To UBound($aColList)-1
				$sQuery &= ',' & GetEscapedJson($s_Input, $aColList[$i])
			Next
			$sQuery &= ',"' & StringReplace($sComment, '"', '""') & '"'

			; Now run the query to store the data.
			FileWriteLine($hDB, $sQuery)

			; Finally, clear out the input so it's ready for the next scan.
			GUICtrlSetData($hNewDataInput, "")

	EndSwitch
WEnd


; Function to update the status bar: first take the rightmost 50 characters, and then if there's a backslash strip everything to the left and prepend with '...'
Func SetStatusBar($_sText)
	If StringLen($_sText) > 50 Then
		$_sText = StringRight($_sText, 50)
		$_sText = "...\" & StringTrimLeft($_sText, StringInStr($_sText,"\"))
	EndIf
	GUICtrlSetData($hStatusBar, $_sText)

	; Since a file is now open, make sure the controls are enabled.
	GUICtrlSetData($hNewDataSubmit, "Load Data")
	GUICtrlSetState($hNewDataSubmit, $GUI_ENABLE)
EndFunc


; Function to get the property of a specific key from the indicated JSON string.
Func GetEscapedJson($_string, $_key)
	Return StringReplace(StringReplace(Json_ObjGet($_string, $_key), '\n', @CRLF), "'", "''")
EndFunc


; Call this function instead of Exit to make sure everything shuts down gracefully.
Func DoExit()
	If $hDB <> '' Then FileClose($hDB)
	Exit
EndFunc
