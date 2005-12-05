unit persrc;

{$IFDEF FPC}
{$MODE Delphi}
{$ENDIF}

interface

{$IFDEF WIN32}
uses windows, classes, sysutils, winbinfile;
{$ELSE}
uses classes, sysutils, UnixBinFile;
{$ENDIF}

type TPEHeader = record
   magic                : array[0..3] of char; //PE#0#0
   machine_type         : word;
   section_count        : word;
   date_time_stamp      : dword;
   symbol_table_offset  : dword;
   symbol_count         : dword;
   optional_header_size : word;
   flags                : word;

   // optional header
   optional_magic       : word;
   link_major           : byte;
   link_minor           : byte;
   total_code_size      : dword;
   total_data_size      : dword;
   total_bss_size       : dword;
   entry_point          : dword;
   code_base_address    : dword;
   data_base_address    : dword; // only in PE32 (0x10b)

   // NT optional header
   base_address         : dword;
   section_allignment   : dword;
   file_allignment      : dword;
   os_major             : word;
   os_minor             : word;
   image_major          : word;
   image_minor          : word;
   subsystem_major      : word;
   subsystem_minor      : word;
   reserved             : dword;
   image_size           : dword;
   header_size          : dword;
   checksum             : dword;
   subsystem            : word;
   dll_flags            : word;
   stack_reserve        : dword;
   stack_commit         : dword;
   heap_reserve         : dword;
   heap_commit          : dword;
   loader_flags         : dword;
   datadict_count       : dword;
end;
type PPEHeader = ^TPEHeader;

type TDirectoryData = record
   address              : dword;
   size                 : dword;
end;
type PDirectotyData = ^TDirectoryData;

type TSectionHeader = record
   name                 : array[0..7] of char;
   virtual_size         : dword;
   virtual_address      : dword;
   data_size            : dword;
   data_pointer         : dword;
   relocation_pointer   : dword;
   linenumber_pointer   : dword;
   relocation_count     : word;
   linenumber_count     : word;
   flags                : dword;
end;
type PSectionHeader = ^TSectionHeader;

type TResourceTable = record
   flags                : dword;
   date_time_stamp      : dword;
   major                : word;
   minor                : word;
   name_count           : word;
   id_count             : word;
end;
type PResourceTable = ^TResourceTable;

type TResourceEntry = record
   name_id              : dword;
   data_pointer         : dword;
end;
type PResourceEntry = ^TResourceEntry;

type TResourceData = record
   data_offset    : dword;
   data_size      : dword;
   codepage       : dword;
   reserved       : dword;
end;
type PResourceData = ^TResourceData;

type TResourceTreeNode = class(TObject)
  private
   Parent         : TObject;
   Children       : TList;  // if Children.Count = 0 then this is a leaf, otherwise this is a ResourceTable (subdirectory)
   ResourceTable  : TResourceTable;
   id : dword; // if name = '' then this is the id otherwise this is a string address
   name : WideString;

   leafdata : String;   // if this is a leaf node the the data is loaded in here...
   codepage : dword;    // leaf node data

   resource_table_offset   : dword; // the offset for this table/leaf when repacking
   resource_string_offset  : dword; // the offset to a string (if any) when repacking
   resource_data_offset    : dword; // the offset for the leaf data when repacking

  public
   constructor Create(Parent : TObject; name_id : dword);
   procedure SetLeafData(LeafData : String; codepage : dword);
   function GetDepth : Integer;
   procedure SetName(Name : WideString);
   function GetName : String;
   function GetPath : String;
   function GetNodeByName(Name : WideString) : TResourceTreeNode;
   function GetNodeById(id : dword) : TResourceTreeNode;
   function CreateNode : TResourceTreeNode;
   procedure SortChildren;

   procedure Unpack(Resource_Offset : dword; Section_Address : dword; F : TBinaryFile);
   function Repack(Section_Address : dword) : String;
end;

