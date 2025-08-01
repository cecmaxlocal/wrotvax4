/* Of course. Here is a complete and well-documented `web.yacc` file.

This example defines a parser for a simple web templating language, similar to Jinja2, Twig, or Liquid. This is a very common use case for parsers in web development.

### The Templating Language Syntax

Our parser will recognize the following constructs:
*   **Plain Text/HTML:** Any text that is not part of a special tag is treated as literal content.
*   **Variable Output:** `{{ user.name }}` - Prints the value of a variable.
*   **Comments:** `{# This is a comment #}` - Ignored by the parser.
*   **If/Else Block:** `{% if user.isAdmin %}` ... `{% else %}` ... `{% endif %}`
*   **For Loop Block:** `{% for item in items %}` ... `{% endfor %}`

---

### `web.yacc` (The Parser Grammar)

This file defines the grammatical structure of our templating language. It uses the tokens provided by the lexer (`web.l`) to build up a parse tree. In this example, instead of building a complex Abstract Syntax Tree (AST), the parser actions will simply print a description of the structure it recognizes.

```yacc */
/* web.yacc - A Yacc parser for a simple web templating language */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Forward declarations for functions provided by the lexer (web.l) */
int yylex();
extern int yylineno;
extern char* yytext;

/* The error reporting function required by Yacc */
void yyerror(const char *s);

/* A helper function to create a node in our "AST" (for demonstration) */
char* make_node(const char* type, const char* val1, const char* val2);

%}

/* 
 * The %union declaration defines all the possible data types that a
 * token or a non-terminal symbol can hold. In our simple language,
 * almost everything is a string.
 */
%union {
    char *str;
}

/* 
 * %token declarations: These are the terminal symbols (tokens) that our 
 * lexer will provide. We assign the 'str' type from the union to tokens 
 * that carry a string value (like an identifier or raw text).
 */
%token <str> TEXT          /* Raw text or HTML content */
%token <str> IDENTIFIER    /* A variable name, e.g., 'user', 'items' */

/* Delimiters */
%token L_VAR               /* {{ */
%token R_VAR               /* }} */
%token L_BLOCK             /* {% */
%token R_BLOCK             /* %} */
%token L_COMMENT           /* {# */
%token R_COMMENT           /* #} */

/* Keywords */
%token IF
%token ELSE
%token ENDIF
%token FOR
%token IN
%token ENDFOR

/* Operators */
%token DOT                 /* . for member access, e.g., user.name */

/* 
 * %type declarations: These associate a data type from the %union with
 * a non-terminal symbol (a grammar rule). This allows rules to have values.
 */
%type <str> statement
%type <str> variable_node
%type <str> if_node
%type <str> for_node
%type <str> expression
%type <str> identifier_path

/* The start symbol of our grammar */
%start template

%%
/* --------- GRAMMAR RULES --------- */

/* A template is a sequence of statements. This is a classic left-recursive
   rule for defining a list of items. */
template:
    /* A template can be empty */
    | template statement 
    ;

/* A statement can be raw text, a variable output, a control block, or a comment. */
statement:
    TEXT { 
        printf("TEXT: \"%s\"\n", $1); 
        free($1); 
    }
    | variable_node
    | if_node
    | for_node
    | L_COMMENT TEXT R_COMMENT { /* Simple comment handling */
        printf("COMMENT: %s\n", $2);
        free($2);
    }
    ;

/* Rule for variable output: {{ expression }} */
variable_node:
    L_VAR expression R_VAR {
        char* node = make_node("PRINT", $2, NULL);
        printf("NODE: %s\n", node);
        free(node);
        free($2);
    }
    ;
    
/* Rule for an if/else/endif block */
if_node:
    L_BLOCK IF expression R_BLOCK template L_BLOCK ENDIF R_BLOCK {
        char* node = make_node("IF", $3, NULL);
        printf("NODE: %s\n", node);
        /* In a real compiler, the 'template' part would be the 'then' block */
        printf("END_IF\n");
        free(node);
        free($3);
    }
    | L_BLOCK IF expression R_BLOCK template L_BLOCK ELSE R_BLOCK template L_BLOCK ENDIF R_BLOCK {
        char* node = make_node("IF-ELSE", $3, NULL);
        printf("NODE: %s\n", node);
        /* 'template' at $5 is the 'then' block, 'template' at $9 is the 'else' block */
        printf("END_IF\n");
        free(node);
        free($3);
    }
    ;

