Attribute VB_Name = "Sound"
'Attribute VB_Name = "Sound"
' =========================================================================
' BasicBoy Emulator Sound Module for Visual Basic 6.0
' 16-bit Stereo Synthesizer with Circular Ring Buffer
' =========================================================================

Option Explicit

Private Type WAVEFORMATEX
    wFormatTag As Integer
    nChannels As Integer
    nSamplesPerSec As Long
    nAvgBytesPerSec As Long
    nBlockAlign As Integer
    wBitsPerSample As Integer
    cbSize As Integer
End Type

Private Type WAVEHDR
    lpData As Long
    dwBufferLength As Long
    dwBytesRecorded As Long
    dwUser As Long
    dwFlags As Long
    dwLoops As Long
    lpNext As Long
    Reserved As Long
End Type

Private Const WHDR_DONE As Long = &H1
Private Const WHDR_PREPARED As Long = &H2

Private Declare Function waveOutOpen Lib "winmm.dll" ( _
    ByRef phwo As Long, ByVal uDeviceID As Long, ByRef pwfx As WAVEFORMATEX, _
    ByVal dwCallback As Long, ByVal dwInstance As Long, ByVal fdwOpen As Long) As Long

Private Declare Function waveOutPrepareHeader Lib "winmm.dll" ( _
    ByVal hwo As Long, ByRef pwh As WAVEHDR, ByVal cbwh As Long) As Long

Private Declare Function waveOutWrite Lib "winmm.dll" ( _
    ByVal hwo As Long, ByRef pwh As WAVEHDR, ByVal cbwh As Long) As Long

Private Declare Function waveOutUnprepareHeader Lib "winmm.dll" ( _
    ByVal hwo As Long, ByRef pwh As WAVEHDR, ByVal cbwh As Long) As Long

Private Declare Function waveOutClose Lib "winmm.dll" (ByVal hwo As Long) As Long
Private Declare Function waveOutReset Lib "winmm.dll" (ByVal hwo As Long) As Long

Private Const SAMPLE_RATE As Long = 44100
' 1            크  : 1024      (   23.2ms)
Private Const BUFFER_SAMPLES As Long = 3 * 1024 + 256 '1024
' 16  트 Stereo =    척  4    트 (Left 2Byte + Right 2Byte)
Private Const BUFFER_BYTES As Long = BUFFER_SAMPLES * 4

'                      (8        =    185ms       큐            )
Private Const NUM_BUFFERS As Long = 2

Private hWaveOut As Long
Private waveHeader(0 To NUM_BUFFERS - 1) As WAVEHDR
Private Buffer(0 To NUM_BUFFERS - 1, 0 To (BUFFER_SAMPLES * 2) - 1) As Integer
Private CurrentBufferIdx As Long

' --- APU Registers & States ---
Private DutyPatterns(0 To 3, 0 To 7) As Byte

' Channel 1
Private Ch1_Enable As Boolean
Private Ch1_Freq As Long, Ch1_Vol As Byte, Ch1_DutyIdx As Long, Ch1_Phase As Double, Ch1_RawFreq As Long

' Channel 2
Private Ch2_Enable As Boolean
Private Ch2_Freq As Long, Ch2_Vol As Byte, Ch2_DutyIdx As Long, Ch2_Phase As Double, Ch2_RawFreq As Long

' Channel 3 (Wave)
Private Ch3_Enable As Boolean
Private Ch3_Freq As Long, Ch3_VolShift As Byte, Ch3_Phase As Single, Ch3_RawFreq As Long
Private WaveRAM(0 To 15) As Byte
' 추가: 0~31 인덱스를 즉시 읽을 수 있는 4-bit 샘플 캐시
Private WaveSamples(0 To 31) As Single


' Channel 4 (Noise)
Private Ch4_Enable As Boolean
Private Ch4_Vol As Byte, Ch4_Freq As Single, Ch4_Phase As Single, Ch4_LFSR As Long, Ch4_Step7 As Boolean

' Panning & Master Control (NR50, NR51, NR52)
Global SoundEnabled As Boolean
Private NR50_VolL As Byte, NR50_VolR As Byte
Private NR51_Pan As Byte

Private PrevInL As Single, PrevOutL As Single
Private PrevInR As Single, PrevOutR As Single

' Channel 4 Envelope & Length 변수
Private Ch4_InitialVol As Long      ' 초기 볼륨 (0~15)
Private Ch4_EnvDir As Long          ' 엔벨로프 방향 (0: 감쇠, 1: 증가)
Private Ch4_EnvPeriod As Long       ' 엔벨로프 변경 주기 (0~7)
Private Ch4_EnvTimer As Long        ' 엔벨로프 틱 카운터
Private Ch4_DACOn As Boolean        ' 하드웨어 DAC 켜짐 여부

Private Ch4_Length As Long          ' 길이 카운터 (0~63)
Private Ch4_LengthEnable As Boolean ' 길이 제한 활성화 여부 (NR44 비트 6)
Private Ch1_LengthEnable As Boolean
Private Ch2_LengthEnable As Boolean
Private Ch3_LengthEnable As Boolean
Private SequencerStep As Long


