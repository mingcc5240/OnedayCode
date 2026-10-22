Attribute VB_Name = "z80cmd"
'This is a part of tha BasicBoy emulator
'You are not allowed to release modified(or unmodified) versions
'without asking me (Raziel).
'For Suggestions ect please e-mail at :stef_mp@yahoo.gr
'(I know the emulator is NOT OPTIMIZED AT ALL)

'This module contains the emulation of some z80 instructions
'Coments will be added with the next release

'Sory for my bad english ...

Option Explicit
Dim memptr As Long, memptr2 As Long
Public Sub rl(reg8 As Long)
    memptr = (reg8 And 128) = 128
    reg8 = ((reg8 * 2) Or -getC) And 255
    setZ reg8 = 0
    setH False
    setN False
    setC (memptr)
End Sub
'Public Sub rla()
'    memptr = (A And 128) = 128
'    A = ((A * 2) Or -getC) And 255
'    setZ A = 0
'    setN False
'    setH False
'    setC (memptr)
'End Sub

Public Sub rla()
    Dim oldC As Long
    Dim newC As Long
    
    ' 1. 기존 Carry 플래그를 0 또는 1의 정수로 추출
    If getC Then oldC = 1 Else oldC = 0
    
    ' 2. 밀려나갈 Bit 7 저장 (새로운 Carry 값)
    newC = (A \ 128) And 1
    
    ' 3. A 레지스터 1비트 Shift 및 기존 Carry 값을 Bit 0에 삽입
    A = ((A * 2) Or oldC) And 255
    
    ' 4. 플래그 설정
    setC (newC = 1)
    setZ False   ' ★ 무조건 False (setZ A = 0 제거)
    setN False
    setH False
End Sub

Public Sub rlc(reg8 As Long)
    setC ((reg8 And 128) = 128)
    reg8 = ((reg8 * 2) Or -(getC)) And 255
    setZ reg8 = 0
    setH False
    setN False
End Sub

'Public Sub rlca()
'    setC ((A And 128) = 128)
'    A = ((A * 2) Or -getC) And 255
'    setZ A = 0
'    setN False
'    setH False
'End Sub

Public Sub rlca()
    Dim bit7 As Long
    
    ' 1. 기존 A 레지스터의 Bit 7 추출 (0 또는 1)
    bit7 = (A \ 128) And 1
    
    ' 2. A 레지스터 1비트 좌측 Shift 및 기존 Bit 7을 Bit 0 위치에 삽입
    A = ((A * 2) Or bit7) And 255
    
    ' 3. 플래그 설정
    setC (bit7 = 1)  ' 밀려나간 Bit 7을 C 플래그에 세팅
    setZ False       ' ★ 중요: Z 플래그는 결과가 0이어도 무조건 False!
    setN False
    setH False
End Sub

Public Sub rr(reg8 As Long)
    memptr = (reg8 And 1) = 1
    reg8 = (reg8 \ 2) Or (128 * -getC)
    setZ reg8 = 0
    setH False
    setN False
    setC (memptr)
End Sub

'Public Sub rra()
'    memptr = (A And 1) = 1
'    A = (A \ 2) Or (128 * -getC)
'    setZ A = 0
'    setN False
'    setH False
'    setC (memptr)
'End Sub
Public Sub rra()
    Dim oldC As Long
    Dim newC As Long
    
    ' 1. 기존 Carry 플래그를 정수 0 또는 1로 먼저 백업
    If getC Then oldC = 1 Else oldC = 0
    
    ' 2. 밀려나갈 A의 Bit 0을 새 Carry 값으로 저장
    newC = A And 1
    
    ' 3. A 레지스터 우측 1비트 Shift 및 기존 Carry(oldC)를 Bit 7(128) 위치에 삽입
    A = (A \ 2) Or (oldC * 128)
    
    ' 4. 플래그 설정
    setC (newC = 1)
    setZ False        ' ★ 무조건 False
    setN False
    setH False
