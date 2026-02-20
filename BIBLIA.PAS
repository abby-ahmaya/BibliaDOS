program BibliaACF;

{ Leitor DOS (Turbo Pascal) para Biblia ACF.
  Usa 3 arquivos gerados por make_dos_data.py:
    - ACF.MET (metadados)
    - ACF.IDX (offsets)
    - ACF.DAT (texto)

  Dica: para acentos (pt-BR), use codepage 850 no DOSBox-X. }

uses
  Crt, Dos;

{$I-} { sem IO checking automatico }

const
  META_FILE = 'ACF.MET';
  IDX_FILE  = 'ACF.IDX';
  DAT_FILE  = 'ACF.DAT';

  MAGIC_LEN = 6;
  MAGIC_STR = 'ACFMET';

  MAX_BOOKS      = 66;
  MAX_NAME_LEN   = 32;
  MAX_ABBREV_LEN = 8;
  MAX_CHAPS_TOT  = 1300;
  VERSE_BUF_SIZE = 4096;
  MAX_CHAP_VERSES = 255;

  SCREEN_W = 80;
  SCREEN_H = 25;

  TITLE_Y   = 1;
  INFO_Y    = 2;
  CONTENT_Y = 3;
  CONTENT_Y2 = 23;
  FOOT_Y1   = 24;
  FOOT_Y2   = 25;

  BG_NORMAL = Blue;
  FG_NORMAL = Yellow;
  BG_HILITE = Cyan;
  FG_HILITE = Black;
  FG_TITLE  = White;

type
  TBookName = String;

var
  TotalBooks: Byte;
  TotalChaps: Word;
  TotalVerses: LongInt;

  BookName: array[1..MAX_BOOKS] of TBookName;
  BookAbbrev: array[1..MAX_BOOKS] of TBookName;
  BookChapCount: array[1..MAX_BOOKS] of Byte;
  BookChapBase: array[1..MAX_BOOKS] of Word;
  BookStart: array[1..MAX_BOOKS] of LongInt;

  ChapVerseCount: array[1..MAX_CHAPS_TOT] of Word;
  ChapStart: array[1..MAX_CHAPS_TOT] of LongInt;

  FMeta, FIdx, FDat: File;

  VerseBuf: array[1..VERSE_BUF_SIZE] of Char;
  VerseBufLen: Word;

  Running: Boolean;
  JumpDirect: Boolean;

  CurBook: Byte;
  CurChap: Word;
  CurVerse: Word;
  TopVerse: Word;


procedure SetNormal;
begin
  TextBackground(BG_NORMAL);
  TextColor(FG_NORMAL);
end;

procedure SetTitle;
begin
  TextBackground(BG_NORMAL);
  TextColor(FG_TITLE);
end;

procedure SetHilite;
begin
  TextBackground(BG_HILITE);
  TextColor(FG_HILITE);
end;

procedure ClearLine(Y: Byte);
var
  i: Byte;
begin
  GotoXY(1, Y);
  for i := 1 to SCREEN_W do
    Write(' ');
end;

procedure WriteAt(X, Y: Byte; S: String);
var
  maxLen: Integer;
begin
  if (X < 1) or (X > SCREEN_W) or (Y < 1) or (Y > SCREEN_H) then
    Exit;
  maxLen := SCREEN_W - X + 1;
  if Length(S) > maxLen then
    S := Copy(S, 1, maxLen);
  GotoXY(X, Y);
  Write(S);
end;

procedure WriteAtPad(X, Y, W: Byte; S: String);
var
  outS: String;
begin
  if W = 0 then
    Exit;
  outS := S;
  if Length(outS) > W then
    outS := Copy(outS, 1, W);
  while Length(outS) < W do
    outS := outS + ' ';
  WriteAt(X, Y, outS);
end;

function UpperStr(S: String): String;
var
  i: Byte;
begin
  for i := 1 to Length(S) do
    S[i] := UpCase(S[i]);
  UpperStr := S;
end;

function HasParam(P: String): Boolean;
var
  i: Integer;
  A: String;
begin
  P := UpperStr(P);
  HasParam := False;
  for i := 1 to ParamCount do
  begin
    A := UpperStr(ParamStr(i));
    if A = P then
    begin
      HasParam := True;
      Exit;
    end;
  end;
end;

procedure Fatal(Msg: String);
var
  ch: Char;
begin
  SetTitle;
  ClrScr;
  WriteLn('ERRO: ', Msg);
  WriteLn;
  WriteLn('Pressione qualquer tecla...');
  ch := ReadKey;
  Halt(1);
end;

function ReadByte(var F: File; var B: Byte): Boolean;
var
  n: Word;
begin
  BlockRead(F, B, 1, n);
  ReadByte := (n = 1);
end;

function ReadWord(var F: File; var W: Word): Boolean;
var
  n: Word;
begin
  BlockRead(F, W, 2, n);
  ReadWord := (n = 2);
end;

function ReadLong(var F: File; var L: LongInt): Boolean;
var
  n: Word;
begin
  BlockRead(F, L, 4, n);
  ReadLong := (n = 4);
end;

function ReadStrBytes(var F: File; Len: Byte; var S: String): Boolean;
var
  i: Byte;
  ch: Char;
  n: Word;
begin
  if Len > 255 then
    Len := 255;
  S[0] := Chr(Len);
  for i := 1 to Len do
  begin
    BlockRead(F, ch, 1, n);
    if n <> 1 then
    begin
      ReadStrBytes := False;
      Exit;
    end;
    S[i] := ch;
  end;
  ReadStrBytes := True;