type TPEFile = class(TObject)

 private
   FileName : String;
   F : TBinaryFile;
   PE_Offset : DWord;
   PE_Header : TPEHeader;
   Resource_Offset : DWord;
   Section_Offset : DWord;
   Rsrc_Section_Number : dword;
   Rsrc_Section_Header : TSectionHeader;

   Tree_Root : TResourceTreeNode;

 public
   constructor Create(FileName : String);
   property GetRsrcRoot : TResourceTreeNode read Tree_Root;
   procedure Save;

end;

function Allign(n : dword; a : dword) : dword;

implementation

uses debug;

constructor TPEFile.Create(FileName : String);
var
   MZ : array[0..1] of char;
   PE : array[0..3] of char;
   W : Word;

   SectionNumber : Integer;
begin
   self.FileName := FileName;
   F := TBinaryFile.Create;
   F.Assign(FileName);
   F.Open(1);

   PE_Offset := 0;
   Resource_Offset := 0;
   F.Seek(0);
   F.BlockRead2(@MZ, sizeof(MZ));

   if MZ = 'MZ' then
   begin
      F.Seek($18);
      F.BlockRead2(@W, sizeof(W));
      if W = $40 then // next step is to find the PE header
      begin
         F.Seek($3C);
         F.BlockRead2(@W, sizeof(W));

         F.Seek(W);
         F.BlockRead2(@PE, sizeof(PE));

         if PE = 'PE' then
         begin
            PE_Offset := W;
         end;
      end;
   end;

   if PE_Offset > 0 then
   begin
      // read PE
      F.Seek(PE_Offset);
      F.BlockRead2(@PE_Header, sizeof(PE_Header));

      Section_Offset := PE_Offset + sizeof(PE_Header) + (PE_Header.datadict_count * 8);

{      for Directory_Number := 0 to PE_Header.datadict_count - 1 do
      begin
         F.Seek(PE_Offset + sizeof(PE_Header) + Directory_Number * sizeof(Directory_Data));
         F.BlockRead2(@Directory_Data, sizeof(Directory_Data));
         Debug('Dir ' + IntToHex(Directory_Number + 1, 2) + '     ' + IntToHex(Directory_Data.size, 8));
      end;}

      F.Seek(Section_Offset);
      for SectionNumber := 1 to PE_Header.section_count do
      begin
         F.BlockRead2(@Rsrc_Section_Header, sizeof(Rsrc_Section_Header));
         if Rsrc_Section_Header.name = '.rsrc' then
         begin
            Rsrc_Section_Number := SectionNumber;
            Resource_Offset := Rsrc_Section_Header.data_pointer;

            // Read in the Resource Buffer...
//            F.Seek(Resource_Offset);
//            SetLength(Buffer, Section_Header.data_size);
//            F.BlockRead2(PChar(Buffer), Section_Header.data_size);
            break;
         end;
      end;
   end;

   if Resource_Offset > 0 then
   begin
      Tree_Root := TResourceTreeNode.Create(nil, 0);
      Tree_Root.Unpack(Resource_Offset, Rsrc_Section_Header.virtual_address, F);
   end;

end;

procedure TPEFile.Save;
var
   RsrcData : String;
   DataSizeDelta : dword;
   Directory_Data : TDirectoryData;
   Adjustment : dword;
