VERSION 5.00
Begin VB.Form db 
   Caption         =   "Debug"
   ClientHeight    =   2700
   ClientLeft      =   60
   ClientTop       =   345
   ClientWidth     =   4755
   LinkTopic       =   "Form2"
   ScaleHeight     =   2700
   ScaleWidth      =   4755
   StartUpPosition =   3  'Windows 기본값
   Begin VB.Label Label5 
      BackStyle       =   0  '투명
      Caption         =   "Rom Size :"
      Height          =   255
      Left            =   120
      TabIndex        =   11
      Top             =   480
      Width           =   855
   End
   Begin VB.Label Ras 
      Height          =   495
      Left            =   1080
      TabIndex        =   21
      Top             =   1080
      Width           =   3255
   End
   Begin VB.Label Ros 
      Height          =   375
      Left            =   1080
      TabIndex        =   20
      Top             =   480
      Width           =   3135
   End
   Begin VB.Label iName 
      Height          =   495
      Left            =   1320
      TabIndex        =   19
      Top             =   1920
      Width           =   3255
   End
   Begin VB.Label Cart 
      Height          =   255
      Left            =   1080
      TabIndex        =   18
      Top             =   1680
      Width           =   3375
   End
   Begin VB.Label Label11 
      Caption         =   "Collor Gameboy Cartridge :"
      Height          =   495
      Left            =   120
      TabIndex        =   17
      Top             =   2160
      Width           =   1095
   End
   Begin VB.Label Label10 
      Caption         =   "Internal Name :"
      Height          =   255
      Left            =   120
      TabIndex        =   16
      Top             =   1920
      Width           =   1215
   End
   Begin VB.Label Label9 
      Caption         =   "Cart Type :"
      Height          =   255
      Left            =   120
      TabIndex        =   15
      Top             =   1680
      Width           =   855
   End
   Begin VB.Label Label8 
      Caption         =   "Ram Banks :"
      Height          =   255
      Left            =   120
      TabIndex        =   14
      Top             =   1245
      Width           =   975
   End
   Begin VB.Label Label7 
      BackStyle       =   0  '투명
      Caption         =   "Rom banks :"
      Height          =   255
      Left            =   120
      TabIndex        =   13
      Top             =   720
      Width           =   975
   End
   Begin VB.Label Label6 
      Caption         =   "Ram Size :"
      Height          =   255
      Left            =   120
      TabIndex        =   12
      Top             =   1080
      Width           =   855
   End
   Begin VB.Label Label4 
      Caption         =   "Rom Cart Info :"
      Height          =   255
      Left            =   1560
      TabIndex        =   10
      Top             =   240
      Width           =   2535
   End
   Begin VB.Label Label1 
      Caption         =   "E :"
      Height          =   255
      Index           =   7
      Left            =   4680
      TabIndex        =   9
      Top             =   6840
      Visible         =   0   'False
      Width           =   255
   End
   Begin VB.Label Label1 
      Caption         =   "F :"
      Height          =   255
      Index           =   6
      Left            =   4680
      TabIndex        =   8
      Top             =   7080
      Visible         =   0   'False
      Width           =   255
   End
   Begin VB.Label Label1 
      Caption         =   "H :"
      Height          =   255
      Index           =   5
      Left            =   4680
      TabIndex        =   7
      Top             =   7320
      Visible         =   0   'False
      Width           =   255
   End
   Begin VB.Label Label1 
      Caption         =   "L :"
      Height          =   255
      Index           =   4
      Left            =   4680
      TabIndex        =   6
      Top             =   7560
      Visible         =   0   'False
      Width           =   255
   End
   Begin VB.Label Label1 
      Caption         =   "SP :"
      Height          =   255
      Index           =   3
      Left            =   4680
      TabIndex        =   5
      Top             =   7800
      Visible         =   0   'False
      Width           =   375
   End
   Begin VB.Label Label1 
      Caption         =   "PC :"
      Height          =   255
      Index           =   2
      Left            =   4680
      TabIndex        =   4
      Top             =   8040
      Visible         =   0   'False
      Width           =   375
   End
   Begin VB.Label Label1 
      Caption         =   "D :"
      Height          =   255
      Index           =   1
      Left            =   4680
      TabIndex        =   3
      Top             =   6600
      Visible         =   0   'False
      Width           =   255
   End
   Begin VB.Label Label3 
      Caption         =   "B :"
      Height          =   255
      Left            =   4680
      TabIndex        =   2
      Top             =   6120
      Visible         =   0   'False
      Width           =   255
   End
   Begin VB.Label Label2 
      Caption         =   "C :"
      Height          =   255
      Left            =   4680
      TabIndex        =   1
      Top             =   6360
      Visible         =   0   'False
      Width           =   255
   End
   Begin VB.Label Label1 
      Caption         =   "A :"
      Height          =   255
      Index           =   0
      Left            =   4680
      TabIndex        =   0
      Top             =   5880
      Visible         =   0   'False
      Width           =   255
   End
End
Attribute VB_Name = "db"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Private Sub Form_Load()
'mem.initCI
Cart.Caption = mem.Ct(mem.rominfo.Ctype)
iName.Caption = mem.rominfo.title
Ros = mem.Ros(mem.rominfo.romsize) & vbNewLine & mem.Rosn(mem.rominfo.romsize)
Ras = mem.Ras(mem.rominfo.ramsize) & vbNewLine & mem.Rasn(mem.rominfo.ramsize)
End Sub
