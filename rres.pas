{$MODE TP}
{$PACKRECORDS 1}
Unit rres;

Interface
   uses rmcore,rmthumb,rmxgfcore,rwxgf2,rmamigarwxgf,rwpal,wmodex;

Function RESInclude(filename:string):word;
Function RESBinary(filename:string):word;

const
 MaxResItems = 255;
type
 resheadrec = Packed Record
                   sig : array[1..3] of char;
                   ver : byte;
                   resitemcount : integer;
              end;

 resrec = Packed Record
             rt     : integer;
             rid    : array[1..20] of char;
             offset : longint;
             size   : longint;
          end;

 resIndex = array[1..MaxResItems] of resrec;

 RFILE = Packed Record
            ResFile  : File;
            ResList  : ^resIndex;
            ResItems : integer;
         end;

Procedure res_open(Var IRFILE : RFILE;filename : string);
Procedure res_close(var IRFILE : RFILE);
Function  res_getsize(VAR IRFILE : RFILE; ri : integer) : longint;
Procedure res_read(VAR IRFILE : RFILE; var rbuf; ri : integer);
(*
Procedure res_dis_xgf(Var IRFILE : RFILE; x,y : integer;ri : integer;dmode : integer);
*)

Implementation

Procedure res_open(Var IRFILE : RFILE;filename : string);
type
  ExeHeaderRec = Record
                    Sig    : Word; (* EXE File signature *)
                    bleft  : Word; (* Number of Bytes in last page of EXE image*)
                    nPages : Word; (* Number of 512 Byte pages in EXE image *)
                 end;

Var
 i,error   : word;
 ressig    : array[1..3] of char;
 ExeHeader : ExeHeaderRec;
 ExeSize   : LongInt;
begin
{$I-}
  assign(IRFILE.Resfile,filename);
  Reset(IRFILE.ResFile,1);
  error:=ioresult;
  if error <> 0 then
  begin
    writeln('error opening resource file ',filename);
    halt;
  end;

  exesize:=0;
  If Filename=ParamStr(0) then
  begin
    BlockRead(IRFILE.ResFile,ExeHeader,SizeOf(ExeHeaderRec));
    ExeSize:=Longint(ExeHeader.bleft)+LongInt((ExeHeader.npages-1))*512;
    Seek(IRFILE.ResFile,ExeSize);
  end;

  blockread(IRFILE.Resfile,ressig,3);
  if ressig <> 'RES' then
  begin
    writeln('not a valid resource file');
    halt;
  end;

  blockread(IRFILE.resfile,IRFILE.resitems,2);
  getmem(IRFILE.reslist,sizeof(resrec)*IRFILE.resitems);
  blockread(IRFILE.resfile,IRFILE.reslist^,sizeof(resrec)*IRFILE.resitems);
  error:=ioresult;
  if error<>0 then
  begin
    writeln('error reading resource file header');
    halt;
  end;

  For i:=1 to IRFILE.resitems do
  begin
    Inc(IRFILE.ResList^[i].offset,exesize);
  end;

{$I+}
end;

Procedure res_close(var IRFILE : RFILE);
var
 error : word;
begin
{$I-}
  close(IRFILE.resfile);
  Freemem(IRFILE.reslist,sizeof(resrec)*IRFILE.resitems);
  error:=ioresult;
  if error <> 0 then
  begin
    writeln('error closing resource file');
    halt;
  end;
{$I+}
end;

Function res_getsize(VAR IRFILE : RFILE; ri : integer) : longint;
begin
 res_getsize:=IRFILE.reslist^[ri].size;
end;

Procedure res_read(VAR IRFILE : RFILE; var rbuf; ri : integer);
var
 error        : word;
begin
{$I-}
   seek(IRFILE.resfile,IRFILE.reslist^[ri].offset);
   blockread(IRFILE.resfile,rbuf,IRFILE.reslist^[ri].size);
   error:=ioresult;
   if error <> 0 then
   begin
     writeln('error reading resource file');
     halt;
   end;
{$I+}
end;
(*
Procedure res_dis_xgf(Var IRFILE : RFILE; x,y : integer;ri : integer;dmode : integer);
var
 width,height : integer;
 bpl,i,error  : integer;
 scanline     : array[1..1030] of integer;
begin
{$I-}
   seek(IRFILE.resfile,IRFILE.reslist^[ri].offset);
   blockread(IRFILE.resfile,width,2);
   blockread(IRFILE.resfile,height,2);

   scanline[1]:=width;
   scanline[2]:=0;

   if (getmaxcolor=255) then
   begin
     bpl:=width+1;
   end
   else
   begin
     bpl:=imagesize(0,0,width,0)-6;
   end;

   for i:=0 to height do
   begin
     blockread(IRFILE.resfile,scanline[3],bpl);
     putimage(x,y+i,Ptr(seg(scanline),ofs(scanline))^,dmode);
   end;
{$I+}
end;
*)


