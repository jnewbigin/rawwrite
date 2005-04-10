unit stub;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, CheckLst, ComCtrls, ExtCtrls, OpenDir, FileCtrl;

type
  TStubForm = class(TForm)
    Label1: TLabel;
    Label2: TLabel;
    CheckListBox1: TCheckListBox;
    Label3: TLabel;
    WriteButton: TButton;
    ExitButton: TButton;
    StatusBar1: TStatusBar;
    DescriptionLabel: TLabel;
    Label4: TLabel;
    FloppyImage: TImage;
    DriveComboBox: TComboBox;
    Label5: TLabel;
    OpenDirectory1: TOpenDirectory;
    CancelButton: TButton;
    VerifyButton: TButton;
    procedure ExitButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure WriteButtonClick(Sender: TObject);
    procedure CheckListBox1Click(Sender: TObject);
    procedure DriveComboBoxDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure CancelButtonClick(Sender: TObject);
    procedure VerifyButtonClick(Sender: TObject);
    procedure CheckListBox1ClickCheck(Sender: TObject);
  private
    { Private declarations }
    ProgressSize : Integer;
  public
    { Public declarations }
    DiskInfo : TStringList;
    OSis95 : Boolean;

    procedure FindFloppy;
    procedure Find95Floppy;
    procedure FindNTFloppy;
    function OnProgress(Progress : Int64; Error : DWORD) : Boolean;

  end;

var
  StubForm: TStubForm;

implementation

uses studio_tools, winbinfile, zlib, debug, winver, md5;

{$R *.DFM}

procedure TStubForm.ExitButtonClick(Sender: TObject);
begin
   Close;
end;

procedure TStubForm.FormCreate(Sender: TObject);
var
   i : Integer;
   Chopper : TStringList;
   Data : String;
   Line : String;
   Name : String;
   Index : Integer;

   Version : TOSVersionInfo;
   VersionString : String;
begin
   OSis95 := False;
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

      if Version.dwPlatformId = VER_PLATFORM_WIN32_WINDOWS then
      begin
         OSis95 := True;
      end;

      StatusBar1.Panels[1].Text := VersionString;
   end;

   for i := 1 to ParamCount do
   begin
      if ParamStr(i) = '--verify' then
      begin
         VerifyButton.Visible := True;
      end
   end;
   
   DiskInfo := TStringList.Create;
   Data := LoadDiskResource('DISKINFO');
   try
      Data := ZDecompressStr(Data);
   except;
   end;
   DiskInfo.Text := Data;

   if DiskInfo.Count > 0 then
   begin
      Label5.Caption := DiskInfo[0];
   end
   else
   begin
      Label5.Caption := 'Disk set not found';
   end;

   for i := 1 to DiskInfo.Count - 1 do
   begin
      Line := Trim(DiskInfo[i]);
      if Length(Line) > 0 then
      begin
         Chopper := TStringList.Create;
         Chopper.CommaText := DiskInfo[i];
         if Chopper.Count = 6 then
         begin
            Name := Chopper[1] + ' (' + Chopper[0] + ')';
            Index := CheckListBox1.Items.AddObject(Name, Chopper);
            if Chopper[3] = 'TRUE' then
            begin
               CheckListBox1.Checked[Index] := True;
            end;
         end;
      end;
   end;
   if CheckListBox1.Items.Count > 0 then
   begin
      CheckListBox1.ItemIndex := 0;
      CheckListBox1Click(CheckListBox1);
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

   DriveComboBox.Items.Add('Save as file...');
   if DriveComboBox.Items.Count = 1 then
   begin
      // this is the only option
      DriveComboBox.ItemIndex := 0;
   end;
   
end;

function TStubForm.OnProgress(Progress : Int64; Error : DWORD) : Boolean;
begin
   StatusBar1.Panels[0].Text := IntToStr((Progress * 100) div ProgressSize) + '%';
   //Log(IntToStr(Progress) + ' of ' + IntToStr(ProgressSize));
   if Error > 0 then
   begin
      MessageDlg(SysErrorMessage(Error), mtError, [mbOK], 0);
   end;

   Application.ProcessMessages;
   if CancelButton.Tag > 0 then
   begin
      Result := True;
   end
   else
   begin
      Result := False;
   end;
end;

procedure TStubForm.WriteButtonClick(Sender: TObject);
var
   i : Integer;
   Count : Integer;
   Chopper : TStringList;
   Data : String;
   BinFile : TBinaryFile;
   Dir : String;
   L : Integer;
   UsingFloppy : Boolean;
   DoWrite : Boolean;
