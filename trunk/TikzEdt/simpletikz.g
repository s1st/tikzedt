grammar simpletikz;

options 
{
	output=AST;
	language = 'CSharp2';
	//backtrack=true;
}


tokens {
	BEGIN	 	= '\\begin';	//todooooo
	END 		= '\\end';    //todooooo
	//BEGINTP	 	= '\\begin{tikzpicture}';
	//ENDTP 		= '\\end{tikzpicture}';
	//BEGINSCOPE	= '\\begin{scope}';
	//ENDSCOPE 	= '\\end{scope}';
	//TIKZPICTURE	= 'tikzpicture';	
	//SCOPE		= 'scope';
	
	USETIKZLIB	= '\\usetikzlibrary';
	TIKZSTYLE	= '\\tikzstyle';
	TIKZSET		= '\\tikzset';
	NODE		= '\\node';
	DRAW		= '\\draw';
	PATH		= '\\path';
	FILL		= '\\fill';
	CLIP		= '\\clip';
	LPAR		= '(';
	RPAR		= ')';
	LBR		= '[';
	RBR		= ']';
	LBRR		= '{';
	RBRR		= '}';
	KOMMA		= ',';
	//SCALE		= 'scale';
	EQU		= '=';
	SEMIC		= ';';
	COLON		= ':';
	//BACKSLASH	= '\\'; // blame antlr
	//STYLESEP	= '/.style';
	//AT		= 'at';
	//LABEL		= 'label';
	//EVERYLOOP	= 'every loop';
	
	// styles
	//ST_INNERSEP	= 'inner sep';
	//ST_OUTERSEP	= 'outer sep';
	//ST_FILL		= 'fill';
	//ST_DRAW		= 'draw';
	//ST_SHAPE	= 'shape';
	//ST_MINSIZE	= 'minimum size';
	//ST_LINEWIDTH	= 'line width';
	//ST_DASHSTYLE	= 'dash style';
	
	// edge option
	//LOOP		= 'loop';
	//IN		= 'in';
	//OUT		= 'out';
	
	// units
	//UN_PTS		= 'pt';
	//UN_CM		= 'cm';
//	UN_IN		= 'in';

// imaginary
IM_PATH;
IM_NODE;
IM_COORD;
IM_SIZE;
IM_NODENAME;
IM_NUMBERUNIT;
IM_PICTURE;
IM_DOCUMENT;
IM_SCOPE;
IM_STARTTAG;
IM_ENDTAG;
IM_OPTIONS;
IM_OPTION_STYLE;
IM_OPTION_KV; 	// key or key value pair
IM_ID;
IM_TIKZSET;
IM_USETIKZLIB;
IM_STRING;
IM_STYLE;
IM_TIKZEDT_CMD;
}

tikzdocument
	:	tikz_cmd_comment* (dontcare_preamble | tikz_styleorset | otherbegin)*  tikzpicture .*	-> ^(IM_DOCUMENT tikz_styleorset* tikzpicture)
	;
	
tikz_cmd_comment
	:	TIKZEDT_CMD_COMMENT  	 -> ^(IM_TIKZEDT_CMD TIKZEDT_CMD_COMMENT)
	;

tikz_styleorset
	:	tikz_style | tikz_set
	;

dontcare_preamble
	:	~(BEGIN | TIKZSTYLE | TIKZSET | TIKZEDT_CMD_COMMENT)
	;
otherbegin
	:	BEGIN LBRR idd RBRR
	;

tikz_style
	:	TIKZSTYLE LBRR idd RBRR '=' tikz_options -> ^(IM_STYLE idd tikz_options)
	;

tikz_options
	: 	squarebr_start (option (',' option)* ','?)? squarebr_end		-> ^(IM_OPTIONS squarebr_start option* squarebr_end)
	;

option
	:	option_style 		
		| option_kv		
	;
	
option_kv
	:	idd ('=' iddornumberunitorstring )? -> ^(IM_OPTION_KV idd iddornumberunitorstring?)  
	;
	
tikzstring
	:	LBRR no_rlbrace* (tikzstring no_rlbrace*)* RBRR -> ^(IM_STRING LBRR RBRR ) //todo
	;

no_rlbrace
	:	~(LBRR | RBRR)
	;
iddornumberunitorstring
	:	idd | numberunit | tikzstring
	;
option_style
	:	idd '/.style' '=' LBRR (option_kv (',' option_kv)*)?  ','? RBRR  -> ^(IM_OPTION_STYLE idd option_kv*)  // '{' option '}' todo: optional ,
	;


	
// id composed of more than one word
//edgeop contains all those word. => use edgeop here, too
//also possible with number, e.g. level 2
idd
	:	edgeop (edgeop)*	-> ^(IM_ID edgeop*)
	|	edgeop INT		-> ^(IM_ID edgeop INT)
	;
	
		
	
