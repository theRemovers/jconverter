#!/usr/bin/env python

import os
import sys
import rgb2cry
import numpy
import math
from PIL import Image

rgbFormat = True # RGB16/CRY16
#dithering = False
asciiOutput = True
header = False
useTga2Cry = True
targetDir = "./"
overwrite = False
mode15bit = False
keepPositive = True
keepNegative = True
grayMode = False
glassMode = False
textureMode = False
clutMode = False
optClut = False
forceBpp = None
aworld = False

def setRgb(b):
    global rgbFormat
    rgbFormat = b

# def setDithering(b):
#     global dithering
#     dithering = b

def setAscii(b):
    global asciiOutput
    asciiOutput = b

def setHeader(b):
    global header
    header = b

def setMode15Bits(b):
    global mode15bit
    mode15bit = b

def setKeepPosNeg(positive, negative):
    global keepPositive
    global keepNegative
    keepPositive = positive
    keepNegative = negative

def setGrayMode():
    global grayMode
    grayMode = True

def setGlassMode():
    global glassMode
    glassMode = True

def setTextureMode():
    global textureMode
    textureMode = True

def setNormalMode():
    global grayMode
    global glassMode
    global textureMode
    grayMode = False
    glassMode = False
    textureMode = False

def setTga2Cry(b):
    global useTga2Cry
    useTga2Cry = b

def setTargetDir(s):
    global targetDir
    targetDir = s[0]

def setOverwrite(b):
    global overwrite
    overwrite = b

def setAworld(b):
    global aworld
    aworld = b

def setClutMode(b):
    global clutMode
    clutMode = b

def setOptClut(b):
    global optClut
    optClut = b

def setForceBpp(n):
    global forceBpp
    forceBpp = n

def clearForceBpp():
    global forceBpp
    forceBpp = None

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
    # if dithering:
    #     add("--dithering")
    # else:
    #     add("--no-dithering")
    if asciiOutput:
        add("--ascii")
    else:
        add("--binary")
    add("--target-dir %s" % targetDir)
    if clutMode:
        add("--clut")
    else:
        add("--no-clut")
    if optClut:
        add("--opt-clut")
    else:
        add("--no-opt-clut")
    if forceBpp:
        add("--force-bpp %d" % forceBpp)
    else:
        add("--no-force-bpp")
    if mode15bit:
        add("--15-bits")
    else:
        add("--16-bits")
    if grayMode:
        add("--gray")
    if glassMode:
        add("--glass")
    if textureMode:
        add("--texture")
    if keepPositive and not keepNegative:
        add("--positive")
    if keepNegative and not keepPositive:
        add("--negative")
    if keepPositive and keepNegative:
        add("--both")
    if overwrite:
        add("--overwrite")
    else:
        add("--no-overwrite")
    if useTga2Cry:
        add("--use-cry-table")
    else:
        add("--compute-cry")
    if aworld:
        add("--aworld")
    else:
        add("--no-aworld")
    if header:
        add("--header")
    else:
        add("--no-header")
    return result

def exponent_mantissa(width):
    assert (width > 0)
    nb = 31
    while width & 0x80000000 == 0:
        width <<= 1
        nb -= 1
    width <<= 1
    exp = nb & 0xf
    mant = numpy.right_shift(width, 30)
    m = (1 << 2) | mant
    blitter_width = numpy.right_shift(m << exp, 2)
    return (exp, mant, blitter_width)

def gen_flags(width, depth):
    exp, mant, blitter_width = exponent_mantissa(width)
    flags = (exp << 11) | (mant << 9) | (depth << 3)
    return flags, blitter_width

def check_blitter_width(width, blitter_width):
    if width != blitter_width:
        print("Invalid blitter width: %d != %d\n" % (blitter_width, width), file=sys.stderr)