end;

procedure LoadMeta;
var
  magic: String;
  ver: Byte;
  i: Integer;
  nameLen: Byte;
  abbrLen: Byte;
  chapCount: Byte;
  chapIdx: Word;
  verseIdx: LongInt;
  vc: Word;
begin
  Assign(FMeta, META_FILE);
  Reset(FMeta, 1);
  if IOResult <> 0 then
    Fatal('Nao foi possivel abrir ' + META_FILE);

  magic := '';
  magic[0] := Chr(MAGIC_LEN);
  for i := 1 to MAGIC_LEN do
    magic[i] := #0;
  if not ReadStrBytes(FMeta, MAGIC_LEN, magic) then
    Fatal('Falha lendo header do ' + META_FILE);
  if magic <> MAGIC_STR then
    Fatal('Arquivo ' + META_FILE + ' invalido (magic)');

  if not ReadByte(FMeta, ver) then
    Fatal('Falha lendo versao do ' + META_FILE);
  if (ver <> 1) and (ver <> 2) then
    Fatal('Versao de meta nao suportada');

  if not ReadByte(FMeta, TotalBooks) then
    Fatal('Falha lendo TotalBooks');
  if TotalBooks > MAX_BOOKS then
    Fatal('TotalBooks maior que MAX_BOOKS');

  if not ReadWord(FMeta, TotalChaps) then
    Fatal('Falha lendo TotalChaps');
  if TotalChaps > MAX_CHAPS_TOT then
    Fatal('TotalChaps maior que MAX_CHAPS_TOT');

  if not ReadLong(FMeta, TotalVerses) then
    Fatal('Falha lendo TotalVerses');

  for i := 1 to TotalBooks do
  begin
    if not ReadByte(FMeta, nameLen) then
      Fatal('Falha lendo nome do livro');
    if nameLen > MAX_NAME_LEN then
      nameLen := MAX_NAME_LEN;
    if not ReadStrBytes(FMeta, nameLen, BookName[i]) then
      Fatal('Falha lendo nome do livro');

    if ver >= 2 then
    begin
      if not ReadByte(FMeta, abbrLen) then
        Fatal('Falha lendo abbrev do livro');
      if abbrLen > MAX_ABBREV_LEN then
        abbrLen := MAX_ABBREV_LEN;
      if not ReadStrBytes(FMeta, abbrLen, BookAbbrev[i]) then
        Fatal('Falha lendo abbrev do livro');
      BookAbbrev[i] := UpperStr(BookAbbrev[i]);
    end
    else
      BookAbbrev[i] := '';

    if not ReadByte(FMeta, chapCount) then
      Fatal('Falha lendo chapCount');
    BookChapCount[i] := chapCount;
  end;

  chapIdx := 1;
  verseIdx := 0;
  for i := 1 to TotalBooks do
  begin
    BookChapBase[i] := chapIdx;
    BookStart[i] := verseIdx;
    for chapCount := 1 to BookChapCount[i] do
    begin
      if not ReadWord(FMeta, vc) then
        Fatal('Falha lendo verseCount');
      ChapVerseCount[chapIdx] := vc;
      ChapStart[chapIdx] := verseIdx;
      verseIdx := verseIdx + vc;
      Inc(chapIdx);
    end;
  end;

  Close(FMeta);
  i := IOResult; { limpa }

  if verseIdx <> TotalVerses then
    Fatal('Meta inconsistente (TotalVerses)');
end;

procedure OpenDataFiles;
begin
  Assign(FIdx, IDX_FILE);
  Reset(FIdx, 1);
  if IOResult <> 0 then
    Fatal('Nao foi possivel abrir ' + IDX_FILE);

  Assign(FDat, DAT_FILE);
  Reset(FDat, 1);
  if IOResult <> 0 then
    Fatal('Nao foi possivel abrir ' + DAT_FILE);
end;

function GetVerseOffset(GlobalIdx: LongInt; var Offs: LongInt): Boolean;
var
  n: Word;
begin
  GetVerseOffset := False;
  if GlobalIdx < 0 then
    Exit;
  Seek(FIdx, GlobalIdx * 4);
  if IOResult <> 0 then
    Exit;
  BlockRead(FIdx, Offs, 4, n);
  if (n <> 4) then
    Exit;
  GetVerseOffset := True;
end;

function ReadVerse(GlobalIdx: LongInt): Boolean;
var
  offs: LongInt;
  n: Word;
  l: Word;
  i, j: Word;
  ch: Char;
  prevSpace: Boolean;
