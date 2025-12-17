/*	---------------------------------------------------------
	File.......: WDO_MYSQL.prg
	Description: Conexión a Bases de Datos MySql 
				  Version for Uhttpd2	
	Author.....: Carles Aubia Floresvi
	Date:......: 26/07/2019
	Updated:...: 17/03/2023	
	--------------------------------------------------------- */ 	
	
#include 'hbclass.ch'
#include "hbdyn.ch"
#include "fileio.ch"

#xcommand ? [<explist,...>] => UWrite( '<br>' [,<explist>] )
#xcommand TRY  => BEGIN SEQUENCE WITH {| oErr | Break( oErr ) }
#xcommand CATCH [<!oErr!>] => RECOVER [USING <oErr>] <-oErr->
#xcommand FINALLY => ALWAYS
#xtranslate Throw( <oErr> ) => ( Eval( ErrorBlock(), <oErr> ), Break( <oErr> )

#define VERSION_WDO_MYSQL					'1.1'

#define HB_VERSION_BITWIDTH  				17
#define NULL  								0  

	
CLASS WDO_MySql FROM WDO

	DATA cServer	
	DATA cUserName	
	DATA cPassword 
	DATA cDatabase 
	DATA nPort 		
 			

	DATA pLib
	DATA hMySql
	DATA hConnection
	
	
	DATA lConnect								INIT .F.
	DATA lPersistent							INIT .F.
	DATA lLog									INIT .F.
	DATA lLogFile								INIT .F.
	DATA lWeb									INIT .T.
	DATA nAffected_Rows						INIT 0
	DATA cError 								INIT ''
	DATA aFields 								INIT {}
	DATA aLog 									INIT {}
	
	DATA nFields								INIT 0
	DATA nSysCallConv
	DATA nSysLong
	DATA nTypePos
	DATA cDllType
	
	CLASSDATA lUtf8 							INIT .F.
	
	METHOD New() 								CONSTRUCTOR
		
	METHOD Query( cSql )	
	
	METHOD Prepare( hRow )
	METHOD Escape( hRow )
	
	METHOD Row_Count()	
	METHOD Last_Insert_Id()	
	
	METHOD Count( hRes )						INLINE ::mysql_num_rows( hRes )
	METHOD FCount( hRes )						INLINE ::mysql_num_fields( hRes )
	METHOD LoadStruct()					
	METHOD DbStruct()							INLINE ::aFields
	METHOD Fetch( hRes )	
	METHOD Fetch_Assoc( hRes )		
	METHOD FetchAll( hRes, lAssociative )
	METHOD Free_Result( hRes )				INLINE ::mysql_free_result( hRes )	
	
	
	
	//	Wrappers (Antonio Linares)
	
	METHOD mysql_init()
	METHOD mysql_Close()
	METHOD mysql_get_server_info()
	METHOD mysql_real_connect( cServer, cUserName, cPassword, cDataBaseName, nPort )
	METHOD mysql_error()
	METHOD mysql_query( cQuery )
	METHOD mysql_store_result()
	METHOD mysql_num_rows( hRes )
	METHOD mysql_num_fields( hRes ) 
	METHOD mysql_fetch_field( hRes )
	METHOD mysql_fetch_row( hRes )
	METHOD mysql_free_result( hRes )
	METHOD mysql_real_escape_string_quote( cQuery )	
	METHOD mysql_get_client_info()

	
	METHOD Version()						INLINE VERSION_WDO_MYSQL
	METHOD VersionName()					INLINE 'WDO_MYSQL ' + VERSION_WDO_MYSQL
	METHOD GetDllVersion()

	METHOD Exit()
	METHOD Close()
	METHOD End()							INLINE ::Close()

ENDCLASS

