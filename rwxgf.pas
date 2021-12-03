{$mode TP}
{$PACKRECORDS 1}

Unit rwxgf;
 Interface
   uses rmcore,bits;

Const
   TPLan   = 1;
   TCLan   = 2;
   QCLan   = 3;
   QBLan   = 4;
   PBLan   = 5;
   GWLan   = 6;
   FPLan   = 7;
   FBLan   = 8;
   ABLan   = 9; //AmigaBasic
   APLan   = 10;
   ACLan   = 11;


   Binary2   = 1;
   Binary4   = 2;
   Binary8   = 3;
   Binary16  = 4;
   Binary32  = 5;
   Binary256 = 6;

   Source2   = 7;
   Source4   = 8;
   Source8   = 9;
   Source16  = 10;
   Source32  = 11;
   Source256 = 12;

   SPRBinary = 13;
   SPRSource = 14;

   PPRBinary = 15;
   PPRSource = 16;

   TEGLText  = 17;

   PALSource = 18;



Function WriteXgf(x,y,x2,y2,LanType : word;filename:string):word;



Implementation

type
 linebuftype = array[0..2047] of byte;

function GetMaxColor : integer;
begin
  GetMaxColor:=RMCoreBase.Palette.GetColorCount -1;
end;

Function WriteXgfFP(x,y,x2,y2 : word;filename:string):word;
type
 //free pascal graph - each pixel takes a Word
 XGFHeadFP = Record
              Width,Height : LongInt;
              reserved     : LongInt;
 end;
 linebufFP = array[0..1023] of Word;
var
 Header : XGFHeadFP;
 lineBuf:linebufFP;
 counter : integer;
 F         : File;
 Error     : Word;
 j,i       : integer;
begin
 Header.Width:=x2-x+1;
 Header.Height:=y2-y+1;
 Header.reserved:=0;
{$I+}
 Assign(F,filename);
 Rewrite(F,1);
 Blockwrite(F,Header,sizeof(Header));

 Error:=IOResult;
 if Error <> 0 then
 begin
   close(F);
   WriteXgfFP:=Error;
   exit;
 end;

 For j:=y to y2 do
 begin
   counter:=0;
   for i:=x to x2 do
   begin
      linebuf[counter]:=RMCoreBase.GetPixel(i,j);
      inc(counter);
   end;
   blockwrite(F,linebuf,header.Width*sizeof(word));
 end;

 Close(F);
 WriteXgfFP:=IOResult;
{$I+}
end;


Function WriteXgfFB(x,y,x2,y2 : word;filename:string):word;
type
 //free takes a Word
 XGFHeadFB = Record
              Width,Height : word;
 end;
 linebufFB = array[0..1023] of Byte;
var
 Header : XGFHeadFB;
 lineBuf:linebufFB;
 counter : integer;
 F         : File;
 Error     : Word;
 j,i       : integer;
 width,height : word;
begin
 width:=x2-x+1;
 Height:=y2-y+1;
 Header.Width:=width SHL 3;
 Header.Height:=height;
{$I+}
 Assign(F,filename);
 Rewrite(F,1);
 Blockwrite(F,Header,sizeof(Header));

 Error:=IOResult;
 if Error <> 0 then
 begin
   close(F);
   WriteXgfFB:=Error;
   exit;
 end;

 For j:=y to y2 do
 begin
   counter:=0;
   for i:=x to x2 do
   begin
      linebuf[counter]:=RMCoreBase.GetPixel(i,j);
      inc(counter);
   end;
   blockwrite(F,linebuf,width);
 end;

 Close(F);
 WriteXgfFB:=IOResult;
{$I+}
end;




//2 color - 1 bitplanes - packed - 1 bits per color
Procedure WriteXgfLine2(Var F: File;xp,ln,width,bytesPerLine,LanType : word);
var
 cb,i : Word;
  mylinebuf : Linebuftype;
  mycolors  : LinebufType;
  x : integer;

