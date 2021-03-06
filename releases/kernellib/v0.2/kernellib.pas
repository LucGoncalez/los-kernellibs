{===========================================================================
	Este arquivo pertence ao Projeto do Sistema Operacional LuckyOS (LOS).
	--------------------------------------------------------------------------
	Copyright (C) 2013 - Luciano L. Goncalez
	--------------------------------------------------------------------------
	a.k.a.: Master Lucky
	eMail : master.lucky.br@gmail.com
	Home  : http://lucky-labs.blogspot.com.br
============================================================================
	Este programa e software livre; voce pode redistribui-lo e/ou modifica-lo
	sob os termos da Licenca Publica Geral GNU, conforme publicada pela Free
	Software Foundation; na versao 2 da	Licenca.

	Este programa e distribuido na expectativa de ser util, mas SEM QUALQUER
	GARANTIA; sem mesmo a garantia implicita de COMERCIALIZACAO ou de
	ADEQUACAO A QUALQUER PROPOSITO EM PARTICULAR. Consulte a Licenca Publica
	Geral GNU para obter mais detalhes.

	Voce deve ter recebido uma copia da Licenca Publica Geral GNU junto com
	este programa; se nao, escreva para a Free Software Foundation, Inc., 59
	Temple Place, Suite 330, Boston, MA	02111-1307, USA. Ou acesse o site do
	GNU e obtenha sua licenca: http://www.gnu.org/
============================================================================
	Unit KernelLib.pas
	--------------------------------------------------------------------------
	Unit com funcionalidades do Kernel.
	--------------------------------------------------------------------------
	Versao: 0.2
	Data: 26/07/2014
	--------------------------------------------------------------------------
	Compilar: Compilavel FPC
	> fpc kernellib.pas
	------------------------------------------------------------------------
	Executar: Nao executavel diretamente; Unit.
===========================================================================}

unit KernelLib;

interface

uses SystemDef, ErrorsDef;


	procedure Shutdown(Mode : TShutDownMode);
	procedure KernelPanic(Error : TErrorCode; ErrorMsg : PChar; AbortRec : PAbortRec);


implementation

uses SysUtils, ConsoleIO, DebugInfo, TTYsDef;


var
	vInPanic : Boolean = False;


	procedure ResetCPU; forward;
	procedure HaltCPU; forward;
	procedure PrintRSoD(Error : TErrorCode; Msg : PChar; AbortRec : PAbortRec; DebugEx : PDebugEX);	forward;


procedure Shutdown(Mode : TShutDownMode);
begin
	if (sdHalt in Mode) then
		HaltCPU
	else
		ResetCPU;
end;

procedure KernelPanic(Error : TErrorCode; ErrorMsg : PChar; AbortRec : PAbortRec);
var
	vAbortRec : TAbortRec;
	vDebugEx : TDebugEX;

begin
	if not vInPanic then // Uma segunda chamada a KernelPanic nao entrara, fazendo ResetCPU
	begin
		vInPanic := True;

		if Assigned(AbortRec) then
		begin
			vAbortRec := AbortRec^;
			vDebugEx := GetDebugEx;
			PrintRSoD(Error, ErrorMsg, @vAbortRec, @vDebugEx);
		end
		else
			PrintRSoD(Error, ErrorMsg, nil, nil);

		Shutdown([sdHalt]);
	end;

	Shutdown([sdReboot, sdForce]);
end;


procedure ResetCPU;
	procedure FastReset; assembler;
	asm
		mov dx, $92
		mov al, 1
		out dx, al
	end;

	procedure PCIReset; assembler;
	asm
		mov dx, $cf9
		mov al, 2
		out dx, al
		mov al, 6
		out dx, al
	end;

begin
	// tentando fast reset
	FastReset;
	// tentando PCI chipset reset
	PCIReset;
end;

procedure HaltCPU; assembler; nostackframe;
asm
	cli
	hlt
end;


procedure PrintRSoD(Error : TErrorCode; Msg : PChar; AbortRec : PAbortRec; DebugEx : PDebugEX);
const
	cStackRows = 12;
	cStackCols = 2;