begin
  ReadVerse := False;
  if not GetVerseOffset(GlobalIdx, offs) then
    Exit;
  Seek(FDat, offs);
  if IOResult <> 0 then
    Exit;
  BlockRead(FDat, l, 2, n);
  if n <> 2 then
    Exit;
  VerseBufLen := l;
  if VerseBufLen > VERSE_BUF_SIZE then
    VerseBufLen := VERSE_BUF_SIZE;
  BlockRead(FDat, VerseBuf, VerseBufLen, n);
  if n <> VerseBufLen then
    Exit;

  { normaliza: remove controles e espacos duplicados }
  j := 0;
  prevSpace := True;
  for i := 1 to VerseBufLen do
  begin
    ch := VerseBuf[i];
    if (ch = #9) or (ch = #10) or (ch = #13) then
      ch := ' ';
    if ch = ' ' then
    begin
      if not prevSpace then
      begin
        Inc(j);
        VerseBuf[j] := ' ';
      end;
      prevSpace := True;
    end
    else if ch < ' ' then
    begin
      { ignora outros controles }
    end
    else
    begin
      Inc(j);
      VerseBuf[j] := ch;
      prevSpace := False;
    end;
  end;
  if (j > 0) and (VerseBuf[j] = ' ') then
    Dec(j);
  VerseBufLen := j;

  ReadVerse := True;
end;

function MakeLine(StartPos, EndPos: Word): String;
var
  s: String;
  i, n: Word;
begin
  if EndPos < StartPos then
  begin
    MakeLine := '';
    Exit;
  end;
  n := EndPos - StartPos + 1;
  if n > 255 then
    n := 255;
  s[0] := Chr(n);
  for i := 1 to n do
    s[i] := VerseBuf[StartPos + i - 1];
  MakeLine := s;
end;

procedure DrawVerse(VerseNum: Word; Highlight: Boolean; var Y: Byte);
var
  i, j, lastSpace, endPos: Word;
  avail: Word;
  firstLine: Boolean;
  prefix: String;
  numS: String;
  line: String;
begin
  if VerseBufLen = 0 then
  begin
    Str(VerseNum:3, numS);
    SetNormal;
    WriteAtPad(2, Y, SCREEN_W - 1, numS + ' (sem texto)');
    Inc(Y);
    Exit;
  end;

  i := 1;
  firstLine := True;
  while (i <= VerseBufLen) and (Y <= CONTENT_Y2) do
  begin
    while (i <= VerseBufLen) and (VerseBuf[i] = ' ') do
      Inc(i);
    if i > VerseBufLen then
      Exit;

    if firstLine then
    begin
      Str(VerseNum:3, numS);
      prefix := numS + ' ';
    end
    else
      prefix := '    ';

    avail := SCREEN_W - 2 - Length(prefix);
    if avail < 10 then
      avail := 10;

    j := i;
    lastSpace := 0;
    while (j <= VerseBufLen) and ((j - i) < avail) do
    begin
      if VerseBuf[j] = ' ' then
        lastSpace := j;
      Inc(j);
    end;

    if (j <= VerseBufLen) and (lastSpace > 0) then
      endPos := lastSpace - 1
    else
      endPos := i + avail - 1;

    if endPos > VerseBufLen then
      endPos := VerseBufLen;

    line := MakeLine(i, endPos);

    SetNormal;

    WriteAtPad(2, Y, SCREEN_W - 1, prefix + line);
    Inc(Y);

    if (j <= VerseBufLen) and (lastSpace > 0) then
      i := lastSpace + 1
    else
      i := endPos + 1;

    firstLine := False;
  end;
end;

function ChapterId(BookIdx: Byte; ChapNum: Word): Word;
begin
  ChapterId := BookChapBase[BookIdx] + (ChapNum - 1);
end;

function BookLabel(BookIdx: Byte): String;
var
  s: String;
  n: Char;
begin
  s := BookName[BookIdx];
  { Tira prefixo numerico no display: "1 Samuel" -> "Samuel 1" }
  if (Length(s) >= 2) and (s[1] in ['1', '2', '3']) and (s[2] = ' ') then
  begin
    n := s[1];
    s := Copy(s, 3, 255);
    BookLabel := s + ' ' + n;
  end
  else
    BookLabel := s;
end;

procedure DrawTitle(Title: String);
begin
  SetTitle;
  WriteAtPad(2, TITLE_Y, SCREEN_W - 1, Title);
end;

procedure DrawFooter(L1, L2: String);
begin
  SetTitle;
  WriteAtPad(2, FOOT_Y1, SCREEN_W - 1, L1);
  WriteAtPad(2, FOOT_Y2, SCREEN_W - 1, L2);
end;

procedure DrawInfo(Info: String);
begin
  SetTitle;
  WriteAtPad(2, INFO_Y, SCREEN_W - 1, Info);
end;

procedure WaitAnyKey;
var
  ch: Char;
begin
  ch := ReadKey;
end;

procedure ShowHelp;
begin
  SetTitle;
  ClrScr;
  WriteLn('Biblia ACF (DOS) - Ajuda');
  WriteLn;
  WriteLn('Menus:');
  WriteLn('  Setas / PgUp / PgDn  mover');
  WriteLn('  Left/Right           VT/NT (menu de livros)');
  WriteLn('  Digite               ex: ap 22 1  (ir direto p/ verso)');
  WriteLn('  Enter                selecionar');
  WriteLn('  ESC / b              voltar (ou limpa digitacao)');
  WriteLn('  q                    sair');
  WriteLn;
  WriteLn('Leitura:');
  WriteLn('  Up/Down             verso anterior/proximo');
  WriteLn('  PgUp/PgDn            -/+ 10 versos');
  WriteLn('  Left/Right           capitulo anterior/proximo');
  WriteLn('  g                   ir para verso');
  WriteLn;
  WriteLn('Pressione qualquer tecla...');
  WaitAnyKey;
end;

function PromptNumber(Prompt: String; MinV, MaxV: Word; var Value: Word): Boolean;
var
  buf: String;
  ch: Char;
  n: Integer;
  done: Boolean;
  code: Integer;
begin
  buf := '';
  PromptNumber := False;
  SetTitle;
  ClearLine(FOOT_Y2);
  WriteAt(2, FOOT_Y2, Prompt);

  done := False;
  repeat
    ch := ReadKey;
    if ch = #27 then
    begin
      PromptNumber := False;
      Exit;
    end;
    if ch = #13 then
      done := True;
    if ch = #8 then
    begin
      if Length(buf) > 0 then
        Dec(buf[0]);
    end
    else if (ch >= '0') and (ch <= '9') then
    begin
      if Length(buf) < 5 then
        buf := buf + ch;
    end;

    SetTitle;
    ClearLine(FOOT_Y2);
    WriteAt(2, FOOT_Y2, Prompt + buf);
  until done;

  if Length(buf) = 0 then
    Exit;

  Val(buf, n, code);
  if code <> 0 then
    Exit;
  if (n < MinV) or (n > MaxV) then
    Exit;

  Value := n;
  PromptNumber := True;
end;

procedure SelfTest;
var
  chapId: Word;
  gIdx: LongInt;
  y: Byte;
begin
  SetTitle;
  ClrScr;
  WriteLn('OK: arquivos carregados');
  WriteLn('Livros   : ', TotalBooks);
  WriteLn('Capitulos: ', TotalChaps);
  WriteLn('Versos   : ', TotalVerses);
  WriteLn;

  chapId := ChapterId(1, 1); { Genesis 1 }
  gIdx := ChapStart[chapId] + 0; { verso 1 }
  if ReadVerse(gIdx) then
  begin
    WriteLn('Exemplo: ', BookLabel(1), ' 1:1');
    y := 1;
    DrawVerse(1, False, y);
  end
  else
    WriteLn('Falha lendo verso de teste.');
end;

function ScreenBooksSelect: Boolean;
const
  OT_BOOKS = 39;
  COL1_X = 2;
  COL2_X = 42;
  DIV_X  = 40;
  COL_W  = 37;
  HDR_Y  = CONTENT_Y;
  LIST_Y = CONTENT_Y + 1;
var
  sel, oldSel: Integer;
  topRow, oldTop: Integer;
  ch, ch2: Char;
  scan: Byte;
  pageSize: Integer;
  otCount, ntCount, maxRows, maxTop: Integer;
  needFullRedraw: Boolean;
  jumpBuf: String;

  procedure DrawDivider;
  var
    yy: Integer;
  begin
    SetTitle;
    for yy := HDR_Y to CONTENT_Y2 do
    begin
      GotoXY(DIV_X, yy);
      Write('|');
    end;
  end;

  procedure DrawHeader;
  begin
    SetTitle;
    ClearLine(HDR_Y);
    WriteAt(COL1_X, HDR_Y, 'VT');
    WriteAt(COL2_X, HDR_Y, 'NT');
    GotoXY(DIV_X, HDR_Y);
    Write('|');
  end;

  procedure DrawJumpLine;
  begin
    SetTitle;
    ClearLine(FOOT_Y2);
    WriteAt(2, FOOT_Y2, 'Ir direto: ' + jumpBuf);
  end;

  procedure FlashError(M: String);
  begin
    SetTitle;
    ClearLine(FOOT_Y2);
    WriteAt(2, FOOT_Y2, M);
    Write(#7);
    Delay(700);
    DrawJumpLine;
  end;

  procedure DrawStatic;
  begin
    SetNormal;
    ClrScr;
    DrawTitle('Biblia ACF (DOS)  |  Livros');
    DrawInfo('Enter: selecionar  |  ap 22 1: ir direto  |  F1: ajuda');
    DrawFooter('Setas/PgUp/PgDn navega  |  q sai', '');
    DrawHeader;
    DrawDivider;
    DrawJumpLine;
  end;

  procedure DrawBookCell(X, Y: Byte; S: String; Selected: Boolean);
  var
    outS: String;
    pad: Integer;
    ii: Integer;
  begin
    if Selected then
      SetHilite
    else
      SetNormal;
    outS := S;
    if Length(outS) > COL_W then
      outS := Copy(outS, 1, COL_W);
    GotoXY(X, Y);
    Write(outS);
    pad := COL_W - Length(outS);
    for ii := 1 to pad do
      Write(' ');
  end;

  function RowOfBook(B: Integer): Integer;
  begin
    if B <= otCount then
      RowOfBook := B
    else
      RowOfBook := B - otCount;
  end;

  procedure EnsureVisible;
  var
    r: Integer;
  begin
    r := RowOfBook(sel);
    if r < topRow then
      topRow := r;
    if r >= (topRow + pageSize) then
      topRow := r - pageSize + 1;
    if topRow < 1 then
      topRow := 1;
    if topRow > maxTop then
      topRow := maxTop;
  end;

  procedure DrawScroll;
  begin
    SetTitle;
    GotoXY(SCREEN_W, HDR_Y);
    if topRow > 1 then
      Write('^')
    else
      Write(' ');
    GotoXY(SCREEN_W, CONTENT_Y2);
    if (topRow + pageSize - 1) < maxRows then
      Write('v')
    else
      Write(' ');
  end;

  procedure DrawPage;
  var
    ii: Integer;
    yy: Byte;
    otRow, ntRow: Integer;
    bIdx: Integer;
    s: String;
  begin
    for ii := 0 to pageSize - 1 do
    begin
      yy := LIST_Y + ii;

      otRow := topRow + ii;
      if otRow <= otCount then
      begin
        bIdx := otRow;
        s := BookLabel(bIdx);
        DrawBookCell(COL1_X, yy, s, bIdx = sel);
      end
      else
        DrawBookCell(COL1_X, yy, '', False);

      ntRow := topRow + ii;
      if ntRow <= ntCount then
      begin
        bIdx := otCount + ntRow;
        s := BookLabel(bIdx);
        DrawBookCell(COL2_X, yy, s, bIdx = sel);
      end
      else
        DrawBookCell(COL2_X, yy, '', False);
    end;
    DrawScroll;
  end;

  procedure DrawBookSingle(B: Integer);
  var
    r: Integer;
    yy: Byte;
    x: Byte;
    s: String;
  begin
    if (B < 1) or (B > TotalBooks) then
      Exit;
    r := RowOfBook(B);
    if (r < topRow) or (r >= (topRow + pageSize)) then
      Exit;
    yy := LIST_Y + (r - topRow);
    if B <= otCount then
      x := COL1_X
    else
      x := COL2_X;
    s := BookLabel(B);
    DrawBookCell(x, yy, s, B = sel);
  end;

  procedure ClearJump;
  begin
    if Length(jumpBuf) > 0 then
    begin
      jumpBuf := '';
      DrawJumpLine;
    end;
  end;

  procedure SplitTokens(S: String; var T1, T2, T3: String);
  var
    i: Byte;
    tok: String;
    count: Byte;
    c: Char;
  begin
    T1 := '';
    T2 := '';
    T3 := '';
    tok := '';
    count := 0;
    for i := 1 to Length(S) do
    begin
      c := S[i];
      if c = ' ' then
      begin
        if Length(tok) > 0 then
        begin
          Inc(count);
          if count = 1 then T1 := tok
          else if count = 2 then T2 := tok
          else if count = 3 then T3 := tok;
          tok := '';
          if count >= 3 then
            Exit;
        end;
      end
      else
        tok := tok + c;
    end;
    if Length(tok) > 0 then
    begin
      Inc(count);
      if count = 1 then T1 := tok
      else if count = 2 then T2 := tok
      else if count = 3 then T3 := tok;
    end;
  end;

  function StripToken(S: String): String;
  begin
    { remove pontuacao simples no fim (ex: "ap:" -> "ap") }
    while (Length(S) > 0) and (S[Length(S)] in ['.', ':', ';', ',']) do
      Dec(S[0]);
    StripToken := S;
  end;

  function StrToWord(S: String; var W: Word): Boolean;
  var
    n: Integer;
    code: Integer;
  begin
    StrToWord := False;
    if Length(S) = 0 then
      Exit;
    Val(S, n, code);
    if code <> 0 then
      Exit;
    if (n < 0) or (n > 65535) then
      Exit;
    W := n;
    StrToWord := True;
  end;

  function FindBookToken(Tok: String; var Bk: Byte): Boolean;
  var
    ii: Integer;
    u: String;
    matches: Byte;
    last: Byte;
  begin
    FindBookToken := False;
    Tok := StripToken(Tok);
    Tok := UpperStr(Tok);
    if Tok = '' then
      Exit;

    { 1) match abreviacao exata }
    for ii := 1 to TotalBooks do
      if (BookAbbrev[ii] <> '') and (BookAbbrev[ii] = Tok) then
      begin
        Bk := ii;
        FindBookToken := True;
        Exit;
      end;

    { 2) match prefixo unico do nome (fallback) }
    matches := 0;
    last := 0;
    for ii := 1 to TotalBooks do
    begin
      u := UpperStr(BookLabel(ii));
      if Copy(u, 1, Length(Tok)) = Tok then
      begin
        Inc(matches);
        last := ii;
      end;
    end;

    if matches = 1 then
    begin
      Bk := last;
      FindBookToken := True;
      Exit;
    end;
  end;

  function TryJumpFromBuf(Buf: String): Boolean;
  var
    t1, t2, t3: String;
    bk: Byte;
    chNum, vNum: Word;
    chapId: Word;
    verseCount: Word;
  begin
    TryJumpFromBuf := False;
    SplitTokens(Buf, t1, t2, t3);
    if t1 = '' then
      Exit;

    if not FindBookToken(t1, bk) then
      Exit;

    { se so digitou o livro, apenas seleciona e limpa }
    if (t2 = '') and (t3 = '') then
    begin
      sel := bk;
      EnsureVisible;
      DrawPage;
      jumpBuf := '';
      DrawJumpLine;
      TryJumpFromBuf := True;
      Exit;
    end;

    if (t2 = '') or (t3 = '') then
      Exit;

    if not StrToWord(t2, chNum) then
      Exit;
    if not StrToWord(t3, vNum) then
      Exit;

    if (chNum < 1) or (chNum > BookChapCount[bk]) then
      Exit;

    chapId := ChapterId(bk, chNum);
    verseCount := ChapVerseCount[chapId];
    if (vNum < 1) or (vNum > verseCount) then
      Exit;

    CurBook := bk;
    CurChap := chNum;
    CurVerse := vNum;
    TopVerse := vNum;
    JumpDirect := True;
    TryJumpFromBuf := True;
  end;