Public Sub InitSound()
    Dim wfx As WAVEFORMATEX
    Dim k As Long
    
    With wfx
        .wFormatTag = 1          ' PCM
        .nChannels = 2            ' Stereo
        .nSamplesPerSec = SAMPLE_RATE
        .wBitsPerSample = 16      ' 16-bit
        .nBlockAlign = 4          ' 2채   * 2    트
        .nAvgBytesPerSec = SAMPLE_RATE * 4
        .cbSize = 0
    End With

    If hWaveOut <> 0 Then CloseSound

    If waveOutOpen(hWaveOut, -1, wfx, 0, 0, 0) = 0 Then
        '              珂 화
        For k = 0 To NUM_BUFFERS - 1
            With waveHeader(k)
                .lpData = VarPtr(Buffer(k, 0))
                .dwBufferLength = BUFFER_BYTES
                .dwBytesRecorded = 0
                .dwUser = 0
                .dwFlags = WHDR_DONE '  珂     쨍                  ( 狗  )     킹
                .dwLoops = 0
            End With
        Next k
        
        CurrentBufferIdx = 0
        SoundEnabled = True
        NR51_Pan = &HFF
        NR50_VolL = 7: NR50_VolR = 7
        Ch4_LFSR = &H7FFF
        
        ' GB APU  溝          Duty Patterns
        DutyPatterns(0, 0) = 0: DutyPatterns(0, 1) = 0: DutyPatterns(0, 2) = 0: DutyPatterns(0, 3) = 0
        DutyPatterns(0, 4) = 0: DutyPatterns(0, 5) = 0: DutyPatterns(0, 6) = 0: DutyPatterns(0, 7) = 1
        
        DutyPatterns(1, 0) = 1: DutyPatterns(1, 1) = 0: DutyPatterns(1, 2) = 0: DutyPatterns(1, 3) = 0
        DutyPatterns(1, 4) = 0: DutyPatterns(1, 5) = 0: DutyPatterns(1, 6) = 0: DutyPatterns(1, 7) = 1
        
        DutyPatterns(2, 0) = 1: DutyPatterns(2, 1) = 0: DutyPatterns(2, 2) = 0: DutyPatterns(2, 3) = 0
        DutyPatterns(2, 4) = 0: DutyPatterns(2, 5) = 1: DutyPatterns(2, 6) = 1: DutyPatterns(2, 7) = 1
        
        DutyPatterns(3, 0) = 0: DutyPatterns(3, 1) = 1: DutyPatterns(3, 2) = 1: DutyPatterns(3, 3) = 1
        DutyPatterns(3, 4) = 1: DutyPatterns(3, 5) = 1: DutyPatterns(3, 6) = 1: DutyPatterns(3, 7) = 0
    End If
End Sub

Public Sub CloseSound()
    Dim k As Long
    If hWaveOut <> 0 Then
        Call waveOutReset(hWaveOut)
        For k = 0 To NUM_BUFFERS - 1
            If (waveHeader(k).dwFlags And WHDR_PREPARED) <> 0 Then
                Call waveOutUnprepareHeader(hWaveOut, waveHeader(k), LenB(waveHeader(k)))
            End If
        Next k
        Call waveOutClose(hWaveOut)
        hWaveOut = 0
    End If
End Sub

