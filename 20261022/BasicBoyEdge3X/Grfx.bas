Attribute VB_Name = "Grfx"
'This is a part of tha BasicBoy emulator
'You are not allowed to release modified(or unmodified) versions
'without asking me (Raziel).
'For Suggestions ect please e-mail at :stef_mp@yahoo.gr
'(I know the emulator is NOT OPTIMIZED AT ALL)

'Graphic Engine
'Currenlty a bit optimized
'Color Gameboy Part is 95% finished
'Coments will be added with the next release

'Sory for my bad english ...

Option Base 0
Option Explicit

Public FPS As Long, fpsT As Long
Dim colid(128, 128) As Long
Dim colidx(128, 128) As Byte
Dim colid2(2, 128, 128) As Long
'Public DDraw As clsDirectDraw7
'Public scrb As clsDDSurface7
'Dim re2 As DxVBLib.RECT
Public FULLSCREEN As Boolean
Dim TCol As Long, mode1 As Boolean
Dim i As Long, i2 As Long, x As Long, y As Long, tilemap As Long, tileloc As Long, tileptr As Long
Dim xoffset As Long, yoffset As Long, tileData As Long, tileend As Long
Dim LByte As Long, HByte As Long, SpriteY As Long
Dim dy As Long, dx As Long, spat As Long
Dim tmp1 As Long, tmp2 As Long, memptr As Long, tmp3 As Long, rx As Long, ry As Long, lolm As Long, tms As Long
Global bb As BITMAPINFO, desthdc As Long, destW As Long, destH As Long, desthimg As Long
Global Vram(0 To 159, 0 To 143) As Integer, mir(255) As Byte, mv1 As Byte, mv2 As Byte, vf As Boolean, cid2 As Long, tiletmp As Long, xs As Long, ys As Long, xt As Long
Global tobj As Long, thdc As Long, dh As Long, dw As Long, xr As Long, yr As Long
Global fskip As Long, fmode As Long, objp(7, 3) As Integer, bgp(7, 3) As Integer
Global vrm As Long, ccp As Long, ccid(128, 128) As Long, tm2 As Long, tm1 As Long, bgat As Byte, gbcP(32767) As Integer
Global wv As Boolean, bgv As Boolean, objv As Boolean, xflip As Long, yflip As Long, lastline As Long
Global curline As Long, tcls(19) As Integer, curFreq As Currency, curStart As Currency, CurEnd As Currency, dblResult As Double
Global Skipf As Boolean

Public Const HALFTONE As Long = 4
Public Const COLORONCOLOR As Long = 3



' 2¹è È®´ë¿ë ºñÆ®¸Ê Çì´õ ¹× 320x288 ¹öÆÛ
Global bb2x As BITMAPINFO
Global Vram2x(0 To 319, 0 To 287) As Integer
Global Scale2x As Boolean

' 160x144 ÀÇ 3¹è ÇØ»óµµ = 480x432
Global Vram3x() As Integer
Global bb3x As BITMAPINFO

Public Sub InitScale3xHeader()
    ReDim Vram3x(0 To 479, 0 To 431)
    
    bb3x.Header.biSize = 40
    bb3x.Header.biWidth = 480
    bb3x.Header.biHeight = -432  ' Top-Down (À½¼ö)
    bb3x.Header.biPlanes = 1
    bb3x.Header.biBitCount = 16  ' RGB555 ÄÃ·¯
    bb3x.Header.biCompression = 0
End Sub

Public Sub InitScale2xHeader()
    With bb2x.Header
        .biSize = Len(bb2x.Header)
        .biWidth = 320
        ' Top-Down DIB ¹æ½ÄÀ¸·Î »óÇÏ ¹ÝÀüÀ» ¹æÁöÇÏ·Á¸é À½¼ö(-288)¸¦ ÁöÁ¤ÇÕ´Ï´Ù.
        ' ±âÁ¸ bb ±¸Á¶Ã¼ÀÇ biHeight°¡ À½¼ö¶ó¸é -288, ¾ç¼ö¶ó¸é 288·Î ¸ÂÃçÁÝ´Ï´Ù.
        .biHeight = -288
        .biPlanes = 1
        .biBitCount = 16            ' 16-bit RGB
        .biCompression = 0          ' BI_RGB
        .biSizeImage = 320& * 288& * 4&
    End With
    Scale2x = True
End Sub

Public Sub ApplyEdge3x()
    Dim x As Long, y As Long
    Dim dx As Long, dy As Long
    
    Dim c As Long, b As Long
    Dim pLeft As Long, pRight As Long, pUp As Long, pDown As Long
    Dim pUL As Long, pUR As Long, pDL As Long, pDR As Long
    
    Dim e0 As Long, e1 As Long, e2 As Long
    Dim e3 As Long, e4 As Long, e5 As Long
    Dim e6 As Long, e7 As Long, e8 As Long
    
    Const MASK555 As Long = &H7BDE&
    
    ' °æ°è Á¦¿Ü ³»ºÎ ¿µ¿ª °í¼Ó ¼øÈ¸ (1 To 142, 1 To 158)
    For y = 1 To 142
        dy = y * 3
        For x = 1 To 158
            dx = x * 3
            
            c = Vram(x, y)
            pUp = Vram(x, y - 1)
            pDown = Vram(x, y + 1)
            pLeft = Vram(x - 1, y)
            pRight = Vram(x + 1, y)
            
            ' Fast-Path: ÆòÅºÇÑ ´Ü»ö ¿µ¿ªÀº ºí·»µù »ý·« (¼º´É ¹æ¾î)
            If (c = pUp) And (c = pDown) And (c = pLeft) And (c = pRight) Then
                Vram3x(dx, dy) = c:     Vram3x(dx + 1, dy) = c:     Vram3x(dx + 2, dy) = c
                Vram3x(dx, dy + 1) = c: Vram3x(dx + 1, dy + 1) = c: Vram3x(dx + 2, dy + 1) = c
                Vram3x(dx, dy + 2) = c: Vram3x(dx + 1, dy + 2) = c: Vram3x(dx + 2, dy + 2) = c
            Else
                ' ´ë°¢¼± 4°³ ÇÈ¼¿ ·Îµå
                pUL = Vram(x - 1, y - 1)
                pUR = Vram(x + 1, y - 1)
                pDL = Vram(x - 1, y + 1)
                pDR = Vram(x + 1, y + 1)
                
                ' Áß½É ÇÈ¼¿ 50% °¨¼â ¼ººÐ
                b = (c And MASK555) \ 2
                
                ' 9°³ ¼­ºêÇÈ¼¿ ±âº»°ª: ¿øº» »ö»ó
                e0 = c: e1 = c: e2 = c
                e3 = c: e4 = c: e5 = c
                e6 = c: e7 = c: e8 = c
                
                ' ===================================================
                ' ÄÚ³Ê 1: ÁÂ»ó´Ü (Top-Left) ¿¡Áö ÆÇÁ¤
                ' ===================================================
                If (pLeft = pUp) And (pLeft <> pDown) And (pUp <> pRight) Then
                    e0 = ((pLeft And MASK555) \ 2) + b
                    If pUL <> c Then
                        e1 = ((pUp And MASK555) \ 2) + b
                        e3 = ((pLeft And MASK555) \ 2) + b
                    End If
                End If
                
                ' ===================================================
                ' ÄÚ³Ê 2: ¿ì»ó´Ü (Top-Right) ¿¡Áö ÆÇÁ¤
                ' ===================================================
                If (pRight = pUp) And (pRight <> pDown) And (pUp <> pLeft) Then
                    e2 = ((pRight And MASK555) \ 2) + b
                    If pUR <> c Then
                        e1 = ((pUp And MASK555) \ 2) + b
                        e5 = ((pRight And MASK555) \ 2) + b
                    End If
                End If
                
                ' ===================================================
                ' ÄÚ³Ê 3: ÁÂÇÏ´Ü (Bottom-Left) ¿¡Áö ÆÇÁ¤
                ' ===================================================
                If (pLeft = pDown) And (pLeft <> pUp) And (pDown <> pRight) Then
                    e6 = ((pLeft And MASK555) \ 2) + b
                    If pDL <> c Then
                        e3 = ((pLeft And MASK555) \ 2) + b
                        e7 = ((pDown And MASK555) \ 2) + b
                    End If
                End If
                
                ' ===================================================
                ' ÄÚ³Ê 4: ¿ìÇÏ´Ü (Bottom-Right) ¿¡Áö ÆÇÁ¤
                ' ===================================================
                If (pRight = pDown) And (pRight <> pUp) And (pDown <> pLeft) Then
                    e8 = ((pRight And MASK555) \ 2) + b
                    If pDR <> c Then
                        e5 = ((pRight And MASK555) \ 2) + b
                        e7 = ((pDown And MASK555) \ 2) + b
                    End If
                End If
                
                ' 3x3 ¼­ºêÇÈ¼¿ ¹öÆÛ¿¡ ±â·Ï
                Vram3x(dx, dy) = e0
                Vram3x(dx + 1, dy) = e1
                Vram3x(dx + 2, dy) = e2
                
                Vram3x(dx, dy + 1) = e3
                Vram3x(dx + 1, dy + 1) = e4
                Vram3x(dx + 2, dy + 1) = e5
                
                Vram3x(dx, dy + 2) = e6
                Vram3x(dx + 1, dy + 2) = e7
                Vram3x(dx + 2, dy + 2) = e8
            End If
        Next x
    Next y
    
    ' ¿Ü°û 1ÇÈ¼¿ ´Ü¼ø º¹Á¦ Ã³¸®
    Call ProcessEdge3xBorders
End Sub