begin
   // we need to adjust the following sizes
   // PE Optional Header Image Size
   // PE Optional Header Data Size
   // Directory entry 3
   // section length

   RsrcData := Tree_Root.Repack(Rsrc_Section_Header.virtual_address);

   //Log('Rsrc len = ' + IntToStr(Length(RsrcData)));
   DataSizeDelta := Length(RsrcData) - Rsrc_Section_Header.data_size;
   //Log('Delta = ' + IntToStr(DataSizeDelta));

   if DataSizeDelta mod PE_Header.section_allignment <> 0 then
   begin
      // We need to adjust the size of the RsrcData to make this allign
      Adjustment := PE_Header.section_allignment - (DataSizeDelta mod PE_Header.section_allignment);
      Log('Adjusting size by ' + IntToStr(Adjustment));
      SetLength(RsrcData, Length(RsrcData) + Adjustment);
      //Log('New Rsrc len = ' + IntToStr(Length(RsrcData)));
      DataSizeDelta := Length(RsrcData) - Rsrc_Section_Header.data_size;
      //Log('New Delta = ' + IntToStr(DataSizeDelta));
   end;

   Rsrc_Section_Header.virtual_size := Length(RsrcData);
   Rsrc_Section_Header.data_size := Length(RsrcData);
   F.Seek(Section_Offset + (Rsrc_Section_Number - 1)* sizeof(Rsrc_Section_Header));
   F.BlockWrite2(@Rsrc_Section_Header, sizeof(Rsrc_Section_Header));

   PE_Header.total_data_size := PE_Header.total_data_size + DataSizeDelta;
   PE_Header.image_size := PE_Header.image_size + DataSizeDelta; //must be multiple of section_alignment
   F.Seek(PE_Offset);
   F.BlockWrite2(@PE_Header, sizeof(PE_Header));

   F.Seek(PE_Offset + sizeof(PE_Header) + 2 * sizeof(Directory_Data)); // 2 = 3rd entry
   F.BlockRead2(@Directory_Data, sizeof(Directory_Data));
   Directory_Data.size := Length(RsrcData);
   F.Seek(PE_Offset + sizeof(PE_Header) + 2 * sizeof(Directory_Data)); // 2 = 3rd entry
   F.BlockWrite2(@Directory_Data, sizeof(Directory_Data));

   F.Seek(Resource_Offset);
   F.BlockWrite2(PChar(RsrcData), Length(RsrcData));
   F.TruncateTo(Resource_Offset + Length(RsrcData));
   F.Close;
   F.Free;

end;


procedure Debug(S : String);
begin
   //Log(S);
end;

function Allign(n : dword; a : dword) : dword;
var
   d : dword;
begin
   d := n mod a;
   if d <> 0 then
   begin
      n := n + (a - d);
   end;
   Result := n;
end;


function Get_Resource_Name(Depth : Integer; id : dword) : String;
begin
   if Depth = 1 then
   begin
      case id of
         $0001 : Result := 'Cursor';
         $0002 : Result := 'Bitmap';
         $0003 : Result := 'Icon';
         $0004 : Result := 'Menu';
         $0005 : Result := 'Dialog';
         $0006 : Result := 'String Table';
         $0007 : Result := 'Font Directory';
         $0008 : Result := 'Font';
         $0009 : Result := 'Accelerators Table';
         $000A : Result := 'RC Data (custom binary data)';
         $000B : Result := 'Message table';
         $000C : Result := 'Group Cursor';
         $000E : Result := 'Group Icon';
         $0010 : Result := 'Version Information';
         $0011 : Result := 'Dialog Include';
         $0013 : Result := 'Plug''n''Play';
         $0014 : Result := 'VXD';
         $0015 : Result := 'Animated Cursor';
         $2002 : Result := 'Bitmap (new version)';
         $2004 : Result := 'Menu (new version)';
         $2005 : Result := 'Dialog (new version)';
         else    Result := IntToStr(id);
      end
   end
   else
   begin
      Result := IntToStr(id);
   end;
end;

constructor TResourceTreeNode.Create(Parent : TObject; name_id : dword);
begin
   if assigned(Parent) then
   begin
      TResourceTreeNode(Parent).Children.Add(self);
      self.Parent := Parent;
   end;
   Children := TList.Create;
   id := name_id;
end;

procedure TResourceTreeNode.SetLeafData(LeafData : String; codepage : dword);
begin
   //Form1.Debug('Leaf Data for ' + GetPath + ' len = ' + IntToStr(Length(LeafData)));
   self.LeafData := LeafData;
   self.codepage := codepage;