METHOD New( cServer, cUsername, cPassword, cDatabase, nPort, cType, lLog, bError ) CLASS WDO_MySql

	local cDll 
	local nTry := 0

	hb_default( @cServer, '' )
	hb_default( @cUserName, '' )
	hb_default( @cPassword, '' )
	hb_default( @cDatabase, '' )
	hb_default( @nPort, 3306 )
	hb_default( @cType, 'MYSQL' )
	hb_default( @lLog, .F. )
	

	if valtype( bError ) == 'B'	
		::bError := bError
	//else
	//	::bError := NIL		//	{|cError| AP_RPuts( '<br>' + cError ), .t. }
	endif
		
	::cServer		:= cServer
	::cUserName		:= cUserName
	::cPassword 	:= cPassword
	::cDatabase 	:= cDatabase
	::nPort 		:= nPort	
	::lLog 			:= lLog 
	
	if( ::lLog, _d( 'WDO log activated' ), nil )		

	//	Cargamos lib mysql
	
		cType := Upper( cType )
		
		DO CASE 
			CASE cType == 'MYSQL' 		
				::cDllType := 'MySql'
				cDll 	:= hb_SysMySQL() 
			CASE cType == 'MARIADB' 	
				::cDllType := 'MariaDB'
				cDll 	:= hb_SysMariaDb() 
			OTHERWISE 
				::SetError(  "Error: Library type:  " + cType )
				retu self 		
		ENDCASE							

		::pLib 	:= hb_LibLoad( cDll )	


		If ValType( ::pLib ) <> "P" 
		
			if( ::lLog, _d( 'WDO ' + ::cError + ' ' + cDll ), nil )
			
			::SetError(  "Error: MySQL library wrong: " + lower( cDll ) )
			
			RETU NIL
		ENDIF
		
	//	Inicializamos Variables 
	
		::nSysCallConv 	:= hb_SysCallConv()
		::nSysLong 		:= hb_SysLong()
		::nTypePos 		:= hb_SysMyTypePos()

	
	//	Inicializamos mysql
	
		
		::hMySQL = ::mysql_init()

		while ::hMySql == 0 .and. nTry < 3
		
			nTry++
			if( ::lLog, _d( 'WDO ' + 'MySQL library failed to initialize. Try: ' + str(nTry)), nil )
			inkey(0.1)	
			::hMySQL = ::mysql_init()			
			
		end 
		
	
		IF ::hMySQL == 0 
			::SetError( "hMySQL = 0 (MySQL library failed to initialize)" )				
			RETU Self
		ENDIF
		
	//	Server Info
	
		// "MySQL version: " + ::mysql_get_server_info()  	

		
	//	Conexion a Base de datos	
		
		::hConnection := ::mysql_real_connect( ::cServer, ::cUserName, ::cPassword, ::cDatabase, ::nPort )
		
		IF  ::hConnection != ::hMySQL
			::SetError(  "Connection = (Failed connection) " + ::mysql_error() )

			RETU Self
		ENDIF
		
		::lConnect := .T.
		
RETU SELF

/*	Ejecutamos un wdo_addslashes sobre las variables a salvar: 
	l'aliga -> l\'aliga
	Hello "World" -> Hello \"Wold\"	
*/
METHOD Prepare( hRow ) CLASS WDO_MySql
	
	local n, aPair, nLen 
	local cType := valtype( hRow )
	
	do case 
		case cType == 'H'
		
			nLen := len( hRow )
	
			for n := 1 to nLen 
			
				aPair := HB_HPairAt( hRow, n )
				
				if valtype( aPair[2] ) == 'C' .or. valtype( aPair[2] ) == 'M' 								
					hRow[ aPair[1] ] := wdo_addslashes( aPair[2] )
				endif

			next 
			
		case cType == 'A'
	
			nLen := len( hRow )
			
			for n := 1 to nLen 							
				
				if valtype(  hRow[ n ] ) == 'C' .or. valtype(  hRow[ n ] ) == 'M' 								
					hRow[ n ] := wdo_addslashes( hRow[ n ] )
				endif

			next 	

		case cType == 'C'								
			
 
			if valtype(  hRow ) == 'C' .or. valtype( hRow ) == 'M' 								
				hRow := wdo_addslashes( hRow )					
			endif
			
	endcase 

retu hRow 


