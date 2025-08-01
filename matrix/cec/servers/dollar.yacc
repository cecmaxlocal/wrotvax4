/* Of course. Here is a complete `servers.yacc` (or `servers.y` for Bison) file that defines a parser for a simple server configuration language.

This grammar specifically incorporates the **dollar** sign (`$`) as part of a `cost` definition, which is a common use case in configuration files. It also uses the standard Yacc/Bison `$` variables (`$1`, `$2`, `$$`, etc.) in its actions.

### The Configuration Language

First, let's define the simple language we want to parse. It will define a list of servers, each with properties like IP, port, memory, and a cost.

**Example `config.txt`:**

``` */
/* # Production web server
server "web-prod-01" {
    ip: "192.168.1.10"
    port: 80
    memory: "16GB"
    cost: $150.50 / month
    tags: ["production", "web", "apache"]
}

# Staging database server
server "db-stage-01" {
    ip: "10.0.5.25"
    port: 5432
    cpu_cores: 8
    cost: $499.00 / month
    tags: ["staging", "database"]
}
```

### `servers.y` (The Yacc/Bison file)

This file defines the grammar rules for the language above.

```yacc */
/* ------------------------------------------------------------------ */
/* -- SECTION 1: C Declarations and Bison/Yacc Directives            -- */
/* ------------------------------------------------------------------ */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* External function prototypes. These are supplied by the lexer. */
int yylex(void);
int yyerror(const char *s);

/* The lexer needs to track line numbers for error reporting. */
extern int yylineno;

%}

/* 
 * The %union directive defines the set of all possible data types for
 * semantic values (both tokens and non-terminal symbols).
 */
%union {
    int ival;
    double fval;
    char *sval;
}

/* 
 * Token Declarations
 * We associate tokens with their data types from the union.
 * For example, an INTEGER token will have its value in the 'ival' field.
 * A STRING token will have its value in the 'sval' field.
 */
%token <sval> STRING
%token <ival> INTEGER
%token <fval> FLOAT_NUM

/* Keywords */
%token SERVER IP PORT CPU_CORES MEMORY COST TAGS

/* Punctuation (no associated value needed) */
%token LBRACE RBRACE LBRACK RBRACK COLON COMMA SLASH DOLLAR

/* 
 * Type Declarations for Non-Terminals
 * This is not strictly necessary for this simple example where we print
 * immediately, but it's good practice for type checking.
 */
%type <sval> string_literal

/* Define the start symbol of the grammar */
%start config_file


%%
/* ------------------------------------------------------------------ */
/* -- SECTION 2: Grammar Rules and Actions                         -- */
/* ------------------------------------------------------------------ */

/* The top-level rule: a file can be empty or contain a list of servers. */
config_file:
    /* empty */
    | server_list
    ;

/* A list of one or more server definitions. */
server_list:
      server_definition
    | server_list server_definition
    ;

/* A single server definition. */
server_definition:
    SERVER string_literal LBRACE property_list RBRACE
    {
        printf("Parsed Server: %s\n{\n", $2);
        /* The action for property_list will have already printed the properties. */
        printf("}\n\n");
        free($2); /* Free the memory allocated by the lexer for the server name */
    }
    ;

/* A list of one or more properties inside the curly braces. */
property_list:
      property
    | property_list property
    ;

/* The different kinds of properties a server can have. */
property:
    IP COLON string_literal
    {
        printf("\t- IP Address: %s\n", $3);
        free($3);
    }
    | PORT COLON INTEGER
    {
        printf("\t- Port: %d\n", $3);
    }
    | CPU_CORES COLON INTEGER
    {
        printf("\t- CPU Cores: %d\n", $3);
    }
    | MEMORY COLON string_literal
    {
        printf("\t- Memory: %s\n", $3);
        free($3);
    }
    | COST COLON DOLLAR FLOAT_NUM SLASH string_literal
    {
        /* This is the rule that handles the dollar sign. */
        /* $1   $2   $3     $4         $5    $6             */
        /* COST COLON DOLLAR FLOAT_NUM SLASH string_literal */
        printf("\t- Cost: $%.2f / %s\n", $4, $6);
        free($6);
    }
    | TAGS COLON LBRACK string_list RBRACK
    {
        /* The actions for string_list have already printed the tags. */
    }
    ;

/* A helper rule to handle quoted strings. */
string_literal:
    STRING
    {
        $$ = $1; /* Pass the string value up the parse tree. */
    }
    ;

/* A comma-separated list of strings for the 'tags' property. */
string_list:
    string_literal
    {
        printf("\t- Tag: %s\n", $1);
        free($1);
    }
    | string_list COMMA string_literal
    {
        printf("\t- Tag: %s\n", $3);
        free($3);
    }
    ;