End Sub

Public Sub rrc(reg8 As Long)
    setC ((reg8 And 1) = 1)
    reg8 = (reg8 \ 2) Or (128 * -getC)
    setZ reg8 = 0
    setH False
    setN False
End Sub
'Public Sub rrca()
'    setC ((A And 1) = 1)
'    A = (A \ 2) Or (128 * -getC)
'    setZ A = 0
'    setN False
'    setH False
'End Sub

Public Sub rrca()
    Dim bit0 As Long
    
    ' 1. 기존 A 레지스터의 Bit 0 추출 (0 또는 1)
    bit0 = A And 1
    
    ' 2. A 레지스터를 우측으로 1비트 Shift하고, 기존 Bit 0을 Bit 7(128) 위치로 이동
    A = (A \ 2) Or (bit0 * 128)
    
    ' 3. 플래그 설정
    setC (bit0 = 1)   ' 밀려나간 Bit 0을 C 플래그에 저장
    setZ False        ' ★ 무조건 False (Z 플래그 세팅 제거)
    setN False
    setH False
End Sub

Public Sub sla(reg8 As Long)
    setC ((reg8 And 128) = 128)
    reg8 = (reg8 * 2) And 255
    setZ reg8 = 0
    setH False
    setN False
End Sub
Public Sub sra(reg8 As Long)
    setC ((reg8 And 1) = 1)
    reg8 = (reg8 \ 2) Or (reg8 And 128)
    setZ reg8 = 0
    setH False
    setN False
End Sub
Public Sub srl(reg8 As Long)
    setC ((reg8 And 1) = 1)
    reg8 = reg8 \ 2
    setZ reg8 = 0
    setH False
    setN False
End Sub
Public Sub zsub(reg8 As Long)
    memptr = A - reg8
    memptr2 = memptr And 255
    setZ memptr2 = 0
    setC A < memptr2
    setH ((A And 15) < (memptr2 And 15))
    setN True
    A = memptr2
End Sub

'Public Sub sbc(reg8 As Long)
'    memptr2 = -getC
'    memptr = (A - reg8 - memptr2) And 255
'    setZ memptr = 0
'    setC A < memptr
'    setH (A And &HF&) < (memptr And 15)
'    setN True
'    A = memptr
'End Sub

Public Sub sbc(reg8 As Long)
    Dim carryVal As Long
    Dim totalSub As Long
    
    ' 1. Carry 값을 0 또는 1로 변환 (-getC 대신 명시적 처리)
    If getC Then carryVal = 1 Else carryVal = 0
    
    ' 2. 빼야 할 총량 (피연산자 + Carry)
    totalSub = reg8 + carryVal
    
    ' 3. H (Half-Carry) 플래그: 하위 4비트 빌림(Underflow) 검사
    setH (A And 15) < ((reg8 And 15) + carryVal)
    
    ' 4. C (Carry) 플래그: 8비트 전체 빌림(Underflow) 검사
    setC A < totalSub
    
    ' 5. N 플래그 (뺄셈이므로 Always True)
    setN True
    
    ' 6. A 레지스터 갱신 및 Z (Zero) 플래그 설정
    A = (A - totalSub) And 255
    setZ (A = 0)
End Sub

Public Sub adc(reg8 As Long)
    memptr = -getC
    memptr2 = (A + reg8 + memptr) And 255
    setZ memptr2 = 0
    setC ((A + reg8 + memptr) And &H100) <> 0&
    setH (((A And &HF&) + (reg8 And &HF&) + memptr) And 16) <> 0&
    setN False
    A = memptr2
End Sub

Public Sub add(reg8 As Long)
    memptr = (A + reg8) And &HFF&
    setZ (memptr = 0&)
    setC ((A + reg8) And &H100) <> 0&
    setH ((((A And &HF&) + (reg8 And &HF&)) And 16) = 16)
    setN False
    A = memptr
End Sub