begin
 {$I-}
 Fillchar(mylinebuf,sizeof(mylinebuf),0);
 Fillchar(mycolors,sizeof(mycolors),0);

 cb:=0;
 x:=0;

 for i:=0 to width-1 do
 begin
     mycolors[i]:=RMCoreBase.GetPixel(xp+i,ln);
 end;

 For i:=0 to BytesPerLine-1 do
 begin
   myLineBuf[i] := (mycolors[x] shl 7) + (mycolors[x+1] shl 6) + (mycolors[x+2] shl 5) + (mycolors[x+3] shl 4) +
                   (mycolors[x+4] shl 3) + (mycolors[x+5] shl 2) + (mycolors[x+6] shl 1) + mycolors[x+7];
   inc(x,8);
  end;

 BlockWrite(F,mylinebuf,BytesPerLine);
{$I+}
end;


//4 color - 1 bitplanes - packed - 2 bits per color
Procedure WriteXgfLine4(Var F: File;xp,ln,width,bytesPerLine,LanType : word);
var
 cb,i : Word;
  mylinebuf : Linebuftype;
  mycolors  : LinebufType;
  x : integer;

begin
 {$I-}
 Fillchar(mylinebuf,sizeof(mylinebuf),0);
 Fillchar(mycolors,sizeof(mycolors),0);

 cb:=0;
 x:=0;

 for i:=0 to width-1 do
 begin
     mycolors[i]:=RMCoreBase.GetPixel(xp+i,ln);
 end;

 For i:=0 to BytesPerLine-1 do
 begin
   myLineBuf[i] := (mycolors[x] shl 6) + (mycolors[x+1] shl 4) + (mycolors[x+2] shl 2) + mycolors[x+3];
   inc(x,4);
  end;

 BlockWrite(F,mylinebuf,BytesPerLine);
{$I+}
end;

//16 color - 4 bitplanes
Procedure WriteXgfLine16(Var F: File;xp,ln,width,bytesPerLine,LanType : word);
var
 BitPlane1 : Word;
 BitPlane2 : Word;
 BitPlane3 : Word;
 BitPlane4 : Word;
 cp,cl,x,
 xoff,j    : Word;
 mylinebuf : Linebuftype;
 Temp      : Word;
begin
{$I-}
 Fillchar(mylinebuf,sizeof(mylinebuf),0);

 BitPlane1:=0;
 BitPlane2:=bytesPerLine;
 BitPlane3:=BytesPerLine*2;
 BitPlane4:=BytesPerLine*3;
 xoff:=xp;
 cp:=0;
 for x:=0 to bytesPerLine-1 do
 begin
   for j:=0 to 7 do
   begin
//      cl:=IconImage[xoff+j,ln];
      cl:=RMCoreBase.GetPixel(xoff+j,ln);

      if biton(3,cl) then setbit((7-j),1,mylinebuf[BitPlane4+cp]);
      if biton(2,cl) then setbit((7-j),1,mylinebuf[BitPlane3+cp]);
      if biton(1,cl) then setbit((7-j),1,mylinebuf[BitPlane2+cp]);
      if biton(0,cl) then setbit((7-j),1,mylinebuf[BitPlane1+cp]);
   end;
   inc(cp);
   inc(xoff,8);
 end;

 If (LanType=TPLan) OR (LanType=TCLan) OR (LanType=PBLan) then
 begin
   For x:=0 to BitPlane2-1 do
   begin
     Temp:=myLineBuf[x];
     mylineBuf[x]:=mylineBuf[x+BitPlane4];
     mylineBuf[x+BitPlane4]:=Temp;
     Temp:=mylineBuf[x+BitPlane2];
     mylineBuf[x+BitPlane2]:=mylineBuf[x+BitPlane3];
     mylineBuf[x+BitPlane3]:=Temp;
   end;
 end;
 BlockWrite(F,mylinebuf,BytesPerLine*4);
{$I+}
end;



Function WriteXgf(x,y,x2,y2,LanType : word;filename:string):word;
Type
 XgfHead = Record
             Width  : Word;
             Height : Word;
           End;
Var
 mylinebuf : Linebuftype;
 myHead    : XgfHead;
 mywidth   : word;
 myheight  : word;
 BPL       : Word;
 F         : File;
 Error     : Word;
 J,I       : Word;
 Temp         : Word;
