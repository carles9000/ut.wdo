/*	---------------------------------------------------------
	File.......: WDO_DBF.prg
	Description: Conexión a Dbf
				  Version for Uhttpd2	
	Author.....: Carles Aubia Floresvi
	Date:......: 26/07/2019
	Updated:...: 17/03/2023	
	--------------------------------------------------------- */ 
	
REQUEST DBFCDX

#include 'hbclass.ch'
	
#define VERSION_WDO_DBF			'0.1c'

	
CLASS WDO_Dbf FROM WDO


	DATA cDbf 								INIT ''
	DATA cIndex								INIT ''
	DATA cAlias 							INIT ''
	DATA cError 							INIT ''
	DATA cPath 								INIT ''
	DATA cRdd 								INIT ''
	DATA lExclusive						INIT .F.
	DATA lRead								INIT .F.
	DATA lOpen								INIT .F.
	DATA lConnect							INIT .F.
	DATA cError 							INIT ''	
	
	
	
	//	Default config for all conections
	
	CLASSDATA cDefaultPath 				INIT hb_dirbase()
	CLASSDATA cDefaultRdd 					INIT 'DBFCDX'
	CLASSDATA nTime							INIT 10
	
	METHOD New() 							CONSTRUCTOR
	
	//	Common methods

	METHOD Open()
	METHOD NewAlias()
	METHOD Close()	
	METHOD Reset()	
	
	METHOD Count()  						INLINE IF ( ::lOpen, (::cAlias)->( RecCount() ), 0 )
	METHOD CountDeleted()	
	
	METHOD FieldPos( n )  				INLINE IF ( ::lOpen, (::cAlias)->( FieldPos( n ) ), '' )
	METHOD FieldName( n )  				INLINE IF ( ::lOpen, (::cAlias)->( FieldName( n ) ), '' )
	METHOD FieldGet( ncField )  			INLINE IF ( ::lOpen, (::cAlias)->( FieldGet( If( ValType( ncField ) == "C", ::FieldPos( ncField ), ncField ) ) ), '' )
    METHOD FieldPut( ncField, uValue )	
	
    METHOD Next( n )  						INLINE IF ( ::lOpen, ( hb_default( @n, 1), (::cAlias)->( DbSkip( n ) )), NIL )
    METHOD Prev( n )  						INLINE IF ( ::lOpen, ( hb_default( @n, -1), (::cAlias)->( DbSkip( n ) )), NIL )
    METHOD First() 						INLINE IF ( ::lOpen, (::cAlias)->( DbGoTop() ), NIL )
    METHOD Last() 							INLINE IF ( ::lOpen, (::cAlias)->( DbGoBottom() ), NIL )
	
	
	METHOD Version()						INLINE VERSION_WDO_DBF
	METHOD VersionName()					INLINE 'WDO_DBF ' + VERSION_WDO_DBF
	
	//	Particular methods...
	
    METHOD GoTo( n ) 						INLINE IF ( ::lOpen, (::cAlias)->( DbGoTo( n ) ), NIL )	
    METHOD Recno() 						INLINE IF ( ::lOpen, (::cAlias)->( Recno() ), -1 )	
    METHOD Focus( cFocus ) 	
    METHOD Seek( cSeek, lSoftSeek ) 
    METHOD BOF()							INLINE IF ( ::lOpen, (::cAlias)->( Bof() ), NIL )	
    METHOD EOF()							INLINE IF ( ::lOpen, (::cAlias)->( Eof() ), NIL )		
    METHOD Deleted()						INLINE IF ( ::lOpen, (::cAlias)->( Deleted() ), NIL )		
    METHOD Delete()						INLINE IF ( ::lOpen, (::cAlias)->( DbDelete() ), NIL )		
    METHOD Recall()						INLINE IF ( ::lOpen, (::cAlias)->( DbRecall() ), NIL )		
    METHOD Append()	
    METHOD Rlock()							
    METHOD Unlock()						INLINE IF ( ::lOpen, (::cAlias)->( DbUnlock() ), NIL )							
    METHOD Zap()							INLINE IF ( ::lOpen, (::cAlias)->( __DbZap() ), NIL )							
    METHOD Pack()							INLINE IF ( ::lOpen, (::cAlias)->( __DbPack() ), NIL )							
    


ENDCLASS

METHOD New( cDbf, cIndex, lOpen ) CLASS WDO_Dbf

	hb_default( @cDbf, '' )
	hb_default( @cIndex, '' )
	hb_default( @lOpen, .T. )
	
	::cPath 	:= ::cDefaultPath
	::cRdd 		:= ::cDefaultRdd	
	
	::cDbf		:= cDbf
	::cIndex	:= cIndex	

	IF lOpen .AND. !empty( ::cDbf )
	
		::Open()
	
	ENDIF	

RETU SELF