Sub push(reg8 As Long)
sp = sp - 1
WriteM sp, reg8
End Sub

Sub pop(reg8 As Long)
reg8 = readM(sp)
sp = sp + 1
End Sub

Sub zand(Val As Long)
A = A And Val
setZ A = 0
setN False
setC False
setH True
End Sub
Sub zor(Val As Long)
A = A Or Val
setZ A = 0
setN False
setH False
setC False
End Sub
Sub zxor(Val As Long)
A = A Xor Val
setZ A = 0
setN False
setH False
setC False
End Sub
Sub cp(Val As Long)
setC A < Val
setH (A And 15) < (Val And 15)
setZ A = Val
setN True
End Sub

'Sub dec(reg8 As Long)
'memptr = reg8
'reg8 = reg8 - 1
'reg8 = reg8 And 255
'setH ((reg8 And 15) < (memptr And 15))
'setZ reg8 = 0
'setN True
'End Sub

'Sub dec16(reg81 As Long, reg82 As Long)
'reg82 = reg82 - 1
'reg81 = reg81 + (reg82 < 0)
'reg81 = reg81 And 255
'reg82 = reg82 And 255
'End Sub

' --- 8비트 DEC (DEC B, C, D, E, H, L, A 등) ---
Sub dec(ByRef reg8 As Long)
    Dim origVal As Long
    origVal = reg8

    ' 1. H 플래그: 연산 전 하위 4비트가 0일 때 1을 빼면 Bit 4 빌림(Underflow) 발생
    setH ((origVal And 15) = 0)
    
    ' 2. N 플래그 설정 (뺄셈이므로 Always True)
    setN True
    
    ' ★ C 플래그는 건드리지 않음! (기존 Carry 상태 유지)

    ' 3. 레지스터 값 1 감소 및 8비트 마스킹
    reg8 = (origVal - 1) And 255
    
    ' 4. Z 플래그 설정
    setZ (reg8 = 0)
End Sub


' --- 16비트 DEC (DEC BC, DE, HL, SP) ---
Sub dec16(ByRef reg81 As Long, ByRef reg82 As Long)
    Dim val16 As Long
    
    ' 상위(reg81), 하위(reg82)를 16비트 값으로 합친 후 1 감소
    val16 = ((reg81 * 256) + reg82 - 1) And 65535
    
    ' 상위/하위 바이트 분할 반영
    reg81 = val16 \ 256
    reg82 = val16 And 255
    
    ' ★ 16비트 DEC는 Z, N, H, C 등 모든 플래그를 절대로 변경하지 않습니다!
End Sub

Sub inc(reg8 As Long)
reg8 = reg8 + 1
reg8 = reg8 And 255
setH ((reg8 And 15) = 0)
setZ reg8 = 0
setN False
End Sub
Sub inc16(reg81 As Long, reg82 As Long)
reg82 = reg82 + 1
reg81 = reg81 - (reg82 > 255)
reg81 = reg81 And 255: reg82 = reg82 And 255
End Sub

'Sub addHL(r1h As Long, r1l As Long)
'setC ((H * 256 + L) + (r1h * 256 + r1l)) > 65535
'setH (((H * 256 + L) And 4095) + ((r1h * 256 + r1l) And 4095)) > 4095
'L = L + r1l
'H = H + r1h
'If L > 255 Then H = H + 1
'L = L And 255: H = H And 255
'setN False
'End Sub

'Sub addSP(Value As Long)
'If Value > 127 Then Value = Value - 256
'memptr = sp + Value
'memptr = memptr And 65535
'        If Value > 0 Then
'          setC sp > memptr
'          setH ((sp Xor Value Xor memptr) And 4096) > 0
'          sp = memptr
'        Else
'          setC sp < memptr
'          setH ((sp Xor Value Xor memptr) And 4096) > 0
'          sp = memptr
'        End If
'        setZ False
'        setN False
'End Sub

