/*
Authors:   tspike (github.com/tspike2k)
Copyright: Copyright (c) 2020

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.
*/

import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.ctype: tolower;
import core.sys.posix.sys.stat;
import core.sys.linux.unistd;
import core.sys.linux.fcntl;
import core.stdc.stdio : SEEK_SET;
import logging;
import print;

nothrow @nogc:

enum TokenType
{
    UNKNOW, 
    META, // Pre-processor macros
    COMMENT,
    LITERAL,
    IDENTIFIER,
    
    TOTAL, 
}

struct Token
{
    TokenType type;
    char[] text;
};

struct Frontmatter
{
    // NOTE: Required frontmatter:
    char[] base; // The base path of the URL
    char[] title; // The page title
    char[] layout; // The page layout
    
    char[] section; // NOTE: 404 page doesn't have a nav section!
    char[] resource; // The type of resources listed on the page (only useful under the resources section
    char[] series; // The name of a given series of chapters (only used when using the "chapter" layout)
    char[] prevPage;
    char[] nextPage;
    char[] chapterIndex;
};

immutable string statCounterStr =
`<!-- Start of StatCounter Code for Default Guide -->
<script type="text/javascript">
var sc_project=10776028;
var sc_invisible=0;
var sc_security="f1df225b";
var scJsHost = (("https:" == document.location.protocol) ?
"https://secure." : "http://www.");
document.write("<sc"+"ript type='text/javascript' src='" +
scJsHost+
"statcounter.com/counter/counter.js'></"+"script>");
</script>
<noscript><div class="statcounter"><a title="shopify
analytics ecommerce tracking"
href="http://statcounter.com/shopify/" target="_blank"><img
class="statcounter"
src="http://c.statcounter.com/10776028/0/f1df225b/0/"
alt="shopify analytics ecommerce
tracking"></a></div></noscript>
<!-- End of StatCounter Code for Default Guide -->`;


immutable string[] navItems =
[
    "", "Home", 
    "tutorials", "Tutorials",
    "articles", "Articles",
    "software", "Software",
    "resources/tools", "Resources",
];

immutable string[] resourcesItems = 
[
    "resources/tools", "Tools",
    "resources/libraries", "Libraries",
    "resources/info", "Information",
    "resources/assets", "Assets",
];

static assert(navItems.length % 2 == 0, "Nav items must be a url/section name pair.");
static assert(resourcesItems.length % 2 == 0, "Resource items must be a url/section name pair.");

immutable string pageTop = 
`<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>{0}</title>
    <meta name="description" content="Discover tools, tutorials, tips, and resources to help make your own video game.">
    <link rel="stylesheet" href="{1}css/main.css">
`;

immutable string freelanceCosmonautHead = 
`    <link rel="stylesheet" href="css/gamestyle.css">
    <script type="text/javascript" src="js/phaser.min.js"></script>
    <script type="text/javascript" src="js/boot.js"></script>
    <script type="text/javascript" src="js/preload.js"></script>
    <script type="text/javascript" src="js/objectstates.js"></script>
    <script type="text/javascript" src="js/mainmenu.js"></script>
    <script type="text/javascript" src="js/maingame.js"></script>
    <script type="text/javascript" src="js/score.js"></script>
    <script type="text/javascript" src="js/gameover.js"></script>
    <script type="text/javascript" src="js/levelselect.js"></script>
`;

immutable string contentHeading = 
`<header>
    <h1>The Game Developer's Guidepost</h1>
    <img src="{0}img/site_logo.png" width="260" height="60" alt="The Game Developer's Guidepost">
    <p>Your guide to learning game development</p>
</header>
`;

immutable string chapterNav =
`<div class="chapterNav"><ul>
    <li><a href="{0}">&larr; prev</a></li>
    <li><a href="{1}">&uarr; index</a></li>
    <li><a href="{2}">next &rarr;</a></li>
</ul></div>
`;

immutable string footer = 
`<footer>
    <span class="footerElement"><a href="http://validator.w3.org/check?uri=referer" target="_blank">Validate HTML</a></span>
    <span class="footerElement"><a href="http://jigsaw.w3.org/css-validator/check/referer" target="_blank">Validate CSS</a></span>
    <span class="footerElement">Updated: {0}</span>
    <span class="footerElement">Copyright &copy; 2015-2020</span>
    <span class="footerElement"><a href="mailto:email@gamedevgp.net">email@gamedevgp.net</a></span>
</footer>
`;

