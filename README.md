# ZCLICONFIG

This repo will someday contain a zig library to analyse the command line,
environment variables and config file to constucvt the configuration
of an application, e.g. a CLI one.

It was inpired by zig-cli [https://github.com/sam701/zig-cli](https://github.com/sam701/zig-cli). It is basically an exercice in learning zig, but should be usable.

(c) Vassili Dzuba, 2025

Distributed under MIT license


## Functionnality

The library- provides a function that reads the arguments of the command line
and uses it to updates some zig structs.

It assumes the command line has the following structure (described in a semi-formal way):

    command_line := progname [option]* (operands* | subcommand+)
    option := ('-' char) || ('--' string) parameter?
    operand := string
    subcommand := subcommandname [option]* (operands* | subcommand+)

When requested, it supports the aggregation of multiples short optios, like in:

    ls -al

The procesisng is described programmatically by Zig structs.