end;

function TResourceTreeNode.GetDepth : Integer;
begin
   if Assigned(Parent) then
   begin
      Result := TResourceTreeNode(Parent).GetDepth + 1;
   end
   else
   begin
      Result := 0;
   end;
end;

procedure TResourceTreeNode.SetName(Name : WideString);
begin
   self.Name := Name;
end;

function TResourceTreeNode.GetName : String;
begin
   if Length(Name) > 0 then
   begin
      Result := Name;
   end
   else
   begin
      if Assigned(Parent) then
      begin
         Result := Get_Resource_Name(GetDepth, id);
      end
      else
      begin
         Result := '';
      end;
   end;
end;

function TResourceTreeNode.GetPath : String;
begin
   if Assigned(Parent) then
   begin
      Result := TResourceTreeNode(Parent).GetPath + '\';
   end;

   Result := Result + GetName;
end;

function TResourceTreeNode.GetNodeByName(Name : WideString) : TResourceTreeNode;
var
   i : Integer;
   ChildNode : TResourceTreeNode;
begin
   Result := nil;
   for i := 0 to Children.Count - 1 do
   begin
      ChildNode := TResourceTreeNode(Children[i]);
      if ChildNode.name = Name then
      begin
         Result := ChildNode;
         break;
      end;
   end;
end;

function TResourceTreeNode.GetNodeById(id : dword) : TResourceTreeNode;
var
   i : Integer;
   ChildNode : TResourceTreeNode;
begin
   Result := nil;
   for i := 0 to Children.Count - 1 do
   begin
      ChildNode := TResourceTreeNode(Children[i]);
      if (ChildNode.name = '') and (ChildNode.id = id) then
      begin
         Result := ChildNode;
         break;
      end;
   end;
end;

function TResourceTreeNode.CreateNode : TResourceTreeNode;
begin
   Result := TResourceTreeNode.Create(self, 0);
end;

function NodeCompare(Item1, Item2: Pointer): Integer;
var
   Node1, Node2 : TResourceTreeNode;
begin
   Node1 := TResourceTreeNode(Item1);
   Node2 := TResourceTreeNode(Item2);

   if (Node1.name = '') and (Node2.name = '') then
   begin
      // id compare
      if Node1.id = Node2.id then
      begin
         Result := 0;
      end
      else if Node1.id < Node2.id then
      begin
         Result := -1;
      end
      else
      begin
         Result := 1;
      end;
   end
   else if (Node1.name <> '') and (Node2.name <> '') then
   begin
      // name compare
      Result := CompareStr(Node1.name, Node2.name);
   end
   else
   begin
      // one of each
      // names are always before id
      if Node1.name = '' then
      begin
         Result := -1;
      end
      else
      begin
         Result := 1;
      end;
   end;
end;

procedure TResourceTreeNode.SortChildren;
begin
   Children.Sort(NodeCompare);
end;

procedure HexDump(Buffer : String);
var
   i, j  : Integer;
   n     : Integer;
   S     : String;
begin
   n := 0;
//   Form1.Memo1.Lines.BeginUpdate;
   while n < Length(Buffer) do
   begin
      S := IntToHex(n, 8) + '  ';
      for j := 1 to 16 do
      begin
         S := S + IntToHex(Ord(Buffer[n + 1]), 2) + ' ';
         n := n + 1;
      end;
      Debug(S);
   end;
//   Form1.Memo1.Lines.EndUpdate;
end;

procedure TResourceTreeNode.Unpack(Resource_Offset : dword; Section_Address : dword; F : TBinaryFile);
   function Load_Unicode(Offset : dword) : WideString;
   var
      len : word;
   begin
      Offset := Offset and $7fffffff;
      F.Seek(Resource_Offset + Offset);
      F.BlockRead2(@len, sizeof(len));
      SetLength(Result, len);
      F.BlockRead2(PChar(Result), len * sizeof(WideChar));
   end;

   function LoadString(Offset : dword; Len : dword) : String;
   begin
      SetLength(Result, Len);
      F.Seek(Offset);
      F.BlockRead2(PChar(Result), Len);
   end;