string[] cppKeywords = 
[
    "asm",
    "auto",
    "bool",
    "break",
    "case",
    "catch",
    "char",
    "class",
    "const",
    "constexpr",
    "continue",
    "decltype",
    "default",
    "delete",
    "do",
    "double",
    "else",
    "enum",
    "explicit",
    "extern",
    "false",
    "float",
    "for",
    "friend",
    "goto",
    "if",
    "inline",
    "int",
    "long",
    "namespace",
    "new",
    "noexcept",
    "nullptr",
    "operator",
    "private",
    "protected",
    "public",
    "return",
    "short",
    "signed",
    "sizeof",
    "static",
    "static_assert",
    "static_cast",
    "struct",
    "switch",
    "template",
    "this",
    "throw",
    "true",
    "try",
    "typedef",
    "typeid",
    "union",
    "unsigned",
    "using",
    "virtual",
    "void",
    "volatile",
    "while",
];

// NOTE: Keywords list taken from Textadept lexer/dmd.lua
string[] dKeywords = 
[
"abstract", "align", "asm", "assert", "auto", "body", "break", "case", "cast",
"catch", "const", "continue", "debug", "default", "delete",
"deprecated", "do", "else", "extern", "export", "false", "final", "finally",
"for", "foreach", "foreach_reverse", "goto", "if", "import", "immutable",
"in", "inout", "invariant", "is", "lazy", "macro", "mixin", "new", "nothrow",
"null", "out", "override", "pragma", "private", "protected", "public", "pure",
"ref", "return", "scope", "shared", "static", "super", "switch",
"synchronized", "this", "throw","true", "try", "typeid", "typeof", "unittest",
"version", "virtual", "volatile", "while", "with", "__gshared", "__thread",
"__traits", "__vector", "__parameters",
"alias", "bool", "byte", "cdouble", "cent", "cfloat", "char", "class",
"creal", "dchar", "delegate", "double", "enum", "float", "function",
"idouble", "ifloat", "int", "interface", "ireal", "long", "module", "package",
"ptrdiff_t", "real", "short", "size_t", "struct", "template", "typedef",
"ubyte", "ucent", "uint", "ulong", "union", "ushort", "void", "wchar",
"string", "wstring", "dstring", "hash_t", "equals_t"
];