/* Rule for a for loop: {% for item in items %} ... {% endfor %} */
for_node:
    L_BLOCK FOR IDENTIFIER IN identifier_path R_BLOCK template L_BLOCK ENDFOR R_BLOCK {
        char* node = make_node("FOR", $3, $5);
        printf("NODE: %s (loop var: %s, collection: %s)\n", node, $3, $5);
        printf("END_FOR\n");
        free(node);
        free($3);
        free($5);
    }
    ;

/* An expression is currently just an identifier path */
expression:
    identifier_path { $$ = $1; /* Pass the value up */ }
    ;

/* An identifier path can be a single ID or a chain of them separated by dots */
identifier_path:
    IDENTIFIER { $$ = $1; /* Base case: just one identifier */ }
    | identifier_path DOT IDENTIFIER {
        /* Concatenate strings to form "parent.child" */
        /* +2 for the dot and null terminator */
        char *result = malloc(strlen($1) + strlen($3) + 2);
        sprintf(result, "%s.%s", $1, $3);
        free($1);
        free($3);
        $$ = result;
    }
    ;

%%
/* --------- ADDITIONAL C CODE --------- */

/* 
 * The main function. It's the entry point of our parser application.
 * It opens the input file (if provided) and calls yyparse().
 */
int main(int argc, char **argv) {
    extern FILE *yyin;
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (!yyin) {
            perror(argv[1]);
            return 1;
        }
    }
    
    printf("--- Starting Parse ---\n");
    int result = yyparse();
    printf("--- Parse Finished ---\n");
    
    if (argc > 1) {
        fclose(yyin);
    }
    
    return result;
}

/* 
 * The error reporting function. Yacc calls this function whenever it
 * encounters a syntax error.
 */
void yyerror(const char *s) {
    fprintf(stderr, "Parse Error on line %d: %s near '%s'\n", yylineno, s, yytext);
}

/* Helper function for demonstration */
char* make_node(const char* type, const char* val1, const char* val2) {
    int size = strlen(type) + (val1 ? strlen(val1) : 0) + (val2 ? strlen(val2) : 0) + 16;
    char *buf = malloc(size);
    if (val2) {
        sprintf(buf, "TYPE=%s, VAL1=%s, VAL2=%s", type, val1, val2);
    } else if (val1) {
        sprintf(buf, "TYPE=%s, VAL=%s", type, val1);
    } else {
        sprintf(buf, "TYPE=%s", type);
    }
    return buf;
}
/* ```

### Next Steps

To make this a runnable program, you need three more things:

1.  **A Lexer (`web.l`):** This file is responsible for reading the input and breaking it into the `tokens` that `web.yacc` expects. I will provide this for you if you ask.
2.  **Compilation:** You need to use `bison` (the GNU version of Yacc) and `flex` (the GNU version of Lex) to compile these files.
3.  **An Input File:** A sample template file to test your parser.

Here is a quick look at what the corresponding `web.l` lexer file would look like:

```lex */
/* web.l - A Flex lexer for the simple web templating language */
%{
#include "web.tab.h" // Header generated by Bison
#include <string.h>

/* We need to define yyerror here if we link lexer and parser separately */
// void yyerror(const char *s); 
%}

/* Options */
%option noyywrap
%option yylineno

/* Regular Expression Definitions */
ID    [a-zA-Z_][a-zA-Z0-9_]*

%%

"{{%s*"          { return L_VAR; }
"%s*}}"          { return R_VAR; }

"{%s*"          { return L_BLOCK; }
"%s*%}"          { return R_BLOCK; }

"{#s*"          { return L_COMMENT; }
"%s*#}"          { return R_COMMENT; }

"if"            { return IF; }
"else"          { return ELSE; }
"endif"         { return ENDIF; }
"for"           { return FOR; }
"in"            { return IN; }
"endfor"        { return ENDFOR; }

"."             { return DOT; }

{ID}            { yylval.str = strdup(yytext); return IDENTIFIER; }

[ \t\r\n]+      { /* Ignore whitespace between tokens inside blocks */ }

[^\{\}]+        { yylval.str = strdup(yytext); return TEXT; }

.               { /* Catch-all for any other character - might be part of TEXT */
                  yylval.str = strdup(yytext); return TEXT; 
                }

%%
/* ```
**Note:** A more robust lexer would use start conditions to differentiate between parsing inside a `{{...}}` block and parsing plain text outside, which can make the `TEXT` rule much simpler and more reliable. The version above is a common and straightforward approach. */