METHOD Escape( hRow ) CLASS WDO_MySql
/*	
	local n, aPair, nLen := len( hRow )
	
	for n := 1 to nLen 
	
		aPair := HB_HPairAt( hRow, n )
		
		hRow[ aPair[1] ] := //wdo_addslashes( aPair[2] )

	next 
*/	

retu hRow 




METHOD Query( cQuery, lError ) CLASS WDO_MySql

	LOCAL nRetVal
	LOCAL hRes			:= 0
	local cSql 		:= ''	

    IF ::hConnection == 0
		RETU 0
	ENDIF	

	lError := .F.
	

	if ( ::lLog	, _d( 'WDO ' + cQuery ), nil )	
	
	::nFields 	:= 0		
	
    nRetVal 	:= ::mysql_query( cQuery )	
	

	IF nRetVal == 0 

		hRes = ::mysql_store_result()

		IF hRes != 0					//	Si Update/Delete hRes == 0
	
			::LoadStruct( hRes )						

			
		ENDIF		

	ELSE

		//::SetError( 'Error: ' + ::mysql_error() )
		
		::SetError( ::mysql_error() )
		
		lError := .t.
		
	ENDIF
   
RETU hRes


METHOD Last_Insert_Id() CLASS WDO_MySql 

	local nId := -1
	local hRes, hRs 
	
	if !empty( hRes := ::Query( "SELECT LAST_INSERT_ID() as last_id"  ) )
	
		hRs := ::Fetch_Assoc( hRes )
	
		nId := Val( hRs['last_id'] )
	
	endif 

RETU nId 

//	Return affected rows. Execute after query

METHOD Row_Count() CLASS WDO_MySql 

	local hRes, hRs 
	
	::nAffected_Rows := 0
	
	if !empty( hRes := ::Query( "SELECT ROW_COUNT() as total"  ) )	
	
		hRs 	:= ::Fetch_Assoc( hRes )
	
		::nAffected_Rows	:= Val( hRs['total'] )
	
	endif 

RETU ::nAffected_Rows

METHOD LoadStruct( hRes ) CLASS WDO_MySql

	LOCAL n, hField	
     
    ::nFields := ::FCount( hRes ) 
    ::aFields := Array( ::nFields )
	
	
    FOR n = 1 to ::nFields
	
        hField := ::mysql_fetch_field( hRes )
		
        if hField != 0
		
			::aFields[ n ] = Array( 4 )
            ::aFields[ n ][ 1 ] = PtrToStr( hField, 0 )
			
            do case              
               case AScan( { 253, 254, 12 }, PtrToUI( hField, ::nTypePos ) ) != 0
                    ::aFields[ n ][ 2 ] = "C"

               case AScan( { 1, 3, 4, 5, 8, 9, 246 }, PtrToUI( hField, ::nTypePos ) ) != 0
                    ::aFields[ n ][ 2 ] = "N"

               case AScan( { 10 }, PtrToUI( hField, ::nTypePos ) ) != 0
                    ::aFields[ n ][ 2 ] = "D"

               case AScan( { 250, 252 }, PtrToUI( hField, ::nTypePos ) ) != 0
                    ::aFields[ n ][ 2 ] = "M"
            endcase 
			
        endif   
		 
	NEXT 
	  
RETU NIL

METHOD Fetch( hRes, aNoEscape ) CLASS WDO_MySql

	LOCAL hRow
	LOCAL aReg
	LOCAL m
	
	hb_default( @aNoEscape, {} )

	if ( hRow := ::mysql_fetch_row( hRes ) ) != 0	
	
		aReg 	:= array( ::nFields )		
	
		if len( aNoEscape ) == 0 
		
			if ::lWeb
			
				for m = 1 to ::nFields	
					aReg[ m ] := wdo_htmlencode( PtrToStr( hRow, m - 1 ) )														
				next
				
			else 		
				
				for m = 1 to ::nFields									
					aReg[ m ] := PtrToStr( hRow, m - 1 ) 
				next
				
				
				//	Ok. Quick !
				//AEval( aReg, {|a,n| aReg[n] := PtrToStr( hRow, n - 1 )} )				

			endif
		
		else 
		
			if ::lWeb
		
				for m = 1 to ::nFields
				
					if Ascan( aNoEscape, ::aFields[m][1] ) > 0
						aReg[ m ] := PtrToStr( hRow, m - 1 ) 
					else
						aReg[ m ] := wdo_htmlencode( PtrToStr( hRow, m - 1 ) )
					endif
				next
			
			else 
			
				for m = 1 to ::nFields
					aReg[ m ] := PtrToStr( hRow, m - 1 )					
				next						
			
			endif 
		
		endif
		
	endif


