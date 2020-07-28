# A Simple Webpage Processor

This is a simple static site generator created to replace Jekyll as the tool for building my personal website. It's a command-line utility for 64-bit Linux computers. It takes a single HTML file as an argument which it reads, processes, and then overwrites with the end result. File processing includes:

* Placing HTML elements common to all pages (css links, header, footer, etc.) into the source file.
* Parsing C/C++ and D code snippets and automatically tagging keywords, literals, comments, and pre-processor directives for syntax highlighting.
* Adding source file modification date to the resulting page.

This software is designed for a singular purpose. As an application, I expect few will find it useful. As source code, I hope its simplicity will inspire other software developers to build their own utilities.

##License

This software is licensed under the BSD Zero Clause License. See [LICENSE.txt](LICENSE.txt) for more information.