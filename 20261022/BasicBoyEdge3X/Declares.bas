Attribute VB_Name = "Declares"
Option Explicit
Option Base 0

'Windows API constants
Public Const BITSPIXEL = 12
Public Const SYSTEM_FONT = 13
Public Const LR_LOADFROMFILE = &H10
Public Const CAPS1 = 94
Public Const C1_TRANSPARENT = &H1
Public Const NEWTRANSPARENT = 3
Public Const PM_NOREMOVE = &H0
Public Const PM_REMOVE = &H1
Public Const WM_QUIT = &H12

'Windows API structures
Public Type OSVERSIONINFO
    dwOSVersionInfoSize As Long
    dwMajorVersion As Long
    dwMinorVersion As Long
    dwBuildNumber As Long
    dwPlatformId As Long
    szCSDVersion As String * 128
End Type

Public Type BITMAPINFOHEADER
  biSize As Long
  biWidth As Long
  biHeight As Long
  biPlanes As Integer
  biBitCount As Integer
  biCompression As Long
  biSizeImage As Long
  biXPelsPerMeter As Long
  biYPelsPerMeter As Long
  biClrUsed As Long
  biClrImportant As Long
End Type

Public Type BITMAPINFO
  Header As BITMAPINFOHEADER
  bits() As Byte
End Type

Public Type BITMAP_STRUCT
    bmType As Long
    bmWidth As Long
    bmHeight As Long
    bmWidthBytes As Long
    bmPlanes As Integer
    bmBitsPixel As Integer
    bmBits As Long
End Type

Public Type RECT_API
    Left As Long
    Top As Long
    Right As Long
    Bottom As Long
End Type

Public Type point
    x As Long
    y As Long
End Type

Public Type MSG
    hWnd As Long
    message As Long
    wParam As Long
    lParam As Long
    time As Long
    point As point
End Type

Public Type RGBQUAD
    Blue As Byte
    Green As Byte
    Red As Byte
    alpha As Byte
End Type

'Windows API functions
Public Declare Function BitBlt _
    Lib "gdi32" ( _
    ByVal hDestDC As Long, _
    ByVal x As Long, _
    ByVal y As Long, _
    ByVal nWidth As Long, _
    ByVal nHeight As Long, _
    ByVal hSrcDC As Long, _
    ByVal xSrc As Long, _
    ByVal ySrc As Long, _
    ByVal dwRop As Long _
) As Long

Declare Function SetDIBitsToDevice _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    ByVal x As Long, _
    ByVal y As Long, _
    ByVal dx As Long, _
    ByVal dy As Long, _
    ByVal SrcX As Long, _
    ByVal SrcY As Long, _
    ByVal Scan As Long, _
    ByVal NumScans As Long, _
    lpBits As Any, _
    lpBI As BITMAPINFO, _
    ByVal wUsage As Long _
) As Long

Declare Function PeekMessage _
    Lib "user32" Alias "PeekMessageA" ( _
    lpMsg As MSG, _
    ByVal hWnd As Long, _
    ByVal wMsgFilterMin As Long, _
    ByVal wMsgFilterMax As Long, _
    ByVal wRemoveMsg As Long _
) As Long

Declare Function GetMessage _
    Lib "user32" Alias "GetMessageA" ( _
    lpMsg As MSG, ByVal hWnd As Long, _
    ByVal wMsgFilterMin As Long, _
    ByVal wMsgFilterMax As Long _
) As Long

Declare Function TranslateMessage _
    Lib "user32" ( _
    lpMsg As MSG _
) As Long

Declare Function DispatchMessage _
    Lib "user32" Alias "DispatchMessageA" ( _
    lpMsg As MSG _
) As Long

Public Declare Sub CopyMemory _
    Lib "kernel32" Alias "RtlMoveMemory" ( _
    lpvDest As Any, _
    lpvSource As Any, _
    ByVal cbCopy As Long _
)

Public Declare Function QueryPerformanceFrequency _
    Lib "kernel32" ( _
    lpFrequency As Currency _
) As Long

Public Declare Function QueryPerformanceCounter _
    Lib "kernel32" ( _
    lpPerformanceCount As Currency _
) As Long


Public Declare Function CreateCompatibleBitmap _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    ByVal nWidth As Long, _
    ByVal nHeight As Long _
) As Long

Public Declare Function CreateCompatibleDC _
    Lib "gdi32" ( _
    ByVal hdc As Long _
) As Long

Public Declare Function CreatePen _
    Lib "gdi32" ( _
    ByVal nPenStyle As Long, _
    ByVal nWidth As Long, _
    ByVal crColor As Long _
) As Long

Public Declare Function DeleteDC _
    Lib "gdi32" ( _
    ByVal hdc As Long _
) As Long

Public Declare Function DeleteObject _
    Lib "gdi32" ( _
    ByVal hObject As Long _
) As Long

Public Declare Function Ellipse _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    ByVal X1 As Long, _
    ByVal Y1 As Long, _
    ByVal X2 As Long, _
    ByVal Y2 As Long _
) As Long

