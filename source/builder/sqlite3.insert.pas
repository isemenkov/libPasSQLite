(******************************************************************************)
(*                                libPasSQLite                                *)
(*               object pascal wrapper around SQLite library                  *)
(*                                                                            *)
(* Copyright (c) 2020 - 2021                                Ivan Semenkov     *)
(* https://github.com/isemenkov/libpassqlite                ivan@semenkov.pro *)
(*                                                          Ukraine           *)
(******************************************************************************)
(*                                                                            *)
(* This source  is free software;  you can redistribute  it and/or modify  it *)
(* under the terms of the GNU General Public License as published by the Free *)
(* Software Foundation; either version 3 of the License.                      *)
(*                                                                            *)
(* This code is distributed in the  hope that it will  be useful, but WITHOUT *)
(* ANY  WARRANTY;  without even  the implied  warranty of MERCHANTABILITY  or *)
(* FITNESS FOR A PARTICULAR PURPOSE.  See the  GNU General Public License for *)
(* more details.                                                              *)
(*                                                                            *)
(* A copy  of the  GNU General Public License is available  on the World Wide *)
(* Web at <http://www.gnu.org/copyleft/gpl.html>. You  can also obtain  it by *)
(* writing to the Free Software Foundation, Inc., 51  Franklin Street - Fifth *)
(* Floor, Boston, MA 02110-1335, USA.                                         *)
(*                                                                            *)
(******************************************************************************)
unit sqlite3.insert;

{$IFDEF FPC}
  {$mode objfpc}{$H+}
{$ENDIF}
{$IFOPT D+}
  {$DEFINE DEBUG}
{$ENDIF}

interface

uses
  SysUtils, Classes, libpassqlite, sqlite3.errors_stack, sqlite3.query,
  sqlite3.structures, sqlite3.result_row, container.memorybuffer;

type
  { Mistmach column type. }
  EMistmatchColumnType = class(Exception);

  TSQLite3Insert = class
  public
    constructor Create (AErrorsStack : PSQL3LiteErrorsStack; ADBHandle :
      ppsqlite3; ATableName : String);
    destructor Destroy; override;

    { Add value to insert list. }
    function Value (AColumnName : String; AValue : Integer) : TSQLite3Insert; 
      overload;
    function Value (AColumnName : String; AValue : Double) : TSQLite3Insert;
      overload;
    function Value (AColumnName : String; AValue : String) : TSQLite3Insert;
      overload;
    function Value (AColumnName : String; AValue : TStream) : TSQLite3Insert;
      overload;
    function Value (AColumnName : String; AValue : TMemoryBuffer) : 
      TSQLite3Insert; overload;
    function ValueNull (AColumnName : String) : TSQLite3Insert; overload;

    { Set multiple insert column data. }
    function Column (AColumnName : String; AColumnType : TDataType) : 
      TSQLite3Insert;

    { Start new insert row. }
    function Row : TSQLite3Insert;

    { Add values to insert row. }
    function Value (AValue : Integer) : TSQLite3Insert; overload;
    function Value (AValue : Double) : TSQLite3Insert; overload;
    function Value (AValue : String) : TSQLite3Insert; overload;
    function Value (AValue : TStream) : TSQLite3Insert; overload;
    function Value (AValue : TMemoryBuffer) : TSQLite3Insert; overload;
    function ValueNull : TSQLite3Insert; overload;

    { Get result. }
    function Get : Integer;  
  private
    function PrepareQuery : String;
      {$IFNDEF DEBUG}inline;{$ENDIF}
    function BindQueryData (AQuery : TSQLite3Query; AIndex : Integer) :
      Integer;
      {$IFNDEF DEBUG}inline;{$ENDIF}
    function PrepareMultipleQuery : String;
      {$IFNDEF DEBUG}inline;{$ENDIF}
    function BindMultipleQueryData (AQuery : TSQLite3Query; AIndex : Integer) : 
      Integer;
      {$IFNDEF DEBUG}inline;{$ENDIF}
  private
    FErrorsStack : PSQL3LiteErrorsStack;
    FDBHandle : ppsqlite3;
    FTableName : String;
    FValuesList : TSQLite3Structures.TValuesList;
    FColumnsList : TSQLite3Structures.TValuesList;
    FMultipleValuesList : TSQLite3Structures.TMultipleValuesList;
    FMemoryBuffersList : TSQLite3Structures.TMemoryBuffersList;
  end;

implementation

{ TSQLite3Insert }

constructor TSQLite3Insert.Create (AErrorsStack : PSQL3LiteErrorsStack; 
  ADBHandle : ppsqlite3; ATableName : String);
begin
  FErrorsStack := AErrorsStack;
  FDBHandle := ADBHandle;
  FTableName := ATableName;
  FValuesList := TSQLite3Structures.TValuesList.Create;
  FColumnsList := TSQLite3Structures.TValuesList.Create;
  FMultipleValuesList := TSQLite3Structures.TMultipleValuesList.Create;
  FMemoryBuffersList := TSQLite3Structures.TMemoryBuffersList.Create;
end;

destructor TSQLite3Insert.Destroy;
begin
  FreeAndNil(FValuesList);
  FreeAndNil(FColumnsList);
  FreeAndNil(FMultipleValuesList);
  FreeAndNil(FMemoryBuffersList);

  inherited Destroy;
end;

function TSQLite3Insert.Value (AColumnName : String; AValue : Integer) : 
  TSQLite3Insert;
var
  val : TSQLite3Structures.TValueItem;
begin
  val.Column_Name := AColumnName;

  val.Value_Type := SQLITE_INTEGER;
  val.Value_Integer := AValue;
  val.Value_Float := 0;
  val.Value_Text := '';
  val.Value_BlobBuffer := nil;

  FValuesList.Append(val);
  Result := Self;
end;

function TSQLite3Insert.Value (AColumnName : String; AValue : Double) : 
  TSQLite3Insert;
var
  val : TSQLite3Structures.TValueItem;
begin
  val.Column_Name := AColumnName;

  val.Value_Type := SQLITE_FLOAT;
  val.Value_Integer := 0;
  val.Value_Float := AValue;
  val.Value_Text := '';
  val.Value_BlobBuffer := nil;

  FValuesList.Append(val);
  Result := Self;
end;

function TSQLite3Insert.Value (AColumnName : String; AValue : String) : 
  TSQLite3Insert;
var
  val : TSQLite3Structures.TValueItem;
begin
  val.Column_Name := AColumnName;

  val.Value_Type := SQLITE_TEXT;
  val.Value_Integer := 0;
  val.Value_Float := 0;
  val.Value_Text := AValue;
  val.Value_BlobBuffer := nil;

  FValuesList.Append(val);
  Result := Self;
end;

function TSQLite3Insert.Value (AColumnName : String; AValue : TStream) : 
  TSQLite3Insert;
var
  val : TSQLite3Structures.TValueItem;
  ptr : Pointer;
begin
  val.Value_BlobBuffer := TMemoryBuffer.Create;
  ptr := val.Value_BlobBuffer.GetAppendBuffer(AValue.Size);
  AValue.Read(ptr, AValue.Size);

  val.Column_Name := AColumnName;

  val.Value_Type := SQLITE_BLOB;
  val.Value_Integer := 0;
  val.Value_Float := 0;
  val.Value_Text := '';

  FValuesList.Append(val);
  Result := Self;
end;

function TSQLite3Insert.Value (AColumnName : String; AValue : TMemoryBuffer) : 
  TSQLite3Insert;
var
  val : TSQLite3Structures.TValueItem;
begin
  val.Column_Name := AColumnName;

  val.Value_Type := SQLITE_BLOB;
  val.Value_Integer := 0;
  val.Value_Float := 0;
  val.Value_Text := '';
  val.Value_BlobBuffer := AValue;

  FValuesList.Append(val);
  Result := Self;
end;

function TSQLite3Insert.ValueNull (AColumnName : String) : TSQLite3Insert;
var
  val : TSQLite3Structures.TValueItem;
begin
  val.Column_Name := AColumnName;

  val.Value_Type := SQLITE_NULL;
  val.Value_Integer := 0;
  val.Value_Float := 0;
  val.Value_Text := '';
  val.Value_BlobBuffer := nil;

  FValuesList.Append(val);
  Result := Self;
end;

function TSQLite3Insert.Column (AColumnName : String; AColumnType : 
  TDataType) : TSQLite3Insert;
var
  item : TSQLite3Structures.TValueItem;
begin
  item.Column_Name := AColumnName;
  item.Value_Type := AColumnType;
  
  item.Value_Integer := 0;
  item.Value_Float := 0;
  item.Value_Text := '';
  item.Value_BlobBuffer := nil;

  FColumnsList.Append(item);
  Result := Self;
end;

function TSQLite3Insert.Row : TSQLite3Insert;
begin
  FMultipleValuesList.Append(TSQLite3Structures.TValuesList.Create);
  Result := Self;
end;

function TSQLite3Insert.Value (AValue : Integer) : TSQLite3Insert;
var
  item : TSQLite3Structures.TValueItem;
begin
  if FMultipleValuesList.LastEntry.HasValue then
  begin
    item.Column_Name := '';
    item.Value_Type := SQLITE_INTEGER;
    item.Value_Integer := AValue;
    item.Value_Float := 0;
    item.Value_Text := '';
    item.Value_BlobBuffer := nil;

    FMultipleValuesList.LastEntry.Value.Append(item);
  end;

  Result := Self;
end;

function TSQLite3Insert.Value (AValue : Double) : TSQLite3Insert;
var
  item : TSQLite3Structures.TValueItem;
begin
  if FMultipleValuesList.LastEntry.HasValue then
  begin
    item.Column_Name := '';
    item.Value_Type := SQLITE_FLOAT;
    item.Value_Integer := 0;
    item.Value_Float := AValue;
    item.Value_Text := '';
    item.Value_BlobBuffer := nil;

    FMultipleValuesList.LastEntry.Value.Append(item);
  end;

  Result := Self;
end;

function TSQLite3Insert.Value (AValue : String) : TSQLite3Insert;
var
  item : TSQLite3Structures.TValueItem;
begin
  if FMultipleValuesList.LastEntry.HasValue then
  begin
    item.Column_Name := '';
    item.Value_Type := SQLITE_TEXT;
    item.Value_Integer := 0;
    item.Value_Float := 0;
    item.Value_Text := AValue;
    item.Value_BlobBuffer := nil;

    FMultipleValuesList.LastEntry.Value.Append(item);
  end;

  Result := Self;
end;

function TSQLite3Insert.Value (AValue : TStream) : TSQLite3Insert;
var
  item : TSQLite3Structures.TValueItem;
  ptr : Pointer;
begin
  if FMultipleValuesList.LastEntry.HasValue then
  begin
    item.Value_BlobBuffer := TMemoryBuffer.Create;
    ptr := item.Value_BlobBuffer.GetAppendBuffer(AValue.Size);
    AValue.Read(ptr, AValue.Size);

    item.Column_Name := '';
    item.Value_Type := SQLITE_BLOB;
    item.Value_Integer := 0;
    item.Value_Float := 0;
    item.Value_Text := '';

    FMultipleValuesList.LastEntry.Value.Append(item);
  end;

  Result := Self;
end;

function TSQLite3Insert.Value (AValue : TMemoryBuffer) : TSQLite3Insert;
var
  item : TSQLite3Structures.TValueItem;
begin
  if FMultipleValuesList.LastEntry.HasValue then
  begin
    item.Column_Name := '';
    item.Value_Type := SQLITE_BLOB;
    item.Value_Integer := 0;
    item.Value_Float := 0;
    item.Value_Text := '';
    item.Value_BlobBuffer := AValue;

    FMultipleValuesList.LastEntry.Value.Append(item);
  end;

  Result := Self;
end;

function TSQLite3Insert.ValueNull : TSQLite3Insert;
var
  item : TSQLite3Structures.TValueItem;
begin
  if FMultipleValuesList.LastEntry.HasValue then
  begin
    item.Column_Name := '';
    item.Value_Type := SQLITE_NULL;
    item.Value_Integer := 0;
    item.Value_Float := 0;
    item.Value_Text := '';
    item.Value_BlobBuffer := nil;

    FMultipleValuesList.LastEntry.Value.Append(item);
  end;

  Result := Self;
end;

function TSQLite3Insert.Get : Integer;
var
  Query : TSQLite3Query;
begin
  if FValuesList.FirstEntry.HasValue then
  begin
    Query := TSQLite3Query.Create (FErrorsStack, FDBHandle, PrepareQuery,
      [SQLITE_PREPARE_NORMALIZE]);
    BindQueryData(Query, 1);
    Query.Run;

    Result := sqlite3_changes(FDBHandle^);
    FreeAndNil(Query);
  end else
  begin
    { Set multiple values. }
    Query := TSQLite3Query.Create (FErrorsStack, FDBHandle, 
      PrepareMultipleQuery, [SQLITE_PREPARE_NORMALIZE]);
    BindMultipleQueryData(Query, 1);

    Query.Run;
    Result := sqlite3_changes(FDBHandle^);
    FreeAndNil(Query);
  end;  
end;

function TSQLite3Insert.PrepareQuery : String;
var
  val : TSQLite3Structures.TValueItem;
  SQL : String;
  i : Integer;  
begin
  if not FValuesList.FirstEntry.HasValue then
    Exit('');

  i := 0;
  SQL := 'INSERT INTO ' + FTableName + ' (';
  for val in FValuesList do
  begin
    { For every column. }
    if i > 0 then
      SQL := SQL + ', ';

    SQL := SQL + val.Column_Name;
    Inc(i);
  end;
  
  i := 0;
  SQL := SQL + ') VALUES (';
  for val in FValuesList do
  begin
    { For every value. }
    if i > 0 then
      SQL := SQL + ', ';

    SQL := SQL + '?';
    Inc(i);
  end;
  
  SQL := SQL + ');';
  Result := SQL;
end;

function TSQLite3Insert.BindQueryData (AQuery : TSQLite3Query; AIndex :
  Integer) : Integer;
var
  i : Integer;
  val : TSQLite3Structures.TValueItem;
begin
  if not FValuesList.FirstEntry.HasValue then
    Exit(AIndex);

  i := AIndex;
  for val in FValuesList do
  begin
    case val.Value_Type of
      SQLITE_INTEGER : AQuery.Bind(i, val.Value_Integer);
      SQLITE_FLOAT :   AQuery.Bind(i, val.Value_Float);
      SQLITE_TEXT :    AQuery.Bind(i, val.Value_Text);
      SQLITE_BLOB :    AQuery.BindBlob(i, val.Value_BlobBuffer.GetBufferData, 
        val.Value_BlobBuffer.GetBufferDataSize);
      SQLITE_NULL :    AQuery.Bind(i);
    end;
    Inc(i);
  end;

  Result := i;
end;

function TSQLite3Insert.PrepareMultipleQuery : String;
var
  SQL : String;
  column_item : TSQLite3Structures.TValueItem;
  value_row : TSQLite3Structures.TValuesList;
  column_iterator : TSQLite3Structures.TValuesList.TIterator;
  value_item : TSQLite3Structures.TValueItem;
  i, j : Integer;
begin
  if (not FColumnsList.FirstEntry.HasValue) or
     (not FMultipleValuesList.FirstEntry.HasValue) then
    Exit('');
  
  SQL := '';

  { If columns list is not empty. }
  if FColumnsList.FirstEntry.HasValue then
  begin
    SQL := SQL + 'INSERT INTO ' + FTableName + ' (';

    i := 0;
    for column_item in FColumnsList do
    begin
      { For each column name. }
      if i > 0 then
        SQL := SQL + ', ';

      SQL := SQL + column_item.Column_Name;
      Inc(i);
    end;

    SQL := SQL + ')';
  end;

  SQL := SQL + ' VALUES ';

  { For each row in list. }
  i := 0;
  for value_row in FMultipleValuesList do
  begin
    column_iterator := FColumnsList.FirstEntry;
    if i > 0 then
      SQL := SQL + ',';

    j := 0;
    SQL := SQL + '(';

    { For each value item in row. }
    for value_item in value_row do
    begin
      if (column_iterator.Value.Value_Type <> value_item.Value_Type) and
         (value_item.Value_Type <> SQLITE_NULL) then
        raise EMistmatchColumnType.Create('Mistmach column type.');

      if j > 0 then
        SQL := SQL + ', ';

      SQL := SQL + '?';
      column_iterator := column_iterator.Next;
      Inc(j);
    end;
    SQL := SQL + ') ';
    Inc(i);
  end;

  SQL := SQL + ';';
  Result := SQL;  
end;

function TSQLite3Insert.BindMultipleQueryData (AQuery : TSQLite3Query; AIndex : 
  Integer) : Integer;
var
  value_row : TSQLite3Structures.TValuesList;
  value_item : TSQLite3Structures.TValueItem;
  i : Integer;
begin
  if not FMultipleValuesList.FirstEntry.HasValue then
    Exit(AIndex);

  i := AIndex;

  { For each row in list. }
  for value_row in FMultipleValuesList do
  begin
    for value_item in value_row do
    begin
      case value_item.Value_Type of
        SQLITE_INTEGER : 
          begin
            AQuery.Bind(i, value_item.Value_Integer);
          end;
        SQLITE_FLOAT : 
          begin
            AQuery.Bind(i, value_item.Value_Float);
          end;
        SQLITE_BLOB : 
          begin
            AQuery.BindBlob(i, value_item.Value_BlobBuffer.GetBufferData,
              value_item.Value_BlobBuffer.GetBufferDataSize);
          end;
        SQLITE_TEXT :
          begin
            AQuery.Bind(i, value_item.Value_Text);
          end;
        SQLITE_NULL :
          begin
            AQuery.Bind(i);
          end;
      end;
      Inc(i);
    end;
  end;

  Result := i;
end;

end.