begin
   try
      CancelButton.Tag := 0;
      CancelButton.Left := WriteButton.Left;
      CancelButton.Visible := True;
      WriteButton.Visible := False;
      // see if we need to get a directory to save to
      if DriveComboBox.ItemIndex = DriveComboBox.Items.Count - 1 then
      begin
         DoWrite := True;
         UsingFloppy := False;
      end
      else
      begin
         DoWrite := False;
         UsingFloppy := True;
      end;

      if UsingFloppy then
      begin
         L := 256;
         SetLength(Dir, L);
         L := GetTempPath(L, PChar(Dir));
         SetLength(Dir, L);
      end
      else
      begin
         if OpenDirectory1.Execute then
         begin
            Dir := OpenDirectory1.Directory + '\';
            if not DirectoryExists(Dir) then
            begin
               exit;
            end;
         end
         else
         begin
            // cancel...
            exit;
         end;
      end;
      Count := 0;
      for i := 0 to CheckListBox1.Items.Count - 1 do
      begin
         if CheckListBox1.Checked[i] then
         begin
            Count := Count + 1;
            Chopper := TStringList(CheckListBox1.Items.Objects[i]);

            if UsingFloppy then
            begin
               if MessageDlg('Insert disk for ' + Chopper[0], mtInformation, mbOKCancel, 0) = mrOK then
               begin
                  DoWrite := True;
               end;
            end;

            if DoWrite then
            begin
               Data := LoadDiskResource(Chopper[4]);
               try
                  Data := ZDecompressStr(Data);
               except
               end;
               BinFile := TBinaryFile.Create;
               try
                  BinFile.Assign(Dir + Chopper[0]);
                  BinFile.Delete;
                  BinFile.CreateNew;
                  BinFile.BlockWrite2(PChar(Data), Length(Data));
                  BinFile.Close;

                  if UsingFloppy then
                  begin
                     ProgressSize := Length(Data);
                     DoDD(BinFile.GetFileName, DriveComboBox.Text, 1024 * 8, -1, 0, 0, OnProgress);
                     BinFile.Delete;
                  end;
               finally
                  BinFile.Free;
               end;
            end;
         end;
      end;

      if Count = 0 then
      begin
         MessageDlg('Please select at least one disk to write', mtError, [mbOK], 0);
      end
      else
      begin
         if not UsingFloppy then
         begin
            MessageDlg(IntToStr(Count) + ' image file(s) extraced to ' + Dir, mtInformation, [mbOK], 0);
         end;
      end;
   finally
      WriteButton.Visible := True;
      CancelButton.Visible := False;
   end;
end;

procedure TStubForm.CheckListBox1Click(Sender: TObject);
var
   i : Integer;
   Chopper : TStringList;
begin
   // update the description
   i := CheckListBox1.ItemIndex;
   if i >= 0 then
   begin
      Chopper := TStringList(CheckListBox1.Items.Objects[i]);
      DescriptionLabel.Caption := Chopper[2];
   end;
end;

procedure TStubForm.DriveComboBoxDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
   SaveColor : TColor;
begin
   with Control as TComboBox do
   begin
      SaveColor := Canvas.Brush.Color;
      Canvas.Brush.Color := clWindow;
      Canvas.FillRect(Rect);
      Canvas.Brush.Color := SaveColor;
      if Index < Items.Count - 1 then
      begin
         // draw the icon
         Canvas.Draw(Rect.Left + 2, Rect.Top + 3, FloppyImage.Picture.Graphic);
      end;
      Canvas.TextOut(Rect.Left + 20, Rect.Top, Items[Index]);
   end;
end;

procedure TStubForm.FindFloppy;
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

procedure TStubForm.Find95Floppy;
begin
   // just add a and b ...? at least for now
   DriveComboBox.Items.Add('A:');
   DriveComboBox.Items.Add('B:');
end;

procedure TStubForm.FindNTFloppy;
var
   h : THandle;
   FileName : String;
   Error : DWORD;
   Drives : TStringList;
   i : Integer;
   DriveType : Integer;
begin
   Drives := TStringList.Create;
   try
      GetDriveStrings(Drives);

      for i := 0 to Drives.Count - 1 do
      begin
         DriveType := Integer(Drives.Objects[i]);
         if DriveType = DRIVE_REMOVABLE then
         begin
            FileName := '\\.\' + Drives[i];
            EndsWith(FileName, '\', FileName);
            h := CreateFile(PChar(FileName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, 0, 0);
            if h <> INVALID_HANDLE_VALUE then
            begin
               DriveComboBox.Items.Add(FileName);
               CloseHandle(h);
            end
            else
            begin
               Error := GetLastError;
               if Error = 21 then
               begin
                  DriveComboBox.Items.Add(FileName);
               end
               else
               begin
                  ShowError(FileName);
               end;
            end;
         end;
      end;
   finally
      Drives.Free;
   end;
end;

procedure TStubForm.CancelButtonClick(Sender: TObject);
begin
   CancelButton.Tag := 1;
end;

procedure TStubForm.VerifyButtonClick(Sender: TObject);
var
   i : Integer;
   Data : String;
   Chopper : TStringList;
   Checksum : String;
   Details : String;
begin
   for i := 0 to CheckListBox1.Items.Count - 1 do
   begin
//      if CheckListBox1.Checked[i] then
      begin
         Chopper := TStringList(CheckListBox1.Items.Objects[i]);

         Data := LoadDiskResource(Chopper[4]);
         try
            Data := ZDecompressStr(Data);
         except
         end;

         Checksum := MD5Print(MD5String(Data));
         if Checksum <> Chopper[5] then
         begin
            Details := Details + 'Checksum failed for ' + Chopper[0] + '.  Should be ' + Chopper[5] + ' but is ' + Checksum;
         end;
      end;
   end;
   if Length(Details) > 0 then
   begin
      MessageDlg(Details, mtError, [mbOK], 0);
   end;
end;

procedure TStubForm.CheckListBox1ClickCheck(Sender: TObject);
var
   i : Integer;
   Count : Integer;
begin
   Count := 0;
   for i := 0 to CheckListBox1.Items.Count - 1 do
   begin
      if CheckListBox1.Checked[i] then
      begin
         Count := Count + 1;
      end;
   end;

   if Count > 0 then
   begin
      WriteButton.Enabled := True;
   end
   else
   begin
      WriteButton.Enabled := False;
   end;
end;

end.