Public Sub ApplyEdge3x_Masked()
    Dim x As Long, y As Long
    Dim dx As Long, dy As Long
    
    Dim c As Long
    Dim pLeft As Long, pRight As Long, pUp As Long, pDown As Long
    Dim pUL As Long, pUR As Long, pDL As Long, pDR As Long
    
    Dim e0 As Long, e1 As Long, e2 As Long
    Dim e3 As Long, e4 As Long, e5 As Long
    Dim e6 As Long, e7 As Long, e8 As Long
    
    Dim bHalf As Long, bEdge As Long
    Const MASK555 As Long = &H7BDE&
    
    ' ³»ºÎ °í¼Ó ¼øÈ¸ (1 To 142, 1 To 158)
    For y = 1 To 142
        dy = y * 3
        For x = 1 To 158
            dx = x * 3
            
            c = Vram(x, y)
            pUp = Vram(x, y - 1)
            pDown = Vram(x, y + 1)
            pLeft = Vram(x - 1, y)
            pRight = Vram(x + 1, y)
            
            ' Fast-path: ÁÖº¯ 4¹æÇâÀÌ ¸ðµÎ °°À¸¸é ¿¬»ê ½ºÅµ
            If (c = pUp) And (c = pDown) And (c = pLeft) And (c = pRight) Then
                Vram3x(dx, dy) = c:     Vram3x(dx + 1, dy) = c:     Vram3x(dx + 2, dy) = c
                Vram3x(dx, dy + 1) = c: Vram3x(dx + 1, dy + 1) = c: Vram3x(dx + 2, dy + 1) = c
                Vram3x(dx, dy + 2) = c: Vram3x(dx + 1, dy + 2) = c: Vram3x(dx + 2, dy + 2) = c
            Else
                pUL = Vram(x - 1, y - 1)
                pUR = Vram(x + 1, y - 1)
                pDL = Vram(x - 1, y + 1)
                pDR = Vram(x + 1, y + 1)
                
                ' ±âº» 9°³ ¼­ºêÇÈ¼¿ ÃÊ±âÈ­
                e0 = c: e1 = c: e2 = c
                e3 = c: e4 = c: e5 = c
                e6 = c: e7 = c: e8 = c
                
                ' ----------------------------------------------------
                ' ÄÚ³Ê 1: ÁÂ»ó´Ü (Top-Left) ¿¡Áö ºí·»µù
                ' ----------------------------------------------------
                If (pLeft = pUp) And (pLeft <> pDown) And (pUp <> pRight) Then
                    ' pLeft¿Í Áß½É c¸¦ 50:50 ºñÆ®¸¶½ºÅ© ºí·»µù
                    bHalf = ((pLeft And MASK555) \ 2) + ((c And MASK555) \ 2)
                    e0 = bHalf
                    
                    If pUL <> c Then
                        ' ¿¡Áö ³¯°³ ¿µ¿ªÀº 75:25·Î ´õ ºÎµå·´°Ô °¨¼â
                        bEdge = ((bHalf And MASK555) \ 2) + ((c And MASK555) \ 2)
                        e1 = bEdge
                        e3 = bEdge
                    End If
                End If
                
                ' ----------------------------------------------------
                ' ÄÚ³Ê 2: ¿ì»ó´Ü (Top-Right) ¿¡Áö ºí·»µù
                ' ----------------------------------------------------
                If (pRight = pUp) And (pRight <> pDown) And (pUp <> pLeft) Then
                    bHalf = ((pRight And MASK555) \ 2) + ((c And MASK555) \ 2)
                    e2 = bHalf
                    
                    If pUR <> c Then
                        bEdge = ((bHalf And MASK555) \ 2) + ((c And MASK555) \ 2)
                        e1 = bEdge
                        e5 = bEdge
                    End If
                End If
                
                ' ----------------------------------------------------
                ' ÄÚ³Ê 3: ÁÂÇÏ´Ü (Bottom-Left) ¿¡Áö ºí·»µù
                ' ----------------------------------------------------
                If (pLeft = pDown) And (pLeft <> pUp) And (pDown <> pRight) Then
                    bHalf = ((pLeft And MASK555) \ 2) + ((c And MASK555) \ 2)
                    e6 = bHalf
                    
                    If pDL <> c Then
                        bEdge = ((bHalf And MASK555) \ 2) + ((c And MASK555) \ 2)
                        e3 = bEdge
                        e7 = bEdge
                    End If
                End If
                
                ' ----------------------------------------------------
                ' ÄÚ³Ê 4: ¿ìÇÏ´Ü (Bottom-Right) ¿¡Áö ºí·»µù
                ' ----------------------------------------------------
                If (pRight = pDown) And (pRight <> pUp) And (pDown <> pLeft) Then
                    bHalf = ((pRight And MASK555) \ 2) + ((c And MASK555) \ 2)
                    e8 = bHalf
                    
                    If pDR <> c Then
                        bEdge = ((bHalf And MASK555) \ 2) + ((c And MASK555) \ 2)
                        e5 = bEdge
                        e7 = bEdge
                    End If
                End If
                
                ' 3x3 ¹öÆÛ¿¡ ±â·Ï
                Vram3x(dx, dy) = e0
                Vram3x(dx + 1, dy) = e1
                Vram3x(dx + 2, dy) = e2
                
                Vram3x(dx, dy + 1) = e3
                Vram3x(dx + 1, dy + 1) = e4
                Vram3x(dx + 2, dy + 1) = e5
                
                Vram3x(dx, dy + 2) = e6
                Vram3x(dx + 1, dy + 2) = e7
                Vram3x(dx + 2, dy + 2) = e8
            End If
        Next x
    Next y
    
    Call ProcessEdge3xBorders
End Sub

Private Sub ProcessEdge3xBorders()
    Dim x As Long, y As Long
    Dim dx As Long, dy As Long
    Dim p As Long, i As Long, j As Long
    
    ' »ó´Ü(y=0), ÇÏ´Ü(y=143)
    For x = 0 To 159
        dx = x * 3
        p = Vram(x, 0)
        For j = 0 To 2
            For i = 0 To 2: Vram3x(dx + i, j) = p: Next i
        Next j
        
        p = Vram(x, 143)
        For j = 429 To 431
            For i = 0 To 2: Vram3x(dx + i, j) = p: Next i
        Next j
    Next x
    
    ' ÁÂÃø(x=0), ¿ìÃø(x=159)
    For y = 1 To 142
        dy = y * 3
        p = Vram(0, y)
        For j = 0 To 2
            For i = 0 To 2: Vram3x(i, dy + j) = p: Next i
        Next j
        
        p = Vram(159, y)
        For j = 0 To 2
            For i = 477 To 479: Vram3x(i, dy + j) = p: Next i
        Next j
    Next y
End Sub

Public Sub ApplyScale2x()
    Dim x As Long, y As Long
    Dim p As Long, a As Long, b As Long, c As Long, d As Long
    Dim p1 As Long, p2 As Long, p3 As Long, p4 As Long
    Dim dx As Long, dy As Long

    For y = 0 To 143
        dy = y * 2
        For x = 0 To 159
            dx = x * 2
            p = Vram(x, y)

            ' °æ°è °Ë»ç: »ó(A), ¿ì(B), ÇÏ(C), ÁÂ(D)
            If y > 0 Then a = Vram(x, y - 1) Else a = p
            If x < 159 Then b = Vram(x + 1, y) Else b = p
            If y < 143 Then c = Vram(x, y + 1) Else c = p
            If x > 0 Then d = Vram(x - 1, y) Else d = p

            ' EPX/Scale2x ±ÔÄ¢ ÆÇÁ¤
            If (d = a) And (c <> a) And (d <> b) Then p1 = a Else p1 = p
            If (a = b) And (a <> c) And (b <> d) Then p2 = b Else p2 = p
            If (d = c) And (d <> a) And (c <> b) Then p3 = c Else p3 = p
            If (b = c) And (b <> a) And (c <> d) Then p4 = c Else p4 = p

            ' 2x2 ¼­ºêÇÈ¼¿ ±â·Ï
            Vram2x(dx, dy) = p1
            Vram2x(dx + 1, dy) = p2
            Vram2x(dx, dy + 1) = p3
            Vram2x(dx + 1, dy + 1) = p4
        Next x
    Next y
End Sub
'''''''''''''''''''
Public Sub ApplyEdge2x()
    Dim x As Long, y As Long
    Dim dx As Long, dy As Long
    
    Dim c As Long, b As Long
    Dim p01b As Long, p21b As Long, p10b As Long, p12b As Long
    Dim pCorner As Long
    
    ' RGB555 50:50 ºí·»µù Àü¿ë ¸¶½ºÅ© (Ã¤³Î Ä§¹ü ¹æÁö)
    Const MASK555 As Long = &H7BDE&
    
    ' °æ°è(¿Ü°û 1ÇÈ¼¿)¸¦ Á¦¿ÜÇÑ 1 To 142, 1 To 158 ³»ºÎ ¼øÈ¸
    For y = 1 To 142
        dy = y * 2
        For x = 1 To 158
            dx = x * 2
            
            ' Áß½É ¹× 4¹æÇâ ÇÈ¼¿ ·Îµå (RGB555)
            c = Vram(x, y)
            p01b = Vram(x - 1, y)   ' ÁÂ
            p21b = Vram(x + 1, y)   ' ¿ì
            p10b = Vram(x, y - 1)   ' »ó
            p12b = Vram(x, y + 1)   ' ÇÏ
            
            ' 1. Fast-Path: ÁÖº¯ 4¹æÇâ »ö»óÀÌ Áß½É°ú ¸ðµÎ °°À¸¸é ºí·»µù »ý·«
            If (c = p01b) And (c = p21b) And (c = p10b) And (c = p12b) Then
                Vram2x(dx, dy) = c
                Vram2x(dx + 1, dy) = c
                Vram2x(dx, dy + 1) = c
                Vram2x(dx + 1, dy + 1) = c
            Else
                ' Áß½É ÇÈ¼¿ 50% °¨¼â (RGB555 Àü¿ë)
                b = (c And MASK555) \ 2
                
                ' ÆÐÅÏ 1: ´ë°¢¼± ¿¡Áö °¨Áö
                If p01b = p10b And p12b = p21b Then
                    pCorner = Vram(x - 1, y - 1)
                    
                    If p10b = p12b And pCorner = c Then
                        Vram2x(dx, dy) = c
                        Vram2x(dx + 1, dy) = ((p10b And MASK555) \ 2) + b
                        Vram2x(dx, dy + 1) = ((p12b And MASK555) \ 2) + b
                        Vram2x(dx + 1, dy + 1) = c
                    Else
                        Vram2x(dx, dy) = ((p01b And MASK555) \ 2) + b
                        Vram2x(dx + 1, dy) = c
                        Vram2x(dx, dy + 1) = c
                        Vram2x(dx + 1, dy + 1) = ((p21b And MASK555) \ 2) + b
                    End If
                    
                ' ÆÐÅÏ 2: ¹Ý´ë ´ë°¢¼± ¿¡Áö °¨Áö
                ElseIf p10b = p21b And p01b = p12b Then
                    Vram2x(dx, dy) = c
                    Vram2x(dx + 1, dy) = ((p10b And MASK555) \ 2) + b
                    Vram2x(dx, dy + 1) = ((p12b And MASK555) \ 2) + b
                    Vram2x(dx + 1, dy + 1) = c
                    
                ' ÀÏ¹Ý ÆòÅº¸é º¹Á¦
                Else
                    Vram2x(dx, dy) = c
                    Vram2x(dx + 1, dy) = c
                    Vram2x(dx, dy + 1) = c
                    Vram2x(dx + 1, dy + 1) = c
                End If
            End If
        Next x
    Next y
    
    Call ProcessEdge2xBorders
End Sub