RETU aReg


METHOD Fetch_Assoc( hRes, aNoEscape ) CLASS WDO_MySql

	LOCAL hRow
	LOCAL hReg		:= {=>}
	LOCAL m
	
	hb_default( @aNoEscape, {} )
	
	
	
	if ( hRow := ::mysql_fetch_row( hRes ) ) != 0
		
		if len( aNoEscape ) == 0 

			if ::lWeb		

				for m = 1 to ::nFields					
					//if ::lUtf8
					//	hReg[ ::aFields[m][1] ] :=  hb_strtoUtf8(wdo_htmlencode( PtrToStr( hRow, m - 1 ) )	)
					//else
						hReg[ ::aFields[m][1] ] :=  wdo_htmlencode( PtrToStr( hRow, m - 1 ) )			
					//endif
				next	

			else
			
				for m = 1 to ::nFields					
					hReg[ ::aFields[m][1] ] :=  PtrToStr( hRow, m - 1 ) 
				next				
			
			endif

		else 
			
			if ::lWeb 
			
				for m = 1 to ::nFields
				
					if Ascan( aNoEscape, ::aFields[m][1]  ) > 0		
						hReg[ ::aFields[m][1] ] :=  PtrToStr( hRow, m - 1 ) 
					else
						hReg[ ::aFields[m][1] ] :=  wdo_htmlencode( PtrToStr( hRow, m - 1 ) )
					endif
				
				next
			
			else 
			
				for m = 1 to ::nFields
				
					if Ascan( aNoEscape, ::aFields[m][1]  ) > 0		
						hReg[ ::aFields[m][1] ] :=  PtrToStr( hRow, m - 1 ) 
					endif
				
				next			
			
			endif
			
		endif
			
		
	endif

RETU hReg

METHOD FetchAll( hRes, lAssociative, aNoEscape ) CLASS WDO_MySql

	LOCAL oRs
	LOCAL aData := {}
	
	__defaultNIL( @lAssociative, .f. )
	__defaultNIL( @aNoEscape, {} )


	
	IF lAssociative 
	
		WHILE ( !empty( oRs := ::Fetch_Assoc( hRes, aNoEscape ) ) )
	
			Aadd( aData, oRs )
		
		END
	
				
	ELSE
	
		WHILE ( !empty( oRs := ::Fetch( hRes, aNoEscape  ) ) )
		
			Aadd( aData, oRs )
			
		END
		
	ENDIF

RETU aData


//	Wrappers...

METHOD mysql_num_rows( hRes ) CLASS WDO_MySql	

return hb_DynCall( { "mysql_num_rows", ::pLib, hb_bitOr( ::nSysLong,;
                  ::nSysCallConv ), ::nSysLong }, hRes )




METHOD mysql_Init() CLASS WDO_MySql

	local u, n, oError 
	local cInfo := ''

	try 
	
		u := hb_DynCall( { "mysql_init", ::pLib, hb_bitOr( ::nSysLong, ::nSysCallConv ) }, NULL )
			
	catch oError 
	
		cInfo := 'Error mysql init' + chr(10) + chr(13)
		
		cInfo += 'Description: ' + oError:description + chr(10) + chr(13)
		
	    if ! Empty( oError:operation )
			cInfo += 'Operation: ' + oError:operation + chr(10) + chr(13)
	    endif            
   
		if ValType( oError:Args ) == "A"
			cInfo += 'Args:' +  chr(10) + chr(13)
			for n = 1 to Len( oError:Args )
				cInfo += "[" + Str( n, 4 ) + "] = " + ValType( oError:Args[ n ] ) + ;
                   "   " + Uvaltochar( oError:Args[ n ] ) + ;
                   If( ValType( oError:Args[ n ] ) == "A", " Len: " + ;
                   AllTrim( Str( Len( oError:Args[ n ] ) ) ), "" ) + chr(10) + chr(13)
			next
			
		endif			
		
		_d( cInfo )
		
	end 
	