void main(string[] args)
{
    if (args.length != 2)
    {
        logErr!"page_processor expects a single filename as an argument. Aborting.\n";
        return;
    }
        
    char[4096] fileNameBuffer;
    auto sourceFileName = format!"{0}"(fileNameBuffer, args[1]);
    char[256] modDateBuffer;
    auto modDate = getModDate(sourceFileName, modDateBuffer);
    
    auto sourceFile = open(sourceFileName.ptr, O_RDONLY, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH);
    if (sourceFile == -1)
    {
        logErr!"Unable to open source file {0}. Aborting.\n"(sourceFileName);
        return;
    }
    
    char[] sourceString;
    {
        // TODO: Error checking!
        stat_t s = void;
        fstat(sourceFile, &s);
        size_t len = s.st_size;
    
        char* sourceStringRaw = cast(char*)calloc(1, len + 1);
        if(!sourceStringRaw)
        {
            logFatal!"Unable to request memory for source file {0}. Aborting.\n"(sourceFileName);
            return;
        }
        
        sourceString = sourceStringRaw[0 .. len];
    }
    
    read(sourceFile, sourceString.ptr, sourceString.length);
    close(sourceFile);
    
    char[] reader = sourceString;
    char[] frontmatterString;
    char[] frontmatterEnd = cast(char[])"<!--frontmatter--->";
    foreach(head; 0 .. reader.length)
    {
        if (stringBeginsWith(frontmatterEnd.ptr, &reader[head]))
        {
            frontmatterString = reader[0 .. head];
            reader = reader[head + frontmatterEnd.length .. reader.length];
            break;
        }
    }
    
    skipWhitespace(reader);
    
    if (frontmatterString.length == 0)
    {
        logFatal!"File {0} does not contain frontmatter. Aborting.\n"(sourceFileName);
        return;
    }
                
    Frontmatter frontmatter = void;
    processFrontmatter(frontmatterString, &frontmatter);
    
    if (frontmatter.base.length == 0)
    {
        logFatal!"Frontmatter for file {0} must contain \"base\" definition. Exiting.\n"(sourceFileName);
        return;
    }
                                  
    if (frontmatter.title.length == 0)
    {
        logFatal!"Frontmatter for file {0} must contain \"title\" definition. Exiting.\n"(sourceFileName);
        return;
    }

    if (frontmatter.layout.length == 0)
    {
        logFatal!"Frontmatter for file {0} must contain \"layout\" definition. Exiting.\n"(sourceFileName);
        return;
    }
    
    version(none)
    {
        int destFile = 1;    
    }
    else
    {    
        auto destFileName = sourceFileName;
        auto destFile = open(destFileName.ptr, O_WRONLY, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH);
        if(destFile == -1)
        {
            logFatal!"Unable to open destination file {0}. Aborting...\n"(destFileName);
            return;
        }
        
        scope(exit) close(destFile);
    }
    
    printFile!pageTop(destFile, frontmatter.title, frontmatter.base);
    if (stringBeginsWithIgnoreCase("freelanceCosmonaut".ptr, frontmatter.layout.ptr))
    {
        printFile!freelanceCosmonautHead(destFile);
    }
    
    printFile!"</head>\n"(destFile);
    printFile!"<body>\n"(destFile);
    
    printFile!"<nav><ul>\n"(destFile);
    
    for(size_t i = 0; i < navItems.length - 1; i += 2)
    {
        printFile!"\t<li><a href='{0}{1}'"(destFile, frontmatter.base, navItems[i]);
        if (frontmatter.section.length > 0 && stringBeginsWithIgnoreCase(navItems[i + 1].ptr, frontmatter.section.ptr))
        {
            printFile!" class='highlight-nav'"(destFile);
        }
        printFile!">{0}</a></li>\n"(destFile, navItems[i + 1]);
    }
    printFile!"</ul></nav>\n"(destFile);
    
    printFile!"<div id=\"wrapper\">\n"(destFile);
    printFile!contentHeading(destFile, frontmatter.base);
    
    if (stringBeginsWithIgnoreCase("chapter", frontmatter.layout.ptr))
    {
        printFile!"<h2>{0}</h2>\n"(destFile, frontmatter.series);
        printFile!chapterNav(destFile, frontmatter.prevPage, frontmatter.chapterIndex, frontmatter.nextPage);
    }
    else if (stringBeginsWithIgnoreCase("resources", frontmatter.layout.ptr))
    {
        printResourceNav(destFile, frontmatter);
    }
    
    processFileContent(destFile, reader);

    if (stringBeginsWithIgnoreCase("chapter", frontmatter.layout.ptr))
    {
        printFile!chapterNav(destFile, frontmatter.prevPage, frontmatter.chapterIndex, frontmatter.nextPage);
    }
    else if (stringBeginsWithIgnoreCase("resources", frontmatter.layout.ptr))
    {
        printResourceNav(destFile, frontmatter);
    }
    
    printFile!footer(destFile, modDate);
    printFile!"</div>\n"(destFile); // wrapper
    printFile!statCounterStr(destFile);
    printFile!"</body>\n"(destFile);
    printFile!"</html>\n"(destFile);
}

void printResourceNav(int destFile, Frontmatter frontmatter)
{
    printFile!"<div class=\"resourceNav\"><ul>\n"(destFile);
    
    for(int i = 0; i < resourcesItems.length; i += 2)
    {
        printFile!"\t<li><a href='{0}{1}'"(destFile, frontmatter.base, resourcesItems[i]);
        if (stringBeginsWithIgnoreCase(resourcesItems[i + 1].ptr, frontmatter.resource.ptr))
        {
            printFile!" class='highlight-nav'"(destFile);
        }
        printFile!">{0}</a></li>\n"(destFile, resourcesItems[i + 1]);
    }
    printFile!"</ul></div>\n"(destFile);
}

bool stringBeginsWithIgnoreCase(const char* a, const char* b)
{    
    size_t i = 0;
    while(a[i] != '\0')
    {
        if(tolower(a[i]) != tolower(b[i])) return false;
        i++;
    }
    
    return true;
}

bool stringBeginsWith(const char* a, const char* b)
{    
    size_t i = 0;
    while(a[i] != '\0')
    {
        if(a[i] != b[i]) return false;
        i++;
    }
    
    return true;
}