' --- 2. addHL 함수 수정 ---
Sub addHL(r1h As Long, r1l As Long)
    Dim hlVal As Long
    Dim r1Val As Long
    Dim sum As Long

    ' 16비트 값으로 변환
    hlVal = (H * 256) + L
    r1Val = (r1h * 256) + r1l

    ' H, C 플래그 계산
    setH ((hlVal And 4095) + (r1Val And 4095)) > 4095
    setC (hlVal + r1Val) > 65535
    setN False   ' Z 플래그는 기존 상태를 그대로 유지합니다.

    ' 결과값 계산 및 레지스터 분할 반영
    sum = (hlVal + r1Val) And 65535
    H = sum \ 256
    L = sum And 255
End Sub

Sub addSP(Value As Long)
    ' 1. 원본 8비트 값(0~255)과 SP의 하위 8비트 추출 (플래그 계산용)
    Dim rawByte As Long
    Dim spLow As Long
    rawByte = Value And 255
    spLow = sp And 255

    ' 2. H 플래그 (Bit 3 오버플로), C 플래그 (Bit 7 오버플로) 계산
    setH ((spLow And 15) + (rawByte And 15)) > 15
    setC (spLow + rawByte) > 255

    ' 3. e8 부호 확장 (-128 ~ 127) 및 SP 값 계산
    If Value > 127 Then Value = Value - 256
    sp = (sp + Value) And 65535

    ' 4. Z, N 플래그 리셋
    setZ False
    setN False
End Sub

Sub swap(reg8 As Long)
reg8 = (reg8 \ 16) Or ((reg8 And 15) * 16)
setZ reg8 = 0
setN False
setH False
setC False
End Sub
'Sub daa()
'        If Not GetN Then
'           If ((A And 15) >= 10 Or getH) Then A = A + 6
'           If ((A And 240) >= 160 Or getC) Then A = A + 96: setC True
'        Else
'           If ((A And 15) >= 10 Or getH) Then A = A - 6
'           If ((A And 240) >= 160 Or getC) Then A = A - 96: setC True
'        End If
'        A = A And 255
'setZ A = 0
'setH False
'End Sub

Sub daa()
    Dim u As Integer
    Dim setCarry As Boolean
    
    u = 0
    setCarry = False

    If Not GetN Then
        ' 덧셈 연산 후 보정 (OrElse -> Or 변경)
        If getH Or ((A And &HF) > 9) Then
            u = u Or &H6
        End If
        If getC Or (A > &H99) Then
            u = u Or &H60
            setCarry = True
        End If
        
        A = (CLng(A) + u) And 255
    Else
        ' 뺄셈 연산 후 보정
        If getH Then
            u = u Or &H6
        End If
        If getC Then
            u = u Or &H60
        End If
        
        A = (CLng(A) - u) And 255
    End If

    ' 플래그 갱신
    If setCarry Then setC True
    setH False
    setZ (A = 0)
End Sub

Sub cpl()
A = 255 - A
setH True
setN True
End Sub
'Sub halt()
'   If IME = False Then Exit Sub
'    memptr = RAM(65535, 0) And RAM(65295, 0)    ' AND IE, IF
 '   If memptr = 0 Then pc = pc - 1: Exit Sub                  'If no Interrupt occured exit
    'Process Interrput
    'Push pc
 '   sp = sp - 1
 '   WriteM sp, pc \ 256
 '   sp = sp - 1
 '   WriteM sp, pc And 255
 '   IME = False
 '   If (memptr And 1) = 1 Then        'V-Blank ?
 '       pc = 64
 '       RAM(65295, 0) = RAM(65295, 0) And 254
 '   ElseIf (memptr And 2) = 2 Then    'LCDC ?
 '       pc = 72
  '      RAM(65295, 0) = RAM(65295, 0) And 253
  '  ElseIf (memptr And 4) = 4 Then    'Timer ?
  '      pc = 80
  '      RAM(65295, 0) = RAM(65295, 0) And 251
  '  ElseIf (memptr And 8) = 8 Then    'Serial ?
  '      pc = 88
  '      RAM(65295, 0) = RAM(65295, 0) And 247
  '  ElseIf (memptr And 16) = 16 Then  'Joypad ?
  '      pc = 96
  '      RAM(65295, 0) = RAM(65295, 0) And 239
  '  End If
