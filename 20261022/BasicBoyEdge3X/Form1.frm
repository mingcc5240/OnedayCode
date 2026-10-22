VERSION 5.00
Object = "{F9043C88-F6F2-101A-A3C9-08002B2F49FB}#1.2#0"; "COMDLG32.OCX"
Begin VB.Form Form1 
   Caption         =   "BasicBoy -Blaarg Cpu Passed- made by Min Ad gemini"
   ClientHeight    =   6435
   ClientLeft      =   165
   ClientTop       =   810
   ClientWidth     =   6915
   KeyPreview      =   -1  'True
   LinkTopic       =   "Form1"
   ScaleHeight     =   6435
   ScaleWidth      =   6915
   StartUpPosition =   3  'Windows 기본값
   Begin VB.PictureBox Picture1 
      Appearance      =   0  '평면
      AutoRedraw      =   -1  'True
      BackColor       =   &H80000005&
      BorderStyle     =   0  '없음
      ForeColor       =   &H80000008&
      Height          =   5985
      Left            =   30
      ScaleHeight     =   399
      ScaleMode       =   3  '픽셀
      ScaleWidth      =   431
      TabIndex        =   0
      Top             =   30
      Visible         =   0   'False
      Width           =   6465
      Begin MSComDlg.CommonDialog cd 
         Left            =   6120
         Top             =   4320
         _ExtentX        =   847
         _ExtentY        =   847
         _Version        =   393216
      End
      Begin VB.Timer Timer1 
         Interval        =   1000
         Left            =   3960
         Top             =   2160
      End
   End
   Begin VB.Label sb 
      Caption         =   "Label1"
      Height          =   255
      Left            =   120
      TabIndex        =   1
      Top             =   4320
      Width           =   4095
   End
   Begin VB.Menu fl 
      Caption         =   "File"
      Begin VB.Menu starte 
         Caption         =   "Open rom"
      End
      Begin VB.Menu ebdf 
         Caption         =   "Exit"
      End
   End
   Begin VB.Menu bn 
      Caption         =   "Emulator"
      Begin VB.Menu EGBC 
         Caption         =   "Emulate GBC"
         Checked         =   -1  'True
      End
      Begin VB.Menu mSound 
         Caption         =   "Emulate Sound"
         Checked         =   -1  'True
      End
      Begin VB.Menu mScale 
         Caption         =   "Scale3X"
         Checked         =   -1  'True
      End
      Begin VB.Menu vid 
         Caption         =   "Video"
         Begin VB.Menu lfps 
            Caption         =   "LimitFPS"
         End
         Begin VB.Menu fs 
            Caption         =   "Frame Skip"
            Begin VB.Menu fs0 
               Caption         =   "No Skip"
            End
            Begin VB.Menu fs6m1 
               Caption         =   "set 1.20x"
            End
            Begin VB.Menu fs5m1 
               Caption         =   "set 1.25x"
            End
            Begin VB.Menu fs4m1 
               Caption         =   "set 1.3x"
            End
            Begin VB.Menu fs3m1 
               Caption         =   "set 1.5x"
            End
            Begin VB.Menu fs1 
               Caption         =   "set x2"
            End
            Begin VB.Menu fs2 
               Caption         =   "set x3"
            End
            Begin VB.Menu fs3 
               Caption         =   "set x4"
            End
            Begin VB.Menu fs4 
               Caption         =   "set x5"
            End
            Begin VB.Menu fs9 
               Caption         =   "set x10"
            End
         End
         Begin VB.Menu md 
            Caption         =   "Mode"
            Begin VB.Menu WA 
               Caption         =   "WinApi"
            End
         End
         Begin VB.Menu rz 
            Caption         =   "Resolution"
            Begin VB.Menu z1 
               Caption         =   "1x"
            End
            Begin VB.Menu z2 
               Caption         =   "2x"
            End
            Begin VB.Menu z3 
               Caption         =   "3X"
            End
            Begin VB.Menu z4 
               Caption         =   "4X"
               Checked         =   -1  'True
            End
            Begin VB.Menu full 
               Caption         =   "Fullscreen"
               Checked         =   -1  'True
            End
         End
         Begin VB.Menu sh 
            Caption         =   "Show"
            Begin VB.Menu sbg 
               Caption         =   "BG"
               Checked         =   -1  'True
            End
            Begin VB.Menu swn 
               Caption         =   "Window"
               Checked         =   -1  'True
            End
            Begin VB.Menu sobj 
               Caption         =   "OBJs"
               Checked         =   -1  'True
            End
         End
      End
      Begin VB.Menu cp 
         Caption         =   "Cpu"
         Begin VB.Menu cr 
            Caption         =   "Core"
            Begin VB.Menu cr1 
               Caption         =   "Mode 1"
               Checked         =   -1  'True
               Enabled         =   0   'False
            End
            Begin VB.Menu cr2 
               Caption         =   "Mode 2"
               Checked         =   -1  'True
            End
         End
         Begin VB.Menu sss 
            Caption         =   "Hacks"
            Begin VB.Menu dt 
               Caption         =   "Disable timer"
               Checked         =   -1  'True
            End
         End
         Begin VB.Menu res 
            Caption         =   "Reset"
         End
      End
      Begin VB.Menu dbv 
         Caption         =   "View Debug Window"
      End
   End