METHOD Open() CLASS WDO_Dbf

	LOCAL oError
	LOCAL cError 	 	:= ''
    LOCAL nIni  		:= 0
    LOCAL nLapsus  	:= ::nTime
    //LOCAL bError   	:= Errorblock({ |o| ErrorHandler(o) })	
    LOCAL bError   	:= Errorblock({ |o| Break(o) })	
	LOCAL cFileDbf 	:= ''
	LOCAL cFileCdx 	:= ''
	LOCAL lAutoOpen	:= Set( _SET_AUTOPEN, .F. )	//	SET AUTOPEN OFF

	::lConnect := .F.
	
	//	Check files...

		IF !empty( ::cDbf )
		
			cFileDbf := ::cPath + '/' + ::cDbf

			IF !File( cFileDbf )
			   ::SetError( 'Tabla de datos no existe: ' + ::cDbf )
			   RETU .F.
			ENDIF
			
		ELSE
		
			RETU .F.
			
		ENDIF
		
		IF !empty( ::cIndex ) 
		
			cFileCdx := ::cPath + '/' + ::cIndex

			IF !File( cFileCdx )
				::SetError( 'Indice de datos no existe: ' + ::cIndex )
				RETU .F.
			ENDIF
			
		ENDIF
		
	//	Open table dbf...
	
		nIni  		:= Seconds()
		

		BEGIN SEQUENCE

			 IF Empty( ::cAlias )
				::cAlias := ::NewAlias()
			 ENDIF
			 
			 

			  WHILE nLapsus >= 0

				 DbUseArea( .T., ::cRDD, cFileDbf, ::cAlias, ! ::lExclusive, ::lRead )
		
				 IF !Neterr() .OR. ( nLapsus == 0 )
					 EXIT
				 ENDIF


				 //SysWait( 0.1 )

				 nLapsus := ::nTime - ( Seconds() - nIni )

				 //SysRefresh()

			  END

		
			  IF NetErr()
				 ::SetError( 'Error de apertura de: ' + cFileDbf )
				ELSE
				 ::cAlias := Alias()
				 ::lOpen  := .t.
 				 
				 IF !empty( cFileCdx )
					SET INDEX TO (cFileCdx )			 			 
				 ENDIF
				 
			  ENDIF
			  
			  ::lConnect := .T.
	

		   RECOVER USING oError	

				cError += if( ValType( oError:SubSystem   ) == "C", oError:SubSystem, "???" ) 
				cError += if( ValType( oError:SubCode     ) == "N", " " + ltrim(str(oError:SubCode )), "/???" ) 
				cError += if( ValType( oError:Description ) == "C", " " + oError:Description, "" )		
			
				::SetError( cError )			

	   END SEQUENCE	
	
	   
	// Restore handler 		   

		ErrorBlock( bError )   
		Set( _SET_AUTOPEN, lAutoOpen )		
	
RETU ::lConnect

METHOD NewAlias() CLASS WDO_Dbf

    LOCAL n      	:= 0
    LOCAL cAlias	:= ''
	LOCAL cSeed 	:= 'ALIAS'

    cAlias  := cSeed + Ltrim(Str(n++))

    WHILE Select(cAlias) != 0
          cAlias := cSeed + Ltrim(Str(n++))
    END

RETU cAlias

METHOD Reset() CLASS WDO_Dbf

	::cAlias := ''
	::lOpen  := .f.
	
RETU NIL

METHOD Close() CLASS WDO_Dbf

    IF ::lOpen
       IF Select( ::cAlias ) > 0
         (::cAlias)->( DbCloseArea() )
       ENDIF
	   
	   ::Reset()	   	   
    ENDIF

RETU NIL





METHOD FieldPut( ncField, uValue ) CLASS WDO_Dbf

	LOCAL lUpdated := .F.
	LOCAL cField
	
	IF !::lOpen	
		RETU .F.
	ENDIF				
	

	If ValType( ncField ) == "C"

		//cField := ::FieldPos( ncField )
		cField := (::cAlias)->(FieldPos( ncField ) )
	ELSE

		cField := ncField 
	ENDIF				

	(::cAlias)->( FieldPut( cField, uValue ) )

	lUpdated := .T.

RETU lUpdated

METHOD Focus( cTag ) CLASS WDO_Dbf

	IF ::lOpen	
		( ::cAlias )->( OrdSetFocus( cTag ) )	
	ENDIF
	
RETU NIL

METHOD Seek( cSeek, lSoftSeek ) CLASS WDO_Dbf

	LOCAL lFound := .F.
	
	__defaultNIL( @lSoftSeek, .F. )	

	IF ! ::lOpen	
		RETU .F.
	ENDIF
	
	lFound 	:= (::cAlias)->( DbSeek( cSeek, lSoftSeek ) )

RETU lFound

METHOD Append() CLASS WDO_Dbf

    LOCAL nlapsus       := 0	
	LOCAL nIni

	IF ! ::lOpen	
		RETU .F.
	ENDIF	
	
	nIni := Seconds()
	
    WHILE nLapsus >= 0 

       (::cAlias)->( DbAppend() )

       IF !Neterr() .or. ( nLapsus == 0 )
           EXIT
       ENDIF

       nLapsus := ::nTime - ( seconds() - nIni )

    END		
	
RETU IF( !Neterr(), .t., .f. )

METHOD RLock( xIdentidad ) CLASS WDO_Dbf

    LOCAL nlapsus	:= 0
	LOCAL lRlock 	:= .F.
	LOCAL nIni
	
	IF ! ::lOpen	
		RETU .F.
	ENDIF	
	
	nIni := Seconds()
	
    WHILE nLapsus >= 0 

       lRlock := (::cAlias)->( DbRlock( xIdentidad ) )

       IF !Neterr() .or. ( nLapsus == 0 )
           EXIT
       ENDIF

       nLapsus := ::nTime - ( seconds() - nIni )

    END		
	
RETU lRlock

METHOD CountDeleted() CLASS WDO_Dbf

    LOCAL nTotal	:= 0	
	LOCAL lSet 	:= Set( _SET_DELETED, .F. )
	LOCAL nRecno  
	
	IF ! ::lOpen	
		RETU 0
	ENDIF	

	nRecno := (::cAlias)->( Recno() )


	(::cAlias)->( DbGoTop() )
	
	COUNT TO nTotal FOR (::cAlias)->( Deleted() )
	
	Set( _SET_DELETED, lSet )
	
	(::cAlias)->( DbGoTo( nRecno )) 
	
RETU nTotal