bool stringBeginsWith(char[] a, const char* b)
{   
    size_t i = 0;
    while(b[i] != '\0')
    {
        if (i >= a.length) return false;
        if (a[i] != b[i]) return false;
        i++;
    }
    
    return true;
}

bool stringsMatch(const char[] a, const char[] b)
{
    if(a.length != b.length) return false;
    
    foreach(i; 0 .. a.length)
    {
        if(a[i] != b[i]) return false;
    }
    
    return true;
}

char[] getModDate(char[] fileName, char[] buffer)
{
    import core.stdc.time;
    import core.stdc.string : strlen;
    
    stat_t statInfo;
    if (stat(fileName.ptr, &statInfo) == -1)
    {
        logWarn!"Unable to stat file {0}\n"(fileName);
        format!"Unknown"(buffer);
    }
    else
    {
        tm* localTime = localtime(&statInfo.st_mtime);
        strftime(buffer.ptr, buffer.length, "%B %d, %Y (%I:%M %p EST)", localTime);    
    }
    
    char[] result = buffer[0 .. strlen(buffer.ptr)];
    return result;
}

bool isAlpha(char c)
{
    return (c >= 'a' && c <= 'z')
        || (c >= 'A' && c <= 'Z');
}

bool isDigit(char c)
{
    return (c >= '0' && c <= '9');
}

bool isLineEnd(char c) {
    return (c == '\n') || (c == '\r');
}

bool isWhitespace(char c){
    return (c == ' ') || (c == '\t')
        || isLineEnd(c);
}

void skipWhitespace(ref char[] reader)
{
    size_t head = 0;
    while(head < reader.length && isWhitespace(reader[head]))
    {
        head++;
    }
    
    reader = reader[head .. reader.length];
}

Token nextToken(ref char[] reader)
{
    skipWhitespace(reader);

    Token token;
    size_t tokenEnd = reader.length;
    size_t readerSkip = 0;
    size_t tokenSkip = 0;
    
    if (reader.length > 0)
    {
        if (reader[0] == '#')
        {
            token.type = TokenType.META;
            
            bool ignoreLineEnd = false;
            foreach(head; 1 .. reader.length)
            {
                if(reader[head] == '\\') ignoreLineEnd = true;
                if (isLineEnd(reader[head]))
                {
                    if (!ignoreLineEnd)
                    {
                        tokenEnd = head;
                        break;
                    }
                    ignoreLineEnd = false;
                }
            }
        }
        else if (reader.length > 1 && reader[0] == '/' && reader[1] == '*')
        {
            token.type = TokenType.COMMENT;
            tokenSkip = 2;
            foreach(i; 2 .. reader.length - 1)
            {
                if (reader[i] == '*' && reader[i+1] == '/')
                {
                    tokenEnd = i;
                    readerSkip = 2;
                    break;
                }
            }
        }
        else if (reader.length > 1 && reader[0] == '/' && reader[1] == '/')
        {
            token.type = TokenType.COMMENT;
            tokenSkip = 2;
            foreach(i; 2 .. reader.length)
            {
                if (isLineEnd(reader[i]))
                {
                    tokenEnd = i;
                    break;
                }
            }
        }
        else if (reader[0] == '"')
        {
            token.type = TokenType.LITERAL;
        
            foreach(head; 1 .. reader.length)
            {
                if(reader[head] == '"' && !(head > 0 && reader[head-1] == '\\'))
                {
                    tokenEnd = head + 1;
                    break;
                }
            }
        }
        else if (isDigit(reader[0]))
        {
            token.type = TokenType.LITERAL;
            foreach(i; 0 .. reader.length)
            {
                if(!(isDigit(reader[i]) || reader[i] == '.' ))
                {
                    tokenEnd = i;
                    break;
                }
            }
        }
        else if (isAlpha(reader[0]))
        {
            token.type = TokenType.IDENTIFIER;
            foreach(head; 1 .. reader.length)
            {
                if(!(isDigit(reader[head]) || isAlpha(reader[head]) || reader[head] == '_'))
                {
                    tokenEnd = head;
                    break;
                }
            }
        }
        else
        {
            tokenEnd = 1;
        }
    }
    
    token.text = reader[tokenSkip .. tokenEnd];
    reader = reader[tokenEnd + readerSkip .. reader.length];
    
    return token;
}