End
Attribute VB_Name = "Form1"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
'Public dih As clsDirectInput8
'Public di As clsDIKeyboard8
Option Explicit

Private Sub Abt_Click()
MsgBox "Project : BasicBoy" & vbNewLine & _
       "Coder   : Raziel" & vbNewLine & _
       "Thanks  : No$gbc (For the pan docs)" & vbNewLine & _
       "          The Author of VisBoy (This begun as a 'Mod' of his emulator)" & vbNewLine & _
       "          The writers of GameBoy Cpu Manual" & vbNewLine & _
       "          The no Doevents tutorial writer" & vbNewLine & _
       "Note(s) :" & vbNewLine & _
       "         Some Variables have the same name with VisBoy." & vbNewLine & _
       "         This is because i was inspired by this emulator." & vbNewLine & _
       "" & vbNewLine & _
       "I need beta testers , Sound Help & someone to make a site" & vbNewLine & _
       "(The current basicboy.8k.com is a disaster...)" _
       , vbOKOnly, "About BasicBoy"
       
       
       

End Sub

Private Sub cc_Click()
'frmCheat.Show
End Sub

Private Sub cr1_Click()
cr1.Checked = True
cr2.Checked = False
cm = 1
SaveSetting "GBE", "CPU", "CM", 1
End Sub

Private Sub cr2_Click()
cr1.Checked = False
cr2.Checked = True
cm = 2
SaveSetting "GBE", "CPU", "CM", 2
End Sub

Private Sub dbv_Click()
 db.Show
End Sub

Private Sub DD7_Click()
full.Visible = True
WA.Checked = False

mm = 1
SaveSetting "GBE", "GFX", "MM", 2
End Sub

Private Sub dt_Click()
 dt.Checked = Not dt.Checked
 utu = Not dt.Checked
 SaveSetting "GBE", "CPU", "DT", utu
End Sub

Private Sub ebdf_Click()
On Error Resume Next
'DDraw.Shutdown
'di.Shutdown

  Sound.CloseSound
End
End Sub

Private Sub EGBC_Click()
 TGBC = Not TGBC
 EGBC.Checked = TGBC
 SaveSetting "GBE", "GBC", "EMU", TGBC
End Sub

Private Sub Form_Load()
bgv = True
wv = True
objv = True
smp = 0
Dim i As Long
'ReDim RAM(32768 To 65535)

If GetSetting("GBE", "GFX", "MM", "1") = 1 Then WA_Click
If GetSetting("GBE", "GFX", "MM", "1") = 2 Then DD7_Click
cm = GetSetting("GBE", "CPU", "CM", 2)
If cm = 1 Then: cr1.Checked = True: cr2.Checked = False: Else cr1.Checked = False: cr2.Checked = True
If GetSetting("GBE", "GFX", "ZM", "1") = 1 Then z1_Click
If GetSetting("GBE", "GFX", "ZM", "1") = 2 Then z2_Click
If GetSetting("GBE", "GFX", "ZM", "1") = 3 Then full_Click
utu = False 'GetSetting("GBE", "CPU", "DT", "True")
lfp = GetSetting("GBE", "CPU", "LFPS", "True")
fskip = GetSetting("GBE", "GFX", "FS", "1")
fmode = GetSetting("GBE", "GFX", "FM", "0")
TGBC = GetSetting("GBE", "GBC", "EMU", "False"): EGBC_Click: EGBC_Click
fs0.Checked = fskip = 1 And fmode = 0
fs6m1.Checked = fskip = 6 And fmode = 1
fs5m1.Checked = fskip = 5 And fmode = 1
fs4m1.Checked = fskip = 4 And fmode = 1
fs3m1.Checked = fskip = 3 And fmode = 1
fs1.Checked = fskip = 2 And fmode = 0
fs2.Checked = fskip = 3 And fmode = 0
fs3.Checked = fskip = 4 And fmode = 0
fs4.Checked = fskip = 5 And fmode = 0
fs9.Checked = fskip = 10 And fmode = 0

 lfps.Checked = lfp
 dt.Checked = Not utu