begin
 if LanType = FPLan then
 begin
   WriteXGF:=WriteXgfFP(x,y,x2,y2,filename);
   exit;
 end
 else if LanType = FBLan then
 begin
   WriteXGF:=WriteXgfFB(x,y,x2,y2,filename);
   exit;
 end;

 {$I-}
 myWidth:=x2-x+1;
 myHeight:=y2-y+1;

 If (LanType=TPLan) OR (LanType=TCLan)  then
 begin
   myhead.Width:=mywidth-1;
   myhead.Height:=myheight-1;
 end
 else If (LanType=PBLan) then
 begin
   myhead.Width:=mywidth;
   myhead.Height:=myheight;
 end
 else  if (LanType=QBLan) OR (LanType=QCLan) OR (LanType=GWLan) then
 begin
   If GetMaxColor=3 then
   begin
     myhead.Width:=mywidth*2
   end
   else If GetMaxColor=255 then
   begin
     myhead.Width:=mywidth SHL 3;
   end
   else
   begin
     myhead.Width:=mywidth;
   end;
   myhead.Height:=myheight;
 end;

 Assign(F,filename);
 Rewrite(F,1);
 BlockWrite(F,myhead,4);

 Error:=IOResult;
 if Error <> 0 then
 begin
   close(F);
   WriteXgf:=Error;
   exit;
 end;

 if GetMaxColor=1 then
 begin
   BPL:=(mywidth+7) div 8;
   For j:=0 to myheight-1 do
   begin
     WriteXgfline2(F,x,y+j,mywidth,BPL,LanType);
     Error:=IOResult;
     if Error <> 0 then
     begin
       close(F);
       WriteXgf:=Error;
       exit;
     end;
    end;
 end
 else if GetMaxColor=3 then
 begin
   BPL:=(mywidth+3) div 4;
   For j:=0 to myheight-1 do
   begin
     WriteXgfline4(F,x,y+j,mywidth,BPL,LanType);
     Error:=IOResult;
     if Error <> 0 then
     begin
       close(F);
       WriteXgf:=Error;
       exit;
     end;
    end;
 end
 else if GetMaxColor=15 then
 begin
   BPL:=(mywidth+7) div 8;
   For j:=0 to myheight-1 do
   begin
     WriteXgfline16(F,x,y+j,mywidth,BPL,LanType);
     Error:=IOResult;
     if Error <> 0 then
     begin
       close(F);
       WriteXgf:=Error;
       exit;
     end;
    end;
 end
 else
 begin
   For j:=y to y2 do
   begin
     For i:=1 to myWidth do
     begin
     //  MyLineBuf[i-1]:=IconImage[i+x-1,j];
         MyLineBuf[i-1]:=RMCoreBase.getPixel(i+x-1,j);

     end;
     BlockWrite(F,MyLineBuf,myWidth);
   end;
 end;

 If (LanType = TPLan) OR (LanType=TCLan)  then
 begin
   Temp:=0;
   BlockWrite(F,Temp,2);
 end;

 Close(F);
 WriteXgf:=IOResult;
{$I+}
end;

Procedure spTOmp(var singlePlane : LineBufType ;
                 var multiplane  : LineBufType;
                 PixelWidth,BytesPerPlane,nPlanes : Word);

var
 BitPlane1 : Word;
 BitPlane2 : Word;
 BitPlane3 : Word;
 BitPlane4 : Word;
 BitPlane5 : Word;
 pixelpos  : Word;
 color     : Word;
 xoffset   : Word;
 x,j       : Word;
begin
 Fillchar(multiplane,sizeof(multiplane),0);

 BitPlane1:=0;
 BitPlane2:=bytesPerPlane;
 BitPlane3:=BytesPerPlane*2;
 BitPlane4:=BytesPerPlane*3;
 BitPlane5:=BytesPerPlane*4;  //32 colors
 xoffset:=0;
 pixelpos:=0;
 for x:=0 to bytesPerPlane-1 do
 begin
   for j:=0 to 7 do
   begin
      color:=SinglePlane[xoffset+j];
      if (nPlanes > 4) AND biton(4,color) then setbit((7-j),1,multiplane[BitPlane5+pixelpos]);
      if (nPlanes > 3) AND biton(3,color) then setbit((7-j),1,multiplane[BitPlane4+pixelpos]);
      if (nPlanes > 2) AND biton(2,color) then setbit((7-j),1,multiplane[BitPlane3+pixelpos]);
      if (nPlanes > 1) AND biton(1,color) then setbit((7-j),1,multiplane[BitPlane2+pixelpos]);
      if (nPlanes > 0) AND biton(0,color) then setbit((7-j),1,multiplane[BitPlane1+pixelpos]);
    end;
   inc(pixelpos);
   inc(xoffset,8);
 end;
end;




begin
end.