RETU u



METHOD mysql_Close() CLASS WDO_MySql

RETU hb_DynCall( { "mysql_close", ::pLib, ::nSysCallConv, ::nSysLong }, ::hMySQL )

				   
METHOD mysql_get_server_info() CLASS WDO_MySql	

RETU hb_DynCall( { "mysql_get_server_info", ::pLib, hb_bitOr( HB_DYN_CTYPE_CHAR_PTR,;
                   ::nSysCallConv ), ::nSysLong }, ::hMySql )			   


				   
METHOD mysql_real_connect( cServer, cUserName, cPassword, cDataBaseName, nPort ) CLASS WDO_MySql	

    if nPort == nil
       nPort = 3306
    endif   

RETU hb_DynCall( { "mysql_real_connect", ::pLib, hb_bitOr( ::nSysLong,;
                     ::nSysCallConv ), ::nSysLong,;
                     HB_DYN_CTYPE_CHAR_PTR, HB_DYN_CTYPE_CHAR_PTR, HB_DYN_CTYPE_CHAR_PTR, HB_DYN_CTYPE_CHAR_PTR,;
                     HB_DYN_CTYPE_LONG, HB_DYN_CTYPE_LONG, HB_DYN_CTYPE_LONG },;
                     ::hMySQL, cServer, cUserName, cPassword, cDataBaseName, nPort, 0, 0 )
                     				   
				   

METHOD mysql_error() CLASS WDO_MySql	

RETU hb_DynCall( { "mysql_error", ::pLib, hb_bitOr( HB_DYN_CTYPE_CHAR_PTR,;
                   ::nSysCallConv ), ::nSysLong }, ::hMySql )

				   

METHOD mysql_query( cQuery ) CLASS WDO_MySql	

	local u
	
	//local bNewError := {|oError| ErrorHandler(oError,.T.) }
	local bNewError := {|oError| Break(oError) }
    local bOldError := Errorblock(bNewError)

	BEGIN SEQUENCE
		u := hb_DynCall( { "mysql_query", ::pLib, hb_bitOr( HB_DYN_CTYPE_INT,;
						   ::nSysCallConv ), ::nSysLong, HB_DYN_CTYPE_CHAR_PTR },;
						   ::hConnection, cQuery )
   
    RECOVER
    
	  ::SetError( ::mysql_error() )
      return nil
    END SEQUENCE
	
	Errorblock(bOldError)
				   
RETU u 

METHOD mysql_real_escape_string_quote( cQuery ) CLASS WDO_MySql	

	cQuery := StrTran( cQuery, "'", "\'" )

retu cQuery

/*
RETU hb_DynCall( { "mysql_real_escape_string", hb_bitOr( HB_DYN_CTYPE_INT,;
                   ::nSysCallConv ), ::nSysLong, HB_DYN_CTYPE_CHAR_PTR, HB_DYN_CTYPE_CHAR_PTR, HB_DYN_CTYPE_LONG, HB_DYN_CTYPE_CHAR_PTR },;
				   ::hConnection, @cQuery, cQuery, Len(cQuery), "\'")	
*/

/*
RETU hb_DynCall( { "mysql_real_escape_string", ::pLib, hb_bitOr( ::nSysLong,;
::nSysCallConv ), ::nSysLong, HB_DYN_CTYPE_CHAR_PTR, HB_DYN_CTYPE_CHAR_PTR, HB_DYN_CTYPE_LONG, HB_DYN_CTYPE_CHAR_PTR },;
::hConnection, @cQuery, cQuery,  Len(cQuery), "\'")				   
*/				   