'Open "c:\l3.txt" For Binary As #99
'gxmode2
'Set dih = New clsDirectInput8
'Set di = New clsDIKeyboard8
'   dih.Startup Me.hWnd
'   di.Startup dih, Me.hWnd
   InitCPU
   For i = 0 To 7 ' For Set,Bit and Res
    BITT(i * 8) = 2 ^ i
    SETT(i * 8) = 255 - 2 ^ i
   Next i
   
   'BITT(0) = 1, SETT(0) = 254 0b1111 1110
   'BITT(1) = 2  SETT(1) = 253
   
   Call Sound.InitSound
   
 
    
   ' Call InitScale2xHeader
    Call InitScale3xHeader
End Sub

Private Sub Form_Terminate()
  Sound.CloseSound
End Sub

Private Sub Form_Unload(Cancel As Integer)
wrRam
On Error Resume Next
'DDraw.Shutdown
'di.Shutdown
Close #999
' Call Sound2.AudioClose
 Call Sound.CloseSound
End
End Sub


Sub resize()
Me.Width = Me.Picture1.Width + 150
Me.Height = Me.Picture1.Height + 1095
End Sub

'frame skip mode 1(act skip(x1(1),x2(2),x3(3),x4(4),x5(5),x6(6))
'frame skip mode 2(act skip(x1.20(6),x1.25(5),x1,3(4),x1.5(3))
Private Sub fs0_Click()
fs0.Checked = True
fs6m1.Checked = False
fs5m1.Checked = False
fs4m1.Checked = False
fs3m1.Checked = False
fs1.Checked = False
fs2.Checked = False
fs3.Checked = False
fs4.Checked = False
fs9.Checked = False
fskip = 1
fmode = 0
SaveSetting "GBE", "GFX", "FS", fskip
SaveSetting "GBE", "GFX", "FM", fmode
End Sub
Private Sub fs1_Click()
fs0.Checked = False
fs6m1.Checked = False
fs5m1.Checked = False
fs4m1.Checked = False
fs3m1.Checked = False
fs1.Checked = True
fs2.Checked = False
fs3.Checked = False
fs4.Checked = False
fs9.Checked = False
fskip = 2
fmode = 0
SaveSetting "GBE", "GFX", "FS", fskip
SaveSetting "GBE", "GFX", "FM", fmode
End Sub
Private Sub fs2_Click()
fs0.Checked = False
fs6m1.Checked = False
fs5m1.Checked = False
fs4m1.Checked = False
fs3m1.Checked = False
fs1.Checked = False
fs2.Checked = True
fs3.Checked = False
fs4.Checked = False
fs9.Checked = False
fskip = 3
fmode = 0
SaveSetting "GBE", "GFX", "FS", fskip
SaveSetting "GBE", "GFX", "FM", fmode
End Sub
Private Sub fs3_Click()
fs0.Checked = False
fs6m1.Checked = False
fs5m1.Checked = False
fs4m1.Checked = False
fs3m1.Checked = False
fs1.Checked = False
fs2.Checked = False
fs3.Checked = True
fs4.Checked = False
fs9.Checked = False
fskip = 4
fmode = 0
SaveSetting "GBE", "GFX", "FS", fskip
SaveSetting "GBE", "GFX", "FM", fmode
End Sub
Private Sub fs4_Click()
fs0.Checked = False
fs6m1.Checked = False
fs5m1.Checked = False
fs4m1.Checked = False
fs3m1.Checked = False
fs1.Checked = False
fs2.Checked = False
fs3.Checked = False
fs4.Checked = True
fs9.Checked = False
fskip = 5
fmode = 0
SaveSetting "GBE", "GFX", "FS", fskip
SaveSetting "GBE", "GFX", "FM", fmode
End Sub
Private Sub fs9_Click()
fs0.Checked = False
fs6m1.Checked = False
fs5m1.Checked = False
fs4m1.Checked = False
fs3m1.Checked = False
fs1.Checked = False
fs2.Checked = False
fs3.Checked = False
fs4.Checked = False
fs9.Checked = True
fskip = 10
fmode = 0
SaveSetting "GBE", "GFX", "FS", fskip
SaveSetting "GBE", "GFX", "FM", fmode
End Sub
Private Sub fs6m1_Click()
fs0.Checked = False
fs6m1.Checked = True
fs5m1.Checked = False
fs4m1.Checked = False
fs3m1.Checked = False
fs1.Checked = False
fs2.Checked = False
fs3.Checked = False
fs4.Checked = False
fs9.Checked = False
fskip = 6
fmode = 1
SaveSetting "GBE", "GFX", "FS", fskip
SaveSetting "GBE", "GFX", "FM", fmode
End Sub
Private Sub fs5m1_Click()
fs0.Checked = False
fs6m1.Checked = False
fs5m1.Checked = True
fs4m1.Checked = False
fs3m1.Checked = False
fs1.Checked = False
fs2.Checked = False
fs3.Checked = False
fs4.Checked = False
fs9.Checked = False
fskip = 5
fmode = 1
SaveSetting "GBE", "GFX", "FS", fskip
SaveSetting "GBE", "GFX", "FM", fmode
End Sub
Private Sub fs4m1_Click()
fs0.Checked = False
fs6m1.Checked = False
fs5m1.Checked = False
fs4m1.Checked = True
fs3m1.Checked = False
fs1.Checked = False
fs2.Checked = False
fs3.Checked = False
fs4.Checked = False
fs9.Checked = False
fskip = 4
fmode = 1
SaveSetting "GBE", "GFX", "FS", fskip
SaveSetting "GBE", "GFX", "FM", fmode
End Sub
Private Sub fs3m1_Click()
fs0.Checked = False
fs6m1.Checked = False
fs5m1.Checked = False
fs4m1.Checked = False
fs3m1.Checked = True
fs1.Checked = False
fs2.Checked = False
fs3.Checked = False
fs4.Checked = False
fs9.Checked = False
fskip = 3
fmode = 1
SaveSetting "GBE", "GFX", "FS", fskip
SaveSetting "GBE", "GFX", "FM", fmode
End Sub
Private Sub lfps_Click()
lfp = Not lfp
lfps.Checked = lfp
SaveSetting "GBE", "CPU", "LFPS", lfp
End Sub


