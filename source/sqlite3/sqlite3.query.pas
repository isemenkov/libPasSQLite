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
unit sqlite3.query; 

{$IFDEF FPC}
  {$mode objfpc}{$H+}
{$ENDIF}
{$IFOPT D+}
  {$DEFINE DEBUG}
{$ENDIF}

interface

uses
  SysUtils, libpassqlite, sqlite3.errors_stack, sqlite3.result, 
  utils.api.cstring, container.list, utils.functor;

type
  { Single SQL query. }
  TSQLite3Query = class
  public
    type
      { Option that is used for special purposes. }
      TPrepareFlag = (
        { The SQLITE_PREPARE_PERSISTENT flag is a hint to the query planner that
          the prepared statement will be retained for a long time and probably
          reused many times. }
        SQLITE_PREPARE_PERSISTENT,

        { The SQLITE_PREPARE_NORMALIZE flag is a no-op. This flag used to be 
          required for any prepared statement that wanted to use the 
          sqlite3_normalized_sql() interface. However, the
          sqlite3_normalized_sql() interface is now available to all prepared
          statements, regardless of whether or not they use this flag. }
        SQLITE_PREPARE_NORMALIZE,

        { The SQLITE_PREPARE_NO_VTAB flag causes the SQL compiler to return an
          error (error code SQLITE_ERROR) if the statement uses any virtual
          tables. }
        SQLITE_PREPARE_NO_VTAB
      );
      TPrepareFlags = set of TPrepareFlag;
  public
    constructor Create (AErrorsStack : PSQL3LiteErrorsStack; ADBHandle : 
      ppsqlite3; AQuery : String; AFlags : TPrepareFlags);
    destructor Destroy; override;

    { Reset a prepared query. Reset a prepared query object back to its 
      initial state, ready to be re-executed. }
    procedure Reset;

    { Binding values to prepared query. }
    function Bind(AIndex : Integer) : TSQLite3Query; overload;
    function Bind(AIndex : Integer; AValue : Double)  : TSQLite3Query; overload;
    function Bind(AIndex : Integer; AValue : Integer) : TSQLite3Query; overload;
    function Bind(AIndex : Integer; AValue : Int64)   : TSQLite3Query; overload;
    function Bind(AIndex : Integer; AValue : String)  : TSQLite3Query; overload;
    function BindBlob(AIndex : Integer; AValue : Pointer; ASize : Int64) :
      TSQLite3Query;
    function BindBlobZero(AIndex : Integer; ASize : Int64) : TSQLite3Query;
      
    { Reset all bindings on a prepared query. }
    procedure ClearBindings;

    { Run the SQL. }
    function Run : TSQLite3Result;
  private
    type
      TBindStringsList = class(
        {$IFDEF FPC}specialize{$ENDIF} TList<API.PAnsiStringWrapper, 
        {$IFDEF FPC}specialize{$ENDIF} 
        TUnsortableFunctor<API.PAnsiStringWrapper> >
      );
  private
    FErrorStack : PSQL3LiteErrorsStack;
    FDBHandle : ppsqlite3;
    FStatementHandle : psqlite3_stmt;
    FQuery : API.PAnsiStringWrapper;
    FBindStrings : TBindStringsList;

    function PrepareFlags (AFlags : TPrepareFlags) : Integer;
  end;

implementation

{ TSQLite3Query }

constructor TSQLite3Query.Create (AErrorsStack : PSQL3LiteErrorsStack; 
  ADBHandle : ppsqlite3; AQuery : String; AFlags : TPrepareFlags);
begin
  FErrorStack := AErrorsStack;
  FBindStrings := TBindStringsList.Create;
  FDBHandle := ADBHandle;
  FQuery := API.CString.Create(AQuery).ToUniquePAnsiChar;
  FErrorStack^.Push(sqlite3_prepare_v3(FDBHandle^, FQuery.Value, FQuery.Length,
    PrepareFlags(AFlags), @FStatementHandle, nil));
end;

destructor TSQLite3Query.Destroy;
begin
  FErrorStack^.Push(sqlite3_finalize(FStatementHandle));
  FreeAndNil(FQuery);
  FreeAndNil(FBindStrings);
  inherited Destroy;
end;

function TSQLite3Query.PrepareFlags (AFlags : TPrepareFlags) : Integer;
begin
  Result := 0;

  if SQLITE_PREPARE_PERSISTENT in AFlags then
    Result := Result or libpassqlite.SQLITE_PREPARE_PERSISTENT;
  if SQLITE_PREPARE_NORMALIZE in AFlags then
    Result := Result or libpassqlite.SQLITE_PREPARE_NORMALIZE;
  if SQLITE_PREPARE_NO_VTAB in AFlags then
    Result := Result or libpassqlite.SQLITE_PREPARE_NO_VTAB;
end;

function TSQLite3Query.Bind(AIndex : Integer) : TSQLite3Query;
begin
  FErrorStack^.Push(sqlite3_bind_null(FStatementHandle, AIndex));
  Result := Self;
end;

function TSQLite3Query.Bind(AIndex : Integer; AValue : Double) : TSQLite3Query;
begin
  FErrorStack^.Push(sqlite3_bind_double(FStatementHandle, AIndex, AValue));
  Result := Self;
end;

function TSQLite3Query.Bind(AIndex : Integer; AValue : Integer) : TSQLite3Query;
begin
  FErrorStack^.Push(sqlite3_bind_int(FStatementHandle, AIndex, AValue));
  Result := Self;
end;

function TSQLite3Query.Bind(AIndex : Integer; AValue : Int64) : TSQLite3Query;
begin
  FErrorStack^.Push(sqlite3_bind_int64(FStatementHandle, AIndex, AValue));
  Result := Self;
end;

function TSQLite3Query.Bind(AIndex : Integer; AValue : String) : TSQLite3Query;
begin
  FBindStrings.Append(API.CString.Create(AValue).ToUniquePAnsiChar);
  FErrorStack^.Push(sqlite3_bind_text(FStatementHandle, AIndex, 
    FBindStrings.LastEntry.Value.Value, FBindStrings.LastEntry.Value.Length, 
    nil));
  Result := Self;
end;

function TSQLite3Query.BindBlob(AIndex : Integer; AValue : Pointer; ASize :
  Int64) : TSQLite3Query;
begin
  FErrorStack^.Push(sqlite3_bind_blob64(FStatementHandle, AIndex, AValue, ASize, 
    nil));
  Result := Self;
end;

function TSQLite3Query.BindBlobZero(AIndex : Integer; ASize : Int64) : 
  TSQLite3Query;
begin
  FErrorStack^.Push(sqlite3_bind_zeroblob(FStatementHandle, AIndex, ASize));
  Result := Self;
end;

procedure TSQLite3Query.ClearBindings;
begin
  FErrorStack^.Push(sqlite3_clear_bindings(FStatementHandle));
end;

procedure TSQLite3Query.Reset;
begin
  FErrorStack^.Push(sqlite3_reset(FStatementHandle));
end;

function TSQLite3Query.Run : TSQLite3Result;
begin
  Result := TSQLite3Result.Create(FErrorStack, FStatementHandle,
    sqlite3_step(FStatementHandle));
end;

end.
