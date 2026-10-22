VERSION 5.00
Begin VB.Form frmCheat 
   Caption         =   "Ram Cheats"
   ClientHeight    =   4035
   ClientLeft      =   60
   ClientTop       =   450
   ClientWidth     =   10275
   LinkTopic       =   "Form2"
   ScaleHeight     =   4035
   ScaleWidth      =   10275
   StartUpPosition =   3  'Windows ±âº»°ª
   Begin VB.CheckBox chkck 
      Caption         =   "Use cheats"
      Height          =   255
      Left            =   7680
      TabIndex        =   8
      Top             =   2160
      Width           =   2535
   End
   Begin VB.ListBox lsttm 
      Height          =   1680
      Left            =   120
      TabIndex        =   7
      Top             =   120
      Width           =   7215
   End
   Begin VB.ListBox lstAdr 
      Height          =   1680
      Left            =   120
      TabIndex        =   6
      Top             =   2040
      Width           =   7215
   End
   Begin VB.PictureBox cd 
      Height          =   480
      Left            =   9600
      ScaleHeight     =   420
      ScaleWidth      =   1140
      TabIndex        =   9
      Top             =   840
      Width           =   1200
   End
   Begin VB.CommandButton cmdLod 
      Caption         =   "Load List"
      Height          =   375
      Left            =   7680
      TabIndex        =   5
      Top             =   3480
      Width           =   1815
   End
   Begin VB.CommandButton cmdSav 
      Caption         =   "Save List"
      Height          =   375
      Left            =   7680
      TabIndex        =   4
      Top             =   3000
      Width           =   1815
   End
   Begin VB.CommandButton cmdNew 
      Caption         =   "Restart"
      Height          =   375
      Left            =   7680
      TabIndex        =   3
      Top             =   1680
      Width           =   1815
   End
   Begin VB.CommandButton cmdFind 
      Caption         =   "Find the value"
      Height          =   375
      Left            =   7680
      TabIndex        =   2
      Top             =   1200
      Width           =   1815
   End
   Begin VB.TextBox txtVal 
      Height          =   285
      Left            =   7680
      TabIndex        =   1
      Top             =   720
      Width           =   1815
   End
   Begin VB.ComboBox cmbsiz 
      Height          =   315
      Left            =   7680
      TabIndex        =   0
      Text            =   "Combo1"
      Top             =   240
      Width           =   1815
   End
End
Attribute VB_Name = "frmCheat"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Private Type cheat
Adr As Long
Siz As Byte
Val(3) As Byte
Frz As Boolean
rb As Long
End Type
Dim fs As Boolean
Dim cheats() As cheat
Dim tcheats() As cheat
Dim uch As Boolean

Private Sub chkck_Click()
uch = chkck.Value
End Sub

Private Sub cmdFind_Click()
Dim i As Long, csiz As Byte, wval(3) As Byte, ti As Long
On Error Resume Next
ReDim tcheats(99999)
csiz = cmbsiz.ListIndex
If csiz = 1 Then
wval(1) = txtVal.Text \ 256: wval(0) = txtVal.Text And 255
Else
wval(0) = txtVal.Text And 255
End If
If csiz = 0 Then
For rb = 0 To 7
For i = LBound(RAM) To UBound(RAM)
If RAM(i, rb) = wval(0) Then
tcheats(ti).Adr = i
tcheats(ti).Val(0) = RAM(i, 0)
tcheats(ti).Siz = czis
ti = ti + 1
End If
Next i
Next rb
ElseIf csiz = 1 Then
For rb = 0 To 7
For i = LBound(RAM) To UBound(RAM) Step 2
If RAM(i, rb) = wval(1) And RAM(i + 1, rb) = wval(0) Then
tcheats(ti).Adr = i
tcheats(ti).Val(0) = RAM(i, rb): tcheats(ti).Val(1) = RAM(i + 1, rb)
tcheats(ti).Siz = csiz
tcheats(ti).rb = rb
ti = ti + 1
End If
Next i
Next rb
End If
If ti = 0 Then ti = 1
ReDim Preserve tcheats(ti - 1)
UpdateList lsttm, tcheats
End Sub

Private Sub cmdLod_Click()
Dim tmp As Long
'cd.Filename = ""
'cd.DialogTitle = "Select a Cheat List to load"
'cd.Filter = "Cheat Files (*.clf)|*.clf"
'cd.ShowOpen
'If Len(cd.Filename) < 1 Then Exit Sub
'Open cd.Filename For Binary As #1
'Get #1, , tmp
'ReDim cheats(tmp)
'Get #1, , cheats
'Close #1
'UpdateList lstAdr, cheats
End Sub

Private Sub cmdNew_Click()
fs = True
lstAdr.Clear
End Sub

Private Sub cmdSav_Click()
'Dim tmp As Long
'cd.Filename = ""
'cd.DialogTitle = "Select a name to save the Cheat List"
'cd.Filter = "Cheat Files (*.clf)|*.clf"
'cd.ShowSave
'If Len(cd.Filename) < 1 Then Exit Sub
'Open cd.Filename For Binary As #1
'tmp = UBound(cheats)
'Put #1, , tmp
'Put #1, , cheats
'Close #1
End Sub

Private Sub Form_Load()
cmbsiz.ListIndex = 0
End Sub

Private Sub UpdateList(list As ListBox, cheats() As cheat)
Dim i As Long
list.Clear
For i = 0 To UBound(cheats)
If cheats(i).Siz = 0 Then list.AddItem cheats(i).Adr & "," & cheats(i).rb & " :" & cheats(i).Val(0), i Else list.AddItem cheats(i).Adr & "," & cheats(i).rb & ":" & CLng(cheats(i).Val(0)) * 256 + cheats(i).Val(1), i
list.Selected(i) = cheats(i).Frz
Next i
End Sub

Private Sub lstAdr_DblClick()
Dim tmp As Long
tmp = InputBox("Give a value")
If cheats(lstAdr.ListIndex).Siz = 2 Then
cheats(lstAdr.ListIndex).Val(0) = tmp \ 256: cheats(lstAdr.ListIndex).Val(1) = tmp And 255
Else
cheats(lstAdr.ListIndex).Val(0) = tmp And 255
End If
UpdateList lstAdr, cheats
End Sub

Private Sub lsttm_DblClick()
ReDim Preserve cheats(UBound(cheats) + 1)
cheats(UBound(cheats)) = tcheats(lsttm.SelCount)
UpdateList lstAdr, cheats
End Sub
Public Sub ChkCheats()
Dim i As Long
If uch Then
For i = 0 To UBound(cheats)
If cheats(i).Siz = 1 Then
RAM(cheats(i).Adr, cheats(i).rb) = cheats(i).Val(0)
RAM(cheats(i).Adr + 1, cheats(i).rb) = cheats(i).Val(1)
Else
RAM(cheats(i).Adr, cheats(i).rb) = cheats(i).Val(0)
End If
Next i
End If
End Sub