numberunit
	:	number unit? -> ^(IM_NUMBERUNIT number unit?) /// check
	;
	
//float exponent interfers with units starting with 'e'
number
	:	(FLOAT_WO_EXP | INT)
	;	
	
unit
	:	 'cm' | 'in' | 'ex' | 'mm' | 'pt' | 'em'
	;
			
tikz_set
	:	 tikz_set_start (option (',' option)*)? roundbr_end -> ^(IM_TIKZSET tikz_set_start option* roundbr_end)
	;

// *** Things that go within the picture ****

tikzpicture 
	:	 tikzpicture_start tikz_options? tikzbody? tikzpicture_end		-> ^(IM_PICTURE tikzpicture_start tikz_options? tikzbody? tikzpicture_end)
	;

tikzbody
	:	( tikzscope | tikzpath | tikznode_ext | dontcare_body_nobr! | tikz_set | tikz_style | otherbegin! |otherend! )  // necessary to prevent conflict with options
		( tikzscope | tikzpath | tikznode_ext | dontcare_body! | tikz_set | tikz_style | otherbegin! |otherend! )*
	;
	
dontcare_body_nobr
	:	(~ (BEGIN | END | NODE | DRAW | PATH | FILL | CLIP | TIKZSTYLE | TIKZSET | LBR))	// necessary to prevent conflict with options
	;	
dontcare_body
	:	(~ (BEGIN | END | NODE | DRAW | PATH | FILL | CLIP | TIKZSTYLE | TIKZSET ))   
	;
otherend
	:	END '{' idd '}'
	;
	
	
// circle and ellipse seem to be the same command

	
//tikzpathi, e.g. (6,2) node[ext] {ddd} -- (6,0) node[ext] {ddd} -> (5,5) circle (3);
//tikzpathi
//	: coordornode_new (edgeop! coordornode_new)*
//	;
//this construct does not work. why?
//	 coordornode (coordornode | tikz_options? edgeop! coordornode )* 
		
tikzscope
	:	tikzscope_start tikz_options? tikzbody? tikzscope_end		-> ^(IM_SCOPE tikzscope_start tikz_options? tikzbody tikzscope_end)
	;

//for "circle" we need size instead of a coordinate
//coordornode
//	:	coord | size | tikznode
//	;
	
	
//coordinates can look like this: (6,2) node[ext] {ddd}
//coordinates are connect e.g. by --, ->, rectangle, circle
//after "circle" the next coordinate is usually just a size.
//coordornode_new
//	:	coord (ID (nodetype)? (tikzstring)?)?		-> ^(coord)
//	|	size
//	;
	




//tikznodee
//	:	node_start tikznode tikzpathi? semicolon_end -> ^(IM_PATH node_start tikznode tikzpathi? semicolon_end) //almost hack like this
//	;
	
// ****** The path commands ********
tikzpath 
	:	path_start tikzpath_element* semicolon_end	-> ^(IM_PATH path_start tikzpath_element* semicolon_end )
	;

tikzpath_element
	:
		  tikz_options 
		| coord
		| tikznode_int
		| circle!
		| arc!
		| LBRR tikzpath_element* RBRR
		| edgeop!
	;
tikznode_ext
	:	node_start tikznode_core tikzpath_element* semicolon_end	-> ^(IM_PATH node_start tikznode_core tikzpath_element* semicolon_end)
	;
tikznode_int
	:	'node'! tikznode_core
	;
tikznode_core
	:	tikznode_decorator* tikzstring		-> ^(IM_NODE tikznode_decorator* tikzstring)
	;
//tikznode
//	:	nodename? ('at' coord)? tikz_options* 			
//	;
tikznode_decorator
	:	  nodename 
		| 'at'! coord
		| tikz_options_dontcare
	;
tikz_options_dontcare
	:	LBR no_rlbracket* (tikz_options_dontcare no_rlbracket*)* RBR -> ^(IM_OPTIONS ) //todo
	;
no_rlbracket
	:	~(LBR | RBR)
	;
nodename
	:	LPAR idd RPAR		-> ^(IM_NODENAME idd)
	;
	
circle
	:	('circle' | 'ellipse') size?	->	// note: options not allowed in between
	;
arc
	:	'arc' (LPAR numberunit ':' numberunit ':' numberunit RPAR)? ->
	;
	
	size
	:	  LPAR numberunit ('and' numberunit)? RPAR		-> ^(IM_SIZE numberunit)
	;