var
	vFrameIni, vFrameCount : LongWord;
	vRows, vCols : Word;
	vMaxFrames : Word;

begin
	CSetBackground(Red);
	CSetColor(White);
	CLineFeed(2);

	CWriteln('Kernel Panic!');
	CWrite('Error: ');
	CWrite(GetErrorString(Error));
	CWrite(' (ErrorNo: ');
	CWrite(Ord(Error));
	CWriteln(')');

	if Assigned(Msg) then
	begin
		vMaxFrames := cStackCols * (cStackRows - 1);

		CWrite('Message: ');
		CWriteln(Msg);
	end
	else
		vMaxFrames := cStackCols * cStackRows;

	CWriteln;

	if Assigned(AbortRec) then
	begin
		CWrite('EAX: ');
		CWrite(IntToHexX(AbortRec^.Basic.EAX, 8));
		CWrite(HT);
		CWrite('CS: ');
		CWrite(IntToHexX(AbortRec^.Basic.CS, 4));
		CWrite(HT);
		CWrite('CR0: ');
		CWrite(IntToHexX(DebugEx^.CR0, 8));
		CWrite(HT);
		CWrite('EIP: ');
		CWrite(AbortRec^.Stack.EIP);
		CWriteln;

		CWrite('EBX: ');
		CWrite(IntToHexX(AbortRec^.Basic.EBX, 8));
		CWrite(HT);
		CWrite('DS: ');
		CWrite(IntToHexX(AbortRec^.Basic.DS, 4));
		CWrite(HT);
		CWrite('CR2: ');
		CWrite(IntToHexX(DebugEx^.CR2, 8));
		CWrite(HT);
		CWrite('EBP: ');
		CWrite(AbortRec^.Stack.EBP);
		CWriteln;

		CWrite('ECX: ');
		CWrite(IntToHexX(AbortRec^.Basic.ECX, 8));
		CWrite(HT);
		CWrite('ES: ');
		CWrite(IntToHexX(AbortRec^.Basic.ES, 4));
		CWrite(HT);
		CWrite('CR3: ');
		CWrite(IntToHexX(DebugEx^.CR3, 8));
		CWrite(HT);
		CWrite('ESP: ');
		CWrite(AbortRec^.Stack.ESP);
		CWriteln;

		CWrite('EDX: ');
		CWrite(IntToHexX(AbortRec^.Basic.EDX, 8));
		CWrite(HT);
		CWrite('FS: ');
		CWrite(IntToHexX(AbortRec^.Basic.FS, 4));
		CWrite(HT);
		CWrite('CR4: ');
		CWrite(IntToHexX(DebugEx^.CR4, 8));
		CWriteln;

		CWrite('ESI: ');
		CWrite(IntToHexX(AbortRec^.Basic.ESI, 8));
		CWrite(HT);
		CWrite('GS: ');
		CWrite(IntToHexX(AbortRec^.Basic.GS, 4));
		CWrite(HT);
		CWrite('EFLAGS: ');
		CWrite(IntToHexX(AbortRec^.Basic.EFLAGS, 8));
		CWriteln;

		CWrite('EDI: ');
		CWrite(IntToHexX(AbortRec^.Basic.EDI, 8));
		CWrite(HT);
		CWrite('SS: ');
		CWrite(IntToHexX(AbortRec^.Basic.SS, 4));
		CWrite(HT);
		CWrite('Stack Frames Levels: ');
		CWriteln(AbortRec^.StackLevels);
		CWriteln;

		vCols := cStackCols;

		if (AbortRec^.StackLevels < vMaxFrames) then
			vFrameCount := AbortRec^.StackLevels
		else
			vFrameCount := vMaxFrames;

		vRows := ((vFrameCount -1) div cStackCols) + 1;

		vFrameIni := AbortRec^.StackLevels - vFrameCount;

		CWriteln('Stack Calls:');
		PrintStackCalls(AbortRec^.Stack.EBP, vFrameIni, vFrameCount, vCols, vRows);
	end
	else
		CWriteln('Nenhuma informacao adicional disponivel :(');
end;


end.