%%
/* ------------------------------------------------------------------ */
/* -- SECTION 3: C Code (Supporting Functions)                     -- */
/* ------------------------------------------------------------------ */

/* The main function to drive the parser. */
int main(int argc, char **argv) {
    /* If a filename is provided, read from it. Otherwise, read from stdin. */
    if (argc > 1) {
        FILE *file = fopen(argv[1], "r");
        if (!file) {
            perror(argv[1]);
            return 1;
        }
        /* Direct yyin (the lexer's input stream) to the file. */
        extern FILE *yyin;
        yyin = file;
    }

    /* Start the parsing process. */
    if (yyparse() != 0) {
        fprintf(stderr, "Parsing failed.\n");
        return 1;
    }

    printf("Parsing completed successfully.\n");
    return 0;
}

/* The error reporting function. Bison calls this when a syntax error is found. */
int yyerror(const char *s) {
    fprintf(stderr, "Parse Error on line %d: %s\n", yylineno, s);
    return 0;
}
```

### How to Compile and Run

To make this work, you need a companion Lex/Flex file (`servers.lex`) to handle tokenization.

1.  **Create `servers.lex` (the Lexer):**
    This file will recognize the patterns (keywords, numbers, strings, etc.) and return the corresponding tokens to the parser.

    ```lex
    %{
    #include "servers.y.h" // Header generated by Bison with token definitions
    #include <string.h>

    // A helper function to handle string literals by removing the quotes.
    void process_string() {
        // yylval is the global variable for passing values to the parser.
        // The .sval field matches our %union declaration in the .y file.
        // strdup allocates new memory for the string.
        yylval.sval = strdup(yytext + 1); // Skip the first quote
        yylval.sval[strlen(yylval.sval) - 1] = '\0'; // Remove the last quote
    }
    %}

    /* Options */
    %option noyywrap
    %option yylineno

    /* Regular Expression Definitions */
    DIGIT       [0-9]
    ID          [a-zA-Z_][a-zA-Z0-9_-]*
    FLOAT       {DIGIT}+\.{DIGIT}*

    %%

    "server"        { return SERVER; }
    "ip"            { return IP; }
    "port"          { return PORT; }
    "cpu_cores"     { return CPU_CORES; }
    "memory"        { return MEMORY; }
    "cost"          { return COST; }
    "tags"          { return TAGS; }
    "month"         { /* We need to handle this as part of a string literal. */
                      yylval.sval = strdup(yytext);
                      return STRING;
                    }

    {DIGIT}+        { yylval.ival = atoi(yytext); return INTEGER; }
    {FLOAT}         { yylval.fval = atof(yytext); return FLOAT_NUM; }

    "\""[^\"]*"\""  { process_string(); return STRING; }
    
    "{"             { return LBRACE; }
    "}"             { return RBRACE; }
    "["             { return LBRACK; }
    "]"             { return RBRACK; }
    ":"             { return COLON; }
    ","             { return COMMA; }
    "/"             { return SLASH; }
    "$"             { return DOLLAR; }

    [ \t\r]+        { /* Ignore whitespace */ }
    \n              { /* Ignore newlines (or count them if you wish) */ }
    #.*\n           { /* Ignore comments */ }

    .               { fprintf(stderr, "Lex Error: Unexpected character '%c' on line %d\n", *yytext, yylineno); }

    %%
    /* ```

2.  **Compile the code:**
    You'll need `bison` (the GNU version of Yacc) and `flex` (the GNU version of Lex).

    ```bash
    # 1. Use bison to generate the C parser and a header file for the tokens.
    # The -d flag creates the servers.y.h header file.
    bison -d servers.y

    # 2. Use flex to generate the C lexer.
    flex servers.lex

    # 3. Compile the generated C files with a C compiler (like gcc).
    #    lex.yy.c is the lexer, servers.y.c is the parser.
    gcc -o server_parser lex.yy.c servers.y.c -lfl

    # The -lfl flag is needed by some versions of flex.
    ```

3.  **Run the parser:**
    Create the `config.txt` file from the example above and run your compiled parser on it.

    ```bash
    ./server_parser config.txt
    ```

4.  **Expected Output:**

    ```
    Parsed Server: web-prod-01
    {
        - IP Address: 192.168.1.10
        - Port: 80
        - Memory: 16GB
        - Cost: $150.50 / month
        - Tag: production
        - Tag: web
        - Tag: apache
    }

    Parsed Server: db-stage-01
    {
        - IP Address: 10.0.5.25
        - Port: 5432
        - CPU Cores: 8
        - Cost: $499.00 / month
        - Tag: staging
        - Tag: database
    }

    Parsing completed successfully.
    ``` */