function GetRESImageSize(width,height,nColors,Lan,ImageType : integer) : longint;
var
 size : longint;
begin
 size:=0;
 Case Lan of TPLan,TCLan:begin
                           Case ImageType of 1:size:=GetXImageSize(width,height,ncolors);
                                             2,3:size:=GetLBMPBMImageSize(width,height); // Xlib LBM/PBM

                           end;
                         end;
             QCLan,QPLan,QBLan,GWLan,PBLan:size:=GetXImageSize(width,height,ncolors);
             FPLan:size:=GetXImageSizeFP(width,height);
             FBLan:size:=GetXImageSizeFB(width,height);

             ABLan:begin
                     Case ImageType of 1:size:=GetABXImageSize(width,height,nColors);
                                       2:size:=GetBobDataSize(width,height,nColors,false); //bob
                                       3:size:=GetBobDataSize(width,height,nColors,true);  //vsprite
                     end;
                   end;
             APLan,ACLan:size:=GetAmigaBitMapSize(width,height,ncolors);
 end;

GetRESImageSize:=size;
end;

function GetRESPaletteSize(nColors,Lan,rgbFormat : integer) : longint;
var
 size : longint;
begin
  size:=0;
  if rgbFormat = ColorIndexFormat then Size:=nColors
    else Size:=nColors*3;
  GetRESPaletteSize:=Size;
end;

Procedure WriteBasicLabel(var data : BufferRec;Lan : integer;LabelName : string);
begin
  //we don't want GWLan  - it has line number already
  if (Lan=ABLan) or (Lan=QBLan) or (Lan=PBLan) or (Lan=FBLan) then
   begin
     Writeln(data.fText,LabelName,'Label:');
   end;
end;

Function RESInclude(filename:string):word;
var
 data    : BufferRec;
 EO      : ImageExportFormatRec;
 i       : integer;
 count   : integer;
 width   : integer;
 height  : integer;
begin
 SetThumbActive;   // we are getting pixel data from core object ThumbBase
 SetGWStartLineNumber(1000); // this is only used for exporting GWBASIC/PCBASIC code

 assign(data.fText,filename);
{$I-}
 rewrite(data.fText);

 count:=ImageThumbBase.GetCount;
 for i:=0 to count-1 do
 begin
   width:=ImageThumbBase.GetWidth(i);
   height:=ImageThumbBase.GetHeight(i);
   ImageThumbBase.GetExportOptions(i,EO);
   SetThumbIndex(i);  //important - otherwise the GetMaxColor and GetPixel functions will not get the right data

   if (EO.Lan>0) and (EO.Palette > 0) then
   begin
     WriteBasicLabel(data,EO.Lan,EO.Name+'Pal');
     WritePalToArrayBuffer(data,EO.Name+'Pal',EO.Lan,EO.Palette);
   end;

   case EO.Lan of TPLan,TCLan,FPLan,FBLan,QBLan,GWLan,QCLan,QPLan,PBLan:
        begin
          if EO.Image = 1 then   //put image format
          begin
            WriteBasicLabel(data,EO.Lan,EO.Name);
            WriteXGFCodeToBuffer(data,0,0,width-1,height-1,EO.Lan,0,EO.Name);
          end;
          if (EO.Image = 1) and (EO.Mask=1) then    //put image mask
          begin
            WriteBasicLabel(data,EO.Lan,EO.Name+'Mask');
            WriteXGFCodeToBuffer(data,0,0,width-1,height-1,EO.Lan,1,EO.Name+'Mask');
          end;
        end;
   end;

   if (EO.LAN=TPLan) AND (EO.Image = 2) then  // XLib LBM
   begin
     WriteTPLBMCodeToBuffer(data,0,0,width-1,height-1,EO.Name);
   end;

   if (EO.LAN=TPLan) AND (EO.Image = 3) then // XLib PBM
   begin
     WriteTPPBMCodeToBuffer(data,0,0,width-1,height-1,EO.Name);
   end;

   if (EO.LAN=TCLan) AND (EO.Image = 2) then  // XLib LBM
   begin
     WriteTCLBMCodeToBuffer(data,0,0,width-1,height-1,EO.Name);
   end;

   if (EO.LAN=TCLan) AND (EO.Image = 3) then // XLib PBM
   begin
     WriteTCPBMCodeToBuffer(data,0,0,width-1,height-1,EO.Name);
   end;



   if (EO.LAN=ABLan) and (EO.Image = 1) then
   begin
     WriteBasicLabel(data,EO.Lan,EO.Name);
     WriteAmigaBasicXGFDataBuffer(0,0,width-1,height-1,0,data,EO.Name);        // put
   end;
   if (EO.LAN=ABLan) and (EO.Image = 1) and (EO.Mask=1) then
   begin
     WriteBasicLabel(data,EO.Lan,EO.Name+'Mask');
     WriteAmigaBasicXGFDataBuffer(0,0,width-1,height-1,1,data,EO.Name+'Mask');        // mask
   end;

   if (EO.LAN=ABLan) and (EO.Image = 2) then
   begin
     WriteBasicLabel(data,EO.Lan,EO.Name);
     WriteAmigaBasicBobDataBuffer(0,0,width-1,height-1,data,EO.Name,false); //bob
   end;
   if (EO.LAN=ABLan) and (EO.Image = 3) then
   begin
     WriteBasicLabel(data,EO.Lan,EO.Name);
     WriteAmigaBasicBobDataBuffer(0,0,width-1,height-1,data,EO.Name,true); // vsprite
   end;

   if (EO.LAN=ACLan) and (EO.Image = 1) then WriteAmigaCBobCodeToBuffer(0,0,width-1,height-1,EO.Name,data,false);        // bob
   if (EO.LAN=ACLan) and (EO.Image = 2) then WriteAmigaCBobCodeToBuffer(0,0,width-1,height-1,EO.Name,data,true);  //vsprite

   if (EO.LAN=APLan) and (EO.Image = 1) then WriteAmigaPascalBobCodeToBuffer(0,0,height-1,width-1,EO.Name,data,false);        // bob
   if (EO.LAN=APLan) and (EO.Image = 2) then WriteAmigaPascalBobCodeToBuffer(0,0,height-1,width-1,EO.Name,data,true);  //vsprite

 end;
 close(data.fText);
 {$I+}
 RESInclude:=IOResult;