Public Declare Function GetBitmapBits _
    Lib "gdi32" ( _
    ByVal hBitmap As Long, _
    ByVal dwCount As Long, _
    lpBits As Any _
) As Long

Public Declare Sub Sleep _
    Lib "kernel32" ( _
    ByVal dwMilliseconds As Long _
)

Public Declare Function GetClientRect _
    Lib "user32" ( _
    ByVal hWnd As Long, _
    lpRect As RECT_API _
) As Long

Public Declare Function GetDC _
    Lib "user32" ( _
    ByVal hWnd As Long _
) As Long

Public Declare Function GetDesktopWindow _
    Lib "user32" ( _
) As Long

Public Declare Function GetDeviceCaps _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    ByVal nIndex As Long _
) As Long

Public Declare Function GetObjectA _
    Lib "gdi32" ( _
    ByVal hObject As Long, _
    ByVal nCount As Long, _
    lpObject As Any _
) As Long

Public Declare Function GetObjectW _
    Lib "gdi32" ( _
    ByVal hObject As Long, _
    ByVal nCount As Long, _
    lpObject As Any _
) As Long

Public Declare Function GetStockObject _
    Lib "gdi32" ( _
    ByVal nIndex As Long _
) As Long

Public Declare Function GetPixel _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    ByVal x As Long, _
    ByVal y As Long _
) As Long

Public Declare Function GetTickCount _
    Lib "kernel32" ( _
) As Long

Public Declare Function GetVersionEx _
    Lib "kernel32" Alias "GetVersionExA" ( _
    lpVersionInformation As OSVERSIONINFO _
) As Long

Public Declare Function IntersectRect _
    Lib "user32" ( _
    lpDestRect As RECT_API, _
    lpSrc1Rect As RECT_API, _
    lpSrc2Rect As RECT_API _
) As Long

Public Declare Function LineTo _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    ByVal x As Long, _
    ByVal y As Long _
) As Long

Public Declare Function LoadImage _
    Lib "user32" Alias "LoadImageA" ( _
    ByVal hInst As Long, _
    ByVal Filename As String, _
    ByVal un1 As Long, _
    ByVal Width As Long, _
    ByVal Height As Long, _
    ByVal opmode As Long _
) As Long

Public Declare Function MoveTo _
    Lib "gdi32" Alias "MoveToEx" ( _
    ByVal hdc As Long, _
    ByVal x As Long, _
    ByVal y As Long, _
    lpPoint As point _
) As Long

Public Declare Function Polyline _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    lpPoint As point, _
    ByVal nCount As Long _
) As Long

Public Declare Function SelectObject _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    ByVal hObject As Long _
) As Long

Public Declare Function SetBkColor _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    ByVal crColor As Long _
) As Long

Public Declare Function SetBkMode _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    ByVal nBkMode As Long _
) As Long

Public Declare Function SetBitmapBits _
    Lib "gdi32" ( _
    ByVal hBitmap As Long, _
    ByVal dwCount As Long, _
    lpBits As Any _
) As Long

Public Declare Function SetPixel _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    ByVal x As Long, _
    ByVal y As Long, _
    ByVal crColor As Long _
) As Long

Public Declare Function SetTextColor _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    ByVal crColor As Long _
) As Long

Public Declare Function TextOutA _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    ByVal x As Long, _
    ByVal y As Long, _
    ByVal lpString As String, _
    ByVal nCount As Long _
) As Long

Public Declare Function TextOutW _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    ByVal x As Long, _
    ByVal y As Long, _
    ByVal lpString As String, _
    ByVal nCount As Long _
) As Long

Public Declare Function ValidateRect _
    Lib "user32" ( _
    ByVal hWnd As Long, _
    lpRect As RECT_API _
) As Long


Public Declare Function GetDIBits _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    ByVal hBitmap As Long, _
    ByVal nStartScan As Long, _
    ByVal nNumScans As Long, _
    lpBits As Any, _
    lpBI As BITMAPINFO, _
    ByVal wUsage As Long _
) As Long

Public Declare Function SetDIBits _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    ByVal hBitmap As Long, _
    ByVal nStartScan As Long, _
    ByVal nNumScans As Long, _
    lpBits As Any, _
    lpBI As BITMAPINFO, _
    ByVal wUsage As Long _
) As Long

Public Declare Function StretchDIBits _
    Lib "gdi32" ( _
    ByVal hdc As Long, _
    ByVal x As Long, _
    ByVal y As Long, _
    ByVal dx As Long, _
    ByVal dy As Long, _
    ByVal SrcX As Long, _
    ByVal SrcY As Long, _
    ByVal wSrcWidth As Long, _
    ByVal wSrcHeight As Long, _
    lpBits As Any, _
    lpBitsInfo As BITMAPINFO, _
    ByVal wUsage As Long, _
    ByVal dwRop As Long _
) As Long

Public Declare Function SetBrushOrgEx Lib "gdi32" (ByVal hdc As Long, ByVal nXOrg As Long, ByVal nYOrg As Long, lppt As Any) As Long

Public Declare Function SetStretchBltMode Lib "gdi32" (ByVal hdc As Long, ByVal nStretchMode As Long) As Long