Private Sub mScale_Click()
 Scale2x = Not Scale2x
 mScale.Checked = Scale2x
End Sub

Private Sub mSound_Click()
 SoundEnabled = Not SoundEnabled
 mSound.Checked = SoundEnabled
End Sub

Private Sub Picture1_KeyDown(KeyCode As Integer, shift As Integer)
 Dim temp As Long, old As Long
    Select Case KeyCode
        Case 37  'Left
            joyval1 = joyval1 Or 2
        Case 38    'Up
            joyval1 = joyval1 Or 4
        Case 39    'Right
            joyval1 = joyval1 Or 1
        Case 40    'Down
            joyval1 = joyval1 Or 8
        Case 90     'Z - A Button
            joyval2 = joyval2 Or 1
        Case 88     'X - B button
            joyval2 = joyval2 Or 2
        Case 13  ' <Enter> - Start
            joyval2 = joyval2 Or 8
        Case 32    ' <Space> - Select
            joyval2 = joyval2 Or 4
        Case 66
        SrceenShot
    End Select
 If old <> joyval1 * 16 + joyval2 Then RAM(65295, 0) = RAM(65295, 0) Or 16  '65295 - FF0F에 해당
End Sub

Private Sub Picture1_KeyUp(KeyCode As Integer, shift As Integer)
 Dim temp As Long, old As Long
