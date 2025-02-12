/*	---------------------------------------------------------
	File.......: WDO.prg
	Description: Base WDO. Conexión a Bases de Datos. 
				  Version for Uhttpd2
	Author.....: Carles Aubia Floresvi
	Date:......: 26/07/2019
	Updated:...: 17/03/2023
	--------------------------------------------------------- */
#include 'hbclass.ch'

#xcommand ? [<explist,...>] => UWrite( '<br>' [,<explist>] )
#xcommand ?? [<explist,...>] => UWrite( [<explist>] )
	
#define WDO_VERSION 		'2.0'

thread static hPool 

CLASS WDO	

	DATA cError 								INIT ''
	
	CLASSDATA lShowError						INIT .t.
	CLASSDATA lLog								INIT .f.
	CLASSDATA bError 								
	
	METHOD VersionName()						INLINE 'WDO UHttpd2'
	METHOD Version()							INLINE WDO_VERSION
	
	METHOD SetError( cError )		
	METHOD GetError()							INLINE ::cError
	
	METHOD View ( aSt, aData, cTitle, lShow ) 
	METHOD Table( aSt, aData, cTitle )
	
ENDCLASS

METHOD SetError( cError ) CLASS WDO
	LOCAL cHtml := ''

	::cError := cError
	
	IF Valtype( ::bError ) == 'B'			
		::cError := Eval( ::bError, ::cError )																			
	ENDIF

	IF ::lShowError										

		? '<h3><b>Error</b>', ::cError, '</b></h3>'
			
	ENDIF

RETU ''

//	------------------------------------------------------- //

METHOD Table( aSt, aData, cTitle ) CLASS WDO
RETU ::View( aSt, aData, cTitle, .F. )

//	------------------------------------------------------- //

METHOD View( aSt, aData, cTitle, lShow ) CLASS WDO

	LOCAL nFields 	:= len( aSt )
	LOCAL cHtml 	:= ''
	LOCAL n, j, nLen
	
	hb_default( @cTitle, '' )
	hb_default( @lShow, .t. )
	
	if !empty( cTitle)
		cHtml += cTitle
	endif
	
	cHtml += '<style>'
	cHtml += '#wdo_mytable tr:hover {background-color: #ddd;}'
	cHtml += '#wdo_mytable tr:nth-child(even){background-color: #e0e6ff;}'
	cHtml += '#wdo_mytable { font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;border-collapse: collapse; width: 100%; }'
	cHtml += '#wdo_mytable thead { background-color: #425ecf;color: white;}'
	cHtml += '</style>'
	cHtml += '<table id="wdo_mytable" border="1" cellpadding="3" >'
	
	cHtml += '<thead><tr>'
	
	FOR n := 1 TO nFields
	
		cHtml += '<td>' + aSt[n][1] + '</td>'
		
	NEXT
	
	cHtml += '</tr></thead>'
	
	nLen := len( aData )
	
	cHtml += '<tbody>'
	
	//? cHtml 
	
	FOR n := 1 to nLen 
	
		cHtml += '<tr>'
		
		FOR j := 1 to nFields

			cHtml += '<td>' + UValtochar( aData[n][j] ) + '</td>'
		
		NEXT
		
		cHtml += '</tr>'
		
		//?? cHtml
	
	NEXT
	
	//?? '</tbody></table><hr>'
	cHtml += '</tbody></table><hr>'	

	if lShow 
		? cHtml
	endif

RETU cHtml

//	------------------------------------------------------- //


function WDO_Version() ; retu WDO_VERSION


function WDO_Pool( cName, bInit )
	local h

	hb_default( @cName, '' )	
	
	if empty( cName )
		retu nil
	endif	

	if hPool == nil 	

		if valtype( bInit ) == 'B'
		
			hPool := {=>}
		
			hPool[ cName ] := { 'id' => hb_threadId(),;
								 'pool' => eval( bInit ) }			
				

			retu hPool[ cName ][ 'pool' ]
		else
			retu nil		
		endif 
	
	endif

	if valtype( hPool ) == 'H' .and. HB_HHasKey( hPool, cName )
			h := hPool[ cName ]
			if valtype( h ) == 'H' .and. HB_HHasKey( h, 'id' ) .and. h[ 'id' ] == hb_threadId()
	
				retu h[ 'pool' ]
			endif
	
	endif	
	
retu nil 