class AsciiFile:
    def __init__(self, fileName):
        self.counter = 0
        self.file = open(fileName, 'w')
        self.dataHdr = None
    def newLine(self):
        if not(self.file):
            return
        if self.counter > 0:
            self.file.write("\n")
            self.counter = 0
    def outputData(self, data):
        if not(self.file):
            return
        if not(self.dataHdr):
            return
        if self.counter == 0:
            self.file.write("\t" + self.dataHdr + "\t")
        else:
            self.file.write(", ")
        self.file.write(data)
        self.counter+=1
        if self.counter >= 16:
            self.newLine()
    def setDataHeader(self, header):
        if self.dataHdr == header:
            return
        self.newLine()
        self.dataHdr = header
    def outputByte(self, v):
        self.setDataHeader("dc.b")
        self.outputData("$%02X" % v)
    def outputWord(self, v):
        self.setDataHeader("dc.w")
        self.outputData("$%04X" % v)
    def outputLong(self, v):
        self.setDataHeader("dc.l")
        self.outputData("$%08X" % v)
    def outputHeader(self, description, baseName, width, phraseWidth, height, depth):
        if not(self.file):
            return
        if clutMode:
            labelName = "_" + baseName + "Map"
        else:
            labelName = "_" + baseName + "Gfx"
        self.file.write("; Converted with 'Jaguar image converter' by Seb/The Removers (Python version)\n")
        self.file.write("\t.data\n")
        self.file.write("\t.globl\t%s\n" % labelName)
        self.file.write("\t.phrase\n")
        self.file.write("%s:\n" % labelName)
        self.file.write("; %d x %d\n" % (width, height))
        self.file.write("; %s\n" % description)
        self.file.write("; %d phrases per line\n" % phraseWidth)
        if header:
            self.file.write("\tdc.w\t%d, %d\n" % (height, width))
            flags, blitter_width = gen_flags(width, depth)
            check_blitter_width(width, blitter_width)
            self.file.write("\tdc.l\t$%08X\t; PITCH1|PIXEL%d|WID%d\n" % (flags, 1 << depth, blitter_width))
    def close(self):
        if not(self.file):
            return
        self.newLine()
        self.file.close()
        self.file = None

class BinaryFile:
    def __init__(self, fileName):
        self.file = open(fileName, 'wb')
    def outputByte(self, v):
        if not(self.file):
            return
        self.file.write(bytearray([v & 0xff]))
    def outputWord(self, v):
        if not(self.file):
            return
        self.file.write(bytearray([(v >> 8) & 0xff, v & 0xff]))
    def outputLong(self, v):
        if not(self.file):
            return
        self.file.write(bytearray([(v >> 24) & 0xff, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff]))
    def outputHeader(self, description, baseName, width, phraseWidth, height, depth):
        if not(self.file):
            return
        if header:
            self.outputWord(height)
            self.outputWord(width)
            flags, blitter_width = gen_flags(width, depth)
            check_blitter_width(width, blitter_width)
            self.outputLong(flags)
    def close(self):
        if not(self.file):
            return
        self.file.close()
        self.file = None

class Rgb24_of_P:
    def __init__(self, image):
        assert image.mode == "P"
        self.image = image
        self.palette = image.getpalette()
    def getPixel(self, x, y):
        w, h = self.getPhysicalSize()
        if 0 <= x and x < w and 0 <= y and y < h:
            idx = 3 * self.image.getpixel((x, y))
            r = self.palette[idx]
            g = self.palette[idx+1]
            b = self.palette[idx+2]
            return (r, g, b)
        else:
            return (0, 0, 0)
    def getPhysicalSize(self):
        return self.image.size

class Rgb24_of_RGB:
    def __init__(self, image):
        assert image.mode == "RGB"
        self.image = image
    def getPixel(self, x, y):
        w, h = self.getPhysicalSize()
        if 0 <= x and x < w and 0 <= y and y < h:
            return self.image.getpixel((x, y))
        else:
            return (0, 0, 0)
    def getPhysicalSize(self):
        return self.image.size

def asRGB24(image):
    if image.mode == "P":
        return Rgb24_of_P(image)
    elif image.mode == "RGB":
        return Rgb24_of_RGB(image)
    else:
        return None