' °¡ÀåÀÚ¸® Å×µÎ¸® 1ÇÈ¼¿ º¹Á¦ Ã³¸® ·çÆ¾
Private Sub ProcessEdge2xBorders()
    Dim x As Long, y As Long
    Dim dx As Long, dy As Long
    Dim p As Long
    
    ' »ó´Ü(y=0) ¹× ÇÏ´Ü(y=143)
    For x = 0 To 159
        dx = x * 2
        ' »ó´Ü Çà
        p = Vram(x, 0)
        Vram2x(dx, 0) = p: Vram2x(dx + 1, 0) = p
        Vram2x(dx, 1) = p: Vram2x(dx + 1, 1) = p
        
        ' ÇÏ´Ü Çà
        p = Vram(x, 143)
        Vram2x(dx, 286) = p: Vram2x(dx + 1, 286) = p
        Vram2x(dx, 287) = p: Vram2x(dx + 1, 287) = p
    Next x
    
    ' ÁÂÃø(x=0) ¹× ¿ìÃø(x=159)
    For y = 1 To 142
        dy = y * 2
        ' ÁÂÃø ¿­
        p = Vram(0, y)
        Vram2x(0, dy) = p: Vram2x(1, dy) = p
        Vram2x(0, dy + 1) = p: Vram2x(1, dy + 1) = p
        
        ' ¿ìÃø ¿­
        p = Vram(159, y)
        Vram2x(318, dy) = p: Vram2x(319, dy) = p
        Vram2x(318, dy + 1) = p: Vram2x(319, dy + 1) = p
    Next y
End Sub

'''''''''''''''''''
Public Sub DrawScreen() 'Using Api and SetBits/StrechBits
    FPS = FPS + 1
    
    If fmode = 0 Then 'frame skip mode 1(act skip(x1(1),x2(2),x3(3),x4(4),x5(5),x6(6))
    If FPS Mod fskip > 0 Then
    Skipf = True
    If lfp Then
    Do
    QueryPerformanceCounter CurEnd
    dblResult = (CurEnd - curStart) / curFreq
    Loop While dblResult < 16.6
    End If
    Exit Sub
    End If
    Else 'frame skip mode 2(act skip(x1.20(6),x1.25(5),x1,3(4),x1.5(3))
    If FPS Mod fskip = 0 Then
    Skipf = True
    If lfp Then
    Do
    QueryPerformanceCounter CurEnd
    dblResult = (CurEnd - curStart) / curFreq
    Loop While dblResult < 16.6
    End If
    Exit Sub
    End If
    End If
    
  If Scale2x Then
    
    'Call ApplyEdge2x
    '320x288 Å©±âÀÇ Vram2x ¹öÆÛ ¼ÛÃâ
    'Call StretchDIBits(desthdc, 0, 0, dw, dh, 0, 0, 320, 288, Vram2x(0, 0), bb2x, 0, vbSrcCopy)
    
    Call ApplyEdge3x_Masked
    ' 480x432 ÇØ»óµµ·Î StretchDIBits È£Ãâ
    Call StretchDIBits(desthdc, 0, 0, dw, dh, 0, 0, 480, 432, Vram3x(0, 0), bb3x, 0, vbSrcCopy)
    
  Else
    StretchDIBits desthdc, 0, 0, dw, dh, 0, 0, 160, 144, Vram(0, 0), bb, 0, vbSrcCopy
  End If
  
    Form1.Picture1.Refresh
 
     Skipf = False
    If lfp Then
      Do
        QueryPerformanceCounter CurEnd
        dblResult = (CurEnd - curStart) / curFreq
      Loop While dblResult < 16.6
    End If
End Sub
   

Sub ccolid2(col As Byte, target As Long)
    Dim tm1 As Long, tm2 As Long
    Dim idx1 As Long, idx2 As Long

    ' 1. (col And 2, col And 1) -> (0~1, 0~1) ì •ê·œí™”
    idx1 = (col And 2) \ 2
    idx2 = col And 1
    colid2(target, 0, 0) = colid(idx1, idx2)

    ' 2. (col And 8, col And 4) -> (0~1, 0~1) ì •ê·œí™”
    idx1 = (col And 8) \ 8
    idx2 = (col And 4) \ 4
    
    tm2 = 1
    Do While tm2 <= 128
        colid2(target, 0, tm2) = colid(idx1, idx2)
        tm2 = tm2 * 2
    Loop

    ' 3. (col And 32, col And 16) -> (0~1, 0~1) ì •ê·œí™”
    idx1 = (col And 32) \ 32
    idx2 = (col And 16) \ 16
    
    tm1 = 1
    Do While tm1 <= 128
        colid2(target, tm1, 0) = colid(idx1, idx2)
        tm1 = tm1 * 2
    Loop

    ' 4. (col And 128, col And 64) -> (0~1, 0~1) ì •ê·œí™”
    idx1 = (col And 128) \ 128
    idx2 = (col And 64) \ 64
    
    tm1 = 1
    Do While tm1 <= 128
        tm2 = 1
        Do While tm2 <= 128
            colid2(target, tm1, tm2) = colid(idx1, idx2)
            tm2 = tm2 * 2
        Loop
        tm1 = tm1 * 2
    Loop
End Sub


Sub initGxMode2(dest As PictureBox, Siz As Long)
mode1 = False
Form1.Picture1.AutoRedraw = True
Form1.Picture1.BorderStyle = 0
Form1.Picture1.ClipControls = False
Form1.Picture1.ScaleMode = 3
Form1.Picture1.BackColor = RGB(256, 256, 256)
Form1.Picture1.Width = 15 * 160 * Siz
Form1.Picture1.Height = 15 * 144 * Siz
Form1.Picture1.Visible = True
With bb.Header
    .biSize = 40
    .biWidth = 160
    .biHeight = -144
    .biPlanes = 1
    .biBitCount = 16
    .biSizeImage = 46080
End With
destW = dest.ScaleWidth
destH = dest.ScaleHeight
desthdc = dest.hdc
desthimg = dest.Image.Handle
initCol
dh = 144 * Siz
dw = 160 * Siz
End Sub

Sub initCol()
For i = 0 To 32767
gbcP(i) = (i And 31744) \ 32 \ 32 + (i And 992) + (i And 31) * 32 * 32
'bgr rgb
Next i
    initMir
    Dim tm2 As Long, tm1 As Long
    If TGBC Then
    colid(0, 0) = rgb15(31, 31, 31)
    For tm2 = 1 To 128
    colid(0, tm2) = rgb15(21, 21, 21)
    Next tm2
    
    For tm1 = 1 To 128
    colid(tm1, 0) = rgb15(10, 10, 10)
    Next tm1
    
    For tm1 = 1 To 128
    For tm2 = 1 To 128
    colid(tm1, tm2) = rgb15(0, 0, 0)
    Next tm2
    Next tm1
    Else
    colid(0, 0) = rgb15(31, 31, 31)
    For tm2 = 1 To 128
    colid(0, tm2) = rgb15(21, 21, 21)
    Next tm2
    
    For tm1 = 1 To 128
    colid(tm1, 0) = rgb15(10, 10, 10)
    Next tm1
    
    For tm1 = 1 To 128
    For tm2 = 1 To 128
    colid(tm1, tm2) = rgb15(0, 0, 0)
    Next tm2
    Next tm1
    End If
    colidx(0, 0) = 0
    
    For tm2 = 1 To 128
    colidx(0, tm2) = 2
    Next tm2
    
    For tm1 = 1 To 128
    colidx(tm1, 0) = 1
    Next tm1
    
    For tm1 = 1 To 128
    For tm2 = 1 To 128
    colidx(tm1, tm2) = 3
    Next tm2
    Next tm1
    
    colid2(0, 0, 0) = colid(0, 0)
    For tm2 = 1 To 128
    colid2(0, 0, tm2) = colid(0, 1)
    Next tm2
    For tm1 = 1 To 128
    colid2(0, tm1, 0) = colid(1, 0)
    Next tm1
    For tm1 = 1 To 128
    For tm2 = 1 To 128
    colid2(0, tm1, tm2) = colid(1, 1)
    Next tm2
    Next tm1
    colid2(1, 0, 0) = colid(0, 0)
    For tm2 = 1 To 128
    colid2(1, 0, tm2) = colid(0, 1)
    Next tm2: For tm1 = 1 To 128
    colid2(1, tm1, 0) = colid(1, 0)
    Next tm1: For tm1 = 1 To 128
    For tm2 = 1 To 128
    colid2(1, tm1, tm2) = colid(1, 1)
    Next tm2
    Next tm1
    colid2(2, 0, 0) = colid(0, 0)
    For tm2 = 1 To 128
    colid2(2, 0, tm2) = colid(0, 1)
    Next tm2
    For tm1 = 1 To 128
    colid2(2, tm1, 0) = colid(1, 0)
    Next tm1: For tm1 = 1 To 128
    For tm2 = 1 To 128
    colid2(2, tm1, tm2) = colid(1, 1)
    Next tm2: Next tm1
End Sub

Public Function initMir()
For i = 0 To 255
mir(i) = (i And 128) \ 128 + (i And 64) \ 32 + (i And 32) \ 8 + (i And 16) \ 2 + _
         (i And 8) * 2 + (i And 4) * 8 + (i And 2) * 32 + (i And 1) * 128
Next i
End Function

Function rgb15(Red As Byte, Green As Byte, Blue As Byte) As Integer
rgb15 = Red * 1024 + Green * 32 + Blue
End Function
Sub SrceenShot()
Dim flname As String, ni As Long
ret:
flname = App.Path & "\" & rominfo.title & " - " & ni & ".bmp"
If Not fileexist(flname) Then
SavePicture Form1.Picture1.Image, flname
Else
ni = ni + 1
GoTo ret
End If
End Sub

Function fileexist(file As String) As Boolean
On Error Resume Next
If FileLen(file) = 0 Then fileexist = False Else fileexist = True
End Function