var
   Resource_Entry : TResourceEntry;
   Resource_Data  : TResourceData;
   Entry_Offset : dword;
   i : Integer;
   NewNode : TResourceTreeNode;
   Node : TResourceTreeNode;
   NodeQueue : TList;
begin
   NodeQueue := TList.Create;
   resource_table_offset := 0;
   NodeQueue.Add(self);

   while NodeQueue.Count > 0 do
   begin
      Node := TResourceTreeNode(NodeQueue[0]);
      NodeQueue.Delete(0);

      F.Seek(Resource_Offset + Node.resource_table_offset);
      F.BlockRead2(@Node.ResourceTable, sizeof(Node.ResourceTable));
   Debug(IntToHex(Node.resource_table_offset, 4) + ' table (' + IntToStr(Node.ResourceTable.name_count) + ',' + IntToStr(Node.ResourceTable.id_count) + ')');
      Entry_Offset := Resource_Offset + Node.resource_table_offset + sizeof(Node.ResourceTable);
      for i := 0 to Node.ResourceTable.name_count + Node.ResourceTable.id_count - 1 do
      begin
         F.Seek(Entry_Offset + (i * sizeof(Resource_Entry)));
         F.BlockRead2(@Resource_Entry, sizeof(Resource_Entry));
   Debug(IntToHex(Node.resource_table_offset + sizeof(Node.ResourceTable) + (i * sizeof(Resource_Entry)), 4) + ' entry id=' + IntToHex(Resource_Entry.name_id, 8));

         NewNode := TResourceTreeNode.Create(Node, Resource_Entry.name_id);
         if i < Node.ResourceTable.name_count then
         begin
            NewNode.SetName(Load_Unicode(Resource_Entry.name_id));
         end;

         if Resource_Entry.data_pointer and $80000000 = $80000000 then
         begin
            Resource_Entry.data_pointer := Resource_Entry.data_pointer and $7fffffff;
            NewNode.resource_table_offset := Resource_Entry.data_pointer;
            NodeQueue.Add(NewNode);
         end
         else
         begin
            F.Seek(Resource_Offset + Resource_Entry.data_pointer);
            F.BlockRead2(@Resource_Data, sizeof(Resource_Data));
            // adjust the data_offset...
            Resource_Data.data_offset := Resource_Data.data_offset + Resource_Offset - Section_Address;
   Debug(IntToHex(Resource_Entry.data_pointer, 4) + ' data ' + IntToHex(Resource_Data.data_offset, 8) + ' ' + IntToHex(Resource_Data.data_size, 8));
            NewNode.SetLeafData(LoadString(Resource_Data.data_offset, Resource_Data.data_size), Resource_Data.codepage);
         end;
      end;
   end;
end;


function TResourceTreeNode.Repack(Section_Address : dword) : String;
var
   i : Integer;
   ChildNode : TResourceTreeNode;

   NameList : TList;
   idList : Tlist;
   n : dword;

   NodeQueue : TList;
   NodeCounter : Integer;
   Node : TResourceTreeNode;

   // How we are going to lay out the pointers...
   TableLength    : dword;
   StringOffset   : dword;
   StringLength   : dword;
   DataOffset     : dword;
   DataLength     : dword;
   TotalLength    : dword;

   Buffer : String;
   BufferPointer : Pointer;

   Resource_Entry : TResourceEntry;
   Resource_Data  : TResourceData;

   UnicodeLength : word;

   procedure Seek(Offset : dword);
   begin
      BufferPointer := PChar(Buffer) + Offset;
   end;

   procedure BlockWrite(Data : Pointer; Length : dword);
   begin
      CopyMemory(BufferPointer, Data, Length);
      BufferPointer := PChar(BufferPointer) + Length;
   end;