Public Sub updatesnd1(clc As Long)
    If Not SoundEnabled Or hWaveOut = 0 Then Exit Sub

    ' 버퍼 재생 완료 여부 확인
    If (waveHeader(CurrentBufferIdx).dwFlags And WHDR_DONE) = 0 Then Exit Sub

    If (waveHeader(CurrentBufferIdx).dwFlags And WHDR_PREPARED) <> 0 Then
        Call waveOutUnprepareHeader(hWaveOut, waveHeader(CurrentBufferIdx), LenB(waveHeader(CurrentBufferIdx)))
    End If

    Dim i As Long
    Dim ch1Sig As Single, ch2Sig As Single, ch3Sig As Single, ch4Sig As Single
    Dim outL As Single, outR As Single
    Dim sampleRateF As Single: sampleRateF = CSng(SAMPLE_RATE)
    Dim bufIdx As Long: bufIdx = 0

    ' 채널별 1단계당 통일된 기본 게인 (최대 볼륨 15 * 4채널 합산 시 약 30,000 수준 매핑)
    Const BASE_GAIN As Single = 500#

    For i = 0 To BUFFER_SAMPLES - 1
        ch1Sig = 0!: ch2Sig = 0!: ch3Sig = 0!: ch4Sig = 0!

        ' --- Channel 1 (Square 1) ---
        If Ch1_Enable And (Ch1_Freq > 0) And (Ch1_Vol > 0) Then
            Ch1_Phase = Ch1_Phase + (CSng(Ch1_Freq) / sampleRateF)
            If Ch1_Phase >= 1! Then Ch1_Phase = Ch1_Phase - Int(Ch1_Phase)
            
            Dim step1 As Long
            step1 = Int(Ch1_Phase * 8!) And 7
            
            ' 실제 사양: 양극/음극 스윙으로 선명한 사각파 형성
            If DutyPatterns(Ch1_DutyIdx, step1) <> 0 Then
                ch1Sig = CSng(Ch1_Vol) * BASE_GAIN
            Else
                ch1Sig = -CSng(Ch1_Vol) * BASE_GAIN
            End If
        End If

        ' --- Channel 2 (Square 2) ---
        If Ch2_Enable And (Ch2_Freq > 0) And (Ch2_Vol > 0) Then
            Ch2_Phase = Ch2_Phase + (CSng(Ch2_Freq) / sampleRateF)
            If Ch2_Phase >= 1! Then Ch2_Phase = Ch2_Phase - Int(Ch2_Phase)
            
            Dim step2 As Long
            step2 = Int(Ch2_Phase * 8!) And 7
            
            If DutyPatterns(Ch2_DutyIdx, step2) <> 0 Then
                ch2Sig = CSng(Ch2_Vol) * BASE_GAIN
            Else
                ch2Sig = -CSng(Ch2_Vol) * BASE_GAIN
            End If
        End If

        ' --- Channel 3 (Wave: 계단식 하드웨어 DAC 복원) ---
        ' 보간(Interpolation)을 제거해야 원본 특유의 쨍하고 맑은 배음이 유지됩니다.
        If Ch3_Enable And (Ch3_Freq > 0) And (Ch3_VolShift > 0) Then
            Ch3_Phase = Ch3_Phase + (CSng(Ch3_Freq) / sampleRateF)
            If Ch3_Phase >= 1! Then Ch3_Phase = Ch3_Phase - Int(Ch3_Phase)
            
            Dim waveIdx As Long
            waveIdx = Int(Ch3_Phase * 32!) And 31
            
            ' 4-bit 샘플 (0~15) 획득 및 볼륨 시프트 적용
            Dim rawSample As Long
            rawSample = GetWaveSample(waveIdx)
            
            Select Case Ch3_VolShift
                Case 1: rawSample = rawSample           ' 100%
                Case 2: rawSample = rawSample \ 2       ' 50%
                Case 3: rawSample = rawSample \ 4       ' 25%
                Case Else: rawSample = 0                ' Mute
            End Select
            
            ' 중심점을 7.5로 두고 진폭 스케일링
            ch3Sig = CSng(rawSample - 7.5!) * (BASE_GAIN * 1.8!)
        End If

        ' --- Channel 4 (Noise) ---
        If Ch4_Enable And (Ch4_Freq > 0!) And (Ch4_Vol > 0) Then
            Ch4_Phase = Ch4_Phase + (CSng(Ch4_Freq) / sampleRateF)
            
            If Ch4_Phase >= 1! Then
                Dim shifts As Long
                shifts = Int(Ch4_Phase)
                Ch4_Phase = Ch4_Phase - CSng(shifts)
                If shifts > 16 Then shifts = 16 ' 초고주파 루프 지연 방지
                
                Dim sCount As Long
                For sCount = 1 To shifts
                    Dim bit0 As Long, bit1 As Long, resultBit As Long
                    bit0 = Ch4_LFSR And 1
                    bit1 = (Ch4_LFSR \ 2) And 1
                    resultBit = bit0 Xor bit1
                    
                    Ch4_LFSR = (Ch4_LFSR \ 2) And &H3FFF
                    Ch4_LFSR = Ch4_LFSR Or (resultBit * 16384)
                    
                    If Ch4_Step7 Then
                        Ch4_LFSR = (Ch4_LFSR And &H7FBF) Or (resultBit * 64)
                    End If
                Next sCount
            End If
            
            ' 비트 0이 0일 때 High, 1일 때 Low 출력 (볼륨 레벨 매칭)
            If (Ch4_LFSR And 1) = 0 Then
                ch4Sig = CSng(Ch4_Vol) * BASE_GAIN
            Else
                ch4Sig = -CSng(Ch4_Vol) * BASE_GAIN
            End If
        End If

        ' --- Stereo Panning Matrix (NR51) ---
        outL = 0!: outR = 0!

        If (NR51_Pan And &H10) <> 0 Then outL = outL + ch1Sig
        If (NR51_Pan And &H20) <> 0 Then outL = outL + ch2Sig
        If (NR51_Pan And &H40) <> 0 Then outL = outL + ch3Sig
        If (NR51_Pan And &H80) <> 0 Then outL = outL + ch4Sig

        If (NR51_Pan And &H1) <> 0 Then outR = outR + ch1Sig
        If (NR51_Pan And &H2) <> 0 Then outR = outR + ch2Sig
        If (NR51_Pan And &H4) <> 0 Then outR = outR + ch3Sig
        If (NR51_Pan And &H8) <> 0 Then outR = outR + ch4Sig

        ' Master Volume Apply (NR50: 0~7 -> 1~8)
        outL = outL * (CSng(NR50_VolL + 1) / 8!)
        outR = outR * (CSng(NR50_VolR + 1) / 8!)

        ' --- DC High-Pass Filter (멍청한 저음 웅웅거림 및 팝 노이즈 차단) ---
        ' 모듈 상단에 선언: Private PrevInL As Single, PrevOutL As Single, PrevInR As Single, PrevOutR As Single
        Dim filteredL As Single, filteredR As Single
        filteredL = 0.995! * (PrevOutL + outL - PrevInL)
        filteredR = 0.995! * (PrevOutR + outR - PrevInR)
        PrevInL = outL: PrevOutL = filteredL
        PrevInR = outR: PrevOutR = filteredR

        ' 16-bit PCM Clamping
        If filteredL > 32767! Then filteredL = 32767!
        If filteredL < -32768! Then filteredL = -32768!
        If filteredR > 32767! Then filteredR = 32767!
        If filteredR < -32768! Then filteredR = -32768!

        Buffer(CurrentBufferIdx, bufIdx) = CInt(filteredL)
        Buffer(CurrentBufferIdx, bufIdx + 1) = CInt(filteredR)
        bufIdx = bufIdx + 2
    Next i

    Call waveOutPrepareHeader(hWaveOut, waveHeader(CurrentBufferIdx), LenB(waveHeader(CurrentBufferIdx)))
    Call waveOutWrite(hWaveOut, waveHeader(CurrentBufferIdx), LenB(waveHeader(CurrentBufferIdx)))
    CurrentBufferIdx = (CurrentBufferIdx + 1) Mod NUM_BUFFERS
End Sub