class CLUT_of_P:
    def __init__(self, image):
        assert image.mode == "P"
        self.image = image
        self.palette = self.image.getpalette()
        nbColors = 0
        for (_, c) in self.image.getcolors():
            nbColors = max(0, c)
        nbColors += 1
        maxClut = forceBpp
        if optClut:
            if nbColors <= 2:
                maxClut = 2
            elif nbColors <= 4:
                maxClut = 4
            elif nbColors <= 16:
                maxClut = 16
            else:
                maxClut = 256
        if not(maxClut) or maxClut == 256:
            self.bppClut = 8
            self.mask = 0xff
        elif maxClut == 2:
            self.bppClut = 1
            self.mask = 0x1
        elif maxClut == 4:
            self.bppClut = 2
            self.mask = 0x3
        else:
            assert maxClut == 16
            self.bppClut = 4
            self.mask = 0xf
    def getBpp(self):
        return self.bppClut
    def getColor(self, idx):
        palette = self.image.getpalette()
        r = palette[3*idx]
        g = self.palette[3*idx+1]
        b = self.palette[3*idx+2]
        return (r, g, b)
    def getNbColors(self):
        return (2 ** self.bppClut)
    def getPhysicalSize(self):
        return self.image.size
    def getPixel(self, x, y):
        w, h = self.getPhysicalSize()
        if 0 <= x and x < w and 0 <= y and y < h:
            idx = self.image.getpixel((x, y))
        else:
            idx = 0
        assert idx & self.mask == idx
        if aworld and self.bppClut == 8:
            idx = idx + 16 * (1 + idx // 112)
        return idx
    def adjustWidth(self, w):
        q1 = w // (8 // self.bppClut)
        if not (w % (8 // self.bppClut) == 0):
            q1+=1
        q = q1 // 8
        if not (q1 % 8 == 0):
            q+=1
        return q * 8 * (8 // self.bppClut)
    def phraseWidth(self, w):
        q1 = w // (8 // self.bppClut)
        if not (w % (8 // self.bppClut) == 0):
            q1+=1
        assert (q1 % 8 == 0)
        return q1 / 8
    def depth(self):
        if self.bppClut == 1:
            return 0
        elif self.bppClut == 2:
            return 1
        elif self.bppClut == 4:
            return 2
        else:
            return 3
    def description(self):
        return ("Pixel map (%d bits per pixel)" % self.bppClut)

def asCLUT(image):
    if image.mode == "P":
        return CLUT_of_P(image)
    else:
        return None

class Codec_RGB:
    def description(self):
        if mode15bit:
            return "Jaguar RGB 15"
        else:
            return "Jaguar RGB 16"
    def ofRgb24(self, r, g, b):
        n = (((r >> 3) & 0x1f) << 11) | ((g >> 2) & 0x3f) | (((b >> 3) & 0x1f) << 6)
        if n != 0 and mode15bit:
            return (n | 1)
        else:
            return n
    def toRgb24(self, n):
        if mode15bit:
            n = n & 0xfffe
        r = ((n >> 11) & 0x1f) << 3
        g = (n & 0x3f) << 2
        b = ((n >> 6) & 0x1f) << 3
        return (r, g, b)

cos30 = math.cos(math.pi / 6)
sin30 = math.sin(math.pi / 6)
tan30 = math.tan(math.pi / 6)

class Codec_CRY:
    def __init__(self):
        self.red = [0, 0, 0, 0, 0, 0, 0, 0,
	            0, 0, 0, 0, 0, 0, 0, 0,
	            34, 34, 34, 34, 34, 34, 34, 34,
	            34, 34, 34, 34, 34, 34, 19, 0,
	            68, 68, 68, 68, 68, 68, 68, 68,
	            68, 68, 68, 68, 64, 43, 21, 0,
	            102, 102, 102, 102, 102, 102, 102, 102,
	            102, 102, 102, 95, 71, 47, 23, 0,
	            135, 135, 135, 135, 135, 135, 135, 135,
	            135, 135, 130, 104, 78, 52, 26, 0,
	            169, 169, 169, 169, 169, 169, 169, 169,
	            169, 170, 141, 113, 85, 56, 28, 0,
	            203, 203, 203, 203, 203, 203, 203, 203,
	            203, 183, 153, 122, 91, 61, 30, 0,
	            237, 237, 237, 237, 237, 237, 237, 237,
	            230, 197, 164, 131, 98, 65, 32, 0,
	            255, 255, 255, 255, 255, 255, 255, 255,
	            247, 214, 181, 148, 115, 82, 49, 17,
	            255, 255, 255, 255, 255, 255, 255, 255,
	            255, 235, 204, 173, 143, 112, 81, 51,
	            255, 255, 255, 255, 255, 255, 255, 255,
	            255, 255, 227, 198, 170, 141, 113, 85,
	            255, 255, 255, 255, 255, 255, 255, 255,
	            255, 255, 249, 223, 197, 171, 145, 119,
	            255, 255, 255, 255, 255, 255, 255, 255,
	            255, 255, 255, 248, 224, 200, 177, 153,
	            255, 255, 255, 255, 255, 255, 255, 255,
	            255, 255, 255, 255, 252, 230, 208, 187,
	            255, 255, 255, 255, 255, 255, 255, 255,
	            255, 255, 255, 255, 255, 255, 240, 221,
	            255, 255, 255, 255, 255, 255, 255, 255,
	            255, 255, 255, 255, 255, 255, 255, 255]
        self.green = [0, 17, 34, 51, 68, 85, 102, 119,
	              136, 153, 170, 187, 204, 221, 238, 255,
	              0, 19, 38, 57, 77, 96, 115, 134,
	              154, 173, 192, 211, 231, 250, 255, 255,
	              0, 21, 43, 64, 86, 107, 129, 150,
	              172, 193, 215, 236, 255, 255, 255, 255,
	              0, 23, 47, 71, 95, 119, 142, 166,
	              190, 214, 238, 255, 255, 255, 255, 255,
	              0, 26, 52, 78, 104, 130, 156, 182,
	              208, 234, 255, 255, 255, 255, 255, 255,
	              0, 28, 56, 85, 113, 141, 170, 198,
	              226, 255, 255, 255, 255, 255, 255, 255,
	              0, 30, 61, 91, 122, 153, 183, 214,
	              244, 255, 255, 255, 255, 255, 255, 255,
	              0, 32, 65, 98, 131, 164, 197, 230,
	              255, 255, 255, 255, 255, 255, 255, 255,
	              0, 32, 65, 98, 131, 164, 197, 230,
	              255, 255, 255, 255, 255, 255, 255, 255,
	              0, 30, 61, 91, 122, 153, 183, 214,
	              244, 255, 255, 255, 255, 255, 255, 255,
	              0, 28, 56, 85, 113, 141, 170, 198,
	              226, 255, 255, 255, 255, 255, 255, 255,
	              0, 26, 52, 78, 104, 130, 156, 182,
	              208, 234, 255, 255, 255, 255, 255, 255,
	              0, 23, 47, 71, 95, 119, 142, 166,
	              190, 214, 238, 255, 255, 255, 255, 255,
	              0, 21, 43, 64, 86, 107, 129, 150,
	              172, 193, 215, 236, 255, 255, 255, 255,
	              0, 19, 38, 57, 77, 96, 115, 134,
	              154, 173, 192, 211, 231, 250, 255, 255,
	              0, 17, 34, 51, 68, 85, 102, 119,
	              136, 153, 170, 187, 204, 221, 238, 255]
        self.blue = [255, 255, 255, 255, 255, 255, 255, 255,
	             255, 255, 255, 255, 255, 255, 255, 255,
	             255, 255, 255, 255, 255, 255, 255, 255,
	             255, 255, 255, 255, 255, 255, 240, 221,
	             255, 255, 255, 255, 255, 255, 255, 255,
	             255, 255, 255, 255, 252, 230, 208, 187,
	             255, 255, 255, 255, 255, 255, 255, 255,
	             255, 255, 255, 248, 224, 200, 177, 153,
	             255, 255, 255, 255, 255, 255, 255, 255,
	             255, 255, 249, 223, 197, 171, 145, 119,
	             255, 255, 255, 255, 255, 255, 255, 255,
	             255, 255, 227, 198, 170, 141, 113, 85,
	             255, 255, 255, 255, 255, 255, 255, 255,
	             255, 235, 204, 173, 143, 112, 81, 51,
	             255, 255, 255, 255, 255, 255, 255, 255,
	             247, 214, 181, 148, 115, 82, 49, 17,
	             237, 237, 237, 237, 237, 237, 237, 237,
	             230, 197, 164, 131, 98, 65, 32, 0,
	             203, 203, 203, 203, 203, 203, 203, 203,
	             203, 183, 153, 122, 91, 61, 30, 0,
	             169, 169, 169, 169, 169, 169, 169, 169,
	             169, 170, 141, 113, 85, 56, 28, 0,
	             135, 135, 135, 135, 135, 135, 135, 135,
	             135, 135, 130, 104, 78, 52, 26, 0,
	             102, 102, 102, 102, 102, 102, 102, 102,
	             102, 102, 102, 95, 71, 47, 23, 0,
	             68, 68, 68, 68, 68, 68, 68, 68,
	             68, 68, 68, 68, 64, 43, 21, 0,
	             34, 34, 34, 34, 34, 34, 34, 34,
	             34, 34, 34, 34, 34, 34, 19, 0,
	             0, 0, 0, 0, 0, 0, 0, 0,
	             0, 0, 0, 0, 0, 0, 0, 0]
    def description(self):
        if mode15bit:
            return "Jaguar CRY 15"
        else:
            return "Jaguar CRY 16"
    def ofRgb24_compute(self, r, g, b):
        def sat4(n):
            return min(max(n, 0), 15)
        y = max(r, g, b)
        if y == 0:
            return 0
        else:
            r_d = (255 * r) / y
            g_d = (255 * g) / y
            b_d = (255 * b) / y
            x = cos30 * (r_d - b_d)
            w = g_d - sin30 * (r_d + b_d)
            xp = x / (34 * cos30)
            if - x * tan30 <= w and w <= x * tan30:
                yp = w / 17
            else:
                yp = w / 34
            c = sat4(round(xp + 7.5)) & 0xf
            r = sat4(round(yp + 7.5)) & 0xf
            return self.getCRY(c, r, y)
    def ofRgb24_table(self, r, g, b):
        y = max(r, g, b)
        if y == 0:
            xx = 0
            yy = 0
            zz = 0
        else:
            xx = ((r * 255) // y) >> 3
            yy = ((g * 255) // y) >> 3
            zz = ((b * 255) // y) >> 3
        cr = rgb2cry.getValue(xx, yy, zz)
        c = (cr >> 4) & 0xf
        r = cr & 0xf
        return self.getCRY(c, r, y)
    def ofRgb24(self, r, g, b):
        if useTga2Cry:
            n=self.ofRgb24_table(r, g, b)
        else:
            n=self.ofRgb24_compute(r, g, b)
        if mode15bit:
            return (n & 0xfffe)
        else:
            return n
    def getCRY(self, c, r, y):
        def check_pos_neg(x):
            if keepPositive and keepNegative:
                return x
            elif keepPositive:
                return max(x, 0)
            elif keepNegative:
                return min(x, 0)
            else:
                return 0
        if grayMode:
            if glassMode:
                return (check_pos_neg(y - 0x80) & 0xff)
            else:
                return y
        elif glassMode:
            return ((check_pos_neg(c - 8) & 0xf) << 12) | ((check_pos_neg(r - 8) & 0xf) << 8) | ((check_pos_neg(y - 0x80)) & 0xff)
        elif textureMode:
            return (((c << 12) | (r << 8) | y) ^ 0x0080)
        else:
            return ((c << 12) | (r << 8) | y)
    def toRgb24(self, n):
        if mode15bit:
            n = n & 0xfffe
        i = c >> 8
        y = c & 0xff
        r = (self.red[i] * y) >> 8
        g = (self.green[i] * y) >> 8
        b = (self.blue[i] * y) >> 8
        return (r, g, b)

def targetName(baseName):
    if asciiOutput:
        return baseName + ".s"
    else:
        if clutMode:
            return baseName + ".map"
        else:
            if rgbFormat:
                return baseName + ".rgb"
            else:
                return baseName + ".cry"

def clutName(baseName):
    if asciiOutput:
        if rgbFormat:
            return baseName + "_rgb_pal.s"
        else:
            return baseName + "_cry_pal.s"
    else:
        if rgbFormat:
            return baseName + "_rgb.pal"
        else:
            return baseName + "_cry.pal"

def openOutFile(name):
    outFileName = os.path.join(targetDir, name)
    if os.path.exists(outFileName) and not overwrite:
        print("File %s already exists" % outFileName, file=sys.stderr)
        return None
    else:
        try:
            if asciiOutput:
                return AsciiFile(outFileName)
            else:
                return BinaryFile(outFileName)
        except:
            print("Error while creating file %s" % outFileName, file=sys.stderr)
            return None

def warn_adjusted_with(w, wp):
    if wp != w:
        print("Extending width from %d to %d\n" % (w, wp))

def processFile(srcFile):
    baseName = os.path.basename(os.path.splitext(srcFile)[0])
    if rgbFormat:
        conv = Codec_RGB()
    else:
        conv = Codec_CRY()
    if clutMode:
        img = asCLUT(Image.open(srcFile))
        if img:
            width, height = img.getPhysicalSize()
            tgtFile = openOutFile(targetName(baseName))
            if tgtFile:
                adjustedWidth = img.adjustWidth(width)
                warn_adjusted_with(width, adjustedWidth)
                phraseWidth = img.phraseWidth(adjustedWidth)
                depth = img.depth()
                tgtFile.outputHeader(img.description(), baseName, adjustedWidth, phraseWidth, height, depth)
                for y in range(height):
                    x = 0
                    while x < adjustedWidth:
                        value = 0
                        for i in range(8 // img.getBpp()):
                            idx = img.getPixel(x, y)
                            value = value << img.getBpp()
                            value = value | idx
                            x+=1
                        tgtFile.outputByte(value)
                tgtFile.close()
            clutFile = openOutFile(clutName(baseName))
            if clutFile:
                for idx in range(img.getNbColors()):
                    (r, g, b) = img.getColor(idx)
                    clutFile.outputWord(conv.ofRgb24(r, g, b))
                clutFile.close()
    else:
        img24 = asRGB24(Image.open(srcFile))
        if img24:
            width, height = img24.getPhysicalSize()
            tgtFile = openOutFile(targetName(baseName))
            if tgtFile:
                phraseWidth = (((width * 2) + 7) // 8)
                adjustedWidth = phraseWidth * 4
                depth = 4
                warn_adjusted_with(width, adjustedWidth)
                tgtFile.outputHeader(conv.description(), baseName, adjustedWidth, phraseWidth, height, depth)
                for y in range(height):
                    for x in range(adjustedWidth):
                        (r, g, b) = img24.getPixel(x, y)
                        tgtFile.outputWord(conv.ofRgb24(r, g, b))
                tgtFile.close()

class Arg:
    def __init__(self):
        self.specList = []
        self.anonFun = lambda x: print("Unknown argument %s" % x)
        self.addArg("-help", 0, lambda _ : self.showHelp(), "display this help")
        self.addArg("--help", 0, lambda _ : self.showHelp(), "display this help")

    def addArg(self, key, nargs, fun, doc):
        self.specList.append((key, nargs, fun, doc))

    def setAnonFun(self, fun):
        self.anonFun = fun

    def findSpec(self, arg):
        for (kwd, nargs, fun, doc) in self.specList:
            if kwd == arg:
                return (nargs, fun, doc)
        return None

    def showHelp(self):
        print("Atari Jaguar Image Converter by Seb/The Removers")
        print("Default options: %s" % optionsToString())
        for (kwd, nargs, fun, doc) in self.specList:
            print("  {0}: {1}".format(kwd, doc))

    def parse(self, args):
        i = 0
        parseSpec = True
        while i < len(args):
            arg = args[i]
            i += 1
            spec = None
            if parseSpec and 0 < len(arg):
                if arg == '--':
                    parseSpec = False
                    continue
                elif arg[0] == '-':
                    spec = self.findSpec(arg)
                    if spec:
                        nargs, fun, doc = spec
                        funArgs = args[i: i+nargs]
                        i += nargs
                        fun(funArgs)
                        continue
                    else:
                        print("Unknown argument %s" % arg)
                        break
            self.anonFun(arg)

arg = Arg()
arg.addArg("-rgb", 0, lambda _: setRgb(True), "rgb16 output format")
arg.addArg("-cry", 0, lambda _: setRgb(False), "cry16 output format")
# arg.addArg("--dithering", 0, lambda _: setDithering(True), "enable dithering")
# arg.addArg("--no-dithering", 0, lambda _: setDithering(False), "disable dithering")
arg.addArg("--ascii", 0, lambda _: setAscii(True), "source output (same as --assembly)")
arg.addArg("--assembly", 0, lambda _: setAscii(True), "assembly file")
arg.addArg("--no-ascii", 0, lambda _: setAscii(False), "data output (same as --binary)")
arg.addArg("--binary", 0, lambda _: setAscii(False), "binary file")
arg.addArg("--target-dir", 1, setTargetDir, "set target directory")
arg.addArg("--clut", 0, lambda _: setClutMode(True), "clut mode")
arg.addArg("--no-clut", 0, lambda _: setClutMode(False), "true color mode")
arg.addArg("--opt-clut", 0, lambda _: setOptClut(True), "optimise low resolution images")
arg.addArg("--no-opt-clut", 0, lambda _: setOptClut(False), "do not optimise low resolution images")
arg.addArg("--force-bpp", 1, lambda s: setForceBpp(int(s[0])), "force bpp in clut mode")
arg.addArg("--no-force-bpp", 0, lambda _: clearForceBpp(), "do not force bpp in clut mode")
arg.addArg("--15-bits", 0, lambda _: setMode15Bits(True), "15 bits mode")
arg.addArg("--16-bits", 0, lambda _: setMode15Bits(False), "16 bits mode")
arg.addArg("--gray", 0, lambda _: setGrayMode(), "gray (CRY intensities)")
arg.addArg("--glass", 0, lambda _: setGlassMode(), "glass (CRY relative)")
arg.addArg("--texture", 0, lambda _: setTextureMode(), "texture fixed intensities (CRY)")
arg.addArg("--positive", 0, lambda _: setKeepPosNeg(positive = True, negative = False), "keep only positive delta")
arg.addArg("--negative", 0, lambda _: setKeepPosNeg(positive = False, negative = True), "keep only negative delta")
arg.addArg("--both", 0, lambda _: setKeepPosNeg(positive = True, negative = True), "keep both delta types")
arg.addArg("--normal", 0, lambda _: setNormalMode(), "normal CRY")
arg.addArg("--overwrite", 0, lambda _: setOverwrite(True), "overwrite existing files")
arg.addArg("--no-overwrite", 0, lambda _: setOverwrite(False), "do not overwrite existing files")
arg.addArg("--use-cry-table", 0, lambda _: setTga2Cry(True), "use precalculed tga2cry conversion table to get CRY values")
arg.addArg("--compute-cry", 0, lambda _: setTga2Cry(False), "really compute CRY values")
arg.addArg("--aworld", 0, lambda _: setAworld(True), "enable Another World mode (undocumented)")
arg.addArg("--no-aworld", 0, lambda _: setAworld(False), "disable Another World mode (undocumented)")
arg.addArg("--header", 0, lambda _: setHeader(True), "emit header for bitmap")
arg.addArg("--no-header", 0, lambda _: setHeader(False), "do not emit header for bitmap")
arg.setAnonFun(processFile)
arg.parse(sys.argv[1:])