begin
  ScreenBooksSelect := False;
  JumpDirect := False;

  otCount := OT_BOOKS;
  if TotalBooks < otCount then
    otCount := TotalBooks;
  ntCount := TotalBooks - otCount;
  if ntCount < 0 then
    ntCount := 0;

  maxRows := otCount;
  if ntCount > maxRows then
    maxRows := ntCount;

  pageSize := CONTENT_Y2 - LIST_Y + 1;
  if pageSize < 1 then
    pageSize := 1;

  maxTop := maxRows - pageSize + 1;
  if maxTop < 1 then
    maxTop := 1;

  sel := CurBook;
  if sel < 1 then sel := 1;
  if sel > TotalBooks then sel := TotalBooks;

  topRow := 1;
  EnsureVisible;

  jumpBuf := '';

  DrawStatic;
  DrawPage;

  while Running do
  begin
    oldSel := sel;
    oldTop := topRow;
    needFullRedraw := False;

    ch := ReadKey;
    if ch = #0 then
    begin
      ch2 := ReadKey;
      scan := Ord(ch2);

      if scan = 59 then { F1 }
      begin
        ShowHelp;
        needFullRedraw := True;
      end
      else
      begin
        ClearJump;

        if scan = 72 then { Up }
        begin
          if sel <= otCount then
          begin
            if sel > 1 then
              Dec(sel);
          end
          else
          begin
            if sel > (otCount + 1) then
              Dec(sel);
          end;
        end
        else if scan = 80 then { Down }
        begin
          if sel <= otCount then
          begin
            if sel < otCount then
              Inc(sel);
          end
          else
          begin
            if sel < TotalBooks then
              Inc(sel);
          end;
        end
        else if scan = 73 then { PgUp }
        begin
          if sel <= otCount then
          begin
            sel := sel - pageSize;
            if sel < 1 then
              sel := 1;
          end
          else
          begin
            sel := sel - pageSize;
            if sel < (otCount + 1) then
              sel := otCount + 1;
          end;
        end
        else if scan = 81 then { PgDn }
        begin
          if sel <= otCount then
          begin
            sel := sel + pageSize;
            if sel > otCount then
              sel := otCount;
          end
          else
          begin
            sel := sel + pageSize;
            if sel > TotalBooks then
              sel := TotalBooks;
          end;
        end
        else if scan = 71 then { Home }
        begin
          if sel <= otCount then
            sel := 1
          else
            sel := otCount + 1;
        end
        else if scan = 79 then { End }
        begin
          if sel <= otCount then
            sel := otCount
          else
            sel := TotalBooks;
        end
        else if scan = 75 then { Left }
        begin
          if sel > otCount then
          begin
            sel := sel - otCount;
            if sel < 1 then
              sel := 1;
          end;
        end
        else if scan = 77 then { Right }
        begin
          if sel <= otCount then
          begin
            if ntCount > 0 then
            begin
              if sel > ntCount then
                sel := ntCount;
              sel := otCount + sel;
            end;
          end;
        end;
      end;
    end
    else
    begin
      if (ch = 'q') or (ch = 'Q') then
      begin
        Running := False;
        Exit;
      end;

      if (ch = #27) or (ch = 'b') or (ch = 'B') then
      begin
        if Length(jumpBuf) > 0 then
        begin
          jumpBuf := '';
          DrawJumpLine;
        end
        else
          Exit;
      end
      else if ch = #13 then
      begin
        if Length(jumpBuf) > 0 then
        begin
          if TryJumpFromBuf(jumpBuf) then
          begin
            if JumpDirect then
            begin
              ScreenBooksSelect := True;
              Exit;
            end;
          end
          else
            FlashError('Invalido. Ex: ap 22 1');
        end
        else
        begin
          CurBook := sel;
          ScreenBooksSelect := True;
          Exit;
        end;
      end
      else if ch = #8 then
      begin
        if Length(jumpBuf) > 0 then
        begin
          Dec(jumpBuf[0]);
          DrawJumpLine;
        end;
      end
      else if ((ch >= 'A') and (ch <= 'Z')) or ((ch >= 'a') and (ch <= 'z')) or
              ((ch >= '0') and (ch <= '9')) or (ch = ' ') then
      begin
        if Length(jumpBuf) < 30 then
        begin
          { evita espacos duplicados }
          if (ch = ' ') and (Length(jumpBuf) > 0) and (jumpBuf[Length(jumpBuf)] = ' ') then
          begin
            { nada }
          end
          else
          begin
            jumpBuf := jumpBuf + ch;
            DrawJumpLine;
          end;
        end;
      end;
    end;

    EnsureVisible;

    if needFullRedraw then
    begin
      DrawStatic;
      DrawPage;
    end
    else if topRow <> oldTop then
      DrawPage
    else if sel <> oldSel then
    begin
      DrawBookSingle(oldSel);
      DrawBookSingle(sel);
      DrawScroll;
    end;
  end;
end;

function ScreenChaptersSelect: Boolean;
var
  sel, top: Integer;
  oldSel, oldTop: Integer;
  ch, ch2: Char;
  scan: Byte;
  pageSize: Integer;
  maxCh: Integer;
  line: String;
  needFullRedraw: Boolean;

  procedure DrawStatic;
  begin
    SetNormal;
    ClrScr;
    DrawTitle('Biblia ACF (DOS)  |  Capitulos');
    DrawInfo(BookLabel(CurBook));
    DrawFooter('Enter: ler  |  ESC/b: voltar  |  F1: ajuda', ' ');
  end;

  procedure DrawPage;
  var
    ii, yy: Integer;
    idx: Integer;
  begin
    for ii := 0 to pageSize - 1 do
    begin
      yy := CONTENT_Y + ii;
      idx := top + ii;
      if idx <= maxCh then
      begin
        if idx = sel then
          SetHilite
        else
          SetNormal;
        ClearLine(yy);
        Str(idx:0, line);
        WriteAt(2, yy, 'Capitulo ' + line);
      end
      else
      begin
        SetNormal;
        ClearLine(yy);
      end;
    end;
  end;

  procedure DrawLine(Index: Integer; Selected: Boolean);
  var
    yy: Integer;
  begin
    if (Index < top) or (Index >= (top + pageSize)) then
      Exit;
    yy := CONTENT_Y + (Index - top);
    if Index <= maxCh then
    begin
      if Selected then
        SetHilite
      else
        SetNormal;
      ClearLine(yy);
      Str(Index:0, line);
      WriteAt(2, yy, 'Capitulo ' + line);
    end;
  end;
begin
  ScreenChaptersSelect := False;
  maxCh := BookChapCount[CurBook];
  pageSize := CONTENT_Y2 - CONTENT_Y + 1;

  sel := 1;
  if sel < 1 then sel := 1;
  if sel > maxCh then sel := maxCh;
  top := 1;
  if sel < top then
    top := sel;
  if sel >= (top + pageSize) then
    top := sel - pageSize + 1;
  if top < 1 then
    top := 1;

  DrawStatic;
  DrawPage;

  while Running do
  begin
    oldSel := sel;
    oldTop := top;
    needFullRedraw := False;

    ch := ReadKey;
    if ch = #0 then
    begin
      ch2 := ReadKey;
      scan := Ord(ch2);
      if scan = 59 then { F1 }
      begin
        ShowHelp;
        needFullRedraw := True;
      end
      else if scan = 72 then { Up }
      begin
        if sel > 1 then
          Dec(sel);
      end
      else if scan = 80 then { Down }
      begin
        if sel < maxCh then
          Inc(sel);
      end
      else if scan = 73 then { PgUp }
      begin
        sel := sel - pageSize;
        if sel < 1 then
          sel := 1;
      end
      else if scan = 81 then { PgDn }
      begin
        sel := sel + pageSize;
        if sel > maxCh then
          sel := maxCh;
      end;
    end
    else
    begin
      if (ch = 'q') or (ch = 'Q') then
      begin
        Running := False;
        Exit;
      end;
      if (ch = 'b') or (ch = 'B') or (ch = #27) then
        Exit;
      if ch = #13 then
      begin
        CurChap := sel;
        CurVerse := 1;
        TopVerse := 1;
        ScreenChaptersSelect := True;
        Exit;
      end;
    end;

    if sel < top then
      top := sel;
    if sel >= (top + pageSize) then
      top := sel - pageSize + 1;
    if top < 1 then
      top := 1;

    if needFullRedraw then
    begin
      DrawStatic;
      DrawPage;
    end
    else if top <> oldTop then
      DrawPage
    else if sel <> oldSel then
    begin
      DrawLine(oldSel, False);
      DrawLine(sel, True);
    end;
  end;
end;

procedure MoveChapter(Delta: Integer);
begin
  if Delta < 0 then
  begin
    if CurChap > 1 then
      Dec(CurChap)
    else if CurBook > 1 then
    begin
      Dec(CurBook);
      CurChap := BookChapCount[CurBook];
    end;
  end
  else
  begin
    if CurChap < BookChapCount[CurBook] then
      Inc(CurChap)
    else if CurBook < TotalBooks then
    begin
      Inc(CurBook);
      CurChap := 1;
    end;
  end;
  CurVerse := 1;
  TopVerse := 1;
end;

procedure ScreenReader;
var
  ch, ch2: Char;
  scan: Byte;
  chapId: Word;
  verseCount: Word;
  y: Byte;
  v: Word;
  globalIdx: LongInt;
  visibleTo: Word;
  tmp: Word;
  info: String;
  n1, n2, n3: String;
  needFullRedraw: Boolean;
  prevBook: Byte;
  prevChap: Word;
  prevTopVerse: Word;
  prevCurVerse: Word;
  pageVisibleTo: Word;
  infoVerseX: Byte;
  VerseYStart: array[1..MAX_CHAP_VERSES] of Byte;

  procedure DrawStatic;
  begin
    SetNormal;
    ClrScr;
    DrawTitle('Biblia ACF (DOS)  |  Leitura');
    DrawFooter('Up/Down verso  |  Left/Right capitulo  |  g ir p/ verso  |  ESC/b voltar', 'q sai  |  F1 ajuda');
  end;

  procedure DrawScroll;
  begin
    SetTitle;
    GotoXY(SCREEN_W, CONTENT_Y);
    if TopVerse > 1 then
      Write('^')
    else
      Write(' ');
    GotoXY(SCREEN_W, CONTENT_Y2);
    if pageVisibleTo < verseCount then
      Write('v')
    else
      Write(' ');
  end;

  procedure DrawInfoLine;
  begin
    Str(CurChap:0, n1);
    Str(verseCount:0, n2);
    info := BookLabel(CurBook) + '  Capitulo ' + n1 + '  Verso ';
    DrawInfo(info);
    infoVerseX := 2 + Length(info);
  end;

  procedure DrawInfoVerse;
  begin
    Str(CurVerse:0, n3);
    if infoVerseX < 2 then
      infoVerseX := 2;
    if infoVerseX > SCREEN_W then
      infoVerseX := SCREEN_W;
    SetTitle;
    WriteAtPad(infoVerseX, INFO_Y, SCREEN_W - infoVerseX + 1, n3 + '/' + n2);
  end;

  procedure ClearVerseMap;
  var
    i: Integer;
  begin
    for i := 1 to MAX_CHAP_VERSES do
      VerseYStart[i] := 0;
  end;

  procedure DrawPage;
  var
    yy: Byte;
  begin
    ClearVerseMap;
    for yy := CONTENT_Y to CONTENT_Y2 do
      WriteAt(1, yy, ' ');
    y := CONTENT_Y;
    v := TopVerse;
    pageVisibleTo := TopVerse;
    while (y <= CONTENT_Y2) and (v <= verseCount) do
    begin
      if v <= MAX_CHAP_VERSES then
        VerseYStart[v] := y;

      globalIdx := ChapStart[chapId] + (v - 1);
      if ReadVerse(globalIdx) then
      begin
        DrawVerse(v, False, y);
        pageVisibleTo := v;
      end
      else
      begin
        SetNormal;
        ClearLine(y);
        WriteAt(2, y, '(erro lendo verso)');
        Inc(y);
      end;
      Inc(v);
    end;
    while y <= CONTENT_Y2 do
    begin
      SetNormal;
      ClearLine(y);
      Inc(y);
    end;
    DrawScroll;
  end;

  procedure DrawVerseMarker(VerseNum: Word; Selected: Boolean);
  var
    yy: Byte;
  begin
    if (VerseNum < 1) or (VerseNum > verseCount) then
      Exit;
    if VerseNum > MAX_CHAP_VERSES then
      Exit;
    yy := VerseYStart[VerseNum];
    if yy = 0 then
      Exit;
    SetNormal;
    if Selected then
      WriteAt(1, yy, '>')
    else
      WriteAt(1, yy, ' ');
  end;
begin
  needFullRedraw := True;
  prevBook := 0;
  prevChap := 0;
  prevTopVerse := 0;
  prevCurVerse := 0;
  pageVisibleTo := 0;

  while Running do
  begin
    chapId := ChapterId(CurBook, CurChap);
    verseCount := ChapVerseCount[chapId];
    if CurVerse < 1 then CurVerse := 1;
    if CurVerse > verseCount then CurVerse := verseCount;
    if TopVerse < 1 then TopVerse := 1;
    if TopVerse > verseCount then TopVerse := verseCount;

    if needFullRedraw or (CurBook <> prevBook) or (CurChap <> prevChap) then
    begin
      DrawStatic;
      DrawInfoLine;
      DrawInfoVerse;
      DrawPage;
      DrawVerseMarker(CurVerse, True);
      prevBook := CurBook;
      prevChap := CurChap;
      prevTopVerse := TopVerse;
      prevCurVerse := CurVerse;
      needFullRedraw := False;
    end
    else if TopVerse <> prevTopVerse then
    begin
      DrawInfoLine;
      DrawInfoVerse;
      DrawPage;
      DrawVerseMarker(CurVerse, True);
      prevTopVerse := TopVerse;
      prevCurVerse := CurVerse;
    end
    else if CurVerse <> prevCurVerse then
    begin
      DrawInfoVerse;
      DrawVerseMarker(prevCurVerse, False);
      DrawVerseMarker(CurVerse, True);
      prevCurVerse := CurVerse;
      DrawScroll;
    end;

    visibleTo := pageVisibleTo;

    ch := ReadKey;
    if ch = #0 then
    begin
      ch2 := ReadKey;
      scan := Ord(ch2);
      if scan = 59 then { F1 }
      begin
        ShowHelp;
        needFullRedraw := True;
      end
      else if scan = 72 then { Up }
      begin
        if CurVerse > 1 then
          Dec(CurVerse);
        if CurVerse < TopVerse then
          TopVerse := CurVerse;
      end
      else if scan = 80 then { Down }
      begin
        if CurVerse < verseCount then
          Inc(CurVerse);
        if CurVerse > visibleTo then
          TopVerse := CurVerse;
      end
      else if scan = 73 then { PgUp }
      begin
        if CurVerse > 10 then
          CurVerse := CurVerse - 10
        else
          CurVerse := 1;
        TopVerse := CurVerse;
      end
      else if scan = 81 then { PgDn }
      begin
        if (CurVerse + 10) <= verseCount then
          CurVerse := CurVerse + 10
        else
          CurVerse := verseCount;
        TopVerse := CurVerse;
      end
      else if scan = 75 then { Left }
      begin
        MoveChapter(-1);
      end
      else if scan = 77 then { Right }
      begin
        MoveChapter(1);
      end
      else if scan = 71 then { Home }
      begin
        CurVerse := 1;
        TopVerse := 1;
      end
      else if scan = 79 then { End }
      begin
        CurVerse := verseCount;
        TopVerse := verseCount;
      end;
    end
    else
    begin
      if (ch = 'q') or (ch = 'Q') then
      begin
        Running := False;
        Exit;
      end;
      if (ch = 'b') or (ch = 'B') or (ch = #27) then
        Exit;
      if (ch = 'g') or (ch = 'G') then
      begin
        if PromptNumber('Ir para verso (1..' + n2 + '): ', 1, verseCount, tmp) then
        begin
          CurVerse := tmp;
          TopVerse := tmp;
        end;
        needFullRedraw := True;
      end;
    end;
  end;
end;

procedure MainUI;
var
  backToBooks: Boolean;
begin
  CurBook := 1;
  CurChap := 1;
  CurVerse := 1;
  TopVerse := 1;

  while Running do
  begin
    if not ScreenBooksSelect then
      Exit;

    if JumpDirect then
    begin
      JumpDirect := False;
      ScreenReader;
    end
    else
    begin
      backToBooks := False;
      while Running and (not backToBooks) do
      begin
        if ScreenChaptersSelect then
          ScreenReader
        else
          backToBooks := True;
      end;
    end;
  end;
end;

begin
  SetNormal;
  LoadMeta;
  OpenDataFiles;

  Running := True;

  if HasParam('/T') or HasParam('-T') then
  begin
    SelfTest;
    Running := False;
  end
  else
    MainUI;

  Close(FIdx);
  Close(FDat);
end.