begin
   NodeQueue := TList.Create;
   NameList := Tlist.Create;
   idList := Tlist.Create;

   // we use a queue so we can flatten out the tree in the correct order
   NodeQueue.Add(self);

   TableLength    := 0;
   StringLength   := 0;
   DataLength     := 0;
   NodeCounter    := 0;

   SortChildren;

   while NodeCounter < NodeQueue.Count do
   begin
      Node := TResourceTreeNode(NodeQueue[NodeCounter]);
      NodeCounter := NodeCounter + 1;

      Node.resource_table_offset := TableLength;
      if Node.Children.Count > 0 then
      begin
         NameList.Clear;
         idList.Clear;
         // we need to sort the children into
         // names - alphbetical order
         // id - id order
         for i := 0 to Node.Children.Count - 1 do
         begin
            ChildNode := TResourceTreeNode(Node.Children[i]);
            ChildNode.SortChildren;
            if Length(ChildNode.Name) > 0 then
            begin
               // alpha sort...
               NameList.Add(ChildNode);
            end
            else
            begin
               // id sort
               idList.Add(ChildNode);
            end;
         end;
   Debug(IntToHex(TableLength, 4) + ' table (' + IntToStr(NameList.Count) + ',' + IntToStr(idList.Count) + ')');
         TableLength := TableLength + sizeof(TResourceTable);
         Node.ResourceTable.name_count := NameList.Count;
         Node.ResourceTable.id_count := idList.Count;

         // count up the entry sizes
         for i := 0 to NameList.Count - 1 do
         begin
            ChildNode := TResourceTreeNode(NameList[i]);
   Debug(IntToHex(TableLength, 4) + ' entry id=' + IntToHex(ChildNode.id, 8));
            TableLength := TableLength + sizeof(TResourceEntry);
            ChildNode.resource_string_offset := StringLength;
            StringLength := StringLength + (Length(ChildNode.name) + 1) * 2;
         end;
         for i := 0 to idList.Count - 1 do
         begin
            ChildNode := TResourceTreeNode(idList[i]);
   Debug(IntToHex(TableLength, 4) + ' entry id=' + IntToHex(ChildNode.id, 8));
            TableLength := TableLength + sizeof(TResourceEntry);
         end;

         // and now queue the children
         for i := 0 to NameList.Count - 1 do
         begin
            ChildNode := TResourceTreeNode(NameList[i]);
            NodeQueue.Add(ChildNode);
         end;
         for i := 0 to idList.Count - 1 do
         begin
            ChildNode := TResourceTreeNode(idList[i]);
            NodeQueue.Add(ChildNode);
         end;
      end
      else
      begin
         // this is a leaf
         Debug(IntToHex(TableLength, 4) + ' data '+ IntToHex(DataLength + 375980,8) + ' ' + IntToHex(Length(Node.leafdata), 8));
         Node.resource_data_offset := DataLength;
         TableLength := TableLength + sizeof(TResourceData);
         DataLength := DataLength + Length(Node.leafdata);
         // I assume that the data also needs to be dword alligned?
         if DataLength mod 4 <> 0 then
         begin
            DataLength := DataLength + (4 - DataLength mod 4);
         end;
      end;
   end;

   StringOffset := TableLength;
   DataOffset := StringOffset + StringLength;
   if DataOffset mod 4 <> 0 then
   begin
      //Debug('data needs padding to dword boundry');
      DataOffset := DataOffset + (4 - DataOffset mod 4);
   end;

   TotalLength := DataOffset + DataLength;

   if TotalLength mod 512 <> 0 then
   begin
      // DataLength needs to pad out to 512 bytes (512 should come from PE header)
      DataLength := DataLength + (512 - TotalLength mod 512);
      TotalLength := DataOffset + DataLength;
   end;


   Debug('table start   0');
   Debug('table length  ' + IntToStr(TableLength));
   Debug('string start  ' + IntToStr(StringOffset));
   Debug('string length ' + IntToStr(StringLength));
   Debug('data start    ' + IntToStr(DataOffset));
   Debug('data length   ' + IntToStr(DataLength));

   Debug('Final size ' + IntToHex(TotalLength, 8));

   // we could now write out to file but for now, use memory...
   SetLength(Buffer, TotalLength);
   FillMemory(PChar(Buffer), Length(Buffer), 0);

   NodeCounter := 0;
   TableLength := 0;
   StringLength := 0;
   while NodeCounter < NodeQueue.Count do
   begin
      Node := TResourceTreeNode(NodeQueue[NodeCounter]);
      NodeCounter := NodeCounter + 1;

      if Node.Children.Count > 0 then
      begin
         // write a table entry
         // the Node already has ResourceTable ready to go
         Seek(TableLength);
         BlockWrite(@Node.ResourceTable, sizeof(Node.ResourceTable));
         TableLength := TableLength + sizeof(Node.ResourceTable);

         for i := 0 to Node.Children.Count - 1 do
         begin
            ChildNode := TResourceTreeNode(Node.Children[i]);
            if Length(ChildNode.Name) > 0 then
            begin
               // write a name entry
               ChildNode.id := $80000000 + StringOffset + ChildNode.resource_string_offset;
               Resource_Entry.name_id :=  + ChildNode.id;
               Resource_Entry.data_pointer := ChildNode.resource_table_offset;
               if ChildNode.Children.Count > 0 then
               begin
                  // this bit indicated that we are pointing to another table
                  Resource_Entry.data_pointer := Resource_Entry.data_pointer or $80000000;
               end;
               Seek(TableLength);
               BlockWrite(@Resource_Entry, sizeof(Resource_Entry));
               TableLength := TableLength + sizeof(Resource_Entry);
               // write out the Strings
               Seek(StringOffset + StringLength);
               UnicodeLength := Length(ChildNode.name);
               BlockWrite(@UnicodeLength, sizeof(UnicodeLength));
               BlockWrite(PChar(ChildNode.name), Length(ChildNode.name) * sizeof(WideChar));
               StringLength := StringLength + sizeof(word) + Length(ChildNode.name) * sizeof(WideChar);
            end;
         end;
         for i := 0 to Node.Children.Count - 1 do
         begin
            ChildNode := TResourceTreeNode(Node.Children[i]);
            if Length(ChildNode.Name) = 0 then
            begin
               // write an id entry
               Resource_Entry.name_id := ChildNode.id;
               Resource_Entry.data_pointer := ChildNode.resource_table_offset;
               if ChildNode.Children.Count > 0 then
               begin
                  // this bit indicated that we are pointing to another table
                  Resource_Entry.data_pointer := Resource_Entry.data_pointer or $80000000;
               end;
               Seek(TableLength);
               BlockWrite(@Resource_Entry, sizeof(Resource_Entry));
               TableLength := TableLength + sizeof(Resource_Entry);
            end;
         end;
      end
      else
      begin
         // write a data entry
         if Node.resource_table_offset <> TableLength then
         begin
            Debug('Something is wrong');
         end;
         Resource_Data.data_offset  := Node.Resource_data_offset + DataOffset + Section_Address;
         Resource_Data.data_size    := Length(Node.leafdata);
         Resource_Data.codepage     := Node.Codepage;
         Resource_Data.reserved     := 0;
         Seek(TableLength);
         BlockWrite(@Resource_Data, sizeof(Resource_Data));
         TableLength := TableLength + sizeof(Resource_Data);

         Seek(Node.Resource_data_offset + DataOffset);
         BlockWrite(PChar(Node.leafdata), Length(Node.leafdata));
      end;
   end;

   // Save out the Data

   //HexDump(Buffer);

//   SaveBuffer('rsrc.bin', Buffer);
   Result := Buffer;
end;

end.