void processFrontmatter(ref char[] reader, Frontmatter* frontmatter)
{
    memset(frontmatter, 0, Frontmatter.sizeof);
    
    auto key = nextToken(reader);
    auto value = nextToken(reader);
    while(reader.length > 0)
    {
        static foreach(member; __traits(allMembers, Frontmatter))
        {            
            if(stringBeginsWithIgnoreCase(member, key.text.ptr))
            {
                if (value.text.length >= 2)
                {
                    mixin("frontmatter." ~ member ~ " = value.text[1 .. $ -1];");                
                }
            }
        }

        key = nextToken(reader);
        value = nextToken(reader);
    }
    
    //logDebug!"frontmatter: {0}\n"(*frontmatter);
}

void skipWhitespaceAndComments(ref char[] reader)
{
    size_t head = 0;
    while(head < reader.length && isWhitespace(reader[head]))
    {
        head++;
        
        if (head < reader.length - 1 && reader[head] == '/' && reader[head+1] == '/')
        {
            while(reader.length > 0 && !isLineEnd(reader[head]))
            {
                head++;
            }
        }
    }
}

bool isKeyword(char[] s, string[] keywords)
{
    foreach(ref keyword; keywords)
    {
        if(stringsMatch(cast(char[])keyword, s)) return true;
    }
    
    return false;
}

void parseAndPrintCode(int destFile, char[] code, string[] keywords)
{
    char[] codeReader = code;
    char* whitespace = codeReader.ptr;
    while(codeReader.length > 0)
    {
        Token token = nextToken(codeReader);
        
        printFile!"{0}"(destFile, whitespace[0 .. token.text.ptr - whitespace]);
        whitespace = codeReader.ptr;
        
        switch(token.type)
        {
            case TokenType.META:
            {
                printFile!"<span class=\"meta\">{0}</span>"(destFile, token.text);
            } break;
            
            case TokenType.COMMENT:
            {
                printFile!"<span class=\"comment\">{0}</span>"(destFile, token.text);
            } break;
            
            case TokenType.LITERAL:
            {
                printFile!"<span class=\"literal\">{0}</span>"(destFile, token.text);
            } break;
            
            default:
            {
                if (isKeyword(token.text, keywords))
                {
                    printFile!"<span class=\"keyword\">{0}</span>"(destFile, token.text);
                }
                else
                {
                    printFile!"{0}"(destFile, token.text);
                }
            } break;
        }
    }
}

void processFileContent(int destFile, ref char[] reader)
{
    enum codeBegin = "<pre><code";
    enum codeEnd = "</code></pre>";
    char* printFrom = reader.ptr;
    size_t head = 0;
    while(head < reader.length)
    {
        if(stringBeginsWith(codeBegin, &reader[head]))
        {
            head += codeBegin.length;
            
            char[] codeTagContents = reader[codeBegin.length .. $];
            while(head < reader.length)
            {
                if (stringBeginsWith(">", &reader[head]))
                {
                    codeTagContents = reader[codeBegin.length .. head];
                    head++;
                    break;
                }
                
                head++;
            }
            
            printFile!"{0}"(destFile, reader[0 .. head]);
            reader = reader[head .. $];
            head = 0;
        
            // NOTE: We assume the default language for code snippets is D.
            char[] language = cast(char[])"d";
        
            auto token = nextToken(codeTagContents);
            while(token.text.length > 0 && !stringBeginsWith(">", token.text.ptr))
            {
                if(stringBeginsWith("class", token.text.ptr))
                {
                    nextToken(codeTagContents); // NOTE: Skip the equals sign after the class attribute
                    token = nextToken(codeTagContents);
                    
                    if(token.text.length > 2)
                    {
                        // NOTE: Trim off the opening and closing quotes
                        language = token.text[1 .. $ -1];
                    }
                }
                
                token = nextToken(codeTagContents);
            }
            
            string[] keywords = dKeywords;
            if(stringBeginsWith("d", language.ptr))
            {
                keywords = dKeywords;
            }
            else if(stringBeginsWith("c++", language.ptr))
            {
                keywords = cppKeywords;
            }
            
            head = 0;
            while(head < reader.length && !stringBeginsWith(codeEnd, &reader[head]))
            {
                head++;
            }
            
            char[] code = reader[0 .. head];
            reader = reader[head .. $];
            head = 0;
            
            parseAndPrintCode(destFile, code, keywords);
        }
        else
        {
            head++;        
        }
    }
    
    printFile!"{0}"(destFile, reader);
}