unit rawwrite;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ComCtrls, ExtCtrls, BlockDev;

const
   DebugHigh = 0;
   DebugOff = 0;
   DebugLow = 0;
type
  TMainForm = class(TForm)
    Label2: TLabel;
    StatusBar1: TStatusBar;
    FloppyImage: TImage;
    DriveComboBox: TComboBox;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Button3: TButton;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    Label1: TLabel;
    FileNameEdit: TEdit;
    Button1: TButton;
    OpenDialog1: TOpenDialog;
    DebugMemo: TMemo;
    WriteButton: TButton;
    Button2: TButton;
    Label7: TLabel;
    ReadFileNameEdit: TEdit;
    Button4: TButton;
    Button5: TButton;
    SaveDialog1: TSaveDialog;
    TabSheet3: TTabSheet;
    Memo1: TMemo;
    Label8: TLabel;
    Label9: TLabel;
    TabSheet4: TTabSheet;
    Label10: TLabel;
    Label11: TLabel;
    WriteCopyEdit: TEdit;
    UpDown1: TUpDown;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure DriveComboBoxDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure WriteButtonClick(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Label5Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Label3DblClick(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
  private
    { Private declarations }
    OSis95 : Boolean;

    procedure Find95Floppy;
    procedure FindNTFloppy;

    procedure Write95Floppy;
    procedure WriteNTFloppy;

  public
    { Public declarations }
    procedure FindFloppy;
    procedure Wait;
    procedure UnWait;
  end;

var
  MainForm: TMainForm;


function ReadFile2(hFile: THandle; Buffer : Pointer; nNumberOfBytesToRead: DWORD;
   var lpNumberOfBytesRead: DWORD; lpOverlapped: POverlapped): BOOL; stdcall;
function WriteFile2(hFile: THandle; Buffer : Pointer; nNumberOfBytesToWrite: DWORD;
   var lpNumberOfBytesWritten: DWORD; lpOverlapped: POverlapped): BOOL; stdcall;

procedure Debug(Str : String; Level : Integer);

implementation

uses DiskIO, ShellAPI;

{$R *.DFM}

function ReadFile2; external kernel32 name 'ReadFile';
function WriteFile2; external kernel32 name 'WriteFile';

procedure Debug(Str : String; Level : Integer);
begin
   MainForm.DebugMemo.Lines.Add(Str);
end;

procedure TMainForm.Wait;
begin
   Screen.Cursor := crHourGlass;
end;

procedure TMainForm.UnWait;
begin
   Screen.Cursor := crDefault;
end;

procedure TMainForm.Button1Click(Sender: TObject);
begin
   OpenDialog1.FileName := FileNameEdit.Text;
   if OpenDialog1.Execute then
   begin
      FileNameEdit.Text := OpenDialog1.FileName;
   end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
   Version : TOSVersionInfo;
   VersionString : String;
begin
   // Prevent error messages being displayed by NT
   SetErrorMode(SEM_FAILCRITICALERRORS);

   // what OS
   Version.dwOSVersionInfoSize := Sizeof(Version);
   if GetVersionEx(Version) then
   begin
      case Version.dwPlatformId of
         VER_PLATFORM_WIN32s        : VersionString := 'WIN32s';
         VER_PLATFORM_WIN32_WINDOWS : VersionString := 'Windows 95';
         VER_PLATFORM_WIN32_NT      : VersionString := 'Windows NT';
      else
         VersionString := 'Unknown OS';
      end;
      VersionString := VersionString + ' ' + IntToStr(Version.dwMajorVersion) +
                                       '.' + IntToStr(Version.dwMinorVersion) +
                                       ' build number ' + IntToStr(Version.dwBuildNumber);
      StatusBar1.Panels[1].Text := VersionString;
      if Version.dwPlatformId = VER_PLATFORM_WIN32_WINDOWS then
      begin
         OSis95 := True;
      end
      else
      begin
         OSis95 := False;
      end;
   end
   else
   begin
      MessageDlg('Could not get Version info!', mtError, [mbOK], 0);
   end;
   FindFloppy;
   if DriveComboBox.Items.Count > 0 then
   begin
      DriveComboBox.ItemIndex := 0;
   end
   else
   begin
      MessageDlg('No Floppy drives found', mtInformation, [mbOK], 0);
   end;
end;

procedure TMainForm.FindFloppy;
begin
   if OSis95 then
   begin
      Find95Floppy;
   end
   else
   begin
      FindNTFloppy;
   end;
end;

procedure TMainForm.Find95Floppy;
begin
   // just add a and b ...? at least for now
   DriveComboBox.Items.Add('A:');
   DriveComboBox.Items.Add('B:');
end;

procedure TMainForm.FindNTFloppy;
var
   Drive : Char;
   h : THandle;
   FileName : String;
begin
   for Drive := 'A' to 'B' do
   begin
      FileName := '\\.\' + Drive + ':';
      h := CreateFile(PChar(FileName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, 0, 0);
      if h <> INVALID_HANDLE_VALUE then
      begin
         DriveComboBox.Items.Add(FileName);
         CloseHandle(h);
      end;

   end;
end;

procedure TMainForm.DriveComboBoxDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
   with Control as TComboBox do
   begin
      // draw the icon
      Canvas.Draw(Rect.Left + 2, Rect.Top + 3, FloppyImage.Picture.Graphic);
      Canvas.TextOut(Rect.Left + 20, Rect.Top, Items[Index]);
   end;
end;

procedure TMainForm.WriteButtonClick(Sender: TObject);
begin
   if OSis95 then
   begin
      Write95Floppy;
   end
   else
   begin
      WriteNTFloppy;
   end;
end;

procedure TMainForm.Write95Floppy;
var
   h1       : THandle;
   Disk     : T95Disk;
   Buffer   : String;
   Read     : DWORD;
   Written  : DWORD;
   Blocks   : Integer;
   WrittenBlocks : Integer;
begin
   // make sure that the file exists...
   h1 := CreateFile(PChar(FileNameEdit.Text), GENERIC_READ, 0, nil, OPEN_EXISTING, 0, 0);
   if h1 <> INVALID_HANDLE_VALUE then
   try
      Blocks := GetFileSize(h1, nil) div 512;
      WrittenBlocks := 0;
      // open the drive
      Disk := T95Disk.Create;
      if DriveComboBox.ItemIndex >= 0 then
      begin
         Disk.SetDisk(DriveComboBox.ItemIndex);

         // write away...
         SetLength(Buffer, 4096);
         while true do
         begin
            ReadFile2(h1, PChar(Buffer), 4096, Read, nil);
            if Read = 0 then break;
            if not Disk.WriteSector(WrittenBlocks, PChar(Buffer), 8) then
            begin
               MessageDlg('Error writing to disk!', mtError, [mbOK], 0);
               break;
            end;
            Inc(WrittenBlocks, 8);
            StatusBar1.Panels[0].Text := IntToStr((WrittenBlocks * 100) div Blocks) + '%';
            StatusBar1.Refresh;
         end;
      end
      else
      begin
         MessageDlg('Please select a drive!', mtError, [mbOK], 0);
      end;
   finally
      CloseHandle(h1);
   end
   else
   begin
      MessageDlg('Error: ' + SysErrorMessage(Error) + '(' + IntToStr(GetLastError) + ')', mtError, [mbOK], 0);
   end;
end;

procedure TMainForm.WriteNTFloppy;
var
   h1       : THandle;
   h2       : THandle;
   Buffer   : String;
   Read     : DWORD;
   Written  : DWORD;
   Blocks   : Integer;
   WrittenBlocks : Integer;
begin
   // make sure that the file exists...
   h1 := CreateFile(PChar(FileNameEdit.Text), GENERIC_READ, 0, nil, OPEN_EXISTING, 0, 0);
   if h1 <> INVALID_HANDLE_VALUE then
   try
      Blocks := GetFileSize(h1, nil) div 512;
      WrittenBlocks := 0;
      // open the drive
      h2 := CreateFile(PChar(DriveComboBox.Text), GENERIC_WRITE, 0, nil, OPEN_EXISTING, 0, 0);
      if h2 <> INVALID_HANDLE_VALUE then
      try
         // write away...
         SetLength(Buffer, 512);
         while true do
         begin
            ReadFile2(h1, PChar(Buffer), 512, Read, nil);
            if Read = 0 then break;
            if not WriteFile2(h2, PChar(Buffer), 512, Written, nil) then
            begin
               MessageDlg('Error ' + IntToStr(GetLastError), mtError, [mbOK], 0);
               break;
            end;
            Inc(WrittenBlocks);
            StatusBar1.Panels[0].Text := IntToStr((WrittenBlocks * 100) div Blocks) + '%';
            StatusBar1.Refresh;
         end;
      finally
         CloseHandle(h2);
      end
      else
      begin
         MessageDlg('Error ' + IntToStr(GetLastError), mtError, [mbOK], 0);
      end;
   finally
      CloseHandle(h1);
   end
   else
   begin
      MessageDlg('Error ' + IntToStr(GetLastError), mtError, [mbOK], 0);
   end;
end;

procedure TMainForm.Button2Click(Sender: TObject);
var
   h1       : THandle;
   Buffer   : String;
   Read     : DWORD;
   Written  : DWORD;
   Blocks   : Integer;
   WrittenBlocks  : Integer;
   BlocksCount    : Integer;
   BlocksRemaining : Integer;
   BlockCount     : Integer;
   FileSize  : Integer;
   CopiesRemaining : Integer;

   Device   : TBlockDevice;
   Zero     : _Large_Integer;
   DiskSize : _Large_Integer;
begin
   if DriveComboBox.ItemIndex < 0 then
   begin
      MessageDlg('Please Select a disk drive', mtWarning, [mbOK], 0);
      exit;
   end;

   Wait;
   try
      CopiesRemaining := UpDown1.Position;

      while CopiesRemaining > 0 do
      begin
         CopiesRemaining := CopiesRemaining - 1;
         BlocksCount := 64;

         // make sure that the file exists...
         h1 := CreateFile(PChar(FileNameEdit.Text), GENERIC_READ, 0, nil, OPEN_EXISTING, 0, 0);
         if h1 <> INVALID_HANDLE_VALUE then
         try
            FileSize := GetFileSize(h1, nil);
            Blocks := FileSize div 512;
            if (Blocks * 512) < FileSize then
            begin
               Blocks := Blocks + 1;
            end;

            WrittenBlocks := 0;

            SetLength(Buffer, 512 * BlocksCount);
            // open the drive
            if osIs95 then
            begin
               Device := TWin95Disk.Create;
               TWin95Disk(Device).SetDiskNumber(DriveComboBox.ItemIndex);
               TWin95Disk(Device).SetOffset(0);
            end
            else
            begin
               Zero.Quadpart := 0;
               DiskSize.Quadpart := 512 * 80 * 2 * 18;
               Device := TNTDisk.Create;
               TNTDisk(Device).SetFileName(DriveComboBox.Text);
               TNTDisk(Device).SetMode(True);
               TNTDisk(Device).SetPartition(Zero, DiskSize);
            end;

            if Device.Open then
            try
               // write away...
               while WrittenBlocks < Blocks do
               begin
                  BlocksRemaining := Blocks - WrittenBlocks;
                  if BlocksRemaining > BlocksCount then
                  begin
                     BlockCount := BlocksCount;
                  end
                  else
                  begin
                     BlockCount := BlocksRemaining;
                  end;

                  ReadFile2(h1, PChar(Buffer), 512 * BlockCount, Read, nil);
                  if Read = 0 then break;
                  Device.WritePhysicalSector(WrittenBlocks, BlockCount, PChar(Buffer));
                  WrittenBlocks := WrittenBlocks + BlockCount;
                  StatusBar1.Panels[0].Text := IntToStr((WrittenBlocks * 100) div Blocks) + '%';
                  Application.ProcessMessages;
               end;
            finally
               Device.Close;
               Device.Free;
            end
            else
            begin
               MessageDlg('Error ' + IntToStr(GetLastError), mtError, [mbOK], 0);
            end;
         finally
            CloseHandle(h1);
         end
         else
         begin
            MessageDlg('Error ' + IntToStr(GetLastError), mtError, [mbOK], 0);
         end;
      end;
   finally
      UnWait;
   end;
end;

procedure TMainForm.Label5Click(Sender: TObject);
begin
   ShellExecute(Handle, 'open', PChar(TLabel(Sender).Caption), nil, nil, SW_SHOWNORMAL)
end;

procedure TMainForm.Button3Click(Sender: TObject);
begin
   Close;
end;

procedure TMainForm.Label3DblClick(Sender: TObject);
begin
//   This will enable the original write code
   DebugMemo.Visible    := True;
//   WriteButton.Visible  := True;
end;

procedure TMainForm.Button4Click(Sender: TObject);
begin
   SaveDialog1.FileName := ReadFileNameEdit.Text;
   if SaveDialog1.Execute then
   begin
      ReadFileNameEdit.Text := SaveDialog1.FileName;
   end;
end;

procedure TMainForm.Button5Click(Sender: TObject);
var
   h1       : THandle;
   Buffer   : String;
   Read     : DWORD;
   Written  : DWORD;
   Blocks   : Integer;
   WrittenBlocks  : Integer;
   BlocksCount    : Integer;
   BlocksRemaining : Integer;
   BlockCount     : Integer;
   FileSize  : Integer;

   Device   : TBlockDevice;
   Zero     : _Large_Integer;
   DiskSize : _Large_Integer;
begin
   if DriveComboBox.ItemIndex < 0 then
   begin
      MessageDlg('Please Select a disk drive', mtWarning, [mbOK], 0);
      exit;
   end;

   Wait;
   try

      BlocksCount := 64;

      // make sure that the file exists...
      h1 := CreateFile(PChar(ReadFileNameEdit.Text), GENERIC_WRITE, 0, nil, CREATE_ALWAYS, 0, 0);
      if h1 <> INVALID_HANDLE_VALUE then
      try
         // we need to read until the end of the disk
         // all data gets written to the file...

{         FileSize := GetFileSize(h1, nil);
         Blocks := FileSize div 512;
         if (Blocks * 512) < FileSize then
         begin
            Blocks := Blocks + 1;
         end;}

         WrittenBlocks := 0;

         Blocks := 2880; // no of 512 blocks on a 1.44 (= 80 * 2 * 18)

         SetLength(Buffer, 512 * BlocksCount);
         // open the drive
         if osIs95 then
         begin
            Device := TWin95Disk.Create;
            TWin95Disk(Device).SetDiskNumber(DriveComboBox.ItemIndex);
            TWin95Disk(Device).SetOffset(0);
         end
         else
         begin
            Zero.Quadpart := 0;
            DiskSize.Quadpart := 512 * 80 * 2 * 18;
            Device := TNTDisk.Create;
            TNTDisk(Device).SetFileName(DriveComboBox.Text);
            TNTDisk(Device).SetMode(True);
            TNTDisk(Device).SetPartition(Zero, DiskSize);
         end;

         if Device.Open then
         try
            // write away...
            while WrittenBlocks < Blocks do
            begin
               BlocksRemaining := Blocks - WrittenBlocks;
               if BlocksRemaining > BlocksCount then
               begin
                  BlockCount := BlocksCount;
               end
               else
               begin
                  BlockCount := BlocksRemaining;
               end;


               Device.ReadPhysicalSector(WrittenBlocks, BlockCount, PChar(Buffer));

               WriteFile2(h1, PChar(Buffer), 512 * BlockCount, Read, nil);
//               if Read = 0 then break;

//               Device.WritePhysicalSector(WrittenBlocks, BlockCount, PChar(Buffer));
               WrittenBlocks := WrittenBlocks + BlockCount;
               StatusBar1.Panels[0].Text := IntToStr((WrittenBlocks * 100) div Blocks) + '%';
               Application.ProcessMessages;
            end;
         finally
            Device.Close;
            Device.Free;
         end
         else
         begin
            MessageDlg('Error ' + IntToStr(GetLastError), mtError, [mbOK], 0);
         end;
      finally
         CloseHandle(h1);
      end
      else
      begin
         MessageDlg('Error ' + IntToStr(GetLastError), mtError, [mbOK], 0);
      end;
   finally
      UnWait;
   end;
end;

end.