end;


Function RESBinary(filename:string):word;
var
 data    : BufferRec;
 EO      : ImageExportFormatRec;
 RR      : resrec;
 RH      : resheadrec;
 i       : integer;
 count   : integer;
 width   : integer;
 height  : integer;
 nColors : integer;
 Size    : LongInt;
 PalSize : Longint;

 HeaderSize  : LongInt;
 OffsetCount : LongInt;
 ExportCount : Integer;
 SLen        : integer;
 Error       : integer;
 MaskName    : string;
 PalName     : string;
begin
 ExportCount:=ImageThumbBase.GetExportImageCount+ImageThumbBase.GetExportMaskCount+ImageThumbBase.GetExportPaletteCount;
 if ExportCount = 0 then exit;

 SetThumbActive;   // we are getting pixel data from core object ThumbBase
 assign(data.f,filename);
{$I-}
 rewrite(data.f,1);
{$I+}
 Error:=IORESULT;
 if Error<>0 then
 begin
    RESBinary:=Error;
    exit;
 end;
 count:=ImageThumbBase.GetCount;
 HeaderSize:=sizeof(RH)+Exportcount*sizeof(resrec);
 OffsetCount:=HeaderSize;

 //write the signature and record count
 RH.sig:='RES';
 RH.ver:=1;
 RH.resitemcount:=Exportcount;
 {$I-}
 Blockwrite(data.f,RH,sizeof(RH));
 {$I+}
 Error:=IORESULT;
 if Error<>0 then
 begin
  RESBinary:=Error;
  exit;
 end;

 //write the header with all the correct offsets where the image is going to be located
 for i:=0 to count-1 do
 begin
   ImageThumbBase.GetExportOptions(i,EO);

   width:=ImageThumbBase.GetWidth(i);
   height:=ImageThumbBase.GetHeight(i);
   nColors:=ImageThumbBase.GetMaxColor(i)+1;
   Size:=GetRESImageSize(width,height,nColors,EO.Lan,EO.Image);


   //write the palette first - if there is a palette
   if EO.Palette > 0 then
   begin
     PalSize:=GetRESPaletteSize(nColors,EO.Lan,EO.Palette);

     PalName:=EO.Name+'Pal';
     fillchar(RR.rid,sizeof(RR.rid),32);
     slen:=Length(PalName);
     if slen > 20 then slen:=20;
     Move(PalName[1],RR.rid,slen);

     RR.size:=PalSize;
     RR.offset:=OffsetCount;
     RR.rt:=EO.Palette; // id's less than 100 are palettes

     inc(OffsetCount,PalSize);
     {$I-}
     Blockwrite(data.f,RR,sizeof(RR));
     {$I+}
     Error:=IORESULT;
     if Error<>0 then
     begin
       RESBinary:=Error;
       exit;
     end;
   end;

   //copy name field
   fillchar(RR.rid,sizeof(RR.rid),32);
   slen:=Length(EO.Name);
   if slen > 20 then slen:=20;
   Move(EO.Name[1],RR.rid,slen);

   //calc size/offset
   if EO.Image > 0  then
   begin
     RR.size:=Size;
     RR.offset:=OffsetCount;
     RR.rt:=EO.Lan*100+EO.Image; //language id * 100 + Image Type to generate resource type

     inc(OffsetCount,Size);
     {$I-}
     Blockwrite(data.f,RR,sizeof(RR));

     //if there is a mask image we write the info also - size is the same, offset and name will be different
     if EO.Mask = 1 then
     begin
       MaskName:=EO.Name+'Mask';
       slen:=Length(MaskName);
       if slen > 20 then slen:=20;
       Move(MaskName[1],RR.rid,slen);

       RR.offset:=OffsetCount;
       inc(OffsetCount,Size);
       Blockwrite(data.f,RR,sizeof(RR));
     end;


     {$I+}
     Error:=IORESULT;
     if Error<>0 then
     begin
       RESBinary:=Error;
       exit;
     end;
   end;

 end;

 //convert and dump image
 for i:=0 to count-1 do
 begin
   width:=ImageThumbBase.GetWidth(i);
   height:=ImageThumbBase.GetHeight(i);
   ImageThumbBase.GetExportOptions(i,EO);
   SetThumbIndex(i);  //important - otherwise the GetMaxColor and GetPixel functions will not get the right data

   if EO.Palette > 0 then WritePalToBuffer(data,EO.Palette);

   Case EO.Lan of QCLan,QPLan,QBLan,GWLan,PBLan:
                                    begin
                                      if (EO.Image = 1) then WriteXgfToBuffer(0,0,width-1,height-1,EO.Lan,0,data);
                                      if (EO.Image = 1) and (EO.Mask=1) then WriteXgfToBuffer(0,0,width-1,height-1,EO.Lan,1,data);
                                    end;
                        TPLan,TCLan: begin
                                       if (EO.Image = 1) then WriteXgfToBuffer(0,0,width-1,height-1,EO.Lan,0,data);
                                       if (EO.Image = 1) and (EO.Mask=1) then WriteXgfToBuffer(0,0,width-1,height-1,EO.Lan,1,data);
                                       if (EO.Image = 2) then WriteLBMToBuffer(0,0,width-1,height-1,data);   //xlib lbm
                                       if (EO.Image = 3) then WritePBMToBuffer(0,0,width-1,height-1,data);   //xlib pbm
                                     end;
                              FPLan: begin
                                       if (EO.Image = 1) then WriteXGFToBufferFP(0,0,width-1,height-1,0,data);
                                       if (EO.Image = 1) and (EO.Mask=1) then WriteXGFToBufferFP(0,0,width-1,height-1,1,data);
                                     end;
                              FBLan: begin
                                        if (EO.Image = 1) then WriteXGFToBufferFB(0,0,width-1,height-1,0,data);
                                        if (EO.Image = 1) and (EO.Mask=1) then WriteXGFToBufferFB(0,0,width-1,height-1,1,data);
                                     end;
                              ABLan:begin
                                      if (EO.Image = 1) then WriteAmigaBasicXGFBuffer(0,0,width-1,height-1,data);
                                      if (EO.Image = 2) then WriteAmigaBasicBobBuffer(0,0,width-1,height-1,data,false); //bob
                                      if (EO.Image = 3) then WriteAmigaBasicBobBuffer(0,0,width-1,height-1,data,true);  //sprite
                                    end;
                        ACLan,APLan:begin
                                       if (EO.Image = 1) then WriteAmigaBobBuffer(0,0,width-1,height-1,data,false);
                                       if (EO.Image = 2) then WriteAmigaBobBuffer(0,0,width-1,height-1,data,true);
                                    end;

   end;
 end;
 {$I-}
 close(data.f);
 {$I+}
 RESBinary:=IOResult;
end;








begin
end.
