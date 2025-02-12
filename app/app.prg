#define VK_ESCAPE	27

REQUEST QQOUT 

REQUEST WDO_DBF
REQUEST WDO_MYSQL

#ifdef __PLATFORM__WINDOWS
    REQUEST WDO_SQLITE3
#endif

request DBFCDX
request HB_RandomInt

function main()

	hb_threadStart( @WebServer() )	
	
	while inkey(0) != VK_ESCAPE
	end

retu nil 

//----------------------------------------------------------------------------//

function WebServer()

	local oServer 	:= Httpd2()
	
	
	//HB_SetEnv( 'WDO_PATH_MYSQL', "c:/xampp.64/htdocs/" )
	HB_SetEnv( 'WDO_PATH_MYSQL', "c:/xampp/htdocs/" )
	
	oServer:SetPort( 81 )
	oServer:SetDirFiles( 'data' )
	oServer:SetDirFiles( 'data/sales/images' )
	oServer:SetDirFiles( 'samples', .T. )		//	.t. == Index list
	
	//	Routing...			

		oServer:Route( '/'		, 'samples/*' )  												
		
	//	-----------------------------------------------------------------------//	
	
	IF ! oServer:Run()
	
		? "=> Server error:", oServer:cError

		RETU 1
	ENDIF
	
RETURN 0

//----------------------------------------------------------------------------//