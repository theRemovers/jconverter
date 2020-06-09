#!/usr/bin/env python

import sys
import rgb2cry

class Options:
    def __init__(self):
        self.rgbFormat = True
        self.dithering = False
        self.asciiOutput = True
    def setRgb(self, b):
        self.rgbFormat = b
    def setDithering(self, b):
        self.dithering = b
    def setAscii(self, b):
        self.asciiOutput = b
    def toString(self):
        result = ""
        def add(x):
            nonlocal result
            if result == "":
                result += x
            else:
                result += " " + x
        if self.rgbFormat:
            add("-rgb")
        else:
            add("-cry")
        if self.dithering:
            add("--dithering")
        else:
            add("--no-dithering")
        if self.asciiOutput:
            add("--ascii")
        else:
            add("--binary")
        return result

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


options = Options()

arg = Arg()
arg.addArg("-rgb", 0, lambda _: options.setRgb(True), "rgb16 output format")
arg.addArg("-cry", 0, lambda _: options.setRgb(False), "cry16 output format")
arg.addArg("--dithering", 0, lambda _: options.setDithering(True), "enable dithering")
arg.addArg("--no-dithering", 0, lambda _: options.setDithering(False), "disable dithering")
arg.addArg("--ascii", 0, lambda _: options.setAscii(True), "source output (same as --assembly)")
arg.addArg("--assembly", 0, lambda _: options.setAscii(True), "assembly file")
arg.addArg("--no-ascii", 0, lambda _: options.setAscii(False), "data output (same as --binary)")
arg.addArg("--binary", 0, lambda _: options.setAscii(False), "binary file")

def processFile(x):
    print(options.toString())
    print(x)

arg.setAnonFun(processFile)

arg.parse(sys.argv[1:])