old = joyval1 * 16 + joyval2
    Select Case KeyCode
        Case 37  'Left
            joyval1 = joyval1 And 253
        Case 38    'Up
            joyval1 = joyval1 And 251
        Case 39   'Right
            joyval1 = joyval1 And 254
        Case 40   'Down
            joyval1 = joyval1 And 247
        Case 90    'Z - A Button
            joyval2 = joyval2 And 254
        Case 88     'X - B button
            joyval2 = joyval2 And 253
        Case 13  ' <Enter> - Start
            joyval2 = joyval2 And 247
        Case 32   ' <Space> - Select
            joyval2 = joyval2 And 251
    End Select
  If old <> joyval1 * 16 + joyval2 Then RAM(65295, 0) = RAM(65295, 0) Or 16
End Sub

Private Sub res_Click()
reset
End Sub

Private Sub rp_Click()
RunCpu2
End Sub

Private Sub sbg_Click()
bgv = Not bgv
sbg.Checked = bgv
End Sub

Private Sub sobj_Click()
  objv = Not objv
  sobj.Checked = objv
End Sub

Private Sub starte_Click()
Dim mt$, bol As Boolean, tls As String, i As Long
If loadrom Then
If mm = 2 Then
   zm = 4
   initGxMode2 Form1.Picture1, zm
Else
'initGxMode1 zm, full.Checked
End If
initCI
If TGBC Then
If ROM(&H143, 0) = 192 Then mt$ = "(GBC) ": GBM = 1 Else If ROM(&H143, 0) <> 0 Then mt$ = "(GB/GBC) ": GBM = 1 Else mt$ = "(GB) ": GBM = 0
Else
If ROM(&H143, 0) = 192 Then mt$ = "(GBC) " Else If ROM(&H143, 0) <> 0 Then mt$ = "(GB/GBC) " Else mt$ = "(GB) "
GBM = 0
End If
resize
reset
tls = ""
For i = 0 To 15
If mem.rominfo.titleB(i) = 0 Then GoTo tiend
tls = tls & Chr(mem.rominfo.titleB(i))
Next i
tiend:
rominfo.title = tls
If tls = "WORMS" Then nwr = False Else nwr = True
Form1.Caption = "BasicBoy - " & tls & " " & mt$
rdRam
rp_Click
End If
Err.Clear
End Sub

Function loadrom2()
Dim ROMBank  As Long, i As Long, mt$
loadrom2 = False
Dim tmp(16383) As Byte
On Error GoTo ext
Dim st As String

 'Open App.Path + "1942.gbc" For Binary As #1
 'Open "e:\emul\1942.gbc" For Binary As #1

'Open "d:\emul\pokemon.gb" For Binary As #1
Open "e:\emul\tetris.gb" For Binary As #1
'ReDim ROM(16383, (LOF(1) / 16384))
ROMBank = 0
While Not EOF(1)
    Get #1, , tmp
    For i = 0 To 16383
    ROM(i, ROMBank) = tmp(i)
    Next i
    ROMBank = ROMBank + 1
Wend
Close #1

''테트리스 롬을 텍스트로 바꾸어 저장함 2022.04.14
'Open "d:\emul\tetrisVB.txt" For Output As #1
'For i = 0 To 16383
' st = "ROM(" + Str(i) + ",0)=" + Str(ROM(i, 0))
' Write #1, st
'Next i

'For i = 0 To 16383
' st = "ROM(" + Str(i) + ",1)=" + Str(ROM(i, 1))
' Write #1, st
'Next i

'Close #1

loadrom2 = True
ext:
End Function


Function loadrom()
Dim ROMBank  As Long, i As Long, mt$
loadrom = False
Dim tmp(16383) As Byte
On Error GoTo ext
cd.CancelError = True
cd.Filter = "GameBoy Roms (*.gb;*.gbc)|*.gb;*.gbc"
cd.ShowOpen


 Open cd.Filename For Binary As #1
'ReDim ROM(16383, (LOF(1) / 16384))
ROMBank = 0
While Not EOF(1)
    Get #1, , tmp
    For i = 0 To 16383
    ROM(i, ROMBank) = tmp(i)
    Next i
    ROMBank = ROMBank + 1
Wend
Close #1
loadrom = True
ext:
End Function


