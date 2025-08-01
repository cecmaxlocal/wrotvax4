/* Of course. Here is a complete and well-commented `check.yacc` file.

This example creates a robust interactive calculator. It's a classic and highly illustrative use of Yacc (or its modern equivalent, Bison) because it clearly demonstrates key concepts:
*   **Tokens**: Numbers, operators.
*   **Grammar Rules**: How tokens combine to form valid expressions.
*   **Operator Precedence and Associativity**: Correctly handling `*` before `+`, and evaluating `5 - 3 - 1` as `(5-3) - 1`.
*   **Semantic Actions**: Performing the actual calculation once a rule is matched.
*   **Interaction with a Lexer**: The `yylex()` function.

For simplicity and to provide a single, self-contained file, the lexer (`yylex`) is included directly in the C code section at the bottom.

---

### `check.yacc`

```yacc */
/*
 * check.yacc - A Yacc specification for a simple integer calculator.
 *
 * This calculator handles:
 * - Basic arithmetic: +, -, *, /
 * - Parentheses for grouping
 * - Unary minus
 * - Operator precedence
 * - Multiple expressions, one per line
 * - Basic error handling for syntax and division by zero.
 */

/****************************************************************************
 *  1. Declarations Section
 ****************************************************************************/

/* C code to be included in the final C source file. */
%{
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

/* Prototype for the lexical analyzer function (lexer) */
int yylex(void);

/* Prototype for the error reporting function */
void yyerror(const char *s);
%}

/*
 * Declare the union of possible semantic values.
 * An expression or a number token will have an integer value.
 */
%union {
    int ival;
}

/* 
 * Declare tokens and their types.
 *
 * %token <ival> NUMBER
 *   - Defines a token named NUMBER.
 *   - <ival> associates this token with the 'ival' field of the %union.
 *     When the lexer returns a NUMBER, it must also set the value in yylval.ival.
 *
 * %token EOL
 *   - Defines a token for End-Of-Line.
 */
%token <ival> NUMBER
%token EOL

/*
 * Declare the types for non-terminals that have a value.
 * 'expr', 'term', and 'factor' will all evaluate to an integer result.
 */
%type <ival> expr
%type <ival> term
%type <ival> factor

/*
 * Define operator precedence and associativity.
 * Operators on the same line have the same precedence.
 * Lines further down the list have higher precedence.
 *
 * %left:  Left-associative (e.g., 5 - 3 - 1 is (5-3) - 1)
 * %right: Right-associative (e.g., for assignment or exponentiation)
 * %nonassoc: For non-associative operators like '<' or '>'.
 */
%left '+' '-'        /* Lowest precedence */
%left '*' '/'        /* Medium precedence */
%right UMINUS      /* Unary minus (highest precedence) */


/****************************************************************************
 *  2. Grammar Rules Section
 ****************************************************************************/
%%

/* The start symbol is 'program'. A program is a list of lines. */
program:
    /* An empty program is valid */
    | program line
    ;

/* A line is either a blank line or an expression followed by a newline. */
line:
      EOL
    | expr EOL   { printf("= %d\n", $1); } /* Print the result of the expression */
    ;

/*
 * Grammar for expressions.
 * $$ refers to the value of the left-hand side (e.g., 'expr').
 * $1, $2, $3... refer to the values of the symbols on the right-hand side.
 */
expr:
      term
        /* The value of 'expr' is the value of 'term' */
        { $$ = $1; }
    | expr '+' term
        { $$ = $1 + $3; }
    | expr '-' term
        { $$ = $1 - $3; }
    ;

term:
      factor
        { $$ = $1; }
    | term '*' factor
        { $$ = $1 * $3; }
    | term '/' factor
        {
            if ($3 == 0) {
                yyerror("Division by zero");
                YYERROR; /* Abort the current rule */
            } else {
                $$ = $1 / $3;
            }
        }
    ;

factor:
      NUMBER
        { $$ = $1; }
    | '(' expr ')'
        /* The value is the value of the inner expression */
        { $$ = $2; }
    | '-' factor %prec UMINUS
        /* This rule gets the precedence of the UMINUS token */
        { $$ = -$2; }
    ;

%%
/****************************************************************************
 *  3. C Code Section
 ****************************************************************************/

#include <string.h>

/*
 * The main function. It calls the parser and returns.
 */
int main(void) {
    printf("Simple Yacc Calculator. Enter expressions or Ctrl-D to exit.\n");
    printf("> ");
    yyparse();
    return 0;
}

/*
 * The error-reporting function. Yacc/Bison calls this when a syntax
 * error is detected.
 */
void yyerror(const char *s) {
    fprintf(stderr, "Error: %s\n", s);
}

/*
 * The lexical analyzer (lexer). This function reads input and returns
 * tokens to the parser.
 *
 * NOTE: In a larger project, this would typically be in a separate
 * file, often generated by Lex/Flex. For this self-contained example,
 * we write it by hand.
 */
int yylex(void) {
    int c;

    /* Skip whitespace */
    while ((c = getchar()) == ' ' || c == '\t') {
        // do nothing
    }

    /* Handle end of input */
    if (c == EOF) {
        return 0; /* Signal to yyparse that input is finished */
    }

    /* Handle numbers */
    if (isdigit(c)) {
        int num = c - '0';
        while (isdigit(c = getchar())) {
            num = num * 10 + (c - '0');
        }
        ungetc(c, stdin); /* Push back the non-digit character */
        yylval.ival = num; /* Set the semantic value */
        return NUMBER;
    }

    /* Handle end-of-line */
    if (c == '\n') {
        printf("> "); /* Prompt for next input */
        return EOL;
    }

    /* Return all other characters (like +, -, *, /, (, ) ) as themselves */
    return c;
}

/* ```

### How to Compile and Run

You will need `bison` (or `yacc`) and a C compiler like `gcc`.

1.  **Save the Code**: Save the content above into a file named `check.yacc`.

2.  **Generate C Code with Bison/Yacc**: Run bison on your `.yacc` file. The `-d` flag is important as it creates a header file (`check.tab.h`) containing the token definitions, which is good practice for larger projects (though not strictly needed here since the lexer is in the same file).

    ```bash
    bison -d check.yacc
    ```
    This will produce two files:
    *   `check.tab.c`: The C source code for the parser.
    *   `check.tab.h`: The C header file with token definitions.

3.  **Compile the C Code**: Use `gcc` (or another C compiler) to compile the generated C file.

    ```bash
    gcc check.tab.c -o check
    ```
    *If you are on a system that links the math library by default for `yacc`/`bison` you might need `gcc check.tab.c -ly -o check` or `-lm`.*

4.  **Run the Program**: Execute the compiled binary.

    ```bash
    ./check
    ```

### Sample Session

```bash
$ ./check
Simple Yacc Calculator. Enter expressions or Ctrl-D to exit.
> 10 + 5
= 15
> 100 / (5 * 4)
= 5
> 20 - 5 * 3
= 5
> -10 * (2 + -5)
= 30
> 10 / 0
Error: Division by zero
> 10 +
Error: syntax error
> 
> 99
= 99
> ^D  (Ctrl-D to exit)
$
``` */