Sub Drawline4()
    curline = RAM(65348, 0) ' 0xFF44 (LY)
    If curline = lastline Then Exit Sub
    lastline = curline

    Dim lcdc As Long
    lcdc = RAM(65344, 0)    ' 0xFF40 (LCDC)

    ' LCD°¡ ²¨Á® ÀÖÀ¸¸é ±×¸®Áö ¾Ê°í Á¾·á
    If (lcdc And 128) = 0 Then Exit Sub

    Dim tileData As Long, tilemap As Long
    Dim xoffset As Long, yoffset As Long
    Dim xs As Long, ys As Long
    Dim tileptr As Long, memptr As Long
    Dim mv1 As Long, mv2 As Long
    Dim x As Long, px As Long
    Dim cIdx As Long

    ' 1. Å¸ÀÏ µ¥ÀÌÅÍ ±âÁØ ÁÖ¼Ò (LCDC Bit 4)
    If (lcdc And 16) <> 0 Then
        tileData = 32768    ' &H8000
    Else
        tileData = 34816    ' &H8800 (Signed Å¸ÀÏ¼Â)
    End If

    ' ========================================================
    ' [1] Background ±×¸®±â
    ' ========================================================
    If bgv Then
        ' BG Å¸ÀÏ ¸Ê ÁÖ¼Ò (LCDC Bit 3)
        If (lcdc And 8) <> 0 Then
            tilemap = 39936 ' &H9C00
        Else
            tilemap = 38912 ' &H9800
        End If

        xoffset = RAM(65347, 0)           ' SCX
        yoffset = (RAM(65346, 0) + curline) And 255 ' SCY + LY (256 ·¦¾î¶ó¿îµå)
        
        ys = yoffset \ 8
        xs = xoffset \ 8
        yoffset = (yoffset And 7) * 2
        xoffset = -(xoffset And 7)

        Dim mapRowAddr As Long
        mapRowAddr = tilemap + ys * 32

        For x = xoffset To 159 Step 8
            ' Å¸ÀÏ ¹øÈ£ Á¶È¸
            Dim tNum As Long
            tNum = RAM(mapRowAddr + xs, 0)

            If tileData = 32768 Then
                tileptr = tNum * 16
            Else
                tileptr = (tNum Xor 128) * 16
            End If

            xs = (xs + 1) And 31 ' Mod 32 ´ë½Å And 31 (¼Óµµ ÃÖÀûÈ­)

            memptr = tileData + tileptr + yoffset
            mv2 = RAM(memptr, 0)     ' Low Plane
            mv1 = RAM(memptr + 1, 0) ' High Plane

            ' 8°³ ÇÈ¼¿ ·»´õ¸µ (ºñÆ® 7ºÎÅÍ 0 ¼ø¼­·Î È­¸é¿¡ ÁÂ->¿ì ¹èÄ¡)
            If x >= 0 And x <= 152 Then
                Vram(x + 7, curline) = colid2(0, mv1 And 1, mv2 And 1)
                Vram(x + 6, curline) = colid2(0, (mv1 \ 2) And 1, (mv2 \ 2) And 1)
                Vram(x + 5, curline) = colid2(0, (mv1 \ 4) And 1, (mv2 \ 4) And 1)
                Vram(x + 4, curline) = colid2(0, (mv1 \ 8) And 1, (mv2 \ 8) And 1)
                Vram(x + 3, curline) = colid2(0, (mv1 \ 16) And 1, (mv2 \ 16) And 1)
                Vram(x + 2, curline) = colid2(0, (mv1 \ 32) And 1, (mv2 \ 32) And 1)
                Vram(x + 1, curline) = colid2(0, (mv1 \ 64) And 1, (mv2 \ 64) And 1)
                Vram(x, curline) = colid2(0, (mv1 \ 128) And 1, (mv2 \ 128) And 1)
            Else
                ' ÁÂ¿ì °æ°è Å¬¸®ÇÎ Ã³¸®
                Dim bitPos As Long, mask As Long: mask = 1
                For bitPos = 7 To 0 Step -1
                    px = x + bitPos
                    If px >= 0 And px < 160 Then
                        Vram(px, curline) = colid2(0, mv1 And 1, mv2 And 1)
                    End If
                    mv1 = mv1 \ 2: mv2 = mv2 \ 2
                Next bitPos
            End If
        Next x
    End If

    ' ========================================================
    ' [2] Window ±×¸®±â
    ' ========================================================
    Dim winY As Long, winX As Long
    winY = RAM(65354, 0) ' 0xFF4A (WY)
    winX = RAM(65355, 0) ' 0xFF4B (WX)

    If ((lcdc And 32) <> 0) And wv And (curline >= winY) And (winX < 167) Then
        If (lcdc And 64) <> 0 Then
            tilemap = 39936 ' &H9C00
        Else
            tilemap = 38912 ' &H9800
        End If

        yoffset = curline - winY
        tilemap = tilemap + (yoffset \ 8) * 32
        yoffset = (yoffset And 7) * 2

        For x = winX - 7 To 159 Step 8
            Dim wTile As Long
            wTile = RAM(tilemap, 0)

            If tileData = 32768 Then
                tileptr = wTile * 16
            Else
                tileptr = (wTile Xor 128) * 16
            End If
            tilemap = tilemap + 1

            memptr = tileData + tileptr + yoffset
            mv2 = RAM(memptr, 0)
            mv1 = RAM(memptr + 1, 0)

            If x >= 0 And x <= 152 Then
                Vram(x + 7, curline) = colid2(0, mv1 And 1, mv2 And 1)
                Vram(x + 6, curline) = colid2(0, (mv1 \ 2) And 1, (mv2 \ 2) And 1)
                Vram(x + 5, curline) = colid2(0, (mv1 \ 4) And 1, (mv2 \ 4) And 1)
                Vram(x + 4, curline) = colid2(0, (mv1 \ 8) And 1, (mv2 \ 8) And 1)
                Vram(x + 3, curline) = colid2(0, (mv1 \ 16) And 1, (mv2 \ 16) And 1)
                Vram(x + 2, curline) = colid2(0, (mv1 \ 32) And 1, (mv2 \ 32) And 1)
                Vram(x + 1, curline) = colid2(0, (mv1 \ 64) And 1, (mv2 \ 64) And 1)
                Vram(x, curline) = colid2(0, (mv1 \ 128) And 1, (mv2 \ 128) And 1)
            Else
                For bitPos = 7 To 0 Step -1
                    px = x + bitPos
                    If px >= 0 And px < 160 Then
                        Vram(px, curline) = colid2(0, mv1 And 1, mv2 And 1)
                    End If
                    mv1 = mv1 \ 2: mv2 = mv2 \ 2
                Next bitPos
            End If
        Next x
    End If

    ' ========================================================
    ' [3] Sprites (OBJ) ±×¸®±â
    ' ========================================================
    If ((lcdc And 2) <> 0) And objv Then
        Dim spriteSizeY As Long
        If (lcdc And 4) = 0 Then spriteSizeY = 8 Else spriteSizeY = 16

        Dim sprCount As Long: sprCount = 0
        Dim sprY As Long, sprX As Long, sprAttr As Long
        Dim sprTile As Long, spat As Long, bgPriority As Boolean
        Dim cid0 As Long: cid0 = colid2(0, 0, 0) ' BG Åõ¸í ±âÁØ »ö»ó

        ' ÇÏµå¿þ¾î ±ÔÄ¢: 1¶óÀÎ´ç ÃÖ´ë 10°³ ½ºÇÁ¶óÀÌÆ® Á¦ÇÑ
        For tilemap = 65180 To 65024 Step -4
            sprY = RAM(tilemap, 0) - 16
            
            ' YÃà ½ºÄµ¶óÀÎ Æ÷ÇÔ °Ë»ç
            If curline >= sprY And curline < (sprY + spriteSizeY) Then
                sprX = RAM(tilemap + 1, 0) - 8
                
                ' XÃà È­¸é ³» Á¸Àç °Ë»ç
                If sprX > -8 And sprX < 160 Then
                    sprCount = sprCount + 1
                    
                    sprAttr = RAM(tilemap + 3, 0)
                    bgPriority = ((sprAttr And 128) <> 0)
                    spat = ((sprAttr And 16) \ 16) + 1 ' OBP0 ¶Ç´Â OBP1 ÆÈ·¹Æ®
                    
                    If spriteSizeY = 8 Then
                        tileptr = RAM(tilemap + 2, 0) * 16
                    Else
                        tileptr = (RAM(tilemap + 2, 0) And 254) * 16
                    End If

                    ' Y ÇÃ¸³(ºñÆ® 6) ¹Ý¿µ ¶óÀÎ ¿ÀÇÁ¼Â
                    Dim lineInSpr As Long
                    lineInSpr = curline - sprY
                    If (sprAttr And 64) <> 0 Then
                        lineInSpr = (spriteSizeY - 1) - lineInSpr
                    End If

                    memptr = 32768 + tileptr + lineInSpr * 2
                    
                    ' X ÇÃ¸³(ºñÆ® 5) °Ë»ç ¹× ¹Ì·¯¸µ
                    If (sprAttr And 32) <> 0 Then
                        mv1 = mir(RAM(memptr + 1, vrm))
                        mv2 = mir(RAM(memptr, vrm))
                    Else
                        mv1 = RAM(memptr + 1, vrm)
                        mv2 = RAM(memptr, vrm)
                    End If

                    ' 8ÇÈ¼¿ ·»´õ¸µ
                    For bitPos = 7 To 0 Step -1
                        px = sprX + bitPos
                        If px >= 0 And px < 160 Then
                            cIdx = (mv1 And 1) Or ((mv2 And 1) * 2)
                            If cIdx <> 0 Then ' 0¹ø »ö»óÀº Åõ¸í Ã³¸®
                                If Not bgPriority Or (Vram(px, curline) = cid0) Then
                                    Vram(px, curline) = colid2(spat, mv1 And 1, mv2 And 1)
                                End If
                            End If
                        End If
                        mv1 = mv1 \ 2: mv2 = mv2 \ 2
                    Next bitPos

                    If sprCount >= 10 Then Exit For ' 1½ºÄµ¶óÀÎ 10°³ ÇÑµµ µµ´Þ ½Ã ·çÇÁ Áï½Ã Á¾·á
                End If
            End If
        Next tilemap
    End If
End Sub