'Public Sub KeyDown(KeyCode As Byte)
'Dim temp As Long, old As Long
'    Select Case KeyCode
'        Case 203  'Left
'            joyval1 = joyval1 Or 2
'        Case 200    'Up
'            joyval1 = joyval1 Or 4
'        Case 205    'Right
'            joyval1 = joyval1 Or 1
'        Case 208    'Down
'            joyval1 = joyval1 Or 8
'        Case 44     'Z - A Button
'            joyval2 = joyval2 Or 1
'        Case 45     'X - B button
'            joyval2 = joyval2 Or 2
'        Case 28, 42, 54  ' <Enter> - Start
'            joyval2 = joyval2 Or 8
'        Case 32, 2    ' <Space> - Select
'            joyval2 = joyval2 Or 4
'        Case 66
'        SrceenShot
'    End Select
'If old <> joyval1 * 16 + joyval2 Then RAM(65295, 0) = RAM(65295, 0) Or 16
'End Sub


'Public Sub KeyUp(KeyCode As Byte)
'Dim temp As Long, old As Long
'old = joyval1 * 16 + joyval2
'    Select Case KeyCode
'        Case 203  'Left
'            joyval1 = joyval1 And 253
'        Case 200    'Up
'            joyval1 = joyval1 And 251
'        Case 205   'Right
'            joyval1 = joyval1 And 254
'        Case 208   'Down
'            joyval1 = joyval1 And 247
'        Case 44    'Z - A Button
'            joyval2 = joyval2 And 254
'        Case 45     'X - B button
'            joyval2 = joyval2 And 253
'        Case 28, 42, 54  ' <Enter> - Start
'            joyval2 = joyval2 And 247
'        Case 32, 2   ' <Space> - Select
'            joyval2 = joyval2 And 251
'    End Select
'    If old <> joyval1 * 16 + joyval2 Then RAM(65295, 0) = RAM(65295, 0) Or 16
'End Sub


Private Sub swn_Click()
wv = Not wv
swn.Checked = wv
End Sub



Private Sub Timer1_Timer()
Dim mestr$, tmp As Single, tmp2 As Single
If fpsT = 0 Then fpsT = GetTickCount: Exit Sub
If bCpuRun Then mestr = "on" Else mestr = "off"
tmp = (GetTickCount - fpsT) / 1000
tmp = CLng(Grfx.FPS / tmp)
tmp2 = (GetTickCount - fpsT) / 1000
tmp2 = (Mhz * 70224 + Clcount) / tmp2
tmp2 = Format$(tmp2 / 1024 / 1024, "000.000")
'sb. .SimpleText = "Cpu Runs at " & tmp2 & " Mhz , Fps " & tmp & " (" & Format(tmp / 60, "00.0%") & ")"
sb.Caption = "Cpu Runs at " & tmp2 & " Mhz , Fps " & tmp & " (" & Format(tmp / 60, "00.0%") & ")"
Form1.Caption = "Cpu Runs at " & tmp2 & " Mhz , Fps " & tmp & " (" & Format(tmp / 60, "00.0%") & ")"

Grfx.FPS = 0
fpsT = GetTickCount
Mhz = 0
End Sub

Private Sub WA_Click()
WA.Checked = True

full.Visible = False
mm = 2
SaveSetting "GBE", "GFX", "MM", 1
If zm > 2 Then zm = 2: SaveSetting "GBE", "GFX", "ZM", 2: z2_Click
End Sub

Private Sub z1_Click()
z1.Checked = True
z2.Checked = False
z3.Checked = False
full.Checked = False
SaveSetting "GBE", "GFX", "ZM", 1
zm = 1
End Sub

Private Sub z2_Click()
z1.Checked = False
z2.Checked = True
z3.Checked = False
full.Checked = False
SaveSetting "GBE", "GFX", "ZM", 2
zm = 2
End Sub
Private Sub full_Click()
 z1.Checked = False
 z2.Checked = False
 z3.Checked = False
 full.Checked = True
 SaveSetting "GBE", "GFX", "ZM", 3
 zm = 3
End Sub

Private Sub z3_Click()
 z1.Checked = False
 z2.Checked = False
 z3.Checked = True
 full.Checked = False
 SaveSetting "GBE", "GFX", "ZM", 3
 zm = 3
End Sub


Private Sub z4_Click()
 z1.Checked = False
 z2.Checked = False
 z3.Checked = False
 z4.Checked = True
 full.Checked = False
 SaveSetting "GBE", "GFX", "ZM", 4
 zm = 4
 
End Sub