'End Sub
Sub halt()
    Dim ieReg As Long
    Dim ifReg As Long
    Dim pending As Long

    ' 1. IE(0xFFFF), IF(0xFF0F) 레지스터 읽기
    ieReg = RAM(65535, 0)
    ifReg = RAM(65295, 0)

    ' 2. 발생 대기 중인 인터럽트 확인 (하위 5비트)
    pending = ieReg And ifReg And 31

    ' 3. 발생한 인터럽트가 없다면 CPU를 HALT 상태(PC 동결)로 유지하고 종료
    If pending = 0 Then
        pc = (pc - 1) And 65535   ' 다음 명령어로 진행하지 않고 현 위치 대기
        Exit Sub
    End If

    ' --- 아래는 인터럽트가 발생하여 HALT가 깨어난 경우 ---

    ' 4. IME가 꺼져(False) 있다면 ISR 점프 없이 HALT만 깨어남 (PC 대기 해제 후 그냥 종료)
    If IME = False Then
        Exit Sub
    End If

    ' 5. IME가 켜져(True) 있다면 스택에 PC를 넣고 인터럽트 Vector로 점프
    IME = False

    ' Push PC
    sp = (sp - 1) And 65535
    WriteM sp, pc \ 256
    sp = (sp - 1) And 65535
    WriteM sp, pc And 255

    ' 우선순위에 맞춰 PC 점프 및 IF 비트 클리어
    If (pending And 1) <> 0 Then         ' V-Blank (0x40)
        pc = 64
        RAM(65295, 0) = RAM(65295, 0) And 254
    ElseIf (pending And 2) <> 0 Then     ' LCD (0x48)
        pc = 72
        RAM(65295, 0) = RAM(65295, 0) And 253
    ElseIf (pending And 4) <> 0 Then     ' Timer (0x50)
        pc = 80
        RAM(65295, 0) = RAM(65295, 0) And 251
    ElseIf (pending And 8) <> 0 Then     ' Serial (0x58)
        pc = 88
        RAM(65295, 0) = RAM(65295, 0) And 247
    ElseIf (pending And 16) <> 0 Then    ' Joypad (0x60)
        pc = 96
        RAM(65295, 0) = RAM(65295, 0) And 239
    End If
End Sub


Sub bit(reg8 As Long, b As Long)
setZ ((reg8 And b) = 0)
setN False
setH True
End Sub
Sub zset(reg8 As Long, b As Long)
reg8 = reg8 Or b
End Sub
Sub res(reg8 As Long, b As Long)
reg8 = reg8 And b
End Sub
Sub jp(Adr As Long, Optional cc As Boolean = True)
If cc Then pc = Adr
End Sub
Sub jr(Val As Long, Optional cc As Boolean = True)
If Val > 127 Then Val = Val - 256
If cc Then pc = pc + Val
End Sub
Sub zcall(Adr As Long, Optional cc As Boolean = True)
If cc Then
sp = sp - 1
WriteM sp, pc \ 256
sp = sp - 1
WriteM sp, pc And 255
pc = Adr
End If
End Sub
Sub rst(Value As Long)
sp = sp - 1
WriteM sp, pc \ 256
sp = sp - 1
WriteM sp, pc And 255
pc = Value
End Sub
Sub ret(Optional cc As Boolean = True)
If cc Then pc = readM(sp) + readM(sp + 1) * 256: sp = sp + 2
End Sub
Sub reti()
pc = readM(sp) + readM(sp + 1) * 256
sp = sp + 2
IME = True
End Sub