Sub Drawline4_0() 'Using Api and SetBits/StrechBits
curline = RAM(65348, 0)
If curline = lastline Then Exit Sub
lastline = curline
    ' Draw Background
    ' Get BG & window Tile Pattern Data Address
    If RAM(65344, 0) And 16 Then
        tileData = 32768
    Else
        tileData = 34816
    End If
    If bgv Then
    ' Get BG Tile Table Address
    If RAM(65344, 0) And 8 Then
        tilemap = 39936
        tms = 39936
    Else
        tilemap = 38912
        tms = 38912
    End If
    tileend = tilemap + 1023
    xoffset = RAM(65347, 0)
    yoffset = RAM(65346, 0) + curline
    xs = xoffset \ 8
    ys = yoffset \ 8
    yoffset = yoffset And 7
    xoffset = -(xoffset And 7)
    For x = xoffset To 159 Step 8
        tiletmp = tilemap + ys * 32 + xs
        If tiletmp > tileend Then tiletmp = tiletmp - 1024
        If tileData = 32768 Then           ' Tile Data @ &H8800-&h97FF is 128ed
            tileptr = RAM(tiletmp, 0) * 16             'Get pointer to tile
        Else
            tileptr = (RAM(tiletmp, 0) Xor 128) * 16
        End If
        
        xs = (xs + 1) Mod 32
        
        memptr = tileData + tileptr + (yoffset And 7) * 2
        mv1 = RAM(memptr + 1, 0): mv2 = RAM(memptr, 0)
        If x > -1 And x < 153 Then
            Vram(x + 7, curline) = colid2(0, mv1 And 1, mv2 And 1): mv1 = mv1 \ 2: mv2 = mv2 \ 2
            Vram(x + 6, curline) = colid2(0, mv1 And 1, mv2 And 1): mv1 = mv1 \ 2: mv2 = mv2 \ 2
            Vram(x + 5, curline) = colid2(0, mv1 And 1, mv2 And 1): mv1 = mv1 \ 2: mv2 = mv2 \ 2
            Vram(x + 4, curline) = colid2(0, mv1 And 1, mv2 And 1): mv1 = mv1 \ 2: mv2 = mv2 \ 2
            Vram(x + 3, curline) = colid2(0, mv1 And 1, mv2 And 1): mv1 = mv1 \ 2: mv2 = mv2 \ 2
            Vram(x + 2, curline) = colid2(0, mv1 And 1, mv2 And 1): mv1 = mv1 \ 2: mv2 = mv2 \ 2
            Vram(x + 1, curline) = colid2(0, mv1 And 1, mv2 And 1): mv1 = mv1 \ 2: mv2 = mv2 \ 2
            Vram(x, curline) = colid2(0, mv1 And 1, mv2 And 1)
        Else
            If x < 153 Then Vram(x + 7, curline) = colid2(0, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -7 And x < 154 Then Vram(x + 6, curline) = colid2(0, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -6 And x < 155 Then Vram(x + 5, curline) = colid2(0, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -5 And x < 156 Then Vram(x + 4, curline) = colid2(0, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -4 And x < 157 Then Vram(x + 3, curline) = colid2(0, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -3 And x < 158 Then Vram(x + 2, curline) = colid2(0, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -2 And x < 159 Then Vram(x + 1, curline) = colid2(0, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -1 Then Vram(x, curline) = colid2(0, mv1 And 1, mv2 And 1)
        End If
    Next x
    End If
    
    
        'Draw Window
    
If (RAM(65344, 0) And 32) = 32 And wv And curline >= RAM(65354, 0) And RAM(65355, 0) < 167 Then
    ' Get window Tile Table Address
    If RAM(65344, 0) And 64 Then
        tilemap = 39936
    Else
        tilemap = 38912
    End If
    yoffset = curline - RAM(65354, 0)
    tilemap = tilemap + (yoffset \ 8) * 32
    yoffset = yoffset And 7
    For x = RAM(65355, 0) - 7 To 159 Step 8
        If tileData = 32768 Then           ' Tile Data @ &H8800-&h97FF is 128ed
            tileptr = RAM(tilemap, 0) * 16             'Get pointer to tile
        Else
            tileptr = (RAM(tilemap, 0) Xor 128) * 16
        End If
        memptr = tileData + tileptr + (yoffset And 7) * 2
        mv1 = RAM(memptr + 1, 0): mv2 = RAM(memptr, 0)
        
        If x > -1 And x < 153 Then
            Vram(x + 7, curline) = colid2(0, mv1 And 1, mv2 And 1): mv1 = mv1 \ 2: mv2 = mv2 \ 2
            Vram(x + 6, curline) = colid2(0, mv1 And 1, mv2 And 1): mv1 = mv1 \ 2: mv2 = mv2 \ 2
            Vram(x + 5, curline) = colid2(0, mv1 And 1, mv2 And 1): mv1 = mv1 \ 2: mv2 = mv2 \ 2
            Vram(x + 4, curline) = colid2(0, mv1 And 1, mv2 And 1): mv1 = mv1 \ 2: mv2 = mv2 \ 2
            Vram(x + 3, curline) = colid2(0, mv1 And 1, mv2 And 1): mv1 = mv1 \ 2: mv2 = mv2 \ 2
            Vram(x + 2, curline) = colid2(0, mv1 And 1, mv2 And 1): mv1 = mv1 \ 2: mv2 = mv2 \ 2
            Vram(x + 1, curline) = colid2(0, mv1 And 1, mv2 And 1): mv1 = mv1 \ 2: mv2 = mv2 \ 2
            Vram(x, curline) = colid2(0, mv1 And 1, mv2 And 1)
            tilemap = tilemap + 1
        Else
            If x < 153 Then Vram(x + 7, curline) = colid2(0, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -7 And x < 154 Then Vram(x + 6, curline) = colid2(0, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -6 And x < 155 Then Vram(x + 5, curline) = colid2(0, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -5 And x < 156 Then Vram(x + 4, curline) = colid2(0, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -4 And x < 157 Then Vram(x + 3, curline) = colid2(0, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -3 And x < 158 Then Vram(x + 2, curline) = colid2(0, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -2 And x < 159 Then Vram(x + 1, curline) = colid2(0, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -1 Then Vram(x, curline) = colid2(0, mv1 And 1, mv2 And 1)
            tilemap = tilemap + 1
        End If
        
    Next x
End If

        'Draw Sprites
If (RAM(65344, 0) And 2) And objv Then
    If (RAM(65344, 0) And 4) = 0 Then
        SpriteY = 7
    Else
        SpriteY = 15
    End If
    For tilemap = 65180 To 65024 Step -4
        y = RAM(tilemap, 0) - 16
        x = RAM(tilemap + 1, 0) - 8
        If y <= curline And y + SpriteY >= curline And x > -8 And x < 160 Then
        
        If SpriteY = 7 Then tileptr = readM(tilemap + 2) * 16 Else tileptr = (RAM(tilemap + 2, 0) And 254) * 16 'Get pointer to tile
        TCol = -((RAM(tilemap + 3, 0) And 128) > 0)
        spat = -((readM(tilemap + 3) And 16) > 0) + 1
        vf = RAM(tilemap + 3, 0) And 32
        'init palete
        memptr = 32768 + tileptr
        
        If (RAM(tilemap + 3, 0) And 64) Then memptr = memptr + SpriteY * 2 - (curline - y) * 2 Else memptr = memptr + (curline - y) * 2
        If vf Then mv1 = mir(RAM(memptr + 1, vrm)): mv2 = mir(RAM(memptr, vrm)) Else mv1 = RAM(memptr + 1, vrm): mv2 = RAM(memptr, vrm)
        
        If TCol = 0 Then
            
            If x < 153 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 7, curline) = colid2(spat, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -7 And x < 154 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 6, curline) = colid2(spat, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -6 And x < 155 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 5, curline) = colid2(spat, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -5 And x < 156 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 4, curline) = colid2(spat, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -4 And x < 157 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 3, curline) = colid2(spat, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -3 And x < 158 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 2, curline) = colid2(spat, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -2 And x < 159 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 1, curline) = colid2(spat, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -1 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x, curline) = colid2(spat, mv1 And 1, mv2 And 1)
            
        Else
            cid2 = colid2(0, 0, 0)
            If x < 153 Then If Vram(x + 7, curline) = cid2 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 7, curline) = colid2(spat, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -7 And x < 154 Then If Vram(x + 6, curline) = cid2 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 6, curline) = colid2(spat, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -6 And x < 155 Then If Vram(x + 5, curline) = cid2 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 5, curline) = colid2(spat, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -5 And x < 156 Then If Vram(x + 4, curline) = cid2 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 4, curline) = colid2(spat, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -4 And x < 157 Then If Vram(x + 3, curline) = cid2 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 3, curline) = colid2(spat, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -3 And x < 158 Then If Vram(x + 2, curline) = cid2 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 2, curline) = colid2(spat, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -2 And x < 159 Then If Vram(x + 1, curline) = cid2 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 1, curline) = colid2(spat, mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -1 Then If Vram(x, curline) = cid2 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x, curline) = colid2(spat, mv1 And 1, mv2 And 1)
            
        End If
    End If
    Next tilemap
   End If
   
   
    
End Sub
Sub Drawline()
    curline = RAM(65348, 0) ' 0xFF44 (LY)
    If curline = lastline Then Exit Sub
    lastline = curline

    Dim lcdc As Long
    lcdc = RAM(65344, 0)    ' 0xFF40 (LCDC)

    ' LCD°¡ ²¨Á® ÀÖÀ¸¸é ±×¸®Áö ¾Ê°í Á¾·á
    If (lcdc And 128) = 0 Then Exit Sub

    Dim tileData As Long, tilemap As Long
    Dim xoffset As Long, yoffset As Long
    Dim xs As Long, ys As Long
    Dim tileptr As Long, memptr As Long
    Dim mv1 As Long, mv2 As Long
    Dim x As Long, px As Long, scrX As Long
    Dim bgat As Long, ccp As Long, vrm As Long
    Dim xflip As Boolean, yflip As Boolean
    Dim tNum As Long

    ' Å¸ÀÏ ÆÐÅÏ µ¥ÀÌÅÍ º£ÀÌ½º ÁÖ¼Ò (LCDC Bit 4)
    If (lcdc And 16) <> 0 Then
        tileData = 32768    ' &H8000 (0~255 Unsigned)
    Else
        tileData = 34816    ' &H8800 (Signed Å¸ÀÏ¼Â)
    End If

    ' ========================================================
    ' [1] GBC Background ±×¸®±â
    ' ========================================================
    If bgv Then
        ' BG Å¸ÀÏ ¸Ê ÁÖ¼Ò (LCDC Bit 3)
        If (lcdc And 8) <> 0 Then
            tilemap = 39936 ' &H9C00
        Else
            tilemap = 38912 ' &H9800
        End If

        xoffset = RAM(65347, 0)
        yoffset = (RAM(65346, 0) + curline) And 255
        ys = yoffset \ 8
        xs = xoffset \ 8
        yoffset = yoffset And 7
        xoffset = -(xoffset And 7)

        Dim mapRowAddr As Long
        mapRowAddr = tilemap + ys * 32

        For x = xoffset To 159 Step 8
            Dim tileEntry As Long
            tileEntry = mapRowAddr + xs

            tNum = RAM(tileEntry, 0)
            If tileData = 32768 Then
                tileptr = tNum * 16
            Else
                tileptr = (tNum Xor 128) * 16
            End If

            bgat = RAM(tileEntry, 1)
            ccp = bgat And 7
            vrm = (bgat And 8) \ 8
            xflip = ((bgat And 32) <> 0)
            yflip = ((bgat And 64) <> 0)

            ' BG ¿ì¼±¼øÀ§/Åõ¸íµµ °Ë»ç¿ë ¹è°æ 0¹ø ÄÃ·¯ ±â·Ï
            If (x >= 0) And (x <= 159) Then
                tcls(x \ 8) = gbcP(bgp(ccp, 0))
            End If

            ' 4°³ »ö»ó LUT Ä³½Ã
            ccid(0, 0) = gbcP(bgp(ccp, 0))
            ccid(0, 1) = gbcP(bgp(ccp, 1))
            ccid(1, 0) = gbcP(bgp(ccp, 2))
            ccid(1, 1) = gbcP(bgp(ccp, 3))

            ' Y-Flip¿¡ µû¸¥ Å¸ÀÏ ³»ºÎ ¶óÀÎ ÁÖ¼Ò
            If yflip Then
                memptr = tileData + tileptr + (14 - yoffset * 2)
            Else
                memptr = tileData + tileptr + (yoffset * 2)
            End If

            ' X-Flip¿¡ µû¸¥ ÇÈ¼¿ µ¥ÀÌÅÍ ·Îµå
            If xflip Then
                mv1 = mir(RAM(memptr + 1, vrm))
                mv2 = mir(RAM(memptr, vrm))
            Else
                mv1 = RAM(memptr + 1, vrm)
                mv2 = RAM(memptr, vrm)
            End If

            xs = (xs + 1) And 31 ' Mod 32 ´ë½Å And 31

            ' È­¸é ³»ºÎ (Å¬¸®ÇÎ ºÒÇÊ¿ä)
            If x >= 0 And x <= 152 Then
                Vram(x + 7, curline) = ccid(mv1 And 1, mv2 And 1)
                Vram(x + 6, curline) = ccid((mv1 \ 2) And 1, (mv2 \ 2) And 1)
                Vram(x + 5, curline) = ccid((mv1 \ 4) And 1, (mv2 \ 4) And 1)
                Vram(x + 4, curline) = ccid((mv1 \ 8) And 1, (mv2 \ 8) And 1)
                Vram(x + 3, curline) = ccid((mv1 \ 16) And 1, (mv2 \ 16) And 1)
                Vram(x + 2, curline) = ccid((mv1 \ 32) And 1, (mv2 \ 32) And 1)
                Vram(x + 1, curline) = ccid((mv1 \ 64) And 1, (mv2 \ 64) And 1)
                Vram(x, curline) = ccid((mv1 \ 128) And 1, (mv2 \ 128) And 1)
            Else
                ' È­¸é ÁÂ/¿ì °æ°è Å¬¸®ÇÎ
                For px = 7 To 0 Step -1
                    scrX = x + px
                    If scrX >= 0 And scrX < 160 Then
                        Vram(scrX, curline) = ccid(mv1 And 1, mv2 And 1)
                    End If
                    mv1 = mv1 \ 2
                    mv2 = mv2 \ 2
                Next px
            End If
        Next x
    End If

    ' ========================================================
    ' [2] GBC Window ±×¸®±â
    ' ========================================================
    Dim winY As Long, winX As Long
    winY = RAM(65354, 0)
    winX = RAM(65355, 0) - 7

    If ((lcdc And 32) <> 0) And wv And (curline >= winY) And (winX < 160) Then
        Dim winTileMapBase As Long
        If (lcdc And 64) <> 0 Then
            winTileMapBase = 39936 ' &H9C00
        Else
            winTileMapBase = 38912 ' &H9800
        End If

        yoffset = curline - winY
        Dim wy As Long: wy = yoffset \ 8
        yoffset = yoffset And 7

        Dim wx As Long: wx = 0
        Dim winRowAddr As Long: winRowAddr = winTileMapBase + (wy * 32)

        For x = winX To 159 Step 8
            Dim winTileEntry As Long
            winTileEntry = winRowAddr + (wx And 31)
            wx = wx + 1

            tNum = RAM(winTileEntry, 0)
            If tileData = 32768 Then
                tileptr = tNum * 16
                memptr = 32768 + tileptr
            Else
                If tNum > 127 Then tNum = tNum - 256
                memptr = 36864 + (tNum * 16)
            End If

            bgat = RAM(winTileEntry, 1)
            ccp = bgat And 7
            vrm = (bgat And 8) \ 8
            xflip = ((bgat And 32) <> 0)
            yflip = ((bgat And 64) <> 0)

            ccid(0, 0) = gbcP(bgp(ccp, 0))
            ccid(0, 1) = gbcP(bgp(ccp, 1))
            ccid(1, 0) = gbcP(bgp(ccp, 2))
            ccid(1, 1) = gbcP(bgp(ccp, 3))

            If yflip Then
                memptr = memptr + (14 - yoffset * 2)
            Else
                memptr = memptr + (yoffset * 2)
            End If

            If xflip Then
                mv1 = mir(RAM(memptr + 1, vrm))
                mv2 = mir(RAM(memptr, vrm))
            Else
                mv1 = RAM(memptr + 1, vrm)
                mv2 = RAM(memptr, vrm)
            End If

            If x >= 0 And x <= 152 Then
                Vram(x + 7, curline) = ccid(mv1 And 1, mv2 And 1)
                Vram(x + 6, curline) = ccid((mv1 \ 2) And 1, (mv2 \ 2) And 1)
                Vram(x + 5, curline) = ccid((mv1 \ 4) And 1, (mv2 \ 4) And 1)
                Vram(x + 4, curline) = ccid((mv1 \ 8) And 1, (mv2 \ 8) And 1)
                Vram(x + 3, curline) = ccid((mv1 \ 16) And 1, (mv2 \ 16) And 1)
                Vram(x + 2, curline) = ccid((mv1 \ 32) And 1, (mv2 \ 32) And 1)
                Vram(x + 1, curline) = ccid((mv1 \ 64) And 1, (mv2 \ 64) And 1)
                Vram(x, curline) = ccid((mv1 \ 128) And 1, (mv2 \ 128) And 1)
            Else
                For px = 7 To 0 Step -1
                    scrX = x + px
                    If scrX >= 0 And scrX < 160 Then
                        Vram(scrX, curline) = ccid(mv1 And 1, mv2 And 1)
                    End If
                    mv1 = mv1 \ 2
                    mv2 = mv2 \ 2
                Next px
            End If
        Next x
    End If

    ' ========================================================
    ' [3] GBC Sprites (OBJ) ±×¸®±â
    ' ========================================================
    If ((lcdc And 2) <> 0) And objv Then
        Dim spriteSizeY As Long
        If (lcdc And 4) = 0 Then spriteSizeY = 8 Else spriteSizeY = 16

        Dim sprCount As Long: sprCount = 0
        Dim sprY As Long, sprX As Long, sprAttr As Long
        Dim sprTile As Long, bgPriority As Boolean
        Dim colBit1 As Long, colBit2 As Long

        ' OAM ½ºÄµ (40°³ ½ºÇÁ¶óÀÌÆ®)
        For tilemap = 65180 To 65024 Step -4
            sprY = RAM(tilemap, 0) - 16

            If curline >= sprY And curline < (sprY + spriteSizeY) Then
                sprX = RAM(tilemap + 1, 0) - 8

                If sprX > -8 And sprX < 160 Then
                    sprCount = sprCount + 1

                    sprAttr = RAM(tilemap + 3, 0)
                    bgPriority = ((sprAttr And 128) <> 0)
                    vrm = (sprAttr And 8) \ 8
                    ccp = sprAttr And 7

                    If spriteSizeY = 8 Then
                        tileptr = RAM(tilemap + 2, 0) * 16
                    Else
                        tileptr = (RAM(tilemap + 2, 0) And 254) * 16
                    End If

                    ' ÆÈ·¹Æ® ¼³Á¤
                    ccid(0, 0) = gbcP(objp(ccp, 0))
                    ccid(0, 1) = gbcP(objp(ccp, 1))
                    ccid(1, 0) = gbcP(objp(ccp, 2))
                    ccid(1, 1) = gbcP(objp(ccp, 3))

                    memptr = 32768 + tileptr

                    ' Y ÇÃ¸³ (Bit 6)
                    Dim lineInSpr As Long
                    lineInSpr = curline - sprY
                    If (sprAttr And 64) <> 0 Then
                        lineInSpr = (spriteSizeY - 1) - lineInSpr
                    End If
                    memptr = memptr + (lineInSpr * 2)

                    ' X ÇÃ¸³ (Bit 5)
                    If (sprAttr And 32) <> 0 Then
                        mv1 = mir(RAM(memptr + 1, vrm))
                        mv2 = mir(RAM(memptr, vrm))
                    Else
                        mv1 = RAM(memptr + 1, vrm)
                        mv2 = RAM(memptr, vrm)
                    End If

                    ' ½ºÇÁ¶óÀÌÆ® ÇÈ¼¿ ·»´õ¸µ ·çÇÁ
                    For px = 7 To 0 Step -1
                        scrX = sprX + px
                        If scrX >= 0 And scrX < 160 Then
                            colBit1 = mv1 And 1
                            colBit2 = mv2 And 1

                            ' colidx(colBit1, colBit2) °Ë»ç (0¹ø »ö»óÀº Åõ¸í)
                            If (colBit1 Or colBit2) <> 0 Then
                                If Not bgPriority Then
                                    Vram(scrX, curline) = ccid(colBit1, colBit2)
                                Else
                                    ' BG ¿ì¼± ¸ðµåÀÏ ¶§´Â ¹è°æÀÌ Åõ¸í»ö(tcls)ÀÏ ¶§¸¸ ±×¸®±â
                                    If Vram(scrX, curline) = tcls(scrX \ 8) Then
                                        Vram(scrX, curline) = ccid(colBit1, colBit2)
                                    End If
                                End If
                            End If
                        End If
                        mv1 = mv1 \ 2
                        mv2 = mv2 \ 2
                    Next px

                    ' 1¶óÀÎ´ç 10°³ ÇÑµµ ½Ã ·çÇÁ Å»Ãâ
                    If sprCount >= 10 Then Exit For
                End If
            End If
        Next tilemap
    End If
End Sub

Sub Drawline_() 'Using Api and SetBits/StrechBits
   
curline = RAM(65348, 0)
If curline = lastline Then Exit Sub
lastline = curline
    ' Draw Background
    ' Get BG & window Tile Pattern Data Address
    If RAM(65344, 0) And 16 Then
        tileData = 32768
    Else
        tileData = 34816
    End If

If bgv Then
    ' Get BG Tile Table Address
    If RAM(65344, 0) And 8 Then
        tilemap = 39936
        tms = 39936
    Else
        tilemap = 38912
        tms = 38912
    End If
    
    tileend = tilemap + 1023
    xoffset = RAM(65347, 0)
    yoffset = RAM(65346, 0) + curline
    xs = xoffset \ 8
    ys = yoffset \ 8
    yoffset = yoffset And 7
    xoffset = -(xoffset And 7)
    
    For x = xoffset To 159 Step 8
        tiletmp = tilemap + ys * 32 + xs
        If tiletmp > tileend Then tiletmp = tiletmp - 1024
        If tileData = 32768 Then           ' Tile Data @ &H8800-&h97FF is 128ed
            tileptr = RAM(tiletmp, 0) * 16             'Get pointer to tile
        Else
            tileptr = (RAM(tiletmp, 0) Xor 128) * 16
        End If
        bgat = RAM(tiletmp, 1)
        ccp = bgat And 7
        tcls(x \ 8) = gbcP(bgp(ccp, 0))
        vrm = (bgat And 8) \ 8
        xflip = (bgat And 32) \ 32: yflip = (bgat And 64) \ 64
        ccid(0, 0) = gbcP(bgp(ccp, 0))
        ccid(0, 1) = gbcP(bgp(ccp, 1))
        ccid(1, 0) = gbcP(bgp(ccp, 2))
        ccid(1, 1) = gbcP(bgp(ccp, 3))
        If yflip Then memptr = tileData + tileptr + 14 - (yoffset And 7) * 2 Else memptr = tileData + tileptr + (yoffset And 7) * 2
        If xflip Then mv1 = mir(RAM(memptr + 1, vrm)): mv2 = mir(RAM(memptr, vrm)) Else mv1 = RAM(memptr + 1, vrm): mv2 = RAM(memptr, vrm)
        xs = (xs + 1) Mod 32
        
      
        '''''''''''''
        ' È­¸é ¾ÈÂÊ(0 <= x <= 152)Àº °æ°è °Ë»ç(If)°¡ ÀüÇô ÇÊ¿ä ¾øÀ¸¹Ç·Î ¹«Á¶°Ç ´ÙÀÌ·ºÆ® ±â·Ï
        If x >= 0 And x <= 152 Then
            Vram(x + 7, curline) = ccid(mv1 And 1, mv2 And 1)
            Vram(x + 6, curline) = ccid((mv1 \ 2) And 1, (mv2 \ 2) And 1)
            Vram(x + 5, curline) = ccid((mv1 \ 4) And 1, (mv2 \ 4) And 1)
            Vram(x + 4, curline) = ccid((mv1 \ 8) And 1, (mv2 \ 8) And 1)
            Vram(x + 3, curline) = ccid((mv1 \ 16) And 1, (mv2 \ 16) And 1)
            Vram(x + 2, curline) = ccid((mv1 \ 32) And 1, (mv2 \ 32) And 1)
            Vram(x + 1, curline) = ccid((mv1 \ 64) And 1, (mv2 \ 64) And 1)
            Vram(x, curline) = ccid((mv1 \ 128) And 1, (mv2 \ 128) And 1)
            
           
        Else
            ' È­¸é ÁÂ/¿ì °æ°è(-7 <= x < 0 ¶Ç´Â x > 152)¿¡ °ÉÄ£ Å¸ÀÏ¸¸ ¾ÈÀüÇÏ°Ô 1ÇÈ¼¿¾¿ Å¬¸®ÇÎ
            Dim px As Long, scrX As Long
            For px = 7 To 0 Step -1
                scrX = x + px
                If scrX >= 0 And scrX < 160 Then
                    Vram(scrX, curline) = ccid(mv1 And 1, mv2 And 1)
                End If
                mv1 = mv1 \ 2
                mv2 = mv2 \ 2
            Next px
        End If
        
        ''''''''''''
      
            
    Next x
    End If
    
    '''''''''''''''''''
    ' ----------------------------------------------------
    ' Draw Window
    ' ----------------------------------------------------
    Dim winY As Long, winX As Long
    Dim wx As Long, wy As Long
    Dim winTileMapBase As Long
    Dim winTileAddr As Long
    
    winY = RAM(65354, 0)        ' WY (Window Y)
    winX = RAM(65355, 0) - 7    ' WX (Window X - 7)
    
    If (RAM(65344, 0) And 32) = 32 And wv And curline >= winY And winX < 160 Then
        ' Window Tile Map Base Address (LCDC bit 6)
        If RAM(65344, 0) And 64 Then
            winTileMapBase = 39936  ' &H9C00
        Else
            winTileMapBase = 38912  ' &H9800
        End If
        
        yoffset = curline - winY
        wy = yoffset \ 8            ' À©µµ¿ì Å¸ÀÏ¸Ê Çà (0 ~ 31)
        yoffset = yoffset And 7     ' Å¸ÀÏ ³» ¶óÀÎ (0 ~ 7)
        
        wx = 0
        For x = winX To 159 Step 8
            ' ÇöÀç Å¸ÀÏÀÇ ¸Ê ÁÖ¼Ò (X ÀÎµ¦½º´Â 0ºÎÅÍ 1Ä­¾¿ Áõ°¡)
            winTileAddr = winTileMapBase + (wy * 32) + (wx Mod 32)
            wx = wx + 1
            
            ' Å¸ÀÏ ¹øÈ£ °¡Á®¿À±â ¹× ÆÐÅÏ µ¥ÀÌÅÍ ÁÖ¼Ò °è»ê
            If tileData = 32768 Then
                ' 0x8000 ¹æ½Ä (Unsigned)
                tileptr = RAM(winTileAddr, 0) * 16
                memptr = 32768 + tileptr
            Else
                ' 0x8800 ¹æ½Ä (Signed: -128 ~ 127, ±âÁØÁ¡ 0x9000 = 36864)
                ' (VBA ¹ÙÀÌÆ®¸¦ Signed Á¤¼ö·Î Ã³¸®)
                Dim rawTile As Long
                rawTile = RAM(winTileAddr, 0)
                If rawTile > 127 Then rawTile = rawTile - 256
                memptr = 36864 + (rawTile * 16)
            End If
            
            bgat = RAM(winTileAddr, 1)
            ccp = bgat And 7
            vrm = (bgat And 8) \ 8
            xflip = (bgat And 32) \ 32
            yflip = (bgat And 64) \ 64
            
            ' ÆÈ·¹Æ® ¼¼ÆÃ
            ccid(0, 0) = gbcP(bgp(ccp, 0))
            ccid(0, 1) = gbcP(bgp(ccp, 1))
            ccid(1, 0) = gbcP(bgp(ccp, 2))
            ccid(1, 1) = gbcP(bgp(ccp, 3))
            
            ' Y-Flip¿¡ µû¸¥ ½ºÄµ¶óÀÎ ¿ÀÇÁ¼Â °è»ê
            If yflip Then
                memptr = memptr + (14 - yoffset * 2)
            Else
                memptr = memptr + (yoffset * 2)
            End If
            
            ' VRAM Bank(vrm)¿¡¼­ 2¹ÙÀÌÆ® ÀÐ±â (X-Flip Àû¿ë)
            If xflip Then
                mv1 = mir(RAM(memptr + 1, vrm))
                mv2 = mir(RAM(memptr, vrm))
            Else
                mv1 = RAM(memptr + 1, vrm)
                mv2 = RAM(memptr, vrm)
            End If
            
            ' ÇÈ¼¿ Âï±â
         
            
            '''''''''''''''''
            If x >= 0 And x <= 152 Then
                Vram(x + 7, curline) = ccid(mv1 And 1, mv2 And 1)
                Vram(x + 6, curline) = ccid((mv1 \ 2) And 1, (mv2 \ 2) And 1)
                Vram(x + 5, curline) = ccid((mv1 \ 4) And 1, (mv2 \ 4) And 1)
                Vram(x + 4, curline) = ccid((mv1 \ 8) And 1, (mv2 \ 8) And 1)
                Vram(x + 3, curline) = ccid((mv1 \ 16) And 1, (mv2 \ 16) And 1)
                Vram(x + 2, curline) = ccid((mv1 \ 32) And 1, (mv2 \ 32) And 1)
                Vram(x + 1, curline) = ccid((mv1 \ 64) And 1, (mv2 \ 64) And 1)
                Vram(x, curline) = ccid((mv1 \ 128) And 1, (mv2 \ 128) And 1)
                
               
            
            Else
                For px = 7 To 0 Step -1
                    scrX = x + px
                    If scrX >= 0 And scrX < 160 Then
                        Vram(scrX, curline) = ccid(mv1 And 1, mv2 And 1)
                    End If
                    mv1 = mv1 \ 2
                    mv2 = mv2 \ 2
                Next px
            End If
            
            ''''''''''''''''''''''
            
            
                
        Next x
    End If
    
    
    
    
    ''''''''''''''''''''''
        
    
    'Draw Sprites
If (RAM(65344, 0) And 2) And objv Then
    If (RAM(65344, 0) And 4) = 0 Then
        SpriteY = 7
    Else
        SpriteY = 15
    End If
    For tilemap = 65180 To 65024 Step -4
        y = RAM(tilemap, 0) - 16
        x = RAM(tilemap + 1, 0) - 8
        If y <= curline And y + SpriteY >= curline And x > -8 And x < 160 Then
        
        If SpriteY = 7 Then tileptr = readM(tilemap + 2) * 16 Else tileptr = (RAM(tilemap + 2, 0) And 254) * 16 'Get pointer to tile
        TCol = -((RAM(tilemap + 3, 0) And 128) > 0)
        vf = RAM(tilemap + 3, 0) And 32
        vrm = (RAM(tilemap + 3, 0) And 8) \ 8
        ccp = RAM(tilemap + 3, 0) And 7
        
        'init palete
        ccid(0, 0) = gbcP(objp(ccp, 0))
        ccid(0, 1) = gbcP(objp(ccp, 1))
        ccid(1, 0) = gbcP(objp(ccp, 2))
        ccid(1, 1) = gbcP(objp(ccp, 3))
        memptr = 32768 + tileptr
        
        If (RAM(tilemap + 3, 0) And 64) Then memptr = memptr + SpriteY * 2 - (curline - y) * 2 Else memptr = memptr + (curline - y) * 2
        If vf Then mv1 = mir(RAM(memptr + 1, vrm)): mv2 = mir(RAM(memptr, vrm)) Else mv1 = RAM(memptr + 1, vrm): mv2 = RAM(memptr, vrm)
        
      
        
        If TCol = 0 Then
            If x < 153 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 7, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -7 And x < 154 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 6, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -6 And x < 155 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 5, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -5 And x < 156 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 4, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -4 And x < 157 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 3, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -3 And x < 158 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 2, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -2 And x < 159 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 1, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -1 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x, curline) = ccid(mv1 And 1, mv2 And 1)
            
        Else
            If x < 153 Then If colidx(mv1 And 1, mv2 And 1) Then If Vram(x + 7, curline) = tcls((x + 7) \ 8) Then Vram(x + 7, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -7 And x < 154 Then If colidx(mv1 And 1, mv2 And 1) Then If Vram(x + 6, curline) = tcls((x + 6) \ 8) Then Vram(x + 6, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -6 And x < 155 Then If colidx(mv1 And 1, mv2 And 1) Then If Vram(x + 5, curline) = tcls((x + 5) \ 8) Then Vram(x + 5, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -5 And x < 156 Then If colidx(mv1 And 1, mv2 And 1) Then If Vram(x + 4, curline) = tcls((x + 4) \ 8) Then Vram(x + 4, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -4 And x < 157 Then If colidx(mv1 And 1, mv2 And 1) Then If Vram(x + 3, curline) = tcls((x + 3) \ 8) Then Vram(x + 3, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -3 And x < 158 Then If colidx(mv1 And 1, mv2 And 1) Then If Vram(x + 2, curline) = tcls((x + 2) \ 8) Then Vram(x + 2, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -2 And x < 159 Then If colidx(mv1 And 1, mv2 And 1) Then If Vram(x + 1, curline) = tcls((x + 1) \ 8) Then Vram(x + 1, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -1 Then If colidx(mv1 And 1, mv2 And 1) Then If Vram(x, curline) = tcls(x \ 8) Then Vram(x, curline) = ccid(mv1 And 1, mv2 And 1)
            
        End If
        

    End If
               
                
    Next tilemap
   End If
   
   
End Sub



Sub Drawline_0() 'Using Api and SetBits/StrechBits
curline = RAM(65348, 0)
If curline = lastline Then Exit Sub
lastline = curline
    ' Draw Background
    ' Get BG & window Tile Pattern Data Address
    If RAM(65344, 0) And 16 Then
        tileData = 32768
    Else
        tileData = 34816
    End If
If bgv Then
    ' Get BG Tile Table Address
    If RAM(65344, 0) And 8 Then
        tilemap = 39936
        tms = 39936
    Else
        tilemap = 38912
        tms = 38912
    End If
    tileend = tilemap + 1023
    xoffset = RAM(65347, 0)
    yoffset = RAM(65346, 0) + curline
    xs = xoffset \ 8
    ys = yoffset \ 8
    yoffset = yoffset And 7
    xoffset = -(xoffset And 7)
    
    For x = xoffset To 159 Step 8
        tiletmp = tilemap + ys * 32 + xs
        If tiletmp > tileend Then tiletmp = tiletmp - 1024
        If tileData = 32768 Then           ' Tile Data @ &H8800-&h97FF is 128ed
            tileptr = RAM(tiletmp, 0) * 16             'Get pointer to tile
        Else
            tileptr = (RAM(tiletmp, 0) Xor 128) * 16
        End If
        bgat = RAM(tiletmp, 1)
        ccp = bgat And 7
        tcls(x \ 8) = gbcP(bgp(ccp, 0))
        vrm = (bgat And 8) \ 8
        xflip = (bgat And 32) \ 32: yflip = (bgat And 64) \ 64
        ccid(0, 0) = gbcP(bgp(ccp, 0))
        ccid(0, 1) = gbcP(bgp(ccp, 1))
        ccid(1, 0) = gbcP(bgp(ccp, 2))
        ccid(1, 1) = gbcP(bgp(ccp, 3))
        If yflip Then memptr = tileData + tileptr + 14 - (yoffset And 7) * 2 Else memptr = tileData + tileptr + (yoffset And 7) * 2
        If xflip Then mv1 = mir(RAM(memptr + 1, vrm)): mv2 = mir(RAM(memptr, vrm)) Else mv1 = RAM(memptr + 1, vrm): mv2 = RAM(memptr, vrm)
        xs = (xs + 1) Mod 32
        
        If x > -1 And x < 153 Then
        Vram(x + 7, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        Vram(x + 6, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        Vram(x + 5, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        Vram(x + 4, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        Vram(x + 3, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        Vram(x + 2, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        Vram(x + 1, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        Vram(x, curline) = ccid(mv1 And 1, mv2 And 1)
        Else
        If x < 153 Then Vram(x + 7, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        If x > -7 And x < 154 Then Vram(x + 6, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        If x > -6 And x < 155 Then Vram(x + 5, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        If x > -5 And x < 156 Then Vram(x + 4, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        If x > -4 And x < 157 Then Vram(x + 3, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        If x > -3 And x < 158 Then Vram(x + 2, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        If x > -2 And x < 159 Then Vram(x + 1, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        If x > -1 Then Vram(x, curline) = ccid(mv1 And 1, mv2 And 1)
        End If
        
    Next x
    End If
    
    
        'Draw Window
    
If (RAM(65344, 0) And 32) = 32 And wv And curline >= RAM(65354, 0) And RAM(65355, 0) < 167 Then
    ' Get window Tile Table Address
    If RAM(65344, 0) And 64 Then
        tilemap = 39936
    Else
        tilemap = 38912
    End If
    yoffset = curline - RAM(65354, 0)
    tilemap = tilemap + (yoffset \ 8) * 32
    yoffset = yoffset And 7
    For x = RAM(65355, 0) - 7 To 159 Step 8
        If tileData = 32768 Then           ' Tile Data @ &H8800-&h97FF is 128ed
            tileptr = RAM(tilemap, 0) * 16             'Get pointer to tile
        Else
            tileptr = (RAM(tilemap, 0) Xor 128) * 16
        End If
        bgat = RAM(tilemap, 1)
        ccp = bgat And 7
        vrm = (bgat And 8) \ 8
        xflip = (bgat And 32) \ 32: yflip = (bgat And 64) \ 64
        ccid(0, 0) = gbcP(bgp(ccp, 0))
        ccid(0, 1) = gbcP(bgp(ccp, 1))
        ccid(1, 0) = gbcP(bgp(ccp, 2))
        ccid(1, 1) = gbcP(bgp(ccp, 3))
        If yflip Then memptr = tileData + tileptr + 14 - yoffset * 2 Else memptr = tileData + tileptr + yoffset * 2
        If xflip Then mv1 = mir(RAM(memptr + 1, vrm)): mv2 = mir(RAM(memptr, vrm)) Else mv1 = RAM(memptr + 1, vrm): mv2 = RAM(memptr, vrm)
        
        If x > -1 And x < 153 Then
        Vram(x + 7, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        Vram(x + 6, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        Vram(x + 5, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        Vram(x + 4, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        Vram(x + 3, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        Vram(x + 2, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        Vram(x + 1, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        Vram(x, curline) = ccid(mv1 And 1, mv2 And 1)
        Else
        If x < 154 Then Vram(x + 7, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        If x > -7 And x < 154 Then Vram(x + 6, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        If x > -6 And x < 155 Then Vram(x + 5, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        If x > -5 And x < 156 Then Vram(x + 4, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        If x > -4 And x < 157 Then Vram(x + 3, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        If x > -3 And x < 158 Then Vram(x + 2, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        If x > -2 And x < 159 Then Vram(x + 1, curline) = ccid(mv1 And 1, mv2 And 1)
        mv1 = mv1 \ 2: mv2 = mv2 \ 2
        If x > -1 Then Vram(x, curline) = ccid(mv1 And 1, mv2 And 1)
        End If
        
        
        
        tilemap = tilemap + 1
    Next x
End If
    
    'Draw Sprites
If (RAM(65344, 0) And 2) And objv Then
    If (RAM(65344, 0) And 4) = 0 Then
        SpriteY = 7
    Else
        SpriteY = 15
    End If
    For tilemap = 65180 To 65024 Step -4
        y = RAM(tilemap, 0) - 16
        x = RAM(tilemap + 1, 0) - 8
        If y <= curline And y + SpriteY >= curline And x > -8 And x < 160 Then
        
        If SpriteY = 7 Then tileptr = readM(tilemap + 2) * 16 Else tileptr = (RAM(tilemap + 2, 0) And 254) * 16 'Get pointer to tile
        TCol = -((RAM(tilemap + 3, 0) And 128) > 0)
        vf = RAM(tilemap + 3, 0) And 32
        vrm = (RAM(tilemap + 3, 0) And 8) \ 8
        ccp = RAM(tilemap + 3, 0) And 7
        'init palete
        ccid(0, 0) = gbcP(objp(ccp, 0))
        ccid(0, 1) = gbcP(objp(ccp, 1))
        ccid(1, 0) = gbcP(objp(ccp, 2))
        ccid(1, 1) = gbcP(objp(ccp, 3))
        memptr = 32768 + tileptr
        
        If (RAM(tilemap + 3, 0) And 64) Then memptr = memptr + SpriteY * 2 - (curline - y) * 2 Else memptr = memptr + (curline - y) * 2
        If vf Then mv1 = mir(RAM(memptr + 1, vrm)): mv2 = mir(RAM(memptr, vrm)) Else mv1 = RAM(memptr + 1, vrm): mv2 = RAM(memptr, vrm)
        
        If TCol = 0 Then
            If x < 153 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 7, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -7 And x < 154 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 6, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -6 And x < 155 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 5, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -5 And x < 156 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 4, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -4 And x < 157 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 3, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -3 And x < 158 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 2, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -2 And x < 159 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x + 1, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -1 Then If colidx(mv1 And 1, mv2 And 1) Then Vram(x, curline) = ccid(mv1 And 1, mv2 And 1)
            
        Else
            If x < 153 Then If colidx(mv1 And 1, mv2 And 1) Then If Vram(x + 7, curline) = tcls((x + 7) \ 8) Then Vram(x + 7, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -7 And x < 154 Then If colidx(mv1 And 1, mv2 And 1) Then If Vram(x + 6, curline) = tcls((x + 6) \ 8) Then Vram(x + 6, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -6 And x < 155 Then If colidx(mv1 And 1, mv2 And 1) Then If Vram(x + 5, curline) = tcls((x + 5) \ 8) Then Vram(x + 5, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -5 And x < 156 Then If colidx(mv1 And 1, mv2 And 1) Then If Vram(x + 4, curline) = tcls((x + 4) \ 8) Then Vram(x + 4, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -4 And x < 157 Then If colidx(mv1 And 1, mv2 And 1) Then If Vram(x + 3, curline) = tcls((x + 3) \ 8) Then Vram(x + 3, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -3 And x < 158 Then If colidx(mv1 And 1, mv2 And 1) Then If Vram(x + 2, curline) = tcls((x + 2) \ 8) Then Vram(x + 2, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -2 And x < 159 Then If colidx(mv1 And 1, mv2 And 1) Then If Vram(x + 1, curline) = tcls((x + 1) \ 8) Then Vram(x + 1, curline) = ccid(mv1 And 1, mv2 And 1)
            mv1 = mv1 \ 2: mv2 = mv2 \ 2
            If x > -1 Then If colidx(mv1 And 1, mv2 And 1) Then If Vram(x, curline) = tcls(x \ 8) Then Vram(x, curline) = ccid(mv1 And 1, mv2 And 1)
            
        End If
    End If
    Next tilemap
   End If
   
End Sub
