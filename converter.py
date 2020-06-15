#!/usr/bin/env python

import sys
import rgb2cry

rgbFormat = True
dithering = False
asciiOutput = True
def setRgb(b):
    global rgbFormat
    rgbFormat = b

def setDithering(b):
    global dithering
    dithering = b

def setAscii(b):
    global asciiOutput
    asciiOutput = b

def optionsToString():
    result = ""
    def add(x):
        nonlocal result
        if result == "":
            result += x
        else:
            result += " " + x
    if rgbFormat:
        add("-rgb")
    else:
        add("-cry")
    if dithering:
        add("--dithering")
    else:
        add("--no-dithering")
    if asciiOutput:
        add("--ascii")
    else:
        add("--binary")
    return result

def processFile(x):
    print(optionsToString())
    print(x)

class Arg:
    def __init__(self):
        self.specList = []
        self.anonFun = lambda x: print("Unknown argument %s" % x)

    def addArg(self, key, nargs, fun, doc):
        self.specList.append((key, nargs, fun, doc))

    def setAnonFun(self, fun):
        self.anonFun = fun

    def findSpec(self, arg):
        for (kwd, nargs, fun, doc) in self.specList:
            if kwd == arg:
                return (nargs, fun, doc)
        return None

    def parse(self, args):
        i = 0
        while i < len(args):
            arg = args[i]
            i += 1
            spec = self.findSpec(arg)
            if spec:
                nargs, fun, doc = spec
                funArgs = args[i: i+nargs]
                i += nargs
                fun(args)
            else:
                self.anonFun(arg)

arg = Arg()
arg.addArg("-rgb", 0, lambda _: setRgb(True), "rgb16 output format")
arg.addArg("-cry", 0, lambda _: setRgb(False), "cry16 output format")
arg.addArg("--dithering", 0, lambda _: setDithering(True), "enable dithering")
arg.addArg("--no-dithering", 0, lambda _: setDithering(False), "disable dithering")
arg.addArg("--ascii", 0, lambda _: setAscii(True), "source output (same as --assembly)")
arg.addArg("--assembly", 0, lambda _: setAscii(True), "assembly file")
arg.addArg("--no-ascii", 0, lambda _: setAscii(False), "data output (same as --binary)")
arg.addArg("--binary", 0, lambda _: setAscii(False), "binary file")
arg.setAnonFun(processFile)
arg.parse(sys.argv[1:])