METHOD mysql_store_result() CLASS WDO_MySql	

RETU hb_DynCall( { "mysql_store_result", ::pLib, hb_bitOr( ::nSysLong,;
                   ::nSysCallConv ), ::nSysLong }, ::hMySQL )



METHOD mysql_num_fields( hRes ) CLASS WDO_MySql	

RETU hb_DynCall( { "mysql_num_fields", ::pLib, hb_bitOr( HB_DYN_CTYPE_LONG_UNSIGNED,;
                   ::nSysCallConv ), ::nSysLong }, hRes )				   
				   
				   
METHOD mysql_fetch_field( hRes ) CLASS WDO_MySql	

RETU hb_DynCall( { "mysql_fetch_field", ::pLib, hb_bitOr( ::nSysLong,;
                   ::nSysCallConv ), ::nSysLong }, hRes )	
				   

	   
METHOD mysql_fetch_row( hRes ) CLASS WDO_MySql	

RETU hb_DynCall( { "mysql_fetch_row", ::pLib, hb_bitOr( ::nSysLong,;
                   ::nSysCallConv ), ::nSysLong }, hRes )	  



METHOD mysql_free_result( hRes ) CLASS WDO_MySql	

	local u, n, oError 
	local cInfo := ''

	try 
	
		u := hb_DynCall( { "mysql_free_result", ::pLib, ::nSysCallConv, ::nSysLong }, hRes )				
		
	catch oError 
	
		cInfo := 'Error mysql_free_result' + chr(10) + chr(13)
		
		cInfo += 'Description: ' + oError:description + chr(10) + chr(13)
		
	    if ! Empty( oError:operation )
			cInfo += 'Operation: ' + oError:operation + chr(10) + chr(13)
	    endif            
   
		if ValType( oError:Args ) == "A"
			cInfo += 'Args:' +  chr(10) + chr(13)
			for n = 1 to Len( oError:Args )
				cInfo += "[" + Str( n, 4 ) + "] = " + ValType( oError:Args[ n ] ) + ;
                   "   " + Uvaltochar( oError:Args[ n ] ) + ;
                   If( ValType( oError:Args[ n ] ) == "A", " Len: " + ;
                   AllTrim( Str( Len( oError:Args[ n ] ) ) ), "" ) + chr(10) + chr(13)
			next
			
		endif			
		
		_d( cInfo )
		
	end 

retu u 
//RETU hb_DynCall( { "mysql_free_result", ::pLib,;
//                   ::nSysCallConv, ::nSysLong }, hRes )



METHOD mysql_get_client_info() CLASS WDO_MySql
    // Esta función de C no requiere parámetros y devuelve un char*
RETU hb_DynCall( { "mysql_get_client_info", ::pLib, ;
                       hb_bitOr( HB_DYN_CTYPE_CHAR_PTR, ::nSysCallConv ) } )

METHOD GetDllVersion() CLASS WDO_MySql
    
    Local cVer := "Unknown"
    
    IF ::pLib != NIL
        cVer := ::mysql_get_client_info()
    ENDIF

RETURN "Library Type: " + ::cDllType + " | Client Version: " + cVer

METHOD Exit() CLASS WDO_MySql

	if ::lPersistent 
		if( ::lLog, _d( 'WDO Persistent' ), nil )				
		retu nil
	endif 

	
RETU NIL

METHOD Close() CLASS WDO_MySql

    IF ValType( ::pLib ) == "P"		

		if( ::lLog, _d( 'WDO Close proc' ), nil )		
		
		::MySql_Close()		
		
		HB_LibFree( ::pLib )
		
		::pLib := NIL
		::hMySql := NIL								

		//hb_idleSleep( 1 )		
		
    ENDIF 

RETU NIL 
//	------------------------------------------------------------

function hb_SysLong()

return If( hb_OSIS64BIT(), HB_DYN_CTYPE_LLONG_UNSIGNED, HB_DYN_CTYPE_LONG_UNSIGNED )