Public Sub updatesnd0(clc As Long)
    If Not SoundEnabled Or hWaveOut = 0 Then Exit Sub

    '    [                堉�     ]
    ' 타      方               치           (WHDR_DONE  첨        ) 見     綬�  풍街莩求 .
    If (waveHeader(CurrentBufferIdx).dwFlags And WHDR_DONE) = 0 Then Exit Sub

    '           狗
    If (waveHeader(CurrentBufferIdx).dwFlags And WHDR_PREPARED) <> 0 Then
        Call waveOutUnprepareHeader(hWaveOut, waveHeader(CurrentBufferIdx), LenB(waveHeader(CurrentBufferIdx)))
    End If

    Dim i As Long
    Dim ch1Sig As Double, ch2Sig As Double, ch3Sig As Double, ch4Sig As Double
    Dim outL As Double, outR As Double
    Dim sampleRateF As Double: sampleRateF = CDbl(SAMPLE_RATE)
    Dim bufIdx As Long: bufIdx = 0

    For i = 0 To BUFFER_SAMPLES - 1
        ch1Sig = 0#: ch2Sig = 0#: ch3Sig = 0#: ch4Sig = 0#

        ' --- Channel 1 (Square 1) ---
        If Ch1_Enable And (Ch1_Freq > 0) And (Ch1_Vol > 0) Then
            Ch1_Phase = Ch1_Phase + (CDbl(Ch1_Freq) / sampleRateF)
            If Ch1_Phase >= 1# Then Ch1_Phase = Ch1_Phase - Int(Ch1_Phase)
            
            Dim step1 As Long
            step1 = Int(Ch1_Phase * 8#) And 7
            
            If DutyPatterns(Ch1_DutyIdx, step1) <> 0 Then
                ch1Sig = CDbl(Ch1_Vol) * 400#
            Else
                ch1Sig = -CDbl(Ch1_Vol) * 400#
            End If
        End If

        ' --- Channel 2 (Square 2) ---
        If Ch2_Enable And (Ch2_Freq > 0) And (Ch2_Vol > 0) Then
            Ch2_Phase = Ch2_Phase + (CDbl(Ch2_Freq) / sampleRateF)
            If Ch2_Phase >= 1# Then Ch2_Phase = Ch2_Phase - Int(Ch2_Phase)
            
            Dim step2 As Long
            step2 = Int(Ch2_Phase * 8#) And 7
            
            If DutyPatterns(Ch2_DutyIdx, step2) <> 0 Then
                ch2Sig = CDbl(Ch2_Vol) * 400#
            Else
                ch2Sig = -CDbl(Ch2_Vol) * 400#
            End If
        End If

        ' --- Channel 3 (Wave) ---
        If Ch3_Enable And (Ch3_Freq > 0) And (Ch3_VolShift > 0) Then
            Ch3_Phase = Ch3_Phase + (CDbl(Ch3_Freq) / sampleRateF)
            If Ch3_Phase >= 1# Then Ch3_Phase = Ch3_Phase - Int(Ch3_Phase)
            
            Dim wavePos As Double
            wavePos = Ch3_Phase * 32#
            
            Dim idx0 As Long, idx1 As Long
            Dim frac As Double
            idx0 = Int(wavePos) And 31
            idx1 = (idx0 + 1) And 31
            frac = wavePos - CDbl(Int(wavePos))

            Dim s0 As Double, s1 As Double
            s0 = CDbl(GetWaveSample(idx0)) - 7.5
            s1 = CDbl(GetWaveSample(idx1)) - 7.5
            
            ch3Sig = s0 + (s1 - s0) * frac

            Select Case Ch3_VolShift
                Case 1: ch3Sig = ch3Sig * 300#
                Case 2: ch3Sig = ch3Sig * 150#
                Case 3: ch3Sig = ch3Sig * 75#
                Case Else: ch3Sig = 0#
            End Select
        End If

        ' --- Channel 4 (Noise) ---
        If Ch4_Enable And (Ch4_Freq > 0#) Then
            Ch4_Phase = Ch4_Phase + (CDbl(Ch4_Freq) / sampleRateF)
            
            If Ch4_Phase >= 1# Then
                Dim shifts As Long
                shifts = Int(Ch4_Phase)
                Ch4_Phase = Ch4_Phase - CDbl(shifts)
                
                Dim sCount As Long
                For sCount = 1 To shifts
                    Dim bit0 As Long, bit1 As Long, resultBit As Long
                    bit0 = Ch4_LFSR And 1
                    bit1 = (Ch4_LFSR \ 2) And 1
                    resultBit = bit0 Xor bit1
                    
                    Ch4_LFSR = (Ch4_LFSR \ 2) And &H3FFF
                    Ch4_LFSR = Ch4_LFSR Or (resultBit * 16384)
                    
                    If Ch4_Step7 Then
                        Ch4_LFSR = (Ch4_LFSR And &HFFBF) Or (resultBit * 64)
                    End If
                Next sCount
            End If
            
            If (Ch4_LFSR And 1) = 0 Then
                ch4Sig = CDbl(Ch4_Vol) * 100#
            Else
                ch4Sig = -CDbl(Ch4_Vol) * 100#
            End If
        End If

        ' --- Stereo Panning Matrix (NR51) ---
        outL = 0#: outR = 0#

        If (NR51_Pan And &H10) <> 0 Then outL = outL + ch1Sig
        If (NR51_Pan And &H20) <> 0 Then outL = outL + ch2Sig
        If (NR51_Pan And &H40) <> 0 Then outL = outL + ch3Sig
        If (NR51_Pan And &H80) <> 0 Then outL = outL + ch4Sig

        If (NR51_Pan And &H1) <> 0 Then outR = outR + ch1Sig
        If (NR51_Pan And &H2) <> 0 Then outR = outR + ch2Sig
        If (NR51_Pan And &H4) <> 0 Then outR = outR + ch3Sig
        If (NR51_Pan And &H8) <> 0 Then outR = outR + ch4Sig

        ' Master Volume Apply
        outL = outL * (CDbl(NR50_VolL + 1) / 8#)
        outR = outR * (CDbl(NR50_VolR + 1) / 8#)

        ' 16-bit PCM Clamping
        If outL > 32767# Then outL = 32767#
        If outL < -32768# Then outL = -32768#
        If outR > 32767# Then outR = 32767#
        If outR < -32768# Then outR = -32768#

        Buffer(CurrentBufferIdx, bufIdx) = CInt(outL)
        Buffer(CurrentBufferIdx, bufIdx + 1) = CInt(outR)
        bufIdx = bufIdx + 2
    Next i

    '    [   큐                   絹 ]
    Call waveOutPrepareHeader(hWaveOut, waveHeader(CurrentBufferIdx), LenB(waveHeader(CurrentBufferIdx)))
    Call waveOutWrite(hWaveOut, waveHeader(CurrentBufferIdx), LenB(waveHeader(CurrentBufferIdx)))
    CurrentBufferIdx = (CurrentBufferIdx + 1) Mod NUM_BUFFERS
End Sub

Public Sub updatesnd(clc As Long)
    If Not SoundEnabled Or hWaveOut = 0 Then Exit Sub

    If (waveHeader(CurrentBufferIdx).dwFlags And WHDR_DONE) = 0 Then Exit Sub

   
    If (waveHeader(CurrentBufferIdx).dwFlags And WHDR_PREPARED) <> 0 Then
        Call waveOutUnprepareHeader(hWaveOut, waveHeader(CurrentBufferIdx), LenB(waveHeader(CurrentBufferIdx)))
    End If

    Dim i As Long
    Dim ch1Sig As Double, ch2Sig As Double, ch3Sig As Double, ch4Sig As Double
    Dim outL As Double, outR As Double
    Dim sampleRateF As Double: sampleRateF = CDbl(SAMPLE_RATE)
    Dim bufIdx As Long: bufIdx = 0

    For i = 0 To BUFFER_SAMPLES - 1
        ch1Sig = 0#: ch2Sig = 0#: ch3Sig = 0#: ch4Sig = 0#

        ' --- Channel 1 (Square 1) ---
        If Ch1_Enable And (Ch1_Freq > 0) And (Ch1_Vol > 0) Then
            Ch1_Phase = Ch1_Phase + (CDbl(Ch1_Freq) / sampleRateF)
            If Ch1_Phase >= 1# Then Ch1_Phase = Ch1_Phase - Int(Ch1_Phase)
            
            Dim step1 As Long
            step1 = Int(Ch1_Phase * 8#) And 7
            
            If DutyPatterns(Ch1_DutyIdx, step1) <> 0 Then
                ch1Sig = CDbl(Ch1_Vol) * 400#
            Else
                ch1Sig = -CDbl(Ch1_Vol) * 400#
            End If
        End If

        ' --- Channel 2 (Square 2) ---
        If Ch2_Enable And (Ch2_Freq > 0) And (Ch2_Vol > 0) Then
            Ch2_Phase = Ch2_Phase + (CDbl(Ch2_Freq) / sampleRateF)
            If Ch2_Phase >= 1# Then Ch2_Phase = Ch2_Phase - Int(Ch2_Phase)
            
            Dim step2 As Long
            step2 = Int(Ch2_Phase * 8#) And 7
            
            If DutyPatterns(Ch2_DutyIdx, step2) <> 0 Then
                ch2Sig = CDbl(Ch2_Vol) * 400#
            Else
                ch2Sig = -CDbl(Ch2_Vol) * 400#
            End If
        End If

        ' --- Channel 3 (Wave) ---
       ' If Ch3_Enable And (Ch3_Freq > 0) And (Ch3_VolShift > 0) Then
       '     Ch3_Phase = Ch3_Phase + (CDbl(Ch3_Freq) / sampleRateF)
       '     If Ch3_Phase >= 1# Then Ch3_Phase = Ch3_Phase - Int(Ch3_Phase)
       '
       '     Dim wavePos As Double
       '     wavePos = Ch3_Phase * 32#
       '
       '     Dim idx0 As Long, idx1 As Long
       '     Dim frac As Double
       '     idx0 = Int(wavePos) And 31
       '     idx1 = (idx0 + 1) And 31
       '     frac = wavePos - CDbl(Int(wavePos))

        '    Dim s0 As Double, s1 As Double
        '    s0 = CDbl(GetWaveSample(idx0)) - 7.5
        '    s1 = CDbl(GetWaveSample(idx1)) - 7.5
            
        '    ch3Sig = s0 + (s1 - s0) * frac

     '       Select Case Ch3_VolShift
     '           Case 1: ch3Sig = ch3Sig * 300#
     '           Case 2: ch3Sig = ch3Sig * 150#
     '           Case 3: ch3Sig = ch3Sig * 75#
     '           Case Else: ch3Sig = 0#
     '       End Select
     '   End If
        ''''
        ' --- Channel 3 (Wave) ---
If Ch3_Enable And (Ch3_Freq > 0) And (Ch3_VolShift > 0) Then
    Ch3_Phase = Ch3_Phase + (CSng(Ch3_Freq) / sampleRateF)
    If Ch3_Phase >= 1! Then Ch3_Phase = Ch3_Phase - Int(Ch3_Phase)
    
    Dim waveIdx As Long
    waveIdx = Int(Ch3_Phase * 32!) And 31
    
    ' 함수 호출 오버헤드 없이 배열에서 즉시 조회
    Dim rawSample As Long
    rawSample = CLng(WaveSamples(waveIdx))
    
    ' 볼륨 시프트 처리 (GB 하드웨어 사양: 비트 시프트)
    Select Case Ch3_VolShift
        Case 1: ' 100% (그대로 유지)
        Case 2: rawSample = rawSample \ 2   ' 50%
        Case 3: rawSample = rawSample \ 4   ' 25%
        Case Else: rawSample = 0            ' Mute (0%)
    End Select
    
    ' -7.5 중심축 기준 대칭 스윙
    ch3Sig = CSng(rawSample - 7.5!) * (300# * 1.8!)
End If
        '''
          ' --- Channel 4 (Noise) ---
        If Ch4_Enable And (Ch4_Freq > 0#) And (Ch4_Vol > 0) Then
            Ch4_Phase = Ch4_Phase + (CDbl(Ch4_Freq) / sampleRateF)
            
            If Ch4_Phase >= 1# Then
                Dim shifts As Long
                shifts = Int(Ch4_Phase)
                Ch4_Phase = Ch4_Phase - CDbl(shifts)
                
                ' 초고주파 클럭 시 루프 폭주 방지 (최대 31회로 클램핑)
                If shifts > 31 Then shifts = 31
                
                Dim sCount As Long
                Dim bit0 As Long, bit1 As Long, resultBit As Long
                
                For sCount = 1 To shifts
                    ' 0번 비트와 1번 비트 XOR
                    bit0 = Ch4_LFSR And 1
                    bit1 = (Ch4_LFSR \ 2) And 1
                    resultBit = bit0 Xor bit1
                    
                    ' 오른쪽으로 1비트 시프트 후 최상위 14번 비트에 결과 주입
                    Ch4_LFSR = (Ch4_LFSR \ 2) And &H3FFF
                    Ch4_LFSR = Ch4_LFSR Or (resultBit * 16384)
                    
                    ' 7-bit 모드: 비트 6(64)에도 동일하게 주입 (&H7FBF 마스크 적용)
                    If Ch4_Step7 Then
                        Ch4_LFSR = (Ch4_LFSR And &H7FBF) Or (resultBit * 64)
                    End If
                Next sCount
            End If
            
            ' 실제 하드웨어 규격: 0번 비트의 반전 출력 (~LFSR & 1)
            ' 비트 0이 0이면 High(+), 1이면 Low(-)
            If (Ch4_LFSR And 1) = 0 Then
                ch4Sig = CDbl(Ch4_Vol) * 200#
            Else
                ch4Sig = -CDbl(Ch4_Vol) * 200#
            End If
        End If
        
        ' --- Stereo Panning Matrix (NR51) ---
        outL = 0#: outR = 0#

        If (NR51_Pan And &H10) <> 0 Then outL = outL + ch1Sig
        If (NR51_Pan And &H20) <> 0 Then outL = outL + ch2Sig
        If (NR51_Pan And &H40) <> 0 Then outL = outL + ch3Sig
        If (NR51_Pan And &H80) <> 0 Then outL = outL + ch4Sig

        If (NR51_Pan And &H1) <> 0 Then outR = outR + ch1Sig
        If (NR51_Pan And &H2) <> 0 Then outR = outR + ch2Sig
        If (NR51_Pan And &H4) <> 0 Then outR = outR + ch3Sig
        If (NR51_Pan And &H8) <> 0 Then outR = outR + ch4Sig

        ' Master Volume Apply
        outL = outL * (CDbl(NR50_VolL + 1) / 8#)
        outR = outR * (CDbl(NR50_VolR + 1) / 8#)

        ' 16-bit PCM Clamping
        If outL > 32767# Then outL = 32767#
        If outL < -32768# Then outL = -32768#
        If outR > 32767# Then outR = 32767#
        If outR < -32768# Then outR = -32768#

        Buffer(CurrentBufferIdx, bufIdx) = CInt(outL)
        Buffer(CurrentBufferIdx, bufIdx + 1) = CInt(outR)
        bufIdx = bufIdx + 2
    Next i

 
    Call waveOutPrepareHeader(hWaveOut, waveHeader(CurrentBufferIdx), LenB(waveHeader(CurrentBufferIdx)))
    Call waveOutWrite(hWaveOut, waveHeader(CurrentBufferIdx), LenB(waveHeader(CurrentBufferIdx)))
    CurrentBufferIdx = (CurrentBufferIdx + 1) Mod NUM_BUFFERS
End Sub

Private Function GetWaveSample(ByVal sampleIdx As Long) As Single
    Dim byteVal As Byte
    byteVal = WaveRAM(sampleIdx \ 2)
    If (sampleIdx Mod 2) = 0 Then
        GetWaveSample = CSng((byteVal \ 16) And &HF)
    Else
        GetWaveSample = CSng(byteVal And &HF)
    End If
End Function



' =========================================================================
' Sound Registers Handlers
' =========================================================================

Public Sub setNR10(val As Long): End Sub

Public Sub setNR11(val As Long)
    Ch1_DutyIdx = (val \ 64) And &H3
End Sub

Public Sub setNR12(val As Long)
    Ch1_Vol = (val \ 16) And &HF
    If Ch1_Vol = 0 Then Ch1_Enable = False
End Sub

Public Sub setNR13(val As Long)
    ' 하위 8비트 갱신
    Ch1_RawFreq = (Ch1_RawFreq And &H700) Or (val And &HFF)
    
    ' 부동소수점(/) 나눗셈으로 소수점 Hz까지 정확하게 보존
    Dim denom As Long
    denom = 2048 - Ch1_RawFreq
    If denom > 0 Then
        Ch1_Freq = 131072# / CDbl(denom)
    Else
        Ch1_Freq = 0#
    End If
End Sub

Public Sub setNR14(val As Long)
    ' 상위 3비트 갱신 (11비트 주파수 완성)
    Ch1_RawFreq = (Ch1_RawFreq And &HFF) Or ((val And &H7) * 256)
    
    Dim denom As Long
    denom = 2048 - Ch1_RawFreq
    If denom > 0 Then
        Ch1_Freq = 131072# / CDbl(denom)
    Else
        Ch1_Freq = 0#
    End If
    
    ' 비트 7: 트리거 (채널 재시작)
    If (val And &H80) <> 0 Then
        ' DAC 상태 확인 (NR12의 상위 5비트가 0이면 DAC Off 상태이므로 Enable 불가)
        ' Ch1_DACOn 플래그가 있다면: If Ch1_DACOn Then Ch1_Enable = True Else Ch1_Enable = False
        Ch1_Enable = True
        
        ' 위상 리셋 (클릭 노이즈 방지 및 위상 정렬)
        Ch1_Phase = 0#
        
        
    End If
End Sub

Public Sub setNR13_0(val As Long)
    Ch1_RawFreq = (Ch1_RawFreq And &H700) Or (val And &HFF)
    If Ch1_RawFreq < 2048 Then Ch1_Freq = 131072 \ (2048 - Ch1_RawFreq)
End Sub

Public Sub setNR14_0(val As Long)
    Ch1_RawFreq = (Ch1_RawFreq And &HFF) Or ((val And &H7) * 256)
    If Ch1_RawFreq < 2048 Then Ch1_Freq = 131072 \ (2048 - Ch1_RawFreq)
    If (val And &H80) <> 0 Then
        Ch1_Enable = True
        Ch1_Phase = 0#
    End If
End Sub

Public Sub setNR21(val As Long)
    Ch2_DutyIdx = (val \ 64) And &H3
End Sub

Public Sub setNR22(val As Long)
    Ch2_Vol = (val \ 16) And &HF
    If Ch2_Vol = 0 Then Ch2_Enable = False
End Sub

Public Sub setNR23_0(val As Long)
    Ch2_RawFreq = (Ch2_RawFreq And &H700) Or (val And &HFF)
    If Ch2_RawFreq < 2048 Then Ch2_Freq = 131072 \ (2048 - Ch2_RawFreq)
End Sub

Public Sub setNR24_0(val As Long)
    Ch2_RawFreq = (Ch2_RawFreq And &HFF) Or ((val And &H7) * 256)
    If Ch2_RawFreq < 2048 Then Ch2_Freq = 131072 \ (2048 - Ch2_RawFreq)
    If (val And &H80) <> 0 Then
        Ch2_Enable = True
        Ch2_Phase = 0#
    End If
End Sub
Public Sub setNR23(val As Long)
    ' 하위 8비트 갱신
    Ch2_RawFreq = (Ch2_RawFreq And &H700) Or (val And &HFF)
    
    ' 부동소수점(/) 나눗셈으로 소수점 Hz까지 정확하게 계산
    Dim denom As Long
    denom = 2048 - Ch2_RawFreq
    If denom > 0 Then
        Ch2_Freq = 131072# / CDbl(denom)
    Else
        Ch2_Freq = 0#
    End If
End Sub

Public Sub setNR24(val As Long)
    ' 상위 3비트 갱신 (11비트 주파수 완성)
    Ch2_RawFreq = (Ch2_RawFreq And &HFF) Or ((val And &H7) * 256)
    
    Dim denom As Long
    denom = 2048 - Ch2_RawFreq
    If denom > 0 Then
        Ch2_Freq = 131072# / CDbl(denom)
    Else
        Ch2_Freq = 0#
    End If
    
    ' 비트 7: 트리거 (채널 재시작)
    If (val And &H80) <> 0 Then
        ' DAC 상태 확인 (NR22 상위 5비트가 0이면 DAC Off 상태이므로 Enable 불가)
        ' 만약 별도 플래그가 없다면 기본 활성화
        Ch2_Enable = True
        
        ' 위상 0 리셋 (클릭 팝 노이즈 방지)
        Ch2_Phase = 0#
        
        ' [필수] 볼륨 엔벨로프 리셋: 이전 노트에서 감쇠되어 0이 된 볼륨을 초기 볼륨으로 복원
        ' Ch2_Vol = Ch2_InitialVol
        ' Ch2_EnvTimer = Ch2_EnvPeriod
    End If
End Sub

Public Sub setNR30(val As Long)
    Ch3_Enable = ((val And &H80) <> 0)
End Sub

Public Sub setNR31(val As Long): End Sub

Public Sub setNR32(val As Long)
    Select Case ((val \ 32) And &H3)
        Case 0: Ch3_VolShift = 0
        Case 1: Ch3_VolShift = 1
        Case 2: Ch3_VolShift = 2
        Case 3: Ch3_VolShift = 3
    End Select
End Sub

Public Sub setNR33(val As Long)
    Ch3_RawFreq = (Ch3_RawFreq And &H700) Or (val And &HFF)
    If Ch3_RawFreq < 2048 Then Ch3_Freq = 65536 \ (2048 - Ch3_RawFreq)
End Sub

Public Sub setNR34(val As Long)
    ' 상위 3비트(비트 0~2) 결합하여 11비트 주파수 형성
    Ch3_RawFreq = (Ch3_RawFreq And &HFF) Or ((val And &H7) * 256)
    
    ' 반드시 정밀 부동소수점(/) 나눗셈을 사용해야 고음역 튜닝이 어긋나지 않음
    Dim denom As Long
    denom = 2048 - Ch3_RawFreq
    
    If denom > 0 Then
        Ch3_Freq = 65536# / CDbl(denom)
    Else
        Ch3_Freq = 0#
    End If
    
    ' 비트 7(트리거): 채널 재시작
    If (val And &H80) <> 0 Then
        ' NR30의 DAC가 켜져 있을 때만 Enable 유지 (NR30_DACOn 플래그 연동 권장)
        ' 만약 별도 변수가 없다면 기존대로 Ch3_Enable = True 유지
        Ch3_Enable = True
        
        ' 위상을 0으로 초기화하여 시작 시 클릭 노이즈 억제
        Ch3_Phase = 0#
    End If
End Sub

Public Sub setNR34_0(val As Long)
    Ch3_RawFreq = (Ch3_RawFreq And &HFF) Or ((val And &H7) * 256)
    If Ch3_RawFreq < 2048 Then Ch3_Freq = 65536 \ (2048 - Ch3_RawFreq)
    If (val And &H80) <> 0 Then Ch3_Enable = True: Ch3_Phase = 0!
End Sub

Public Sub setWaveRAM0(ByVal Index As Long, ByVal val As Byte)
    If Index >= 0 And Index <= 15 Then WaveRAM(Index) = val
End Sub

Public Sub setWaveRAM(ByVal Index As Long, ByVal val As Byte)
  If Index >= 0 And Index <= 15 Then
        WaveRAM(Index) = val
        
        ' 상위 4비트 (짝수 인덱스: 0, 2, 4 ...)
        WaveSamples(Index * 2) = CSng((val \ 16) And &HF)
        
        ' 하위 4비트 (홀수 인덱스: 1, 3, 5 ...)
        WaveSamples(Index * 2 + 1) = CSng(val And &HF)
    End If
End Sub


Public Sub setNR41(val As Long)
    ' 하위 6비트 (0~5): 사운드 길이 로드 (최대 64 샘플 틱)
    Ch4_Length = 64 - (val And &H3F)
End Sub

Public Sub setNR42(val As Long)
    ' 비트 4~7: 초기 볼륨 (0~15)
    Ch4_InitialVol = (val \ 16) And &HF
    Ch4_Vol = Ch4_InitialVol
    
    ' 비트 3: 엔벨로프 방향 (0: 감쇠, 1: 증가)
    Ch4_EnvDir = (val \ 8) And &H1
    
    ' 비트 0~2: 엔벨로프 주기 (스텝 간격, 0이면 엔벨로프 비활성)
    Ch4_EnvPeriod = val And &H7
    Ch4_EnvTimer = Ch4_EnvPeriod
    
    ' 하드웨어 DAC 상태 확인: 상위 5비트가 0이면 DAC Off
    Ch4_DACOn = ((val And &HF8) <> 0)
    If Not Ch4_DACOn Then
        Ch4_Enable = False
    End If
End Sub

Public Sub setNR43(val As Long)
    Dim s As Long: s = (val \ 16) And &HF
    Dim r As Long: r = val And &H7
    Ch4_Step7 = ((val And &H8) <> 0)
    
    ' Pan Docs 하드웨어 사양: s = 14, 15는 클럭이 공급되지 않음 (채널 음소거)
    If s >= 14 Then
        Ch4_Freq = 0#
        Exit Sub
    End If
    
    ' 2^(s+1) 정수 연산 (비트 시프트 대용: 2 * (2^s))
    Dim pow2 As Long
    pow2 = 2 ^ (s + 1)
    
    ' r = 0 일 때는 분모가 0.5 * 2^(s+1) = 2^s
    ' r > 0 일 때는 분모가 r * 2^(s+1)
    If r = 0 Then
        Ch4_Freq = 524288# / CDbl(pow2 \ 2)
    Else
        Ch4_Freq = 524288# / CDbl(r * pow2)
    End If
End Sub

Public Sub setNR44(val As Long)
    ' 비트 6: 사운드 길이 카운터 사용 여부
    Ch4_LengthEnable = ((val And &H40) <> 0)
    
    ' 비트 7: 채널 재시작 (트리거)
    If (val And &H80) <> 0 Then
        ' DAC가 켜져 있을 때만 채널 활성화
        If Ch4_DACOn Then
            Ch4_Enable = True
        End If
        
        ' 볼륨을 초기 볼륨값으로 복원
        Ch4_Vol = Ch4_InitialVol
        Ch4_EnvTimer = Ch4_EnvPeriod
        
        ' 길이가 만료(0)된 상태였다면 64로 재설정
        If Ch4_Length = 0 Then Ch4_Length = 64
        
        ' 위상 및 LFSR 초기화 (강한 타격감 유지)
        Ch4_Phase = 0#
        Ch4_LFSR = &H7FFF
    End If
End Sub





Public Sub setNR41_0(val As Long): End Sub

Public Sub setNR42_0(val As Long)
    Ch4_Vol = (val \ 16) And &HF
    If Ch4_Vol = 0 Then Ch4_Enable = False
End Sub

Public Sub setNR43_0(val As Long)
    Dim s As Long: s = (val \ 16) And &HF
    Dim r As Long: r = val And &H7
    Ch4_Step7 = ((val And &H8) <> 0)
    
    Dim d As Double
    If r = 0 Then d = 0.5 Else d = CDbl(r)
    
    Ch4_Freq = 524288! / (d * CDbl(2 ^ (s + 1)))
End Sub

Public Sub setNR44_0(val As Long)
    If (val And &H80) <> 0 Then
        Ch4_Enable = True
        Ch4_LFSR = &H7FFF
    End If
End Sub

' Stereo Routing / Volume Control
Public Sub setNR50(val As Long)
    NR50_VolR = val And &H7
    NR50_VolL = (val \ 16) And &H7
End Sub

Public Sub setNR51(val As Long)
    NR51_Pan = val And &HFF
End Sub

Public Sub setNR52(val As Long)
    SoundEnabled = ((val And &H80) <> 0)
End Sub