//Is this needed?
//-> ^(IM_COORD[$lc] coord_modifier? numberunit)
	
	
coord	
	:	  nodename 								-> ^(IM_COORD nodename)
		| ( coord_modifier? LPAR numberunit coord_sep numberunit RPAR)		-> ^(IM_COORD coord_modifier? numberunit+ coord_sep)
	;
coord_sep
	:	( ',' | ':' )	
	;

//these operators depend on used packets. => all all strings.	
edgeop	
	:	'--' | '->' | '|-' | '-|' | ID
	;	
//	:	'--' | 'edge' | '->' | '|-' | '-|' | 'to' | 'grid' | 'rectangle'

coord_modifier
	:	'+' | '++'
	;
	
/*


path_end
	:	SEMIC -> ^(IM_ENDTAG SEMIC)
	;



//tikz_something
//	:	( ID | '\\' ID)+  -> 
//	;



//documentclass
//	:	'\\documentclass' ('[' (~ ']')* ']')? '{' (~'}')*  '}'
//	;


	
usetikzlib
	:	usetikzlib_start idd (',' idd)* roundbr_end -> ^(IM_USETIKZLIB usetikzlib_start idd* roundbr_end)
	;
usetikzlib_start
	:	USETIKZLIB '{' -> ^(IM_STARTTAG USETIKZLIB) // todo: check if necessary ...
	;



tikzstring
	:	'{'  (tikzstring | MATHSTRING | ID)* '}' -> ^(IM_STRING '{' '}' ) //todo
	;
*/
//tikzbody2
//	:	'hallo'
//	;

// ***** start and end tags *****
squarebr_start
	:	LBR -> ^(IM_STARTTAG LBR)
	;
squarebr_end
	:	RBR -> ^(IM_ENDTAG RBR)
	;	
semicolon_end
	:	';'	-> ^(IM_ENDTAG ';')
	;
roundbr_end
	:	'}'	-> ^(IM_ENDTAG '}')
	;
tikz_set_start
	:	TIKZSET '{'		-> ^(IM_STARTTAG ) // todo: check if suffices
	;
tikzpicture_start
	:	BEGIN '{' 'tikzpicture' '}' -> ^(IM_STARTTAG BEGIN)
	;
tikzpicture_end
	:	END '{' 'tikzpicture' '}' -> ^(IM_ENDTAG END)
	;
tikzscope_start
	:	BEGIN '{' 'scope' '}' -> ^(IM_STARTTAG BEGIN)
	;
tikzscope_end
	:	END '{' 'scope' '}' -> ^(IM_ENDTAG END)
	;
path_start 
	:	path_start_tag -> ^(IM_STARTTAG path_start_tag)
	;
node_start
	:	NODE -> ^(IM_STARTTAG NODE)
	;
path_start_tag
	:	DRAW | FILL | PATH | CLIP
	;

ID  :	('a'..'z'|'A'..'Z'|'_') ('a'..'z'|'A'..'Z'|'0'..'9'|'_'|'.'|'!')*
    ;

INT :	'-'? '0'..'9'+
    ;

//float's exponent interfers with units starting with 'e'.
//FLOAT
//    :   '-'? ('0'..'9')+ '.' ('0'..'9')* EXPONENT?
//    |   '-'? '.' ('0'..'9')+ EXPONENT?
//    |   '-'? ('0'..'9')+ EXPONENT
//    |   '-'? '.' ('0'..'9')+
//    ;

FLOAT_WO_EXP    
    :   '-'? ('0'..'9')+ '.' ('0'..'9')* 
    |   '-'? '.' ('0'..'9')+
    ;
    
TIKZEDT_CMD_COMMENT
    :   '%' WS '!TIKZEDT'   ~('\n'|'\r')* '\r'? '\n'
    ;

COMMENT
    :   '%' ~('\n'|'\r')* '\r'? '\n' {$channel=HIDDEN;}
    ;

WS  :   ( ' '
        | '\t'
        | '\r'
        | '\n'
        ) {$channel=HIDDEN;}
    ;

fragment EXPONENT : ('e'|'E') ('+'|'-')? ('0'..'9')+ ;


//OPTIONS :	'[' ~(']')* ']';

//STRING	:	'{' ( ESC_SEQ | ~('\\' | '}') )* '}';   /// not correct like this
MATHSTRING 
	:	'$' ( ESC_SEQ | ~('\\' | '$') )* '$';
//STRING
//    :  '"' ( ESC_SEQ | ~('\\'|'"') )* '"'
//    ;

//CHAR:  '\'' ( ESC_SEQ | ~('\''|'\\') ) '\''
//    ;



COMMAND
	: '\\' ID
	;
	
//fragment // this is a hack	
ESC_SEQ
    :   '\\' .   // ( |'\"'|'\''|'\\')
    ;



SOMETHING 
	:	. ;