//----------------------------------------------------------------//

function hb_SysCallConv()

return If( ! "Windows" $ OS(), HB_DYN_CALLCONV_CDECL, HB_DYN_CALLCONV_STDCALL )

//----------------------------------------------------------------//


function hb_SysMyTypePos()

return If( hb_version( HB_VERSION_BITWIDTH ) == 64,;
       If( "Windows" $ OS(), 26, 28 ), 19 )   

//----------------------------------------------------------------//

function hb_SysMySQL()

   local cLibName

   
   if ! "Windows" $ OS()
      if "Darwin" $ OS()
         cLibName = "/usr/local/Cellar/mysql/8.0.16/lib/libmysqlclient.dylib"
      else   
         cLibName = If( hb_version( HB_VERSION_BITWIDTH ) == 64,;
                        "/usr/lib/x86_64-linux-gnu/libmysqlclient.so",; // libmysqlclient.so.20 for mariaDB
                        "/usr/lib/x86-linux-gnu/libmysqlclient.so" )
      endif                  
   else

		IF hb_version( HB_VERSION_BITWIDTH ) == 64
		
			IF !Empty( HB_GetEnv( 'WDO_PATH_MYSQL' ) )
				cLibName = HB_GetEnv( 'WDO_PATH_MYSQL' ) + 'libmysql64.dll'
			ELSE
				cLibName = "c:/Apache24/htdocs/libmysql64.dll"
			ENDIF
		
		ELSE
		
			IF !Empty( HB_GetEnv( 'WDO_PATH_MYSQL' ) )
				cLibName = HB_GetEnv( 'WDO_PATH_MYSQL' ) + 'libmysql.dll'
			ELSE
				cLibName = "c:/Apache24/htdocs/libmysql.dll"
			ENDIF		
		
		ENDIF

   endif

return cLibName 

//----------------------------------------------------------------//

function hb_SysMariaDb()

   local cLibName

   
   if ! "Windows" $ OS()
      if "Darwin" $ OS()
         cLibName = "/usr/local/Cellar/mysql/8.0.16/lib/libmysqlclient.dylib"
      else   
         cLibName = If( hb_version( HB_VERSION_BITWIDTH ) == 64,;
                        "/usr/lib/x86_64-linux-gnu/libmariadbclient.so",; // libmysqlclient.so.20 for mariaDB
                        "/usr/lib/x86-linux-gnu/libmariadbclient.so" )
      endif                  
   else

		IF hb_version( HB_VERSION_BITWIDTH ) == 64
		
			IF !Empty( HB_GetEnv( 'WDO_PATH_MYSQL' ) )
				cLibName = HB_GetEnv( 'WDO_PATH_MYSQL' ) + 'libmariadb64.dll'
			ELSE
				cLibName = "c:/Apache24/htdocs/libmariadb64.dll"
			ENDIF
		
		ELSE
		
			IF !Empty( HB_GetEnv( 'WDO_PATH_MYSQL' ) )
				cLibName = HB_GetEnv( 'WDO_PATH_MYSQL' ) + 'libmariadb64.dll'
			ELSE
				cLibName = "c:/Apache24/htdocs/libmariadb64.dll"
			ENDIF		
		
		ENDIF

   endif

return cLibName 

function wdo_addslashes( c )

	c := StrTran( c, '\', '\\' )
	c := StrTran( c, "'", "\'" )
	c := StrTran( c, '"', '\"' )
	
	//	Pending byte NULL
	
retu c	

function wdo_htmlencode( cString )

   local cChar, cRet := "" 

   for each cChar in cString
		do case
			case cChar == "<"	; cChar := "&lt;"
			case cChar == '>'	; cChar := "&gt;"     				
			case cChar == "&"	; cChar := "&amp;"     
			case cChar == '"'	; cChar := "&quot;" 
			case cChar == "'"	; cChar := "&apos;"   			          
		endcase
		
		cRet += cChar 
   next
	
RETURN cRet


